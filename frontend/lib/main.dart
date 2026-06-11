import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/auth_gate.dart';
import 'core/theme.dart';

void main() => runApp(const ProviderScope(child: GrowAntApp()));

class GrowAntApp extends StatelessWidget {
  const GrowAntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrowAnt',
      debugShowCheckedModeBanner: false,
      theme: growAntTheme(),
      home: const AuthGate(),
    );
  }
}
