import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/net/dlna_server.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/playlist/playlist.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/core/utils/media_format.dart';
import 'package:kyndrel/features/browse/browse_sources.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Where Browse is.
@immutable
class BrowseState {
  const new({
    this.stack = const [],
    this.entries,
    this.loading = false,
    this.error,
    this.notListable = false,
    this.needsPassword,
    this.query = '',
    this.servers = const [],
    this.discovering = false,
  });

  /// From the root place to the folder shown; empty shows the places.
  final List<BrowseLocation> stack;
  final List<BrowseEntry>? entries;
  final bool loading;
  final String? error;
  final bool notListable;

  /// A server waiting for its password.
  final SavedServer? needsPassword;
  final String query;

  /// Media servers found on the network.
  final List<DlnaServer> servers;
  final bool discovering;

  BrowseState copyWith({
    List<BrowseLocation>? stack,
    List<BrowseEntry>? Function()? entries,
    bool? loading,
    String? Function()? error,
    bool? notListable,
    SavedServer? Function()? needsPassword,
    String? query,
    List<DlnaServer>? servers,
    bool? discovering,
  }) => BrowseState(
    stack: stack ?? this.stack,
    entries: entries != null ? entries() : this.entries,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
    notListable: notListable ?? this.notListable,
    needsPassword: needsPassword != null ? needsPassword() : this.needsPassword,
    query: query ?? this.query,
    servers: servers ?? this.servers,
    discovering: discovering ?? this.discovering,
  );
}

/// Browse: this device's folders and network servers, like MX Player's
/// file view and VLC's "Local network" (task 8.7).
class BrowseController extends Notifier<BrowseState> {
  int _load = 0;

  @override
  BrowseState build() => const BrowseState();

  BrowseService get _service => ref.read(browseServiceProvider);

  Future<void> open(BrowseLocation location) =>
      _show([...state.stack, location]);

  Future<void> back() async {
    if (state.stack.length <= 1) {
      state = const BrowseState().copyWith(servers: state.servers);
      return;
    }
    await _show(state.stack.sublist(0, state.stack.length - 1));
  }

  /// Jumps to breadcrumb [index].
  Future<void> goTo(int index) => _show(state.stack.sublist(0, index + 1));

  Future<void> reload() => _show(state.stack);

  void search(String query) => state = state.copyWith(query: query);

  Future<void> setPassword(SavedServer server, String password) async {
    _service.passwords[server.key] = password;
    await reload();
  }

  Future<void> _show(List<BrowseLocation> stack) async {
    final id = ++_load;
    state = state.copyWith(
      stack: stack,
      entries: () => null,
      loading: true,
      error: () => null,
      notListable: false,
      needsPassword: () => null,
      query: '',
    );
    try {
      final entries = await _service.list(stack.last);
      if (id != _load) return;
      state = state.copyWith(entries: () => entries, loading: false);
    } on NeedsPassword catch (e) {
      if (id == _load) {
        state = state.copyWith(loading: false, needsPassword: () => e.server);
      }
    } on BrowseNotListable {
      if (id == _load) {
        state = state.copyWith(loading: false, notListable: true);
      }
    } on Object catch (e) {
      if (id == _load) {
        state = state.copyWith(loading: false, error: () => '$e');
      }
    }
  }

  /// Looks for media servers on the network.
  Future<void> discover() async {
    if (state.discovering) return;
    state = state.copyWith(discovering: true);
    try {
      final found = await _service.discover();
      state = state.copyWith(servers: found, discovering: false);
    } on Object {
      state = state.copyWith(discovering: false);
    }
  }
}

final browseProvider = NotifierProvider<BrowseController, BrowseState>(
  BrowseController.new,
);

/// Plays [files] from [start], with login headers where needed.
Future<void> playEntries(
  WidgetRef ref,
  List<BrowseEntry> files, {
  int start = 0,
}) async {
  final service = ref.read(playerServiceProvider);
  for (final f in files) {
    if (f.headers.isNotEmpty) service.setSourceHeaders(f.play!, f.headers);
  }
  await ref.read(playlistProvider.notifier).openAll([
    for (final f in files) f.play!,
  ], start: start);
}

class BrowseView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browseProvider);
    return state.stack.isEmpty ? const _Places() : const _Folder();
  }
}

