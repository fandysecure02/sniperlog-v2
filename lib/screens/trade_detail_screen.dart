import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
import '../theme/app_theme.dart';

// Halaman detail satu trade, termasuk tampilan gambar penuh
class TradeDetailScreen extends StatelessWidget {
  final Trade trade;

  const TradeDetailScreen({super.key, required this.trade});

  String _formatTanggal(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _hasilColor(String hasil) {
    switch (hasil) {
      case 'WIN':
        return AppColors.win;
      case 'LOSS':
        return AppColors.loss;
      default:
        return AppColors.be;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Trade #${trade.id}'),
        actions: [
          // Tombol hapus trade
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.loss),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Screenshot penuh jika ada
            if (trade.screenshotPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(trade.screenshotPath!),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, _) => Container(
                    height: 120,
                    color: AppColors.surfaceVariant,
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Card info utama
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header: Pair + Hasil badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          trade.pair,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _hasilColor(trade.hasil).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _hasilColor(trade.hasil), width: 1.5),
                          ),
                          child: Text(
                            trade.hasil,
                            style: GoogleFonts.poppins(
                              color: _hasilColor(trade.hasil),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatTanggal(trade.createdAt),
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const Divider(height: 24),

                    // P/L besar di tengah
                    Text(
                      '${trade.pl >= 0 ? '+' : ''}\$${trade.pl.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: trade.pl >= 0 ? AppColors.win : AppColors.loss,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${trade.pips >= 0 ? '+' : ''}${trade.pips} pips',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const Divider(height: 24),

                    // Detail angka
                    _buildDetailRow('Entry Price',
                        trade.entryPrice.toStringAsFixed(5)),
                    _buildDetailRow('Lot Size', trade.lotSize.toString()),
                    _buildDetailRow(
                        'Stop Loss', trade.sl.toStringAsFixed(5)),
                    _buildDetailRow(
                        'Take Profit', trade.tp.toStringAsFixed(5)),
                  ],
                ),
              ),
            ),

            // Note jika ada
            if (trade.note != null && trade.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notes,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Catatan',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trade.note!,
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog konfirmasi hapus
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Hapus Trade?',
          style: GoogleFonts.poppins(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Trade ini akan dihapus permanen dari database.',
          style:
              GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () async {
              // Tutup dialog dulu
              Navigator.pop(ctx);
              // Simpan provider & navigator sebelum async gap
              final provider = context.read<TradeProvider>();
              final navigator = Navigator.of(context);
              await provider.deleteTrade(trade.id!);
              // Kembali ke halaman sebelumnya (dashboard)
              navigator.pop();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
