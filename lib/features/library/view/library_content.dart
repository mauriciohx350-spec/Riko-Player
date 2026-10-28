import 'package:flutter/material.dart';

import '../data/music_library_service.dart';
import '../logic/library_controller.dart';
import 'widgets/library_message.dart';
import 'widgets/song_tile.dart';

class LibraryContent extends StatefulWidget {
  const LibraryContent({super.key, this.service});

  final MusicLibraryService? service;

  @override
  State<LibraryContent> createState() => _LibraryContentState();
}

class _LibraryContentState extends State<LibraryContent>
    with WidgetsBindingObserver {
  late final LibraryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LibraryController(widget.service ?? MusicLibraryService());
    WidgetsBinding.instance.addObserver(this);
    _controller.load(requestPermission: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Revalida o acesso e novas músicas sem abrir outro diálogo.
      _controller.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Widget _message() {
    switch (_controller.status) {
      case LibraryStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(48),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Buscando suas músicas…'),
            ],
          ),
        );
      case LibraryStatus.denied:
        return LibraryMessage(
          icon: Icons.library_music_outlined,
          title: 'Permita o acesso às suas músicas',
          description:
              _controller.actionError ??
              'Precisamos de acesso aos arquivos de áudio para mostrar sua biblioteca. '
                  'Se a solicitação não aparecer, habilite a permissão nas configurações do Android.',
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_controller.permanentlyDenied)
                FilledButton(
                  onPressed: () => _controller.load(requestPermission: true),
                  child: const Text('Permitir acesso'),
                ),
              TextButton(
                onPressed: _controller.openSettings,
                child: const Text('Abrir configurações'),
              ),
            ],
          ),
        );
      case LibraryStatus.error:
        return LibraryMessage(
          icon: Icons.error_outline,
          title: 'Não foi possível ler as músicas',
          description: 'Ocorreu um erro ao consultar os arquivos de áudio do dispositivo.',
          action: FilledButton.tonal(
            onPressed: () => _controller.load(),
            child: const Text('Tentar novamente'),
          ),
        );
      case LibraryStatus.unsupported:
        return const LibraryMessage(
          icon: Icons.phone_android,
          title: 'Biblioteca disponível no Android',
          description: 'Abra o Riko Player em um dispositivo Android para consultar suas músicas locais.',
        );
      case LibraryStatus.ready:
        return LibraryMessage(
          icon: _controller.isEmpty
              ? Icons.music_note_outlined
              : Icons.search_off,
          title: _controller.isEmpty
              ? 'Nenhuma música encontrada'
              : 'Nenhum resultado para a pesquisa',
          description: _controller.isEmpty
              ? 'Salve músicas na pasta Música do dispositivo e atualize a biblioteca. '
                    'Os arquivos precisam estar indexados pelo Android.'
              : 'Tente pesquisar por outro título ou artista.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final loading = _controller.isLoading;
        final showSongs =
            _controller.status == LibraryStatus.ready &&
            _controller.songs.isNotEmpty;
        return RefreshIndicator(
          onRefresh: () => _controller.load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        onChanged: _controller.search,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Pesquisar músicas',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 4,
                        child: _controller.isRefreshing
                            ? const LinearProgressIndicator(
                                semanticsLabel: 'Atualizando biblioteca',
                              )
                            : null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Suas músicas',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Atualizar biblioteca',
                            onPressed: loading
                                ? null
                                : () => _controller.load(),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (showSongs)
                SliverList.builder(
                  key: const ValueKey('library-songs'),
                  findChildIndexCallback: (key) => key is ValueKey<int>
                      ? _controller.indexOfSong(key.value)
                      : null,
                  itemCount: _controller.songs.length,
                  itemBuilder: (context, index) {
                    final song = _controller.songs[index];
                    return SongTile(
                      key: ValueKey(song.id),
                      song: song,
                      service: _controller.service,
                    );
                  },
                )
              else
                SliverToBoxAdapter(child: _message()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}
