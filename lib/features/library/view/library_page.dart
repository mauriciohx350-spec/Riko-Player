import 'package:flutter/material.dart';

import '../../playback/view/miniplayer.dart';

import '../../settings/view/settings_page.dart';
import 'library_content.dart';
import '../../playlists/view/playlists_content.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _selectedIndex = 0;
  bool _playlistsOpened = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Riko Player',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            const LibraryContent(),
            if (_playlistsOpened)
              const PlaylistsContent()
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Miniplayer(),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _selectedIndex = index;
                if (index == 1) _playlistsOpened = true;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'Biblioteca',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music),
                label: 'Playlists',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
