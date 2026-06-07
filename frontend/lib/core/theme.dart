import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 흑백 중심 + 개미 모티프 톤. 본문/상단 폰트: Noto Sans KR (한글 가독성).
ThemeData growAntTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF111111),
    brightness: Brightness.light,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    textTheme: GoogleFonts.notoSansKrTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF5F5F5),
      foregroundColor: const Color(0xFF111111),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.notoSansKr(
        color: const Color(0xFF111111),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// 한국 관습: 상승 빨강 / 하락 파랑
const Color upColor = Color(0xFFE53935);
const Color downColor = Color(0xFF1E88E5);
const Color inkColor = Color(0xFF111111);
