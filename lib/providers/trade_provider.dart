import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trade.dart';
import '../helpers/database_helper.dart';

// Provider utama yang mengurus semua state aplikasi SniperLog
class TradeProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Trade> _allTrades = [];      // Semua trade (urut ASC untuk kalkulasi)
  List<Trade> _recentTrades = [];   // 20 trade terbaru (untuk tampilan list)
  List<Trade> _todayTrades = [];    // Trade hari ini

  double _initialBalance = 1000.0;  // Balance awal dari SharedPreferences

  bool _isLoading = false;

  // ===================== GETTER =====================

  List<Trade> get allTrades => _allTrades;
  List<Trade> get recentTrades => _recentTrades;
  List<Trade> get todayTrades => _todayTrades;
  double get initialBalance => _initialBalance;
  bool get isLoading => _isLoading;

  // Total P/L semua trade
  double get totalPL {
    return _allTrades.fold(0.0, (sum, t) => sum + t.pl);
  }

  // Balance saat ini
  double get currentBalance => _initialBalance + totalPL;

  // Winrate dalam persen
  double get winrate {
    if (_allTrades.isEmpty) return 0.0;
    final wins = _allTrades.where((t) => t.hasil == 'WIN').length;
    return (wins / _allTrades.length) * 100;
  }

  // Total trade hari ini
  int get todayTradeCount => _todayTrades.length;

  // Total P/L hari ini
  double get todayPL {
    return _todayTrades.fold(0.0, (sum, t) => sum + t.pl);
  }

  // ===================== MAX DRAWDOWN =====================
  // Rumus: equity tertinggi - equity terendah setelahnya
  // Return: {percent: double, dollar: double}
  Map<String, double> get maxDrawdown {
    if (_allTrades.isEmpty) return {'percent': 0.0, 'dollar': 0.0};

    // Bangun equity curve dari balance awal
    List<double> equityCurve = [_initialBalance];
    for (final trade in _allTrades) {
      equityCurve.add(equityCurve.last + trade.pl);
    }

    double maxDD = 0.0;
    double peak = equityCurve[0];

    for (final equity in equityCurve) {
      if (equity > peak) peak = equity;
      final drawdown = peak - equity;
      if (drawdown > maxDD) maxDD = drawdown;
    }

    final ddPercent = peak > 0 ? (maxDD / peak) * 100 : 0.0;
    return {'percent': ddPercent, 'dollar': maxDD};
  }

  // ===================== CONSECUTIVE =====================

  // Hitung streak LOSS berurutan terpanjang
  int get maxConsecutiveLoss {
    if (_allTrades.isEmpty) return 0;
    int maxStreak = 0;
    int currentStreak = 0;

    for (final trade in _allTrades) {
      if (trade.hasil == 'LOSS') {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        // WIN atau BE = reset counter loss
        currentStreak = 0;
      }
    }
    return maxStreak;
  }

  // Hitung streak WIN berurutan terpanjang
  int get maxConsecutiveWin {
    if (_allTrades.isEmpty) return 0;
    int maxStreak = 0;
    int currentStreak = 0;

    for (final trade in _allTrades) {
      if (trade.hasil == 'WIN') {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        // LOSS atau BE = reset counter win
        currentStreak = 0;
      }
    }
    return maxStreak;
  }

  // ===================== LOAD DATA =====================

  // Load semua data dari database
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load balance dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _initialBalance = prefs.getDouble('initial_balance') ?? 1000.0;

      // Load trade dari SQLite
      _allTrades = await _db.getAllTradesAsc();
      _recentTrades = await _db.getRecentTrades(20);
      _todayTrades = await _db.getTodayTrades();
    } catch (e) {
      debugPrint('Error loadData: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ===================== SIMPAN TRADE =====================

  Future<bool> saveTrade(Trade trade) async {
    try {
      await _db.insertTrade(trade);
      await loadData(); // Reload semua data setelah simpan
      return true;
    } catch (e) {
      debugPrint('Error saveTrade: $e');
      return false;
    }
  }

  // ===================== HAPUS TRADE =====================

  Future<bool> deleteTrade(int id) async {
    try {
      // Cari trade dulu untuk dapat path screenshot-nya
      final trades = _allTrades.where((t) => t.id == id).toList();
      if (trades.isNotEmpty && trades.first.screenshotPath != null) {
        // Hapus file screenshot agar tidak orphan di storage
        await deleteScreenshot(trades.first.screenshotPath);
      }
      await _db.deleteTrade(id);
      await loadData();
      return true;
    } catch (e) {
      debugPrint('Error deleteTrade: $e');
      return false;
    }
  }

  // ===================== RESET SEMUA DATA =====================

  Future<void> resetAllData() async {
    try {
      await _db.deleteAllTrades();

      // Reset balance ke default
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('initial_balance', 1000.0);
      _initialBalance = 1000.0;

      await loadData();
    } catch (e) {
      debugPrint('Error resetAllData: $e');
    }
  }

  // ===================== UPDATE BALANCE AWAL =====================

  Future<void> updateInitialBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('initial_balance', balance);
    _initialBalance = balance;
    notifyListeners();
  }

  // ===================== EXPORT CSV =====================

  // Return string isi CSV
  String generateCSV() {
    final buffer = StringBuffer();
    // Header
    buffer.writeln(
        'ID,Tanggal,Pair,Entry Price,Lot Size,SL,TP,Hasil,Pips,P/L,Note');

    for (final trade in _allTrades) {
      final date =
          '${trade.createdAt.day.toString().padLeft(2, '0')}/${trade.createdAt.month.toString().padLeft(2, '0')}/${trade.createdAt.year} ${trade.createdAt.hour.toString().padLeft(2, '0')}:${trade.createdAt.minute.toString().padLeft(2, '0')}';
      final note = (trade.note ?? '').replaceAll(',', ';'); // Hindari konflik koma di CSV
      buffer.writeln(
          '${trade.id},$date,${trade.pair},${trade.entryPrice},${trade.lotSize},${trade.sl},${trade.tp},${trade.hasil},${trade.pips},${trade.pl},$note');
    }

    return buffer.toString();
  }

  // ===================== HITUNG P/L OTOMATIS =====================
  // Pips * Lot * 10 (per pip per lot = $10, bisa disesuaikan)
  // CATATAN: Sesuaikan multiplier di sini kalau perlu per pair
  static double hitungPL(String pair, int pips, double lotSize, String hasil) {
    // Jika BE, P/L selalu 0 (balik modal)
    if (hasil == 'BE') return 0.0;

    // Multiplier: 1 pip = $10 per 1 lot standar
    // Untuk pair seperti USDJPY biasanya berbeda, tapi dianggap sama dulu
    const double multiplierPerLotPerPip = 10.0;

    // Pastikan tanda pips konsisten dengan hasil:
    // WIN harus positif, LOSS harus negatif
    final absPips = pips.abs();
    final signedPips = hasil == 'LOSS' ? -absPips : absPips;

    return signedPips * lotSize * multiplierPerLotPerPip;
  }

  // ===================== HAPUS FILE SCREENSHOT =====================
  Future<void> deleteScreenshot(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error hapus screenshot: $e');
    }
  }
}
