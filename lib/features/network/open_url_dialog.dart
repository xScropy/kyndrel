import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/net/webdav.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a network stream: HLS, DASH, RTSP, HTTP(S), SMB, or a WebDAV
/// folder to browse (task 4.5).
Future<void> showOpenUrlDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const OpenUrlDialog());

/// Supported schemes and what they're for (shown as help).
const networkSchemes = {
  'https:// http://': 'Files, HLS (.m3u8), DASH (.mpd), WebDAV',
  'rtsp:// rtmp://': 'Cameras and live streams',
  'smb://': 'Windows shares (needs an SMB-enabled mpv build)',
};

class OpenUrlDialog extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OpenUrlDialog> createState() => OpenUrlDialogState();
}

class OpenUrlDialogState extends ConsumerState<OpenUrlDialog> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _login = false;
  String? _error;
  bool _busy = false;

  /// WebDAV browsing state.
  List<DavEntry>? _entries;
  late Uri _folder;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  List<String> get _headers => _login && _user.text.isNotEmpty
      ? [basicAuthHeader(_user.text, _password.text)]
      : const [];

  /// `smb://user:pass@host/…` for SMB; headers for HTTP.
  String _withLogin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !_login || _user.text.isEmpty) return url;
    if (uri.scheme == 'smb' || uri.scheme == 'rtsp') {
      return uri
          .replace(
            userInfo:
                '${Uri.encodeComponent(_user.text)}:'
                '${Uri.encodeComponent(_password.text)}',
          )
          .toString();
    }
    return url;
  }

  static bool isValid(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        const {
          'http',
          'https',
          'rtsp',
          'rtmp',
          'rtmps',
          'smb',
          'ftp',
          'udp',
          'srt',
        }.contains(uri.scheme) &&
        uri.host.isNotEmpty;
  }

  Future<void> _remember(String url) async {
    // Never store passwords.
    final clean = Uri.parse(url).replace(userInfo: '').toString();
    await ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            recentUrls: [
              clean,
              ...s.recentUrls.where((u) => u != clean),
            ].take(10).toList(),
          ),
        );
  }

  Future<void> _play(List<String> urls) async {
    final service = ref.read(playerServiceProvider);
    for (final u in urls) {
      service.setSourceHeaders(u, _headers);
    }
    await _remember(urls.first);
    await ref.read(playlistProvider.notifier).openAll(urls);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _open() async {
    final url = _url.text.trim();
    if (!isValid(url)) {
      setState(
        () => _error = 'Enter a full address, e.g. https://… or rtsp://…',
      );
      return;
    }
    final uri = Uri.parse(url);
    // A folder-looking http(s) address: try WebDAV first.
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.path.endsWith('/')) {
      await _browse(uri);
      return;
    }
    await _play([_withLogin(url)]);
  }

  Future<void> _browse(Uri folder) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final dav = WebDavClient(
      user: _login ? _user.text : '',
      password: _login ? _password.text : '',
    );
    try {
      final entries = await dav.list(folder);
      setState(() {
        _entries = entries;
        _folder = folder;
      });
    } on WebDavException catch (e) {
      setState(() => _error = e.message);
    } on Exception catch (e) {
      setState(() => _error = "Couldn't open the folder: $e");
    } finally {
      dav.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isMedia(DavEntry e) => PlaylistController.mediaExtensions.any(
    (x) => e.name.toLowerCase().endsWith(x),
  );

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(settingsProvider.select((s) => s.recentUrls));
    final entries = _entries;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Open network stream',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('url-field'),
                controller: _url,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'https://…/video.m3u8, rtsp://…, smb://…',
                ),
                onSubmitted: (_) => unawaited(_open()),
              ),
              CheckboxListTile(
                key: const Key('url-login'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _login,
                onChanged: (v) => setState(() => _login = v ?? false),
                title: const Text('Needs a login'),
              ),
              if (_login)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('url-user'),
                        controller: _user,
                        decoration: const InputDecoration(labelText: 'User'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('url-password'),
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                    ),
                  ],
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const Key('url-error'),
                    style: const TextStyle(color: KyndrelColors.error),
                  ),
                ),
              const SizedBox(height: 12),
              if (entries != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Uri.decodeComponent(_folder.path),
                        style: KyndrelTheme.sectionLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_folder.pathSegments
                        .where((s) => s.isNotEmpty)
                        .isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            unawaited(_browse(_folder.resolve('..'))),
                        child: const Text('Up'),
                      ),
                    TextButton(
                      key: const Key('dav-play-all'),
                      onPressed: entries.any(_isMedia)
                          ? () => unawaited(
                              _play([
                                for (final e in entries.where(_isMedia))
                                  e.url.toString(),
                              ]),
                            )
                          : null,
                      child: const Text('Play folder'),
                    ),
                  ],
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in entries)
                        if (e.isFolder || _isMedia(e))
                          ListTile(
                            key: Key('dav-${e.name}'),
                            dense: true,
                            leading: Icon(
                              e.isFolder ? Icons.folder : Icons.movie_outlined,
                            ),
                            title: Text(e.name),
                            onTap: () => unawaited(
                              e.isFolder
                                  ? _browse(e.url)
                                  : _play([e.url.toString()]),
                            ),
                          ),
                    ],
                  ),
                ),
              ] else if (recent.isNotEmpty) ...[
                const Text('RECENT', style: KyndrelTheme.sectionLabel),
                for (final u in recent.take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, size: 18),
                    title: Text(
                      u,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _url.text = u,
                  ),
              ] else
                for (final e in networkSchemes.entries)
                  Text(
                    '${e.key}  ${e.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: KyndrelColors.textSecondary,
                    ),
                  ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('url-open'),
                    onPressed: _busy ? null : () => unawaited(_open()),
                    child: Text(_busy ? 'Connecting…' : 'Open'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
