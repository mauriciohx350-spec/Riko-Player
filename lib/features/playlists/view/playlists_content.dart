import 'package:flutter/material.dart';

import '../../library/view/widgets/library_message.dart';
import '../logic/playlists_controller.dart';
import '../models/playlist.dart';
import 'playlist_details_page.dart';
import 'playlists_scope.dart';
import 'widgets/playlist_name_dialog.dart';
import 'widgets/playlist_error.dart';

class PlaylistsContent extends StatefulWidget {
  const PlaylistsContent({super.key});
  @override
  State<PlaylistsContent> createState() => _PlaylistsContentState();
}

class _PlaylistsContentState extends State<PlaylistsContent> {
  late final PlaylistsController _controller;
  @override
  void initState() {
    super.initState();
    _controller = context
        .getInheritedWidgetOfExactType<PlaylistsScope>()!
        .controller;
    _controller.load();
  }

  Future<void> _create() async {
    final name = await showPlaylistNameDialog(context);
    if (name == null || !mounted) return;
    final playlist = await _controller.create(name);
    if (!mounted || playlist == null) return;
    await _open(playlist);
  }

  Future<void> _open(Playlist playlist) => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => PlaylistDetailsPage(id: playlist.id)),
  );
  Future<void> _action(Playlist playlist, String action) async {
    if (action == 'rename') {
      final name = await showPlaylistNameDialog(context, name: playlist.name);
      if (name != null && mounted) await _controller.rename(playlist.id, name);
    } else if (await confirmPlaylistDeletion(context, playlist.name) &&
        mounted) {
      await _controller.delete(playlist.id);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => RefreshIndicator(
      onRefresh: _controller.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    'Suas playlists',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: _controller.busy ? null : _create,
                    icon: const Icon(Icons.add),
                    label: const Text('Nova playlist'),
                  ),
                ],
              ),
            ),
          ),
          if (_controller.loading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                semanticsLabel: 'Carregando playlists',
              ),
            ),
          if (_controller.error != null)
            SliverToBoxAdapter(
              child: PlaylistError(
                message: _controller.error!,
                onRetry: _controller.load,
              ),
            ),
          if (!_controller.loading &&
              _controller.error == null &&
              _controller.playlists.isEmpty)
            const SliverToBoxAdapter(
              child: LibraryMessage(
                icon: Icons.queue_music,
                title: 'Nenhuma playlist por aqui',
                description:
                    'Crie uma playlist e reúna suas músicas favoritas.',
              ),
            ),
          SliverList.builder(
            itemCount: _controller.playlists.length,
            itemBuilder: (context, index) {
              final playlist = _controller.playlists[index];
              return ListTile(
                key: ValueKey(playlist.id),
                leading: Icon(
                  Icons.queue_music,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${playlist.trackCount} música(s)'),
                onTap: () => _open(playlist),
                trailing: PopupMenuButton<String>(
                  enabled: !_controller.busy,
                  tooltip: 'Opções da playlist',
                  onSelected: (action) => _action(playlist, action),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renomear')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir playlist'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    ),
  );
}
