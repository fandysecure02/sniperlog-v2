import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/trade_provider.dart';
import 'screens/input_trade_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Paksa orientasi portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Warna system status bar agar sesuai dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    // Daftarkan Provider di root aplikasi
    ChangeNotifierProvider(
      create: (_) => TradeProvider()..loadData(), // Load data saat start
      child: const SniperLogApp(),
    ),
  );
}

class SniperLogApp extends StatelessWidget {
  const SniperLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SniperLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Dark mode default, tidak ikut sistem
      themeMode: ThemeMode.dark,
      home: const MainNavigation(),
    );
  }
}

// ===================== NAVIGASI UTAMA =====================
// Bottom Navigation Bar dengan 2 tab: Input & Dashboard
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 1; // Default buka tab Dashboard

  // Halaman-halaman yang ditampilkan
  final List<Widget> _screens = [
    const InputTradeScreen(),
    const DashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack: menjaga state tiap halaman saat tab berpindah
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            // Tab Input Trade
            BottomNavigationBarItem(
              icon: const Icon(Icons.add_circle_outline),
              activeIcon: const Icon(Icons.add_circle),
              label: 'Input',
            ),
            // Tab Dashboard
            BottomNavigationBarItem(
              icon: const Icon(Icons.bar_chart_outlined),
              activeIcon: const Icon(Icons.bar_chart),
              label: 'Dashboard',
            ),
          ],
        ),
      ),

      // Tidak ada FAB - navigasi sudah via BottomNavigationBar
      // Tombol simpan ada di dalam InputTradeScreen
    );
  }
}
