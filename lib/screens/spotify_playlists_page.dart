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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/spotify_service.dart';
import 'package:musify/utilities/common_variables.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/section_header.dart';

class SpotifyPlaylistsPage extends StatefulWidget {
  const SpotifyPlaylistsPage({super.key});

  @override
  State<SpotifyPlaylistsPage> createState() => _SpotifyPlaylistsPageState();
}

class _SpotifyPlaylistsPageState extends State<SpotifyPlaylistsPage> {
  final _spotifyService = SpotifyService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
    });

    await _spotifyService.refreshPlaylists();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify Playlists'),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.arrow_clockwise_24_filled),
            onPressed: _loadPlaylists,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _spotifyService.spotifyPlaylistsNotifier,
              builder: (context, playlists, child) {
                if (playlists.isEmpty) {
                  return Center(
                    child: Text(
                      'No playlists found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: commonSingleChildScrollViewPadding,
                  child: Column(
                    children: [
                      SectionHeader(title: 'Your Spotify Playlists'),
                      ...playlists.map((playlist) {
                        return PlaylistBar(
                          playlist['title'],
                          playlist,
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
