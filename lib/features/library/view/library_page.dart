import 'package:flutter/material.dart';

import '../../settings/view/settings_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _selectedIndex = 0;

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
          children: const [
            _LibraryContent(),
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.queue_music,
                    title: 'Nenhuma playlist por aqui',
                    description: 'Suas playlists aparecerão aqui quando essa funcionalidade estiver disponível.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _selectedIndex = index);
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
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
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
                const SizedBox(height: 32),
                Text(
                  'Suas músicas',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: _EmptyState(
            icon: Icons.music_note_outlined,
            title: 'Nenhuma música encontrada',
            description: 'As músicas armazenadas no seu dispositivo aparecerão automaticamente aqui quando a leitura de músicas estiver disponível.',
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
