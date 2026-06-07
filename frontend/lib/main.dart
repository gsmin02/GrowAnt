import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/auth/login_screen.dart';

// TODO(market-slice): runApp을 ProviderScope로 감싸기 — const ProviderScope(child: GrowAntApp()).
//   스펙: docs/superpowers/specs/2026-06-07-market-rest-slice-design.md §4.4
void main() => runApp(const GrowAntApp());

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