/// This device's places and the network servers.
class _Places extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final state = ref.watch(browseProvider);
    final c = ref.read(browseProvider.notifier);
    final roots = ref.watch(localRootsProvider);
    final servers = savedServers(settings);
    const label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: KyndrelColors.sectionLabel,
      letterSpacing: KyndrelTokens.sectionLabelLetterSpacing,
    );
    return ListView(
      key: const Key('browse-places'),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(
            l.libraryBrowse,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Text(l.browseDevice.toUpperCase(), style: label),
        ),
        if (roots.value == null)
          const ListTile(
            key: Key('browse-roots-loading'),
            leading: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KyndrelColors.accent,
              ),
            ),
          ),
        for (final r in roots.value ?? const <LocalLocation>[])
          ListTile(
            key: Key('browse-root-${r.label}'),
            leading: Icon(
              r.title == 'Home' ? Icons.home_outlined : Icons.folder_outlined,
            ),
            title: Text(r.title == 'Home' ? l.browseHome : r.label),
            subtitle: Text(r.path),
            onTap: () => unawaited(c.open(r)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(l.browseNetwork.toUpperCase(), style: label),
              ),
              IconButton(
                key: const Key('browse-discover'),
                tooltip: l.libraryRefresh,
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(localRootsProvider);
                  unawaited(c.discover());
                },
              ),
            ],
          ),
        ),
        for (final s in servers)
          ListTile(
            key: Key('browse-server-${s.name}'),
            leading: Icon(switch (s.kind) {
              ServerKind.webdav => Icons.cloud_outlined,
              ServerKind.ftp => Icons.dns_outlined,
              ServerKind.smb => Icons.lan_outlined,
              ServerKind.sftp => Icons.terminal,
            }),
            title: Text(s.name),
            subtitle: Text('${s.kind.name.toUpperCase()} · ${s.address}'),
            onTap: () => s.kind.listable
                ? unawaited(c.open(ServerLocation(s, '/', title: s.name)))
                : unawaited(
                    ref.read(playlistProvider.notifier).open(s.address),
                  ),
            trailing: IconButton(
              tooltip: l.browseRemove,
              icon: const Icon(Icons.close),
              onPressed: () => updateSettings(
                ref,
                (x) => x.copyWith(
                  browseServers: [
                    for (final j in x.browseServers)
                      if (try_(
                            () => SavedServer.fromJson(
                              jsonDecode(j) as Map<String, Object?>,
                            ),
                          ) !=
                          s)
                        j,
                  ],
                ),
              ),
            ),
          ),
        if (state.discovering)
          ListTile(
            leading: const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KyndrelColors.accent,
              ),
            ),
            title: Text(l.browseSearching),
          ),
        for (final d in state.servers)
          ListTile(
            key: Key('browse-dlna-${d.name}'),
            leading: const Icon(Icons.storage),
            title: Text(d.name),
            subtitle: const Text('DLNA'),
            onTap: () => unawaited(c.open(DlnaLocation(d, '0', d.name))),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('browse-add-server'),
              onPressed: () => unawaited(_addServer(context, ref)),
              icon: const Icon(Icons.add),
              label: Text(l.browseAddServer),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _addServer(BuildContext context, WidgetRef ref) async {
  final server = await showDialog<SavedServer>(
    context: context,
    builder: (_) => const _ServerDialog(),
  );
  if (server == null) return;
  updateSettings(
    ref,
    (s) => s.copyWith(
      browseServers: [...s.browseServers, jsonEncode(server.toJson())],
    ),
  );
}

class _ServerDialog extends StatefulWidget {
  const new();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _user = TextEditingController();
  ServerKind _kind = ServerKind.webdav;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _user.dispose();
    super.dispose();
  }

  static String _hint(ServerKind k) => switch (k) {
    ServerKind.webdav => 'https://nas.local/dav/',
    ServerKind.ftp => 'ftp://192.168.1.10/',
    ServerKind.smb => 'smb://nas/videos/',
    ServerKind.sftp => 'sftp://nas/home/me/',
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const Key('browse-server-dialog'),
      title: Text(l.browseAddServer),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ServerKind>(
              key: const Key('server-kind'),
              initialValue: _kind,
              decoration: InputDecoration(labelText: l.browseServerKind),
              dropdownColor: KyndrelColors.surface,
              items: [
                for (final k in ServerKind.values)
                  DropdownMenuItem(value: k, child: Text(k.name.toUpperCase())),
              ],
              onChanged: (k) => setState(() => _kind = k ?? _kind),
            ),
            if (!_kind.listable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.browseOpenOnly,
                  style: const TextStyle(
                    color: KyndrelColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            TextField(
              key: const Key('server-name'),
              controller: _name,
              decoration: InputDecoration(labelText: l.browseServerName),
            ),
            TextField(
              key: const Key('server-address'),
              controller: _address,
              decoration: InputDecoration(
                labelText: l.browseServerAddress,
                hintText: _hint(_kind),
              ),
            ),
            TextField(
              key: const Key('server-user'),
              controller: _user,
              decoration: InputDecoration(labelText: l.browseUser),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('server-save'),
          onPressed: () {
            final address = _address.text.trim();
            final uri = Uri.tryParse(address);
            if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;
            // The address says what it is (ftp://, smb://, sftp://).
            final kind =
                ServerKind.values
                    .where((k) => k.name == uri.scheme)
                    .firstOrNull ??
                _kind;
            Navigator.pop(
              context,
              SavedServer(
                kind: kind,
                name: _name.text.trim().isEmpty ? uri.host : _name.text.trim(),
                address: address,
                user: _user.text.trim(),
              ),
            );
          },
          child: Text(l.browseSave),
        ),
      ],
    );
  }
}

