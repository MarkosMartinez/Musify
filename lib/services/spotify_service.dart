/*
 *     Copyright (C) 2025 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/logger_service.dart';

class SpotifyService {
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal();

  final _logger = Logger();
  String? _spDc;
  String? _spKey;
  bool _isLoggedIn = false;

  ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
  ValueNotifier<List<Map<String, dynamic>>> spotifyPlaylistsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static const String _spotifyApiBase = 'https://api.spotify.com/v1';
  static const String _spotifyWebBase = 'https://spclient.wg.spotify.com';

  Future<void> initialize() async {
    await loadCredentials();
  }

  Future<void> loadCredentials() async {
    _spDc = await getData('settings', 'spotifySpDc') as String?;
    _spKey = await getData('settings', 'spotifySpKey') as String?;
    _isLoggedIn = _spDc != null && _spDc!.isNotEmpty;
    isLoggedInNotifier.value = _isLoggedIn;

    if (_isLoggedIn) {
      await refreshPlaylists();
    }
  }

  Future<bool> loginWithCookies(String spDc, String spKey) async {
    try {
      _spDc = spDc.trim();
      _spKey = spKey.trim();

      // Verify credentials by making a test request
      final isValid = await _validateCredentials();

      if (isValid) {
        await addOrUpdateData('settings', 'spotifySpDc', _spDc);
        await addOrUpdateData('settings', 'spotifySpKey', _spKey);
        _isLoggedIn = true;
        isLoggedInNotifier.value = true;
        await refreshPlaylists();
        return true;
      } else {
        _spDc = null;
        _spKey = null;
        return false;
      }
    } catch (e) {
      _logger.log('Spotify login error', e);
      return false;
    }
  }

  Future<bool> _validateCredentials() async {
    try {
      final response = await http.get(
        Uri.parse('$_spotifyApiBase/me'),
        headers: _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logger.log('Spotify credential validation error', e);
      return false;
    }
  }

  Map<String, String> _getHeaders() {
    final cookies = <String>[];
    if (_spDc != null) cookies.add('sp_dc=$_spDc');
    if (_spKey != null) cookies.add('sp_key=$_spKey');

    return {
      'Cookie': cookies.join('; '),
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!_isLoggedIn) return null;

    try {
      final response = await http.get(
        Uri.parse('$_spotifyApiBase/me'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      _logger.log('Error fetching Spotify profile', e);
    }
    return null;
  }

  String? _getImageUrl(dynamic images) {
    if (images != null && images is List && images.isNotEmpty) {
      return images[0]['url'] as String?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists() async {
    if (!_isLoggedIn) return [];

    try {
      final playlists = <Map<String, dynamic>>[];
      var nextUrl = '$_spotifyApiBase/me/playlists?limit=50';

      while (nextUrl.isNotEmpty) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List;

          for (final item in items) {
            playlists.add({
              'id': item['id'],
              'title': item['name'],
              'description': item['description'] ?? '',
              'image': _getImageUrl(item['images']) ?? '',
              'owner': item['owner']['display_name'] ?? '',
              'tracks_total': item['tracks']?['total'] ?? 0,
              'is_spotify': true,
            });
          }

          nextUrl = data['next'] ?? '';
        } else {
          break;
        }
      }

      return playlists;
    } catch (e) {
      _logger.log('Error fetching Spotify playlists', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPlaylistTracks(String playlistId) async {
    if (!_isLoggedIn) return [];

    try {
      final tracks = <Map<String, dynamic>>[];
      var nextUrl = '$_spotifyApiBase/playlists/$playlistId/tracks?limit=50';

      while (nextUrl.isNotEmpty) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List;

          for (final item in items) {
            if (item['track'] == null) continue;
            final track = item['track'];

            final artists = track['artists'];
            final artistName = artists != null && artists is List && artists.isNotEmpty
                ? artists[0]['name']
                : '';

            tracks.add({
              'id': track['id'],
              'title': track['name'],
              'artist': artistName,
              'album': track['album']?['name'] ?? '',
              'image': _getImageUrl(track['album']?['images']) ?? '',
              'duration': track['duration_ms'] ?? 0,
              'uri': track['uri'],
            });
          }

          nextUrl = data['next'] ?? '';
        } else {
          break;
        }
      }

      return tracks;
    } catch (e) {
      _logger.log('Error fetching playlist tracks', e);
      return [];
    }
  }

  Future<bool> addTrackToPlaylist(String playlistId, String trackUri) async {
    if (!_isLoggedIn) return false;

    try {
      final response = await http.post(
        Uri.parse('$_spotifyApiBase/playlists/$playlistId/tracks'),
        headers: _getHeaders(),
        body: json.encode({
          'uris': [trackUri],
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      _logger.log('Error adding track to Spotify playlist', e);
      return false;
    }
  }

  Future<bool> removeTrackFromPlaylist(
    String playlistId,
    String trackUri,
  ) async {
    if (!_isLoggedIn) return false;

    try {
      final response = await http.delete(
        Uri.parse('$_spotifyApiBase/playlists/$playlistId/tracks'),
        headers: _getHeaders(),
        body: json.encode({
          'tracks': [
            {'uri': trackUri}
          ],
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logger.log('Error removing track from Spotify playlist', e);
      return false;
    }
  }

  String _buildSearchQuery(String title, String artist) {
    // Remove special characters that might interfere with search
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final cleanArtist = artist.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    
    // Build query with proper formatting
    final parts = <String>[];
    if (cleanTitle.isNotEmpty) parts.add('track:$cleanTitle');
    if (cleanArtist.isNotEmpty) parts.add('artist:$cleanArtist');
    
    return parts.join(' ');
  }

  Future<String?> searchTrack(String title, String artist) async {
    if (!_isLoggedIn) return null;

    try {
      final query = _buildSearchQuery(title, artist);
      if (query.isEmpty) return null;

      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('$_spotifyApiBase/search?q=$encodedQuery&type=track&limit=1'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final tracks = data['tracks']?['items'] as List?;

        if (tracks != null && tracks.isNotEmpty) {
          return tracks[0]['uri'] as String;
        }
      }
    } catch (e) {
      _logger.log('Error searching track on Spotify', e);
    }
    return null;
  }

  Future<void> refreshPlaylists() async {
    if (_isLoggedIn) {
      final playlists = await getUserPlaylists();
      spotifyPlaylistsNotifier.value = playlists;
    }
  }

  Future<void> logout() async {
    _spDc = null;
    _spKey = null;
    _isLoggedIn = false;
    isLoggedInNotifier.value = false;
    spotifyPlaylistsNotifier.value = [];

    await deleteData('settings', 'spotifySpDc');
    await deleteData('settings', 'spotifySpKey');
  }

  bool get isLoggedIn => _isLoggedIn;
}
