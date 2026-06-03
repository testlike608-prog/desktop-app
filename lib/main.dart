import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_provider.dart';
import 'services/backend_process.dart';
import 'screens/status_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── نشغّل Splash أولاً ────────────────────────────────────────────────────
  runApp(const _SplashApp(message: 'جاري تشغيل الـ backend...'));

  // ── نشغّل الـ backend ─────────────────────────────────────────────────────
  final result = await BackendProcess.start(timeout: 30);

  String? warningMsg;
  if (result == BackendStartResult.notFound) {
    // development mode — البايثون شغّال منفصل، نكمل عادي
    warningMsg = null;
  } else if (result == BackendStartResult.timeout) {
    warningMsg = 'Backend شغّال لكن ما ردّش — تحقق من api_server.exe';
  } else if (result == BackendStartResult.failedToLaunch) {
    warningMsg = 'فشل تشغيل api_server.exe — تأكد من وجوده';
  }

  // ── نشغّل الـ app الحقيقي ─────────────────────────────────────────────────
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: TestStationApp(startupWarning: warningMsg),
    ),
  );
}

// ─── Splash Screen ────────────────────────────────────────────────────────────
class _SplashApp extends StatelessWidget {
  final String message;
  const _SplashApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: kBgDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kAccent.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.hexagon_outlined, color: kAccent, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Test Station Controller',
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: kTextSub, fontSize: 13),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF1E293B),
                  color: kAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Root App ─────────────────────────────────────────────────────────────────
class TestStationApp extends StatefulWidget {
  final String? startupWarning;
  const TestStationApp({super.key, this.startupWarning});

  @override
  State<TestStationApp> createState() => _TestStationAppState();
}

class _TestStationAppState extends State<TestStationApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BackendProcess.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      BackendProcess.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Station Controller',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: MainShell(startupWarning: widget.startupWarning),
    );
  }
}

// ─── Main Shell (Sidebar + Content) ──────────────────────────────────────────
class MainShell extends StatefulWidget {
  final String? startupWarning;
  const MainShell({super.key, this.startupWarning});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _pages = [
    StatusScreen(),
    LogsScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard,   label: 'Status'),
    _NavItem(icon: Icons.list_alt_outlined,  activeIcon: Icons.list_alt,    label: 'Logs'),
    _NavItem(icon: Icons.settings_outlined,  activeIcon: Icons.settings,    label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: kBgDark,
      body: Column(
        children: [
          // ── Startup warning (مرة واحدة بس) ──────────────────────────────
          if (widget.startupWarning != null)
            _StartupWarningBanner(message: widget.startupWarning!),

          Expanded(
            child: Row(
              children: [
                // ── Sidebar ────────────────────────────────────────────────
                _Sidebar(
                  selectedIndex: _selectedIndex,
                  onSelect: (i) => setState(() => _selectedIndex = i),
                  navItems: _navItems,
                  isConnected: prov.backendConnected,
                ),

                // ── Content ────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      if (!prov.backendConnected)
                        _DisconnectedBanner(error: prov.lastError),
                      Expanded(child: _pages[_selectedIndex]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<_NavItem> navItems;
  final bool isConnected;

  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.navItems,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: kSidebarDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.hexagon_outlined, color: kAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'TestStation',
                      style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 42),
                  child: Text(
                    'CONTROL PANEL',
                    style: TextStyle(
                      color: kTextSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Connection status pill
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (isConnected ? kSuccess : kDanger).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isConnected ? kSuccess : kDanger).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: isConnected ? kSuccess : kDanger),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Backend Online' : 'Backend Offline',
                    style: TextStyle(
                      color: isConnected ? kSuccess : kDanger,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: kBorderDark, height: 1),
          const SizedBox(height: 8),

          // Nav buttons
          ...List.generate(navItems.length, (i) {
            final item     = navItems[i];
            final selected = i == selectedIndex;
            return _NavButton(item: item, selected: selected, onTap: () => onSelect(i));
          }),

          const Spacer(),

          // Version
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'v1.0  •  © 2026 Meeserv',
              style: TextStyle(color: kTextSub, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? kAccent.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? kAccent.withOpacity(0.4) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  color: selected ? kAccent : kTextSub,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? kAccent : kTextSub,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// ─── Banners ──────────────────────────────────────────────────────────────────
class _DisconnectedBanner extends StatelessWidget {
  final String? error;
  const _DisconnectedBanner({this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A0A0A),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kWarning, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Backend غير متصل — في حالة الـ development شغّل: python api_server.py',
              style: TextStyle(color: kWarning, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupWarningBanner extends StatefulWidget {
  final String message;
  const _StartupWarningBanner({required this.message});

  @override
  State<_StartupWarningBanner> createState() => _StartupWarningBannerState();
}

class _StartupWarningBannerState extends State<_StartupWarningBanner> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      color: kDanger.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kDanger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.message,
                style: const TextStyle(color: kDanger, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: kTextSub, size: 16),
            onPressed: () => setState(() => _visible = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