/// A folder: breadcrumbs, search, play all, its folders and files.
class _Folder extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_Folder> createState() => _FolderState();
}

class _FolderState extends ConsumerState<_Folder> {
  final _password = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(browseProvider);
    final c = ref.read(browseProvider.notifier);
    final q = state.query.toLowerCase();
    final shown = [
      for (final e in state.entries ?? const <BrowseEntry>[])
        if (q.isEmpty || e.name.toLowerCase().contains(q)) e,
    ];
    final files = [
      for (final e in shown)
        if (!e.isFolder && e.play != null) e,
    ];

    Widget body;
    if (state.loading) {
      body = const Center(
        child: CircularProgressIndicator(color: KyndrelColors.accent),
      );
    } else if (state.needsPassword != null) {
      final s = state.needsPassword!;
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('${s.name} · ${s.user}'),
            TextField(
              key: const Key('browse-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l.browsePassword),
              onSubmitted: (v) => unawaited(c.setPassword(s, v)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('browse-password-ok'),
              onPressed: () => unawaited(c.setPassword(s, _password.text)),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      );
    } else if (state.notListable || state.error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.notListable ? l.browseOpenOnly : l.browseFailed(state.error!),
            key: const Key('browse-error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: KyndrelColors.textSecondary),
          ),
        ),
      );
    } else if (shown.isEmpty) {
      body = Center(
        child: Text(
          l.browseEmpty,
          style: const TextStyle(color: KyndrelColors.textSecondary),
        ),
      );
    } else {
      body = ListView.builder(
        key: PageStorageKey('browse-${state.stack.last.hashCode}'),
        itemExtent: 64,
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final e = shown[i];
          return ListTile(
            key: Key('browse-entry-${e.name}'),
            leading: Icon(
              e.isFolder ? Icons.folder : Icons.movie_outlined,
              color: e.isFolder ? KyndrelColors.accent : null,
            ),
            title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: e.size == null ? null : Text(formatBytes(e.size!)),
            onTap: () {
              if (e.isFolder && e.location != null) {
                unawaited(c.open(e.location!));
              } else if (e.play != null) {
                // The folder plays on from the chosen file.
                unawaited(playEntries(ref, files, start: files.indexOf(e)));
              }
            },
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                key: const Key('browse-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BackButtonIcon(),
                onPressed: () => unawaited(c.back()),
              ),
              Expanded(
                child: _searching
                    ? TextField(
                        key: const Key('browse-search-field'),
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: l.browseFind,
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: c.search,
                      )
                    : SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          children: [
                            for (final (i, loc)
                                in state.stack.indexed.toList().reversed)
                              Row(
                                children: [
                                  if (i > 0)
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: KyndrelColors.textSecondary,
                                    ),
                                  TextButton(
                                    key: Key('browse-crumb-$i'),
                                    onPressed: () => unawaited(c.goTo(i)),
                                    child: Text(
                                      loc.label,
                                      style: TextStyle(
                                        color: i == state.stack.length - 1
                                            ? KyndrelColors.textPrimary
                                            : KyndrelColors.textSecondary,
                                        fontWeight: i == state.stack.length - 1
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ].reversed.toList(),
                        ),
                      ),
              ),
              IconButton(
                key: const Key('browse-search'),
                tooltip: l.browseFind,
                icon: Icon(_searching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) c.search('');
                }),
              ),
              IconButton(
                key: const Key('browse-shuffle'),
                tooltip: l.libraryShuffle,
                icon: const Icon(Icons.shuffle),
                onPressed: files.isEmpty
                    ? null
                    : () => unawaited(
                        playEntries(ref, [...files]..shuffle(math.Random())),
                      ),
              ),
              IconButton(
                key: const Key('browse-play-all'),
                tooltip: l.libraryPlayAll,
                icon: const Icon(Icons.play_arrow),
                onPressed: files.isEmpty
                    ? null
                    : () => unawaited(playEntries(ref, files)),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
