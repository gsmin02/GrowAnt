import 'package:flutter/material.dart';

/// 흑백 중심 + 개미 모티프 톤 (8주차: 메인 컬러 #000 / #FFF).
ThemeData growAntTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF111111),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F5F5),
      foregroundColor: Color(0xFF111111),
      elevation: 0,
      centerTitle: false,
    ),
    // TODO: 제주고딕/프리텐다드 폰트 추가 (8주차 결정)
  );
}

// 한국 관습: 상승 빨강 / 하락 파랑
const Color upColor = Color(0xFFE53935);
const Color downColor = Color(0xFF1E88E5);
const Color inkColor = Color(0xFF111111);
