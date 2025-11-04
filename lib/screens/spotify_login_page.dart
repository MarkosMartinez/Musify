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

import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/spotify_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SpotifyLoginPage extends StatefulWidget {
  const SpotifyLoginPage({super.key});

  @override
  State<SpotifyLoginPage> createState() => _SpotifyLoginPageState();
}

class _SpotifyLoginPageState extends State<SpotifyLoginPage> {
  final _spotifyService = SpotifyService();
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _showManualEntry = false;
  final _spDcController = TextEditingController();
  final _spKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            await _checkForCookies();
          },
          onWebResourceError: (WebResourceError error) {
            showToast(context, 'Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://accounts.spotify.com/login'));
  }

  Future<void> _checkForCookies() async {
    try {
      final cookieManager = WebViewCookieManager();
      final cookies =
          await cookieManager.getCookies(Uri.parse('https://spotify.com'));

      String? spDc;
      String? spKey;

      for (final cookie in cookies) {
        if (cookie.name == 'sp_dc') {
          spDc = cookie.value;
        } else if (cookie.name == 'sp_key') {
          spKey = cookie.value;
        }
      }

      if (spDc != null && spDc.isNotEmpty) {
        // Found cookies, attempt login
        final success =
            await _spotifyService.loginWithCookies(spDc, spKey ?? '');

        if (success && mounted) {
          showToast(context, 'Successfully logged in to Spotify!');
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      // Error checking cookies, continue
    }
  }

  Future<void> _loginWithManualCookies() async {
    final spDc = _spDcController.text.trim();
    final spKey = _spKeyController.text.trim();

    if (spDc.isEmpty) {
      showToast(context, 'Please enter sp_dc cookie');
      return;
    }

    final success = await _spotifyService.loginWithCookies(spDc, spKey);

    if (success && mounted) {
      showToast(context, 'Successfully logged in to Spotify!');
      Navigator.of(context).pop(true);
    } else if (mounted) {
      showToast(context, 'Login failed. Please check your cookies.');
    }
  }

  @override
  void dispose() {
    _spDcController.dispose();
    _spKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login to Spotify'),
        actions: [
          IconButton(
            icon: Icon(_showManualEntry ? Icons.web : Icons.edit),
            onPressed: () {
              setState(() {
                _showManualEntry = !_showManualEntry;
              });
            },
            tooltip: _showManualEntry ? 'Use WebView' : 'Manual Entry',
          ),
        ],
      ),
      body: _showManualEntry ? _buildManualEntry() : _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildManualEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Manual Cookie Entry',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'To get your cookies:\n'
            '1. Login to Spotify on your browser\n'
            '2. Open Developer Tools (F12)\n'
            '3. Go to:\n'
            '   • Chrome/Edge: Application > Cookies\n'
            '   • Firefox: Storage > Cookies\n'
            '   • Safari: Storage > Cookies\n'
            '4. Select https://open.spotify.com\n'
            '5. Find and copy sp_dc (required) and sp_key (optional)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _spDcController,
            decoration: const InputDecoration(
              labelText: 'sp_dc (Required)',
              border: OutlineInputBorder(),
              hintText: 'Paste your sp_dc cookie here',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _spKeyController,
            decoration: const InputDecoration(
              labelText: 'sp_key (Optional)',
              border: OutlineInputBorder(),
              hintText: 'Paste your sp_key cookie here',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loginWithManualCookies,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Login'),
            ),
          ),
        ],
      ),
    );
  }
}
