import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
import '../theme/app_theme.dart';

class InputTradeScreen extends StatefulWidget {
  const InputTradeScreen({super.key});

  @override
  State<InputTradeScreen> createState() => _InputTradeScreenState();
}

class _InputTradeScreenState extends State<InputTradeScreen> {
  // Controller untuk setiap input
  final _entryPriceCtrl = TextEditingController();
  final _lotSizeCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _pipsCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _customPairCtrl = TextEditingController();

  // State pilihan
  String? _selectedPair;
  String _selectedHasil = '';
  String? _screenshotPath;

  // Daftar pair default + custom yang ditambahkan user
  final List<String> _pairs = ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY'];

  bool _isSaving = false;

  @override
  void dispose() {
    _entryPriceCtrl.dispose();
    _lotSizeCtrl.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    _pipsCtrl.dispose();
    _noteCtrl.dispose();
    _customPairCtrl.dispose();
    super.dispose();
  }

  // ===================== AUTO HITUNG PIPS =====================
  // Hitung pips dari entry, sl/tp, dan hasil
  // XAUUSD: 1 pip = 0.1 (price point), multiplier 10
  // Pair 4-digit (EURUSD, GBPUSD, dll): 1 pip = 0.0001, multiplier 10000
  // USDJPY (2-digit): 1 pip = 0.01, multiplier 100
  void _autoHitungPips() {
    final entry = double.tryParse(_entryPriceCtrl.text);
    final sl = double.tryParse(_slCtrl.text);
    final tp = double.tryParse(_tpCtrl.text);

    // Butuh entry price untuk hitung
    if (entry == null) return;
    // BE tidak perlu auto-hitung
    if (_selectedHasil == 'BE' || _selectedHasil.isEmpty) return;

    // Tentukan multiplier berdasarkan pair
    double pipsMultiplier;
    if (_selectedPair == 'XAUUSD') {
      pipsMultiplier = 10.0;      // Gold: 0.1 per pip
    } else if (_selectedPair == 'USDJPY') {
      pipsMultiplier = 100.0;     // JPY pair: 0.01 per pip
    } else {
      pipsMultiplier = 10000.0;   // Pair 4-desimal: 0.0001 per pip
    }

    if (_selectedHasil == 'WIN' && tp != null && tp != 0.0) {
      final diff = (tp - entry).abs();
      final pips = (diff * pipsMultiplier).round();
      _pipsCtrl.text = pips.toString();
    } else if (_selectedHasil == 'LOSS' && sl != null && sl != 0.0) {
      final diff = (sl - entry).abs();
      final pips = -(diff * pipsMultiplier).round();
      _pipsCtrl.text = pips.toString();
    }
  }

