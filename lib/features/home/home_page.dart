import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/market_provider.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/providers/crypto_provider.dart';
import '../../core/providers/blog_provider.dart';
import '../../core/providers/watchlist_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/portfolio_provider.dart' hide StockQuote;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/market_model.dart';
import '../../core/models/crypto_model.dart';
import '../../core/models/blog_post_model.dart';

import '../../core/utils/formatters.dart';
import 'widgets/index_card.dart';
import '../../core/shell/main_shell.dart';

// Inline providers for calendar (reuse from finance page logic)
import '../../core/api/api_client.dart';

final _calEarningsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/calendar/earnings');
  return (data).cast<Map<String, dynamic>>();
});

final _calDividendsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/calendar/dividends');
  return (data).cast<Map<String, dynamic>>();
});

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

  /// Enters search mode. Pre-fills a popular ticker (selected, so typing
  /// replaces it) so results/cards show immediately instead of a blank screen.
  void _enterSearch() {
    if (!_searching) setState(() => _searching = true);
    if (_searchCtrl.text.isEmpty) {
      const seed = 'NVDA';
      _searchCtrl.text = seed;
      _searchCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: seed.length);
      ref.read(_stockQueryProvider.notifier).state = seed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query      = ref.watch(_stockQueryProvider);
    final screener   = ref.watch(screenerProvider);
    final cryptoData = ref.watch(cryptoMarketsProvider);

    // Lets the shared search button (from any tab) open search here.
    ref.listen(searchTriggerProvider, (_, __) {
      if (mounted) _enterSearch();
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: _searching ? 8 : NavigationToolbar.kMiddleSpacing,
        title: _searching
            ? Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 20, color: context.colors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                            color: context.colors.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search stocks and crypto…',
                          hintStyle: TextStyle(color: context.colors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) => ref
                            .read(_stockQueryProvider.notifier)
                            .state = v.trim(),
                      ),
                    ),
                  ],
                ),
              )
            : Text('Markets'),
        leading: _searching
            ? IconButton(icon: Icon(Icons.arrow_back), onPressed: _clearSearch)
            : null,
        actions: [
          if (_searching && query.isNotEmpty)
            IconButton(icon: Icon(Icons.close), onPressed: _clearSearch)
          else if (!_searching) ...[
            IconButton(
              icon: Icon(Icons.search_rounded),
              onPressed: _enterSearch,
            ),
            MainShellMenu.themeButton(),
            MainShellMenu.settingsButton(),
            MainShellMenu.avatarButton(),
          ],
        ],
      ),
      body: _searching
          ? _SearchResults(query: query, screener: screener, crypto: cryptoData)
          : const _MarketsBody(),
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  final String query;
  final AsyncValue<List<StockQuote>> screener;
  final AsyncValue<List<CryptoMarket>> crypto;
  const _SearchResults(
      {required this.query, required this.screener, required this.crypto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (query.trim().isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_rounded, size: 48, color: c.surfaceAlt),
          const SizedBox(height: 12),
          Text('Search stocks, crypto and articles',
              style: TextStyle(color: c.textMuted)),
        ]),
      );
    }

    final q = query.toLowerCase();
    int score(String sym, String name) {
      final s = sym.toLowerCase();
      final n = name.toLowerCase();
      if (s == q) return 4;
      if (s.startsWith(q)) return 3;
      if (n.startsWith(q)) return 2;
      if (s.contains(q) || n.contains(q)) return 1;
      return 0;
    }

    // 1) Matching assets — top 10 (5 + 5 in a 2-column grid).
    final scored = <({Widget card, int score})>[];
    for (final s in (screener.valueOrNull ?? <StockQuote>[])) {
      final sc = score(s.symbol, s.name);
      if (sc > 0) {
        scored.add((
          card: _AssetCard(
            logo: _Logo(symbol: s.symbol, size: 34, radius: 9),
            symbol: s.symbol,
            name: s.name,
            price: fmtStockPrice(s.price),
            changePct: s.changePct,
            onTap: () => context.push('/stocks/${s.symbol}'),
          ),
          score: sc,
        ));
      }
    }
    for (final cm in (crypto.valueOrNull ?? <CryptoMarket>[])) {
      final sc = score(cm.symbol, cm.name);
      if (sc > 0) {
        scored.add((
          card: _AssetCard(
            logo: _CoinLogo(image: cm.image, symbol: cm.symbol),
            symbol: cm.symbol.toUpperCase(),
            name: cm.name,
            price: fmtCryptoPrice(cm.currentPrice),
            changePct: cm.priceChangePercentage24h,
            onTap: () => context.push('/crypto/${cm.id}'),
          ),
          score: sc,
        ));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final assetCards = scored.take(10).map((e) => e.card).toList();

    // 2) Favorites (watchlist) — up to 10.
    final favs = (ref.watch(watchlistProvider).valueOrNull ?? <WatchlistItem>[])
        .take(10)
        .toList();

    // 3) Related articles — blog posts matching the query.
    final posts = (ref.watch(blogPostsProvider).valueOrNull ?? <BlogPost>[])
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            (p.excerpt ?? '').toLowerCase().contains(q) ||
            (p.tickers ?? const <String>[])
                .any((t) => t.toLowerCase().contains(q)))
        .take(6)
        .toList();

    if (assetCards.isEmpty && favs.isEmpty && posts.isEmpty) {
      return Center(
        child: Text('No results for "$query"',
            style: TextStyle(color: c.textMuted)),
      );
    }

    final cardW = (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2;
    Widget grid(List<Widget> cards) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final w in cards) SizedBox(width: cardW, child: w)],
        );

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (assetCards.isNotEmpty) ...[
          const _SearchSection('Results'),
          grid(assetCards),
        ],
        if (favs.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SearchSection('Favorites'),
          grid([for (final f in favs) _FavCard(item: f)]),
        ],
        if (posts.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SearchSection('Related articles'),
          for (final p in posts) _SearchPostCard(post: p),
        ],
      ],
    );
  }
}

