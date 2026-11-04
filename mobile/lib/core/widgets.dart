import 'package:flutter/material.dart';

const Color kBrand = Color(0xFF128A52);
const Color kBrandDark = Color(0xFF0C6B3F);
const Color kInk = Color(0xFF16241D);
const Color kMuted = Color(0xFF5D6F66);
const Color kSurface = Color(0xFFF5FAF7);
const Color kLine = Color(0xFFE3E6EA);
const Color kAmber = Color(0xFFF2A71B);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kBrand),
    scaffoldBackgroundColor: kSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: kLine)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kLine),
      ),
      margin: EdgeInsets.zero,
    ),
  );
}

Color statusColor(String status) {
  switch (status) {
    case 'PENDING':
      return const Color(0xFF7A5600);
    case 'ASSIGNED':
      return const Color(0xFF14497F);
    case 'COLLECTED':
      return const Color(0xFF2D3A9B);
    case 'IN_TRANSIT':
      return const Color(0xFF0F5F8A);
    case 'RECEIVED':
    case 'PROCESSED':
      return kBrandDark;
    case 'REJECTED':
    case 'CANCELLED':
      return const Color(0xFF9B2F1C);
    default:
      return kInk;
  }
}

Color statusBackground(String status) {
  switch (status) {
    case 'PENDING':
      return const Color(0xFFFDF1D6);
    case 'ASSIGNED':
      return const Color(0xFFE2EDFB);
    case 'COLLECTED':
      return const Color(0xFFE6E9FB);
    case 'IN_TRANSIT':
      return const Color(0xFFDFF0FB);
    case 'RECEIVED':
    case 'PROCESSED':
      return const Color(0xFFD8F3E3);
    case 'REJECTED':
    case 'CANCELLED':
      return const Color(0xFFFBE4DE);
    default:
      return const Color(0xFFEEF1F0);
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  final String label;

  const StatusChip({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusBackground(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: statusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String formatUGX(Object? value) {
  final n = double.tryParse('$value') ?? 0;
  final rounded = n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < rounded.length; i++) {
    if (i > 0 && (rounded.length - i) % 3 == 0) buffer.write(',');
    buffer.write(rounded[i]);
  }
  return 'UGX $buffer';
}

String formatPoints(Object? value) {
  final n = int.tryParse('${value ?? 0}') ?? 0;
  final digits = n.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return n < 0 ? '-$buffer' : buffer.toString();
}

String formatDate(String iso) {
  if (iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return iso;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

class EmptyView extends StatelessWidget {
  final String message;
  const EmptyView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, style: const TextStyle(color: kMuted)),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE4DE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0BDB1)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9B2F1C), fontSize: 13),
      ),
    );
  }
}

/// Slim status strip: offline / pending-sync indicator.
class OfflineBanner extends StatelessWidget {
  final bool online;
  final int pending;
  final bool syncing;
  const OfflineBanner({
    super.key,
    required this.online,
    required this.pending,
    required this.syncing,
  });

  @override
  Widget build(BuildContext context) {
    if (online && pending == 0 && !syncing) return const SizedBox.shrink();
    final String text;
    final Color bg;
    final Color fg;
    if (!online) {
      text = pending > 0
          ? 'Offline · $pending change(s) waiting to sync'
          : 'Offline · showing saved data';
      bg = const Color(0xFFFFF4E0);
      fg = const Color(0xFF7A5600);
    } else if (syncing) {
      text = 'Syncing $pending change(s)…';
      bg = const Color(0xFFE0F0FF);
      fg = const Color(0xFF14497F);
    } else {
      text = '$pending change(s) will sync shortly';
      bg = const Color(0xFFFFF4E0);
      fg = const Color(0xFF7A5600);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: bg,
      child: Row(
        children: [
          if (!online)
            Icon(Icons.cloud_off, size: 14, color: fg)
          else if (syncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else
            Icon(Icons.cloud_sync, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
