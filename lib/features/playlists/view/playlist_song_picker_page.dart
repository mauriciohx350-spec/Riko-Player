import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';

import '../../library/logic/library_controller.dart';
import '../../library/logic/song_details.dart';
import '../../library/view/widgets/song_artwork.dart';
import '../logic/playlist_details_controller.dart';
import 'playlists_scope.dart';
import 'widgets/playlist_error.dart';

class PlaylistSongPickerPage extends StatefulWidget {
  const PlaylistSongPickerPage({super.key, required this.controller});
  final PlaylistDetailsController controller;
  @override
  State<PlaylistSongPickerPage> createState() => _PlaylistSongPickerPageState();
}

class _PlaylistSongPickerPageState extends State<PlaylistSongPickerPage> {
  final Map<String, SongModel> _selected = {};
  String _search = '';
  String? _message;
  Future<void> _save(LibraryController library) async {
    if (library.status != LibraryStatus.ready || library.isLoading) return;
    final catalog = {for (final song in library.allSongs) song.uri: song};
    final songs = _selected.keys
        .map((uri) => catalog[uri])
        .whereType<SongModel>()
        .toList();
    if (songs.length != _selected.length) {
      setState(() {
        _selected.removeWhere((uri, _) => !catalog.containsKey(uri));
        _message = 'A biblioteca mudou. Confira sua seleção e tente novamente.';
      });
      return;
    }
    final count = await widget.controller.add(songs);
    if (mounted && count != null) Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    final library = PlaylistsScope.of(context).library;
    final details = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar músicas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar biblioteca',
            onPressed: library.isLoading ? null : () => library.load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([library, details]),
        builder: (context, _) {
          final ready =
              library.status == LibraryStatus.ready && !library.isLoading;
          final existing =
              details.details?.tracks.map((entry) => entry.uri).toSet() ??
              <String>{};
          final songs = library.allSongs
              .where(
                (song) =>
                    song.displayTitle.toLowerCase().contains(_search) ||
                    song.displayArtist.toLowerCase().contains(_search),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar para adicionar',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                ),
              ),
              if (library.isLoading || details.busy)
                const LinearProgressIndicator(),
              if (!ready && !library.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Text(
                        'Não foi possível consultar as músicas. Verifique a permissão e atualize a biblioteca.',
                      ),
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
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_message!),
                ),
              if (details.error != null) PlaylistError(message: details.error!),
              Expanded(
                child: !ready
                    ? const Center(child: Text('Aguardando biblioteca'))
                    : songs.isEmpty
                    ? const Center(child: Text('Nenhuma música encontrada'))
                    : ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final uri = song.uri;
                          final already = existing.contains(uri);
                          return CheckboxListTile(
                            key: ValueKey(uri ?? song.id),
                            secondary: SongArtwork(
                              song: song,
                              service: library.service,
                              size: 40,
                            ),
                            title: Text(
                              song.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              already ? 'Já adicionada' : song.displayArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: already || _selected.containsKey(uri),
                            onChanged: details.busy || already || uri == null
                                ? null
                                : (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selected[uri] = song;
                                      } else {
                                        _selected.remove(uri);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: !ready || details.busy || _selected.isEmpty
                          ? null
                          : () => _save(library),
                      child: Text('Adicionar (${_selected.length})'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
