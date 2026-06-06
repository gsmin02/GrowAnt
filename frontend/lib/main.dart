import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'core/theme.dart';

void main() => runApp(const GrowAntApp());

class GrowAntApp extends StatelessWidget {
  const GrowAntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrowAnt',
      debugShowCheckedModeBanner: false,
      theme: growAntTheme(),
      home: const AppShell(),
    );
  }
}
