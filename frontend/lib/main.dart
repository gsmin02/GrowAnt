import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/auth/login_screen.dart';

void main() => runApp(const ProviderScope(child: GrowAntApp()));

class GrowAntApp extends StatelessWidget {
  const GrowAntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrowAnt',
      debugShowCheckedModeBanner: false,
      theme: growAntTheme(),
      home: const LoginScreen(),
    );
  }
}
