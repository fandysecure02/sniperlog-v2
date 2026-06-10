import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
import '../theme/app_theme.dart';
import 'trade_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  String _formatTanggal(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ===================== EXPORT CSV =====================
  Future<void> _exportCSV() async {
    final provider = context.read<TradeProvider>();
    if (provider.allTrades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Belum ada data untuk diexport.'),
            backgroundColor: AppColors.be),
      );
      return;
    }

    try {
      final csv = provider.generateCSV();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sniperlog_trades.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'SniperLog Trading Data',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal export: $e'),
              backgroundColor: AppColors.loss),
        );
      }
    }
  }

  // ===================== DIALOG EDIT BALANCE =====================
  Future<void> _editBalance() async {
    final provider = context.read<TradeProvider>();
    // Buat controller lokal dan pastikan di-dispose setelah dialog selesai
    final ctrl = TextEditingController(
        text: provider.initialBalance.toStringAsFixed(2));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Atur Balance Awal',
          style: GoogleFonts.poppins(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.poppins(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            prefixText: '\$ ',
            hintText: '1000.00',
          ),
          // Autofocus agar keyboard langsung muncul
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style:
                    GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val >= 0) {
                await provider.updateInitialBalance(val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    // Dispose controller setelah dialog ditutup
    ctrl.dispose();
  }

  // ===================== DIALOG RESET DATA =====================
  Future<void> _resetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '⚠️ Reset Semua Data?',
          style: GoogleFonts.poppins(
              color: AppColors.loss, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Semua trade dan balance akan dihapus permanen!\nAksi ini tidak bisa dibatalkan.',
          style: GoogleFonts.poppins(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style:
                    GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Reset!'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<TradeProvider>().resetAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Data berhasil direset.'),
              backgroundColor: AppColors.be),
        );
      }
    }
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          // Export CSV
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _exportCSV,
            tooltip: 'Export CSV',
          ),
          // Settings / Reset
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'balance') _editBalance();
              if (value == 'reset') _resetData();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'balance',
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text('Atur Balance Awal',
                        style:
                            GoogleFonts.poppins(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_outlined,
                        color: AppColors.loss, size: 18),
                    const SizedBox(width: 8),
                    Text('Reset Semua Data',
                        style: GoogleFonts.poppins(color: AppColors.loss)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<TradeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final hasTrades = provider.allTrades.isNotEmpty;

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: provider.loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- GRID ANALYTICS CARDS ----
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.4,
                    children: [
                      // Balance Awal
                      _buildStatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Balance Awal',
                        value:
                            '\$${provider.initialBalance.toStringAsFixed(2)}',
                        valueColor: AppColors.textPrimary,
                        onTap: _editBalance,
                        showEdit: true,
                      ),
                      // Current Balance
                      _buildStatCard(
                        icon: Icons.show_chart,
                        label: 'Current Balance',
                        value:
                            '\$${provider.currentBalance.toStringAsFixed(2)}',
                        valueColor: provider.currentBalance >=
                                provider.initialBalance
                            ? AppColors.win
                            : AppColors.loss,
                      ),
                      // Total P/L
                      _buildStatCard(
                        icon: Icons.attach_money,
                        label: 'Total P/L',
                        value:
                            '${provider.totalPL >= 0 ? '+' : ''}\$${provider.totalPL.toStringAsFixed(2)}',
                        valueColor:
                            provider.totalPL >= 0 ? AppColors.win : AppColors.loss,
                      ),
                      // Winrate
                      _buildStatCard(
                        icon: Icons.emoji_events_outlined,
                        label: 'Winrate',
                        value:
                            '${provider.winrate.toStringAsFixed(1)}%',
                        valueColor: provider.winrate >= 50
                            ? AppColors.win
                            : AppColors.loss,
                        subtitle: hasTrades
                            ? '${provider.allTrades.length} total trade'
                            : null,
                      ),
                      // Max Drawdown
                      _buildStatCard(
                        icon: Icons.trending_down,
                        label: 'Max Drawdown',
                        value:
                            '${provider.maxDrawdown['percent']!.toStringAsFixed(1)}%',
                        valueColor: AppColors.loss,
                        subtitle:
                            '\$${provider.maxDrawdown['dollar']!.toStringAsFixed(2)}',
                      ),
                      // Trade Hari Ini
                      _buildStatCard(
                        icon: Icons.today_outlined,
                        label: 'Trade Hari Ini',
                        value: '${provider.todayTradeCount}',
                        valueColor: AppColors.textPrimary,
                        subtitle:
                            '${provider.todayPL >= 0 ? '+' : ''}\$${provider.todayPL.toStringAsFixed(2)}',
                        subtitleColor: provider.todayPL >= 0
                            ? AppColors.win
                            : AppColors.loss,
                      ),
                      // Consecutive Loss
                      _buildStatCard(
                        icon: Icons.warning_amber_outlined,
                        label: 'Max Loss Streak',
                        value: '${provider.maxConsecutiveLoss}x',
                        valueColor: AppColors.loss,
                        bgColor: AppColors.consecutiveLossBg,
                        subtitle: 'berurutan',
                      ),
                      // Consecutive Win
                      _buildStatCard(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Max Win Streak',
                        value: '${provider.maxConsecutiveWin}x',
                        valueColor: AppColors.win,
                        bgColor: AppColors.consecutiveWinBg,
                        subtitle: 'berurutan',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ---- LIST TRADE TERBARU ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trade Terbaru',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${provider.recentTrades.length} trade',
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Empty state
                  if (!hasTrades)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.recentTrades.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        return _buildTradeItem(
                            provider.recentTrades[i], context);
                      },
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================== WIDGET CARDS STAT =====================
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    Color? bgColor,
    String? subtitle,
    Color? subtitleColor,
    bool showEdit = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 16),
                if (showEdit)
                  const Icon(Icons.edit_outlined,
                      color: AppColors.accent, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: subtitleColor ?? AppColors.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================== ITEM LIST TRADE =====================
  Widget _buildTradeItem(Trade trade, BuildContext context) {
    final hasilColor = trade.hasil == 'WIN'
        ? AppColors.win
        : trade.hasil == 'LOSS'
            ? AppColors.loss
            : AppColors.be;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TradeDetailScreen(trade: trade),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            // Thumbnail screenshot kecil (jika ada)
            if (trade.screenshotPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(trade.screenshotPath!),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                ),
              )
            else
              _thumbPlaceholder(),

            const SizedBox(width: 12),

            // Info trade
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trade.pair,
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Badge hasil
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasilColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trade.hasil,
                          style: GoogleFonts.poppins(
                            color: hasilColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTanggal(trade.createdAt),
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      // P/L dan pips
                      Row(
                        children: [
                          Text(
                            '${trade.pips >= 0 ? '+' : ''}${trade.pips}p  ',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${trade.pl >= 0 ? '+' : ''}\$${trade.pl.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              color: trade.pl >= 0
                                  ? AppColors.win
                                  : AppColors.loss,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'Lot: ${trade.lotSize}',
                    style: GoogleFonts.poppins(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }

  // Placeholder thumbnail saat tidak ada screenshot
  Widget _thumbPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.candlestick_chart_outlined,
          color: AppColors.textHint, size: 24),
    );
  }

  // Empty state
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
              color: AppColors.textHint.withOpacity(0.5), size: 64),
          const SizedBox(height: 16),
          Text(
            'Belum ada trade.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catat trade pertamamu!',
            style: GoogleFonts.poppins(
              color: AppColors.textHint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
