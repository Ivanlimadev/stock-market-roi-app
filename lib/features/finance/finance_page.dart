import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/shell/main_shell.dart';
import '../../core/widgets/app_bottom_nav.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final earningsProvider = FutureProvider.autoDispose<List<EarningsEvent>>((ref) async {
  final res = await ApiClient.dio.get('/calendar/earnings');
  final list = (res.data as List? ?? []);
  return list.map((e) => EarningsEvent.fromJson(e as Map<String, dynamic>)).toList();
});

final dividendsProvider = FutureProvider.autoDispose<List<DividendEvent>>((ref) async {
  final res = await ApiClient.dio.get('/calendar/dividends');
  final list = (res.data as List? ?? []);
  return list.map((e) => DividendEvent.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Models ────────────────────────────────────────────────────────────────────

class EarningsEvent {
  final String symbol;
  final String? name;
  final String? date;
  final String? time; // 'bmo' | 'amc'
  final double? epsEstimate;
  final double? epsActual;

  const EarningsEvent({required this.symbol, this.name, this.date, this.time,
    this.epsEstimate, this.epsActual});

  factory EarningsEvent.fromJson(Map<String, dynamic> j) => EarningsEvent(
    symbol:      j['symbol']      as String? ?? '',
    name:        j['name']        as String?,
    date:        j['date']        as String?,
    time:        j['time']        as String?,
    epsEstimate: (j['epsEstimate'] as num?)?.toDouble(),
    epsActual:   (j['epsActual']   as num?)?.toDouble(),
  );
}

class DividendEvent {
  final String symbol;
  final String? name;
  final String? exDate;
  final double? amount;

  const DividendEvent({required this.symbol, this.name, this.exDate, this.amount});

  factory DividendEvent.fromJson(Map<String, dynamic> j) => DividendEvent(
    symbol:  j['symbol']  as String? ?? '',
    name:    j['name']    as String?,
    exDate:  j['exDate']  as String? ?? j['ex_dividend_date'] as String?,
    amount:  (j['amount'] as num?)?.toDouble() ?? (j['dividend'] as num?)?.toDouble(),
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});
  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.public_rounded),
            tooltip: 'US Economy',
            onPressed: () => context.push('/us-macro'),
          ),
          MainShellMenu.themeButton(),
          MainShellMenu.settingsButton(),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.emerald,
          labelColor: AppColors.emerald,
          unselectedLabelColor: context.colors.textMuted,
          tabs: const [
            Tab(text: 'Earnings'),
            Tab(text: 'Dividends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _EarningsTab(),
          _DividendsTab(),
        ],
      ),
    );
  }
}

// ── Earnings tab ──────────────────────────────────────────────────────────────

class _EarningsTab extends ConsumerWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(earningsProvider);

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () async {
        ref.invalidate(earningsProvider);
        await ref.read(earningsProvider.future).then((_) {}).catchError((_) {});
      },
      child: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => _retryCenter(context, 'Earnings unavailable', () => ref.invalidate(earningsProvider)),
        data: (events) {
          // Group by date
          final grouped = <String, List<EarningsEvent>>{};
          for (final e in events) {
            final key = e.date ?? 'Unknown';
            grouped.putIfAbsent(key, () => []).add(e);
          }
          final dates = grouped.keys.toList()..sort();

          if (dates.isEmpty) {
            return Center(
              child: Text('No upcoming earnings', style: TextStyle(color: context.colors.textMuted)));
          }

          return ListView.builder(
            itemCount: dates.length,
            itemBuilder: (_, i) {
              final date   = dates[i];
              final items  = grouped[date]!;
              final label  = _fmtDate(date);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(label,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: context.colors.textMuted, letterSpacing: 0.5)),
                  ),
                  ...items.map((e) => _EarningsRow(event: e)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  final EarningsEvent event;
  const _EarningsRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final hasActual = event.epsActual != null;
    final beat = hasActual && event.epsEstimate != null &&
        event.epsActual! >= event.epsEstimate!;

    return InkWell(
      onTap: () => context.push('/stocks/${event.symbol}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(9)),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                'https://assets.parqet.com/logos/symbol/${event.symbol}?format=png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    event.symbol.length >= 2 ? event.symbol.substring(0, 2) : event.symbol,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: context.colors.textMuted)),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.symbol,
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                  if (event.name != null)
                    Text(event.name!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (event.time != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                    child: Text(event.time == 'bmo' ? 'Pre-market' : 'After-hours',
                      style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                  ),
                if (event.epsEstimate != null) ...[
                  SizedBox(height: 3),
                  Text(
                    hasActual
                        ? 'EPS: \$${event.epsActual!.toStringAsFixed(2)}'
                        : 'Est: \$${event.epsEstimate!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: hasActual
                          ? (beat ? AppColors.emerald : AppColors.red)
                          : context.colors.textSecond),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dividends tab ─────────────────────────────────────────────────────────────

class _DividendsTab extends ConsumerWidget {
  const _DividendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dividendsProvider);

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () async {
        ref.invalidate(dividendsProvider);
        await ref.read(dividendsProvider.future).then((_) {}).catchError((_) {});
      },
      child: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => _retryCenter(context, 'Dividends unavailable', () => ref.invalidate(dividendsProvider)),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Text('No upcoming dividends', style: TextStyle(color: context.colors.textMuted)));
          }
          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_ , $) => Divider(height: 1, color: context.colors.surfaceAlt),
            itemBuilder: (_, i) => _DividendRow(event: events[i]),
          );
        },
      ),
    );
  }
}

class _DividendRow extends StatelessWidget {
  final DividendEvent event;
  const _DividendRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/stocks/${event.symbol}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(9)),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                'https://assets.parqet.com/logos/symbol/${event.symbol}?format=png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    event.symbol.length >= 2 ? event.symbol.substring(0, 2) : event.symbol,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: context.colors.textMuted)),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.symbol,
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                  if (event.name != null)
                    Text(event.name!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (event.amount != null)
                  Text('\$${event.amount!.toStringAsFixed(4)}',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      color: AppColors.emerald)),
                if (event.exDate != null) ...[
                  SizedBox(height: 2),
                  Text('Ex: ${_fmtDate(event.exDate!)}',
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _retryCenter(BuildContext context, String msg, VoidCallback onRetry) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: context.colors.textMuted),
        SizedBox(height: 12),
        Text(msg, style: TextStyle(color: context.colors.textMuted)),
        SizedBox(height: 16),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.emerald,
            side: BorderSide(color: AppColors.emerald),
          ),
          child: Text('Retry'),
        ),
      ],
    ),
  );
}

String _fmtDate(String iso) {
  try {
    final dt  = DateTime.parse(iso);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'Today';
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day) return 'Tomorrow';
    return DateFormat('MMM d, yyyy').format(dt);
  } catch (_) {
    return iso;
  }
}