class _SearchSection extends StatelessWidget {
  final String title;
  const _SearchSection(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: context.colors.textMuted)),
      );
}

class _CoinLogo extends StatelessWidget {
  final String image, symbol;
  const _CoinLogo({required this.image, required this.symbol});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Image.network(image, width: 34, height: 34,
            errorBuilder: (_, __, ___) => Container(
                  width: 34,
                  height: 34,
                  color: context.colors.surfaceAlt,
                  child: Center(
                      child: Text(symbol.toUpperCase().substring(0, 1),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: context.colors.textMuted))),
                )),
      );
}

class _AssetCard extends StatelessWidget {
  final Widget logo;
  final String symbol, name, price;
  final double changePct;
  final VoidCallback onTap;
  const _AssetCard({
    required this.logo,
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = changePct >= 0 ? AppColors.emerald : AppColors.red;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.surfaceAlt),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            logo,
            const SizedBox(width: 10),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: c.textPrimary)),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: c.textPrimary)),
            ),
            const SizedBox(width: 6),
            _ChangeBadge(value: changePct, color: color),
          ]),
        ]),
      ),
    );
  }
}

class _FavCard extends StatelessWidget {
  final WatchlistItem item;
  const _FavCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCrypto = item.assetType == 'crypto';
    final logo = (isCrypto && (item.image?.isNotEmpty ?? false))
        ? _CoinLogo(image: item.image!, symbol: item.symbol)
        : _Logo(symbol: item.symbol, size: 34, radius: 9);
    return InkWell(
      onTap: () => isCrypto
          ? context.push(
              '/crypto/${item.coingeckoId ?? item.symbol.toLowerCase()}')
          : context.push('/stocks/${item.symbol}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.surfaceAlt),
        ),
        child: Row(children: [
          logo,
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.symbol.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: c.textPrimary)),
              Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textMuted)),
            ]),
          ),
          const Icon(Icons.star_rounded, size: 16, color: AppColors.emerald),
        ]),
      ),
    );
  }
}

class _SearchPostCard extends StatelessWidget {
  final BlogPost post;
  const _SearchPostCard({required this.post});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/blog/${post.slug}', extra: post),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.surfaceAlt),
          ),
          child: Row(children: [
            if (post.imageUrl?.isNotEmpty ?? false)
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(14)),
                child: Image.network(post.imageUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(width: 72, height: 72, color: c.surfaceAlt)),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.category.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emerald,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                              height: 1.25)),
                    ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child:
                  Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Markets body ──────────────────────────────────────────────────────────────

