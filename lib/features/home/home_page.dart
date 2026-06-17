import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/market_provider.dart';
import '../../core/providers/news_provider.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';
import 'widgets/index_card.dart';
import 'widgets/stock_row.dart';
import 'widgets/news_card.dart';

final _stockQueryProvider = StateProvider<String>((ref) => '');

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();
  bool _searching   = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(_stockQueryProvider.notifier).state = '';
    _focusNode.unfocus();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final query        = ref.watch(_stockQueryProvider);
    final screenerData = ref.watch(screenerProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search stocks…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) =>
                    ref.read(_stockQueryProvider.notifier).state = v.trim(),
              )
            : const Text('Markets'),
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSearch,
              )
            : null,
        actions: [
          if (_searching && query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSearch,
            )
          else if (!_searching) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search stocks',
              onPressed: () => setState(() => _searching = true),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(marketOverviewProvider);
                ref.invalidate(marketNewsProvider);
                ref.invalidate(screenerProvider);
              },
            ),
          ],
        ],
      ),
      body: _searching
          ? _StockSearchResults(query: query, screener: screenerData)
          : _MarketsBody(ref: ref),
    );
  }
}

// ── Search results overlay ───────────────────────────────────────────────────

class _StockSearchResults extends StatelessWidget {
  final String query;
  final AsyncValue<List<StockQuote>> screener;
  const _StockSearchResults({required this.query, required this.screener});

  @override
  Widget build(BuildContext context) {
    return screener.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (e, _) => const Center(
          child: Text('Failed to load stocks',
              style: TextStyle(color: AppColors.textMuted))),
      data: (all) {
        final results = query.isEmpty
            ? all
            : all.where((s) =>
                s.symbol.toUpperCase().contains(query.toUpperCase()) ||
                s.name.toLowerCase().contains(query.toLowerCase())).toList();

        if (query.isNotEmpty && results.isEmpty) {
          return Center(
            child: Text('No results for "$query"',
                style: const TextStyle(color: AppColors.textMuted)));
        }

        if (query.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, size: 48, color: AppColors.surfaceAlt),
                SizedBox(height: 12),
                Text('Type to search stocks',
                    style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          );
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: results.length,
          itemBuilder: (_, i) => _SearchTile(stock: results[i]),
        );
      },
    );
  }
}

class _SearchTile extends StatelessWidget {
  final StockQuote stock;
  const _SearchTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    final up    = stock.changePct >= 0;
    final color = up ? AppColors.emerald : AppColors.red;

    return InkWell(
      onTap: () => context.push('/stocks/${stock.symbol}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                'https://assets.parqet.com/logos/symbol/${stock.symbol}?format=png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    stock.symbol.length >= 2
                        ? stock.symbol.substring(0, 2)
                        : stock.symbol,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.symbol,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(stock.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${stock.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${up ? '+' : ''}${stock.changePct.toStringAsFixed(2)}%',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Markets body (normal state) ───────────────────────────────────────────────

class _MarketsBody extends ConsumerWidget {
  const _MarketsBody({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final marketAsync  = innerRef.watch(marketOverviewProvider);
    final newsAsync    = innerRef.watch(marketNewsProvider);
    final gainersAsync = innerRef.watch(topGainersProvider);
    final losersAsync  = innerRef.watch(topLosersProvider);

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () async {
        innerRef.invalidate(marketOverviewProvider);
        innerRef.invalidate(marketNewsProvider);
        innerRef.invalidate(screenerProvider);
        await Future.wait([
          innerRef.read(marketOverviewProvider.future).then((_) {}).catchError((_) {}),
          innerRef.read(marketNewsProvider.future).then((_) {}).catchError((_) {}),
        ]);
      },
      child: ListView(
        children: [
          // Indices strip
          marketAsync.when(
            loading: () => _IndicesSkeletons(),
            error:   (e, _) => _errorTile('Market indices unavailable'),
            data: (data) {
              if (data.indices.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  separatorBuilder: (_ , $) => const SizedBox(width: 10),
                  itemCount: data.indices.length,
                  itemBuilder: (_, i) => IndexCard(index: data.indices[i]),
                ),
              );
            },
          ),

          // Top Gainers
          gainersAsync.when(
            loading: () => _MoversSkeletons(),
            error:   (e, _) => const SizedBox.shrink(),
            data: (stocks) {
              if (stocks.isEmpty) return const SizedBox.shrink();
              return _Section(
                title: 'Top Gainers',
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.emerald,
                child: Column(
                  children: stocks.take(5).map((s) => StockRow(stock: s)).toList(),
                ),
              );
            },
          ),

          // Top Losers
          losersAsync.when(
            loading: () => _MoversSkeletons(),
            error:   (e, _) => const SizedBox.shrink(),
            data: (stocks) {
              if (stocks.isEmpty) return const SizedBox.shrink();
              return _Section(
                title: 'Top Losers',
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.red,
                child: Column(
                  children: stocks.take(5).map((s) => StockRow(stock: s)).toList(),
                ),
              );
            },
          ),

          // Market News preview
          newsAsync.when(
            loading: () => _NewsSkeletons(),
            error:   (e, _) => _errorTile('News unavailable'),
            data: (news) {
              if (news.isEmpty) return const SizedBox.shrink();
              return _Section(
                title: 'Market News',
                icon: Icons.newspaper_rounded,
                iconColor: AppColors.textSecond,
                child: SizedBox(
                  height: 240,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    separatorBuilder: (_ , $) => const SizedBox(width: 12),
                    itemCount: news.length,
                    itemBuilder: (_, i) => NewsCard(news: news[i]),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _errorTile(String msg) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
  );
}

// ── Shared section header ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _Section(
      {required this.title,
      required this.icon,
      required this.iconColor,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────────────────────

class _IndicesSkeletons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        separatorBuilder: (_ , $) => const SizedBox(width: 10),
        itemCount: 4,
        itemBuilder: (_ , $) => Container(
          width: 110, height: 80,
          decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _MoversSkeletons extends StatelessWidget {
  const _MoversSkeletons();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Container(width: 120, height: 18, color: AppColors.surface),
        ),
        ...List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsSkeletons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        separatorBuilder: (_ , $) => const SizedBox(width: 12),
        itemCount: 3,
        itemBuilder: (_ , $) => Container(
          width: 260, height: 236,
          decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