  // ===================== AMBIL SCREENSHOT =====================
  Future<void> _ambilScreenshot() async {
    // Tunjukkan pilihan: Kamera atau Galeri
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih Sumber Gambar',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.accent),
              title: Text('Kamera',
                  style: GoogleFonts.poppins(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.accent),
              title: Text('Galeri',
                  style: GoogleFonts.poppins(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (choice == null) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: choice,
        imageQuality: 80, // Kompres sedikit untuk hemat storage
      );

      if (image == null) return;

      // Salin gambar ke folder documents app
      final appDir = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory('${appDir.path}/screenshots');
      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      // Nama file unik berdasarkan timestamp
      final fileName =
          'trade_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final savedPath = '${screenshotDir.path}/$fileName';

      await File(image.path).copy(savedPath);

      setState(() {
        _screenshotPath = savedPath;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal mengambil gambar: $e', isError: true);
      }
    }
  }

  // ===================== DIALOG TAMBAH PAIR CUSTOM =====================
  void _showTambahPairDialog() {
    _customPairCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Tambah Pair',
          style: GoogleFonts.poppins(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: _customPairCtrl,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.poppins(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Contoh: GBPJPY',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newPair = _customPairCtrl.text.trim().toUpperCase();
              if (newPair.isNotEmpty && !_pairs.contains(newPair)) {
                setState(() {
                  _pairs.add(newPair);
                  _selectedPair = newPair;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  // ===================== VALIDASI & SIMPAN =====================
  Future<void> _simpanTrade() async {
    // Validasi wajib
    if (_selectedPair == null) {
      _showSnackbar('Pair wajib dipilih!', isError: true);
      return;
    }
    if (_lotSizeCtrl.text.trim().isEmpty) {
      _showSnackbar('Lot Size wajib diisi!', isError: true);
      return;
    }
    if (_selectedHasil.isEmpty) {
      _showSnackbar('Hasil trade (WIN/LOSS/BE) wajib dipilih!', isError: true);
      return;
    }

    final lotSize = double.tryParse(_lotSizeCtrl.text);
    if (lotSize == null || lotSize <= 0) {
      _showSnackbar('Lot Size tidak valid!', isError: true);
      return;
    }

    final pips = int.tryParse(_pipsCtrl.text) ?? 0;
    final entryPrice = double.tryParse(_entryPriceCtrl.text) ?? 0.0;
    final sl = double.tryParse(_slCtrl.text) ?? 0.0;
    final tp = double.tryParse(_tpCtrl.text) ?? 0.0;

    // Hitung P/L otomatis (dengan logika sign berdasarkan hasil)
    final pl = TradeProvider.hitungPL(_selectedPair!, pips, lotSize, _selectedHasil);

    final trade = Trade(
      pair: _selectedPair!,
      entryPrice: entryPrice,
      lotSize: lotSize,
      sl: sl,
      tp: tp,
      hasil: _selectedHasil,
      pips: pips,
      pl: pl,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      screenshotPath: _screenshotPath,
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);

    final provider = context.read<TradeProvider>();
    final success = await provider.saveTrade(trade);

    setState(() => _isSaving = false);

    if (success && mounted) {
      _showSnackbar('Trade berhasil disimpan! 🎯', isError: false);
      _resetForm();
    } else if (mounted) {
      _showSnackbar('Gagal menyimpan trade.', isError: true);
    }
  }

  void _resetForm() {
    _entryPriceCtrl.clear();
    _lotSizeCtrl.clear();
    _slCtrl.clear();
    _tpCtrl.clear();
    _pipsCtrl.clear();
    _noteCtrl.clear();
    setState(() {
      _selectedPair = null;
      _selectedHasil = '';
      _screenshotPath = null;
    });
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.loss : AppColors.win,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Trade'),
        actions: [
          // Tombol reset form
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Reset Form',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- PAIR DROPDOWN ----
              _buildSectionLabel('Pair'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPair,
                          hint: Text('Pilih Pair',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textHint)),
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceVariant,
                          style: GoogleFonts.poppins(
                              color: AppColors.textPrimary, fontSize: 14),
                          items: _pairs.map((pair) {
                            return DropdownMenuItem(
                              value: pair,
                              child: Text(pair),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedPair = value);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol tambah pair custom
                  GestureDetector(
                    onTap: _showTambahPairDialog,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ---- ENTRY PRICE & LOT SIZE ----
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Entry Price'),
                        const SizedBox(height: 8),
                        _buildNumberField(
                          controller: _entryPriceCtrl,
                          hint: '2045.50',
                          isDecimal: true,
                          onChanged: (_) => _autoHitungPips(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Lot Size *'),
                        const SizedBox(height: 8),
                        _buildNumberField(
                          controller: _lotSizeCtrl,
                          hint: '0.10',
                          isDecimal: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ---- SL & TP ----
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Stop Loss'),
                        const SizedBox(height: 8),
                        _buildNumberField(
                          controller: _slCtrl,
                          hint: '2040.00',
                          isDecimal: true,
                          onChanged: (_) => _autoHitungPips(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Take Profit'),
                        const SizedBox(height: 8),
                        _buildNumberField(
                          controller: _tpCtrl,
                          hint: '2055.00',
                          isDecimal: true,
                          onChanged: (_) => _autoHitungPips(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ---- HASIL RADIO BUTTON ----
              _buildSectionLabel('Hasil Trade *'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildHasilChip('WIN', AppColors.win),
                  const SizedBox(width: 10),
                  _buildHasilChip('LOSS', AppColors.loss),
                  const SizedBox(width: 10),
                  _buildHasilChip('BE', AppColors.be),
                ],
              ),

              const SizedBox(height: 16),

              // ---- PIPS ----
              _buildSectionLabel('Pips (auto / manual)'),
              const SizedBox(height: 8),
              TextField(
                controller: _pipsCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                inputFormatters: [
                  // Izinkan minus opsional di awal, diikuti digit
                  FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                ],
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Contoh: 20 atau -15',
                  prefixIcon:
                      Icon(Icons.trending_up, color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 16),

              // ---- NOTE ----
              _buildSectionLabel('Catatan (opsional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Setup, alasan entry, kondisi market...',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

              // ---- SCREENSHOT ----
              _buildSectionLabel('Screenshot'),
              const SizedBox(height: 8),
              _buildScreenshotWidget(),

              const SizedBox(height: 28),

              // ---- TOMBOL SIMPAN ----
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _simpanTrade,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Menyimpan...' : 'SIMPAN TRADE'),
                ),
              ),

              const SizedBox(height: 32),
            ],
        ),
      ),
    );
  }

  // ===================== WIDGET HELPERS =====================

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String hint,
    bool isDecimal = false,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: [
        // Regex tanpa anchor ^ $ karena FilteringTextInputFormatter bekerja per karakter
        FilteringTextInputFormatter.allow(
            isDecimal ? RegExp(r'[\d.]') : RegExp(r'\d')),
      ],
      style: GoogleFonts.poppins(color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: hint),
      onChanged: onChanged,
    );
  }

  // Chip untuk pilihan WIN / LOSS / BE
  Widget _buildHasilChip(String label, Color color) {
    final isSelected = _selectedHasil == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedHasil = label;
          });
          _autoHitungPips();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget area screenshot
  Widget _buildScreenshotWidget() {
    if (_screenshotPath != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_screenshotPath!),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Tombol hapus gambar
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                // Hapus file yang sudah di-copy ke documents agar tidak orphan
                final pathToDelete = _screenshotPath;
                setState(() => _screenshotPath = null);
                if (pathToDelete != null) {
                  File(pathToDelete).exists().then((exists) {
                    if (exists) File(pathToDelete).delete();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.loss,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    // Belum ada gambar, tampilkan tombol
    return GestureDetector(
      onTap: _ambilScreenshot,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.accent.withOpacity(0.5),
              style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.accent.withOpacity(0.7), size: 32),
            const SizedBox(height: 6),
            Text(
              'Tap untuk ambil/pilih screenshot',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