/// Greets the signed-in user and shows their total portfolio balance at the
/// top of the Markets/Home screen.
class _WelcomeHeader extends ConsumerWidget {
  const _WelcomeHeader();

  String _fallbackName() {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first;
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }
    return 'Investor';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final holdings = ref.watch(portfolioEnrichedProvider);

    final name = profile.maybeWhen(
      data: (p) {
        final dn = p?.displayName?.trim();
        return (dn != null && dn.isNotEmpty) ? dn : _fallbackName();
      },
      orElse: _fallbackName,
    );

    final total = holdings.maybeWhen(
      data: (list) => list.fold<double>(0, (s, h) => s + h.currentValue),
      orElse: () => null,
    );
    final fmt = NumberFormat.simpleCurrency(locale: 'en_US');
    final hide = ref.watch(hideBalancesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: TextStyle(fontSize: 13, color: c.textMuted)),
                const SizedBox(height: 2),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Portfolio balance',
                  style: TextStyle(fontSize: 11, color: c.textMuted)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Street mode: toggle balance visibility right next to it.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref
                        .read(hideBalancesProvider.notifier)
                        .state = !hide,
                    child: Icon(
                        hide
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: c.textMuted),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    total == null ? '—' : (hide ? '••••' : fmt.format(total)),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketsBody extends ConsumerStatefulWidget {
  const _MarketsBody();
  @override
  ConsumerState<_MarketsBody> createState() => _MarketsBodyState();
}

class _MarketsBodyState extends ConsumerState<_MarketsBody> {
  int _rankTab = 3; // default Dividend (0=Gainers 1=Losers 2=Active 3=Dividend 4=Trending)

  @override
  Widget build(BuildContext context) {
    final marketAsync  = ref.watch(marketOverviewProvider);
    final heatmapAsync = ref.watch(top10ByMarketCapProvider);
    final gainersAsync = ref.watch(topGainersProvider);
    final losersAsync  = ref.watch(topLosersProvider);
    final activeAsync  = ref.watch(topByVolumeProvider);
    final divAsync     = ref.watch(topDividendProvider);
    final trendAsync   = ref.watch(trendingProvider);
    final earningsAsync = ref.watch(_calEarningsProvider);
    final dividendsAsync = ref.watch(_calDividendsProvider);
    final cryptoAsync  = ref.watch(cryptoMarketsProvider);
    final blogAsync    = ref.watch(blogPostsProvider);

    AsyncValue<List<StockQuote>> rankData() {
      return switch (_rankTab) {
        0 => gainersAsync,
        1 => losersAsync,
        2 => activeAsync,
        3 => divAsync,
        _ => trendAsync,
      };
    }

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () async {
        ref.invalidate(marketOverviewProvider);
        ref.invalidate(screenerProvider);
        ref.invalidate(trendingProvider);
        ref.invalidate(cryptoMarketsProvider);
        ref.invalidate(blogPostsProvider);
        ref.invalidate(_calEarningsProvider);
        ref.invalidate(_calDividendsProvider);
        await Future.wait([
          ref.read(marketOverviewProvider.future).then((_) {}).catchError((_) {}),
          ref.read(screenerProvider.future).then((_) {}).catchError((_) {}),
        ]);
      },
      child: ListView(
        children: [

          // ── 0. Welcome + portfolio balance ─────────────────────────────
          const _WelcomeHeader(),

          // ── 1. Index Cards ─────────────────────────────────────────────
          marketAsync.when(
            loading: () => _indexSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              if (data.indices.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    for (int i = 0; i < data.indices.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: IndexCard(index: data.indices[i])),
                    ],
                  ],
                ),
              );
            },
          ),

