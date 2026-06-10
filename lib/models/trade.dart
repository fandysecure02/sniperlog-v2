// Model data untuk satu trade
// Representasi tabel 'trades' di SQLite

class Trade {
  final int? id;
  final String pair;       // e.g. XAUUSD
  final double entryPrice;
  final double lotSize;
  final double sl;
  final double tp;
  final String hasil;      // 'WIN', 'LOSS', 'BE'
  final int pips;          // bisa negatif
  final double pl;         // Profit/Loss dalam USD
  final String? note;
  final String? screenshotPath; // path gambar lokal
  final DateTime createdAt;

  Trade({
    this.id,
    required this.pair,
    required this.entryPrice,
    required this.lotSize,
    required this.sl,
    required this.tp,
    required this.hasil,
    required this.pips,
    required this.pl,
    this.note,
    this.screenshotPath,
    required this.createdAt,
  });

  // Konversi dari Map (hasil query SQLite) ke objek Trade
  factory Trade.fromMap(Map<String, dynamic> map) {
    return Trade(
      id: map['id'] as int?,
      pair: map['pair'] as String,
      entryPrice: (map['entry_price'] as num).toDouble(),
      lotSize: (map['lot_size'] as num).toDouble(),
      sl: (map['sl'] as num).toDouble(),
      tp: (map['tp'] as num).toDouble(),
      hasil: map['hasil'] as String,
      pips: map['pips'] as int,
      pl: (map['pl'] as num).toDouble(),
      note: map['note'] as String?,
      screenshotPath: map['screenshot_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Konversi dari objek Trade ke Map untuk disimpan ke SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'pair': pair,
      'entry_price': entryPrice,
      'lot_size': lotSize,
      'sl': sl,
      'tp': tp,
      'hasil': hasil,
      'pips': pips,
      'pl': pl,
      'note': note,
      'screenshot_path': screenshotPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy dengan perubahan tertentu
  Trade copyWith({
    int? id,
    String? pair,
    double? entryPrice,
    double? lotSize,
    double? sl,
    double? tp,
    String? hasil,
    int? pips,
    double? pl,
    String? note,
    String? screenshotPath,
    DateTime? createdAt,
  }) {
    return Trade(
      id: id ?? this.id,
      pair: pair ?? this.pair,
      entryPrice: entryPrice ?? this.entryPrice,
      lotSize: lotSize ?? this.lotSize,
      sl: sl ?? this.sl,
      tp: tp ?? this.tp,
      hasil: hasil ?? this.hasil,
      pips: pips ?? this.pips,
      pl: pl ?? this.pl,
      note: note ?? this.note,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
