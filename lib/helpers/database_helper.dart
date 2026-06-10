import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trade.dart';

// Helper singleton untuk semua operasi database
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Getter database, buat kalau belum ada
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sniperlog.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Dapatkan path direktori database di Android
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Buat tabel saat pertama kali database dibuat
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pair TEXT NOT NULL,
        entry_price REAL NOT NULL,
        lot_size REAL NOT NULL,
        sl REAL NOT NULL,
        tp REAL NOT NULL,
        hasil TEXT NOT NULL,
        pips INTEGER NOT NULL,
        pl REAL NOT NULL,
        note TEXT,
        screenshot_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // ===================== CRUD =====================

  // Simpan trade baru
  Future<int> insertTrade(Trade trade) async {
    final db = await database;
    return await db.insert('trades', trade.toMap());
  }

  // Ambil semua trade, urut dari terbaru
  Future<List<Trade>> getAllTrades() async {
    final db = await database;
    final result = await db.query(
      'trades',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Trade.fromMap(map)).toList();
  }

  // Ambil trade terbaru N buah (untuk tampilan dashboard)
  Future<List<Trade>> getRecentTrades(int limit) async {
    final db = await database;
    final result = await db.query(
      'trades',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return result.map((map) => Trade.fromMap(map)).toList();
  }

  // Ambil trade hari ini
  Future<List<Trade>> getTodayTrades() async {
    final db = await database;
    final today = DateTime.now();
    // Buat start dan end hari ini dalam ISO format untuk range query
    final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final result = await db.query(
      'trades',
      where: "created_at >= ? AND created_at <= ?",
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Trade.fromMap(map)).toList();
  }

  // Ambil semua trade urut dari terlama (untuk kalkulasi equity curve)
  Future<List<Trade>> getAllTradesAsc() async {
    final db = await database;
    final result = await db.query(
      'trades',
      orderBy: 'created_at ASC',
    );
    return result.map((map) => Trade.fromMap(map)).toList();
  }

  // Hapus semua trade (untuk fitur reset)
  Future<void> deleteAllTrades() async {
    final db = await database;
    await db.delete('trades');
  }

  // Hapus satu trade berdasarkan id
  Future<int> deleteTrade(int id) async {
    final db = await database;
    return await db.delete(
      'trades',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tutup koneksi database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
