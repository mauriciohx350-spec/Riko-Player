import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/library/view/library_page.dart';

class RikoPlayerApp extends StatelessWidget {
  const RikoPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riko Player',
      debugShowCheckedModeBanner: false,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const LibraryPage(),
    );
  }
}
