import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _levelFilter = 'ALL';
  String _textFilter  = '';
  bool   _autoScroll  = true;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  static const _levels = ['ALL', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'];

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _passes(LogEntry e) {
    if (_levelFilter != 'ALL' && e.level != _levelFilter) return false;
    if (_textFilter.isNotEmpty &&
        !e.message.toLowerCase().contains(_textFilter)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<AppProvider>();
    final allLogs = prov.logs;
    final entries = allLogs.where(_passes).toList();

    // Auto-scroll to bottom
    if (_autoScroll && _scrollController.hasClients && entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────────
          const Text(
            'Logs',
            style: TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'سجلات النظام المباشرة — يتم تحديثها فور حدوثها',
            style: TextStyle(color: kTextSub, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // ── Toolbar ─────────────────────────────────────────────────────────
          Row(
            children: [
              // Level filter label
              const Text('المستوى:', style: TextStyle(color: kTextSub, fontSize: 13)),
              const SizedBox(width: 8),
              _LevelDropdown(
                value: _levelFilter,
                onChanged: (v) => setState(() => _levelFilter = v),
              ),
              const SizedBox(width: 12),

              // Text search
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: kTextPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث في الـ logs...',
                    hintStyle: const TextStyle(color: kTextSub),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kBorderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kBorderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kAccent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(Icons.search, color: kTextSub, size: 18),
                  ),
                  onChanged: (v) => setState(() => _textFilter = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),

              // Auto-scroll toggle
              Row(
                children: [
                  Checkbox(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v ?? true),
                    activeColor: kAccent,
                  ),
                  const Text('Auto-scroll', style: TextStyle(color: kTextSub, fontSize: 13)),
                ],
              ),
              const SizedBox(width: 8),

              // Clear button
              OutlinedButton(
                onPressed: () => prov.clearLogs(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextSub,
                  side: const BorderSide(color: kBorderDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Log view ─────────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderDark),
              ),
              child: entries.isEmpty
                  ? const Center(
                      child: Text('لا توجد سجلات', style: TextStyle(color: kTextSub)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _LogLine(entry: entries[i]),
                    ),
            ),
          ),
          const SizedBox(height: 8),

          // Entry counter — total entries like Python (not filtered count)
          Text(
            entries.length == allLogs.length
                ? '${allLogs.length} entries'
                : '${entries.length} / ${allLogs.length} entries',
            style: const TextStyle(color: kTextSub, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Log Line ─────────────────────────────────────────────────────────────────
class _LogLine extends StatelessWidget {
  final LogEntry entry;
  const _LogLine({required this.entry});

  // Fixed-width level tag (matches Python's [LEVELNAME] display)
  static const _levelWidth = <String, String>{
    'DEBUG':    'DEBUG   ',
    'INFO':     'INFO    ',
    'WARNING':  'WARNING ',
    'ERROR':    'ERROR   ',
    'CRITICAL': 'CRITICAL',
  };

  @override
  Widget build(BuildContext context) {
    final color  = logColor(entry.level);
    final isBold = entry.level == 'WARNING' ||
                   entry.level == 'ERROR'   ||
                   entry.level == 'CRITICAL';

    // The message field already contains the full formatted string:
    // "2026-06-01 10:23:45 [INFO] module: message"
    // We display it as-is, colored by level.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        entry.message,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'Consolas, monospace',
          fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          height: 1.55,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ─── Level Dropdown ───────────────────────────────────────────────────────────
class _LevelDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LevelDropdown({required this.value, required this.onChanged});

  static const _levels = ['ALL', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'];

  // Color for the dropdown item label
  static Color _itemColor(String level) {
    if (level == 'ALL') return kTextPrimary;
    return logColor(level);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorderDark),
      ),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: kCardDark,
        underline: const SizedBox(),
        style: const TextStyle(color: kTextPrimary, fontSize: 13),
        items: _levels
            .map((l) => DropdownMenuItem(
                  value: l,
                  child: Text(
                    l,
                    style: TextStyle(color: _itemColor(l), fontSize: 13),
                  ),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
