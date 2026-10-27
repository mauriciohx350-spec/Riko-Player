import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class RikoPlayerApp extends StatelessWidget {
  const RikoPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riko Player',
      debugShowCheckedModeBanner: false,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const Scaffold(body: Center(child: Text('Riko Player'))),
    );
  }
}
