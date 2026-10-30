import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';

import '../../library/logic/library_controller.dart';
import '../../playback/view/miniplayer.dart';
import '../../playback/view/playback_scope.dart';
import '../logic/playlist_details_controller.dart';
import '../logic/playlist_song_resolver.dart';
import '../models/playlist.dart';
import '../models/playlist_track.dart';
import 'playlist_song_picker_page.dart';
import 'playlists_scope.dart';
import 'widgets/playlist_name_dialog.dart';
import 'widgets/playlist_error.dart';
import 'widgets/playlist_track_tile.dart';

class PlaylistDetailsPage extends StatefulWidget {
  const PlaylistDetailsPage({super.key, required this.id});
  final String id;
  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  late final PlaylistDetailsController _controller;
  final _resolver = PlaylistSongResolver();
  @override
  void initState() {
    super.initState();
    final scope = context.getInheritedWidgetOfExactType<PlaylistsScope>()!;
    _controller = PlaylistDetailsController(
      scope.controller.repository,
      widget.id,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  Future<void> _play({String? entryId}) async {
    final details = _controller.details;
    if (details == null) return;
    try {
      final skipped = await _resolver.play(
        details.tracks,
        PlaylistsScope.of(context).library,
        PlaybackScope.of(context).controller,
        startingEntryId: entryId,
      );
      if (mounted && skipped > 0) {
        _message('$skipped música(s) indisponível(is) ignorada(s).');
      }
    } on PlaylistException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _add() async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => PlaylistSongPickerPage(controller: _controller),
      ),
    );
    if (mounted && count != null) {
      _message(
        count == 0
            ? 'As músicas selecionadas já estavam na playlist.'
            : '$count música(s) adicionada(s). Duplicatas foram ignoradas.',
      );
    }
  }

  Future<void> _action(String action) async {
    final scope = PlaylistsScope.of(context);
    final playlist = _controller.details?.playlist;
    if (playlist == null) return;
    if (action == 'rename') {
      final name = await showPlaylistNameDialog(context, name: playlist.name);
      if (name != null && mounted) {
        await scope.controller.rename(playlist.id, name);
        if (mounted && scope.controller.error != null) {
          _message(scope.controller.error!);
        }
      }
    } else if (action == 'delete') {
      if (await confirmPlaylistDeletion(context, playlist.name) && mounted) {
        final deleted = await scope.controller.delete(playlist.id);
        if (!mounted) return;
        if (deleted) {
          Navigator.pop(context);
        } else {
          _message(scope.controller.error ?? 'Não foi possível excluir.');
        }
      }
    } else {
      final library = scope.library;
      final catalog =
          library.status == LibraryStatus.ready && !library.isLoading
          ? {
              for (final song in library.allSongs)
                if (song.uri != null) song.uri!: song,
            }
          : <String, SongModel>{};
      await _controller.sort(
        action == 'title' ? PlaylistSort.title : PlaylistSort.artist,
        catalog,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = PlaylistsScope.of(context).library;
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, library]),
      builder: (context, _) {
        final details = _controller.details;
        final tracks = _resolver.resolve(details?.tracks ?? [], library);
        final ready =
            library.status == LibraryStatus.ready && !library.isLoading;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              details?.playlist.name ?? 'Playlist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Adicionar músicas',
                onPressed: details == null || _controller.busy ? null : _add,
                icon: const Icon(Icons.playlist_add),
              ),
              PopupMenuButton<String>(
                enabled: details != null && !_controller.busy,
                tooltip: 'Opções da playlist',
                onSelected: _action,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renomear')),
                  PopupMenuItem(
                    value: 'title',
                    child: Text('Ordenar por título'),
                  ),
                  PopupMenuItem(
                    value: 'artist',
                    child: Text('Ordenar por artista'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir playlist'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (_controller.loading || _controller.busy || library.isLoading)
                const LinearProgressIndicator(),
              if (_controller.error != null)
                PlaylistError(
                  message: _controller.error!,
                  onRetry: _controller.load,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${tracks.length} música(s)'),
                    FilledButton.icon(
                      onPressed: !ready || tracks.isEmpty || _controller.busy
                          ? null
                          : () => _play(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Reproduzir'),
                    ),
                    TextButton.icon(
                      onPressed: library.isLoading
                          ? null
                          : () => library.load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar biblioteca'),
                    ),
                  ],
                ),
              ),
              if (!ready)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Text(
                        'A disponibilidade será verificada quando a biblioteca estiver acessível.',
                      ),
                      if (library.status == LibraryStatus.denied)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  library.load(requestPermission: true),
                              child: const Text('Permitir acesso'),
                            ),
                            TextButton(
                              onPressed: library.openSettings,
                              child: const Text('Abrir configurações'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: details == null
                    ? Center(
                        child: Text(
                          _controller.loading
                              ? 'Carregando playlist…'
                              : 'Playlist não encontrada',
                        ),
                      )
                    : tracks.isEmpty
                    ? const Center(
                        child: Text('Adicione músicas à sua playlist.'),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: tracks.length,
                        onReorderItem: (oldIndex, newIndex) {
                          _controller.move(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) => PlaylistTrackTile(
                          key: ValueKey(tracks[index].entry.id),
                          track: tracks[index],
                          index: index,
                          busy: _controller.busy || _controller.loading,
                          service: library.service,
                          onPlay: () => _play(entryId: tracks[index].entry.id),
                          onRemove: () =>
                              _controller.remove(tracks[index].entry.id),
                        ),
                      ),
              ),
            ],
          ),
          bottomNavigationBar: const SafeArea(top: false, child: Miniplayer()),
        );
      },
    );
  }
}