          // ── 2. Top 10 Heatmap ─────────────────────────────────────────
          _SectionHeader(title: 'Top 10 Stocks', subtitle: 'By market cap'),
          heatmapAsync.when(
            loading: () => _heatmapSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stocks) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: stocks.length,
                itemBuilder: (_, i) => _HeatmapCard(stock: stocks[i]),
              ),
            ),
          ),

          // ── 3. Rankings ────────────────────────────────────────────────
          _SectionHeader(title: 'Rankings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _RankChip(label: 'Dividend', idx: 3, current: _rankTab, onTap: (v) => setState(() => _rankTab = v)),
                  _RankChip(label: 'Gainers',  idx: 0, current: _rankTab, onTap: (v) => setState(() => _rankTab = v)),
                  _RankChip(label: 'Losers',   idx: 1, current: _rankTab, onTap: (v) => setState(() => _rankTab = v)),
                  _RankChip(label: 'Active',   idx: 2, current: _rankTab, onTap: (v) => setState(() => _rankTab = v)),
                  _RankChip(label: 'Trending', idx: 4, current: _rankTab, onTap: (v) => setState(() => _rankTab = v)),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          rankData().when(
            loading: () => _rankSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stocks) => Column(
              children: stocks.take(5).toList().asMap().entries.map((e) =>
                _RankRow(stock: e.value, rank: e.key + 1, tab: _rankTab),
              ).toList(),
            ),
          ),

          // ── 3b. Calculators (most-used) ────────────────────────────────
          _SectionHeader(
            title: 'Calculators',
            trailing: GestureDetector(
              onTap: () => context.push('/calculators'),
              child: Text('See all',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Expanded(
                    child: _CalcCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Compound',
                        route: '/calculators/compound-interest')),
                SizedBox(width: 10),
                Expanded(
                    child: _CalcCard(
                        icon: Icons.calendar_month_rounded,
                        label: 'DCA',
                        route: '/calculators/dca')),
                SizedBox(width: 10),
                Expanded(
                    child: _CalcCard(
                        icon: Icons.percent_rounded,
                        label: 'ROI',
                        route: '/calculators/roi')),
              ],
            ),
          ),
          SizedBox(height: 8),

          // ── 4. Calendar: Dividends & Earnings ─────────────────────────
          _SectionHeader(title: 'Calendar'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _CalCard(
                  title: 'Dividends',
                  icon: Icons.attach_money_rounded,
                  color: AppColors.emerald,
                  async: dividendsAsync,
                  builder: (item) => _DivRow(item: item),
                )),
                SizedBox(width: 10),
                Expanded(child: _CalCard(
                  title: 'Earnings',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF6366F1),
                  async: earningsAsync,
                  builder: (item) => _EarningsRow(item: item),
                )),
              ],
            ),
          ),

          // ── 5. Crypto Preview ──────────────────────────────────────────
          _SectionHeader(
            title: 'Crypto',
            trailing: TextButton(
              onPressed: () => context.push('/crypto'),
              child: Text('See more', style: TextStyle(color: AppColors.emerald, fontSize: 12)),
            ),
          ),
          cryptoAsync.when(
            loading: () => _cryptoSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (coins) => Column(
              children: coins.take(5).map((c) => _CryptoPreviewRow(coin: c)).toList(),
            ),
          ),

          // ── 6. Artigos Recentes ────────────────────────────────────────
          _SectionHeader(
            title: 'Do Nosso Blog',
            subtitle: 'Artigos recentes',
            trailing: TextButton(
              onPressed: () => context.go('/news'),
              child: Text('Ver todos', style: TextStyle(color: AppColors.emerald, fontSize: 12)),
            ),
          ),
          blogAsync.when(
            loading: () => _blogSkeleton(),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Error loading posts: $e',
                  style: TextStyle(fontSize: 11, color: AppColors.red)),
            ),
            data: (posts) {
              final recent = posts.take(4).toList();
              if (recent.isEmpty) return const SizedBox.shrink();
              return Column(
                children: recent.map((post) => _HomeBlogTile(post: post)).toList(),
              );
            },
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _indexSkeleton() => SizedBox(
    height: 112,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      separatorBuilder: (_, __) => SizedBox(width: 10),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        width: 110, height: 92,
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _heatmapSkeleton() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 2.6, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: 10,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12))),
    ),
  );

  Widget _rankSkeleton() => Column(
    children: List.generate(5, (_) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(height: 44, decoration: BoxDecoration(
        color: context.colors.surface, borderRadius: BorderRadius.circular(10))),
    )),
  );

  Widget _cryptoSkeleton() => Column(
    children: List.generate(5, (_) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(height: 44, decoration: BoxDecoration(
        color: context.colors.surface, borderRadius: BorderRadius.circular(10))),
    )),
  );

  Widget _blogSkeleton() => Column(
    children: List.generate(3, (_) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(
          color: context.colors.surface, borderRadius: BorderRadius.circular(10))),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 12, width: 60, color: context.colors.surface),
          SizedBox(height: 8),
          Container(height: 14, color: context.colors.surface),
          SizedBox(height: 6),
          Container(height: 14, width: double.infinity * 0.7, color: context.colors.surface),
        ])),
      ]),
    )),
  );
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ],
        )),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _Logo extends StatelessWidget {
  final String symbol;
  final double size;
  final double radius;
  const _Logo({required this.symbol, this.size = 36, this.radius = 10});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(radius)),
    clipBehavior: Clip.antiAlias,
    child: Image.network(
      'https://assets.parqet.com/logos/symbol/$symbol?format=png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Text(symbol.length >= 2 ? symbol.substring(0, 2) : symbol,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: size * 0.28, color: context.colors.textMuted)),
      ),
    ),
  );
}

class _ChangeBadge extends StatelessWidget {
  final double value;
  final Color color;
  const _ChangeBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%',
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

// ── Calculator card ───────────────────────────────────────────────────────────

class _CalcCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _CalcCard({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.emerald, size: 22),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ── Heatmap card ──────────────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  final StockQuote stock;
  const _HeatmapCard({required this.stock});

  @override
  Widget build(BuildContext context) {
    final up    = stock.changePct >= 0;
    final color = up ? AppColors.emerald : AppColors.red;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/stocks/${stock.symbol}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.surfaceAlt),
        ),
        child: Row(children: [
          _Logo(symbol: stock.symbol, size: 36, radius: 9),
          SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stock.symbol, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
            Text(fmtStockPrice(stock.price), style: TextStyle(fontSize: 11, color: context.colors.textSecond)),
          ])),
          _ChangeBadge(value: stock.changePct, color: color),
        ]),
      ),
    );
  }
}

// ── Rankings ──────────────────────────────────────────────────────────────────

class _RankChip extends StatelessWidget {
  final String label;
  final int idx;
  final int current;
  final ValueChanged<int> onTap;
  const _RankChip({required this.label, required this.idx, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = idx == current;
    return GestureDetector(
      onTap: () => onTap(idx),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.emerald : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.emerald : context.colors.surfaceAlt),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : context.colors.textMuted,
        )),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final StockQuote stock;
  final int rank;
  final int tab;
  const _RankRow({required this.stock, required this.rank, required this.tab});

  @override
  Widget build(BuildContext context) {
    final up    = stock.changePct >= 0;
    final color = up ? AppColors.emerald : AppColors.red;

    String value() {
      switch (tab) {
        case 2: // Active — volume
          final v = stock.volume ?? 0;
          if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
          if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
          return v.toStringAsFixed(0);
        case 3: // Dividend yield
          return '${((stock.dividendYield ?? 0) * 100).toStringAsFixed(2)}%';
        default:
          return '${up ? '+' : ''}${stock.changePct.toStringAsFixed(2)}%';
      }
    }

    return InkWell(
      onTap: () => context.push('/stocks/${stock.symbol}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          SizedBox(width: 20, child: Text('$rank', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colors.textMuted), textAlign: TextAlign.center)),
          SizedBox(width: 10),
          _Logo(symbol: stock.symbol, size: 36, radius: 9),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stock.symbol, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            Text(stock.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tab == 2 ? context.colors.textPrimary : color)),
            if (tab == 2 || tab == 3)
              Text(fmtStockPrice(stock.price), style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ]),
        ]),
      ),
    );
  }
}

// ── Calendar ──────────────────────────────────────────────────────────────────

class _CalCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<List<Map<String, dynamic>>> async;
  final Widget Function(Map<String, dynamic>) builder;
  const _CalCard({required this.title, required this.icon, required this.color,
    required this.async, required this.builder});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.surfaceAlt),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
      Divider(height: 1, color: context.colors.surfaceAlt),
      async.when(
        loading: () => Padding(padding: const EdgeInsets.all(12),
          child: Column(children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(height: 32, decoration: BoxDecoration(
              color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(6))),
          )))),
        error: (_, __) => Padding(padding: EdgeInsets.all(12),
          child: Text('Unavailable', style: TextStyle(fontSize: 11, color: context.colors.textMuted))),
        data: (items) => Column(
          children: items.take(4).map(builder).toList(),
        ),
      ),
    ]),
  );
}

class _DivRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DivRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final symbol = item['symbol'] as String? ?? '';
    final exDate = item['exDate'] as String? ?? item['ex_dividend_date'] as String? ?? '';
    final amount = (item['amount'] as num?)?.toDouble() ?? (item['dividend'] as num?)?.toDouble() ?? 0.0;
    String fmtDate(String iso) {
      try { return DateFormat('MMM d').format(DateTime.parse(iso)); } catch (_) { return iso; }
    }
    return InkWell(
      onTap: () => context.push('/stocks/$symbol'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          _Logo(symbol: symbol, size: 28, radius: 7),
          SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(symbol, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            if (exDate.isNotEmpty) Text(fmtDate(exDate), style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
          ])),
          if (amount > 0) Text('\$${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald)),
        ]),
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _EarningsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final symbol = item['symbol'] as String? ?? '';
    final date   = item['date']   as String? ?? '';
    final time   = item['time']   as String?;
    String fmtDate(String iso) {
      try { return DateFormat('MMM d').format(DateTime.parse(iso)); } catch (_) { return iso; }
    }
    Color timeColor = time == 'bmo' ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);
    String timeLabel = time == 'bmo' ? 'Pre' : time == 'amc' ? 'Post' : '';
    return InkWell(
      onTap: () => context.push('/stocks/$symbol'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          _Logo(symbol: symbol, size: 28, radius: 7),
          SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(symbol, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            if (date.isNotEmpty) Text(fmtDate(date), style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
          ])),
          if (timeLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: timeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(timeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: timeColor)),
            ),
        ]),
      ),
    );
  }
}

// ── Crypto preview ────────────────────────────────────────────────────────────

class _CryptoPreviewRow extends StatelessWidget {
  final CryptoMarket coin;
  const _CryptoPreviewRow({required this.coin});

  @override
  Widget build(BuildContext context) {
    final up    = coin.priceChangePercentage24h >= 0;
    final color = up ? AppColors.emerald : AppColors.red;
    String fmtPrice(double p) => fmtCryptoPrice(p).replaceFirst('\$', '');
    return InkWell(
      onTap: () => context.push('/crypto/${coin.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 24,
            child: Text('#${coin.marketCapRank ?? ''}',
              style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ),
          SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(coin.image, width: 36, height: 36,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 36, height: 36, color: context.colors.surfaceAlt,
                child: Center(child: Text(coin.symbol.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textMuted))),
              )),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(coin.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            Text(coin.symbol.toUpperCase(), style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${fmtPrice(coin.currentPrice)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            SizedBox(height: 2),
            _ChangeBadge(value: coin.priceChangePercentage24h, color: color),
          ]),
        ]),
      ),
    );
  }
}

// ── Home Blog Tile ────────────────────────────────────────────────────────────

const _homeCatColors = {
  'Markets':    Color(0xFF6366F1),
  'Stocks':     Color(0xFF10B981),
  'Investing':  Color(0xFFF59E0B),
  'Economics':  Color(0xFFEF4444),
  'Crypto':     Color(0xFFF97316),
  'Technology': Color(0xFF3B82F6),
};

class _HomeBlogTile extends StatelessWidget {
  final BlogPost post;
  const _HomeBlogTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final catColor = _homeCatColors[post.category] ?? AppColors.emerald;
    final ago      = _blogTimeAgo(post.publishedAt);

    return InkWell(
      onTap: () => context.push('/blog/${post.slug}', extra: post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: post.imageUrl != null
                  ? Image.network(
                      post.imageUrl!,
                      width: 72, height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _blogPlaceholder(catColor),
                    )
                  : _blogPlaceholder(catColor),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(post.category,
                        style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w700)),
                    ),
                    SizedBox(width: 8),
                    Text(ago, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                  ]),
                  SizedBox(height: 5),
                  Text(
                    post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary, height: 1.4),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _blogPlaceholder(Color color) => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.article_rounded, color: color.withValues(alpha: 0.4), size: 28),
  );

  String _blogTimeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      if (diff.inDays < 30)    return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) { return ''; }
  }
}
