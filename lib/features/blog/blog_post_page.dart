import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/share_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/blog_post_model.dart';
import '../../core/providers/blog_provider.dart';
import '../../core/providers/stock_detail_provider.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_footer.dart';
import '../../core/widgets/author_byline.dart';
import '../../core/data/blog_authors.dart';
import '../../core/widgets/comments_section.dart';
import '../../core/ads/native_ad_tile.dart';

// Busca o post completo pelo slug quando content não vem na navegação
final _fullPostProvider = FutureProvider.autoDispose
    .family<BlogPost, String>((ref, slug) async {
  final data = await Supabase.instance.client
      .from('blog_posts')
      .select('slug, title, excerpt, content, image_url, category, published_at, tickers, author_slug')
      .eq('slug', slug)
      .single();
  return BlogPost.fromJson(data);
});

int _readingTime(String? content) {
  if (content == null || content.isEmpty) return 1;
  final words = content.trim().split(RegExp(r'\s+')).length;
  final mins = (words / 200).ceil();
  return mins < 1 ? 1 : mins;
}

const _catColors = {
  'Stocks':     Color(0xFF10B981),
  'Investing':  Color(0xFFF59E0B),
  'Markets':    Color(0xFF6366F1),
  'Economics':  Color(0xFFEF4444),
  'Crypto':     Color(0xFFF97316),
  'Technology': Color(0xFF3B82F6),
};

class BlogPostPage extends ConsumerWidget {
  final String slug;
  final BlogPost? post;

  const BlogPostPage({super.key, required this.slug, this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tem conteúdo completo — renderiza direto
    if (post?.content != null) return _PostBody(post: post!);

    // Sem conteúdo — busca do Supabase
    final async = ref.watch(_fullPostProvider(slug));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Failed to load article')),
      ),
      data: (loaded) => _PostBody(post: loaded),
    );
  }
}

// ── Post body ─────────────────────────────────────────────────────────────────

class _PostBody extends ConsumerWidget {
  final BlogPost post;
  const _PostBody({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mdSheet = MarkdownStyleSheet(
      p:               TextStyle(fontSize: 15, color: context.colors.textSecond, height: 1.7),
      h1:              TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colors.textPrimary, height: 1.3),
      h2:              TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary, height: 1.35),
      h3:              TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
      strong:          TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary),
      em:              TextStyle(fontStyle: FontStyle.italic, color: context.colors.textSecond),
      a:               const TextStyle(
        color: Color(0xFFF59E0B),
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: Color(0xFFF59E0B),
      ),
      blockquote:      TextStyle(fontSize: 14, color: context.colors.textMuted, fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.emerald, width: 3)),
        color: AppColors.emerald.withValues(alpha: 0.05),
      ),
      code:            TextStyle(fontSize: 13, color: context.colors.textPrimary,
          backgroundColor: context.colors.surfaceAlt),
      codeblockDecoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          post.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        actions: [
          Builder(
            builder: (btnCtx) => IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share',
              onPressed: () {
                final text = '${post.title}\nhttps://stockmarketroi.com/blog/${post.slug}';
                if (post.imageUrl != null) {
                  shareWithImage(
                    btnCtx: btnCtx,
                    text: text,
                    imageUrl: post.imageUrl!,
                    filename: '${post.slug}.jpg',
                  );
                } else {
                  shareText(btnCtx, text);
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        children: [
          // ── Título completo + metadados ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
            child: Text(
              post.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          Row(children: [
            _CatBadge(category: post.category),
            const SizedBox(width: 8),
            Text(_timeAgo(post.publishedAt),
                style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
            const Spacer(),
            Icon(Icons.schedule_rounded, size: 13, color: context.colors.textMuted),
            const SizedBox(width: 3),
            Text('${_readingTime(post.content)} min read',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
          ]),
          if (post.excerpt != null && post.excerpt!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
              child: Text(
                post.excerpt!,
                style: TextStyle(
                  fontSize: 15,
                  color: context.colors.textMuted,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 8),

          // ── Conteúdo do post (com native ad in-article) ──────────────────
          ..._articleContent(context, mdSheet),

          // ── Card do ativo relacionado ─────────────────────────────────
          if (post.tickers != null && post.tickers!.isNotEmpty) ...[
            const SizedBox(height: 32),
            _TickerCard(ticker: post.tickers!.first),
          ],

          const SizedBox(height: 28),
          _ShareRow(post: post),
          const SizedBox(height: 14),
          _TagsRow(post: post),

          const SizedBox(height: 40),
          Divider(color: context.colors.surfaceAlt),
          const SizedBox(height: 20),

          // ── Mais artigos ─────────────────────────────────────────────────
          _MoreArticles(currentSlug: post.slug, category: post.category),

          // ── Author byline (tap to expand) ────────────────────────────────
          AuthorByline(author: authorForSlug(post.authorSlug)),

          // ── Discussion ───────────────────────────────────────────────────
          CommentsSection(target: (type: 'post', id: post.slug)),

          const SizedBox(height: 32),

          // ── Footer ───────────────────────────────────────────────────────
          const AppFooter(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Renders the article body, splitting it in half (on a paragraph boundary)
  /// to drop a single in-article native ad into the middle — but only for posts
  /// long enough that the ad isn't jammed next to the title or the footer.
  List<Widget> _articleContent(BuildContext context, MarkdownStyleSheet sheet) {
    final leadingImage =
        post.imageUrl != null ? '![${post.title}](${post.imageUrl})\n\n' : '';
    final content = post.content ?? '';

    void onTapLink(String text, String? href, String? title) {
      if (href == null) return;
      final uri = Uri.tryParse(href);
      if (uri == null) return;
      final path = uri.path;
      if (uri.host.isEmpty || uri.host.contains('stockmarketroi.com')) {
        if (path.startsWith('/stocks/') ||
            path.startsWith('/crypto/') ||
            path.startsWith('/blog/')) {
          context.push(path);
          return;
        }
      }
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Widget md(String data) => MarkdownBody(
          selectable: true,
          onTapLink: onTapLink,
          styleSheet: sheet,
          data: data,
        );

    final paras =
        content.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();

    // Short posts: render whole, no in-article ad.
    if (paras.length < 6) {
      return [md(leadingImage + content)];
    }

    final splitAt = (paras.length / 2).floor();
    final first = paras.sublist(0, splitAt).join('\n\n');
    final second = paras.sublist(splitAt).join('\n\n');

    return [
      md(leadingImage + first),
      const SizedBox(height: 20),
      const NativeAdTile(label: 'Advertisement'),
      const SizedBox(height: 20),
      md(second),
    ];
  }

  String _timeAgo(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      if (diff.inDays < 30)    return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) { return ''; }
  }
}

// ── Mais Artigos (com abas Related / Latest) ─────────────────────────────────

class _MoreArticles extends ConsumerStatefulWidget {
  final String currentSlug;
  final String category;
  const _MoreArticles({required this.currentSlug, required this.category});

  @override
  ConsumerState<_MoreArticles> createState() => _MoreArticlesState();
}

class _MoreArticlesState extends ConsumerState<_MoreArticles> {
  int _tab = 0; // 0 = Related, 1 = Latest

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(blogPostsProvider);
    final c = context.colors;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (e, _) => const SizedBox.shrink(),
      data: (all) {
        List<BlogPost> posts;
        if (_tab == 0) {
          final same  = all.where((p) => p.slug != widget.currentSlug && p.category == widget.category).take(4).toList();
          final other = all.where((p) => p.slug != widget.currentSlug && p.category != widget.category).toList();
          posts = [...same, ...other].take(4).toList();
        } else {
          posts = all.where((p) => p.slug != widget.currentSlug).take(4).toList();
        }
        if (posts.isEmpty) return const SizedBox.shrink();

        final featured = posts.first;
        final rest     = posts.skip(1).where((p) => p.imageUrl != null).take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('More Articles',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                          color: c.textPrimary)),
                ),
                _TabBtn(label: 'Related', selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0)),
                const SizedBox(width: 6),
                _TabBtn(label: 'Latest', selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Featured (1º) com resumo ──────────────────────────────────
            GestureDetector(
              onTap: () => context.push('/blog/${featured.slug}', extra: featured),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (featured.imageUrl != null)
                      Image.network(
                        featured.imageUrl!,
                        width: double.infinity, height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, _) => const SizedBox.shrink(),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CatBadge(category: featured.category),
                          const SizedBox(height: 8),
                          Text(featured.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary, height: 1.3)),
                          if (featured.excerpt != null && featured.excerpt!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(featured.excerpt!,
                                maxLines: 3, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13,
                                    color: c.textMuted, height: 1.5)),
                          ],
                          const SizedBox(height: 10),
                          Row(children: [
                            Text('Read article',
                                style: TextStyle(fontSize: 12,
                                    color: AppColors.emerald,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 13, color: AppColors.emerald),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── 3 cards com imagem + título ───────────────────────────────
            ...rest.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => context.push('/blog/${p.slug}', extra: p),
                child: Container(
                  height: 88,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      if (p.imageUrl != null)
                        SizedBox(
                          width: 88, height: 88,
                          child: Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, _) => Container(
                              color: c.surfaceAlt,
                              child: Icon(Icons.article_outlined,
                                  size: 24, color: c.textMuted),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 88, height: 88,
                          color: c.surfaceAlt,
                          child: Icon(Icons.article_outlined,
                              size: 24, color: c.textMuted),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CatBadge(category: p.category, small: true),
                              const SizedBox(height: 5),
                              Text(p.title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary, height: 1.3)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}

// ── Ticker Card ──────────────────────────────────────────────────────────────

class _TickerCard extends ConsumerWidget {
  final String ticker;
  const _TickerCard({required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(stockDetailProvider(ticker));
    final historyAsync = ref.watch(stockHistoryProvider(ticker));
    final c = context.colors;

    return detailAsync.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error:   (e, _) => const SizedBox.shrink(),
      data: (stock) {
        double? change12m;
        historyAsync.whenData((bars) {
          if (bars.length >= 2) {
            final first = bars.first.close;
            final last  = bars.last.close;
            if (first > 0) change12m = (last - first) / first * 100;
          }
        });

        final info = stock.info;
        final isUp = (change12m ?? 0) >= 0;

        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabeçalho: logo + ticker + nome ──────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'https://assets.parqet.com/logos/symbol/$ticker?format=png',
                        width: 56, height: 56, fit: BoxFit.contain,
                        errorBuilder: (ctx, err, _) => Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(ticker.substring(0, 1),
                                style: TextStyle(fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticker,
                              style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary)),
                          Text(stock.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Métricas ─────────────────────────────────────────────
              Divider(height: 1, color: c.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    Row(children: [
                      _MetricTile(
                        label: 'Price',
                        value: '\$${_fmt(stock.currentPrice)}',
                        valueColor: c.textPrimary,
                      ),
                      _MetricTile(
                        label: 'Chg (12M)',
                        value: change12m != null
                            ? '${isUp ? '+' : ''}${change12m!.toStringAsFixed(2)}%'
                            : '--',
                        valueColor: change12m == null
                            ? c.textPrimary
                            : isUp ? AppColors.emerald : AppColors.red,
                        trailing: change12m != null
                            ? Icon(
                                isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 16,
                                color: isUp ? AppColors.emerald : AppColors.red,
                              )
                            : null,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _MetricTile(
                        label: 'Net Margin',
                        value: info?.profitMargin != null
                            ? '${(info!.profitMargin! * 100).toStringAsFixed(2)}%'
                            : '--',
                        valueColor: c.textPrimary,
                      ),
                      _MetricTile(
                        label: 'Div. Yield',
                        value: info?.dividendYield != null
                            ? '${(info!.dividendYield! * 100).toStringAsFixed(2)}%'
                            : '--',
                        valueColor: c.textPrimary,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _MetricTile(
                        label: 'P/E',
                        value: info?.pe != null ? _fmt(info!.pe!) : '--',
                        valueColor: c.textPrimary,
                      ),
                      _MetricTile(
                        label: 'P/B',
                        value: info?.priceToBook != null ? _fmt(info!.priceToBook!) : '--',
                        valueColor: c.textPrimary,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/stocks/$ticker'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('View all indicators ($ticker)'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return v.toStringAsFixed(0);
    if (v >= 100)     return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  const _MetricTile({required this.label, required this.value,
      this.valueColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? context.colors.textPrimary)),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Share Row ─────────────────────────────────────────────────────────────────

class _ShareRow extends StatelessWidget {
  final BlogPost post;
  const _ShareRow({required this.post});

  String get _url => 'https://stockmarketroi.com/blog/${post.slug}';
  String get _text => '${post.title}\n$_url';

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Share this article',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: c.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          _SocialBtn(
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            icon: Icons.chat_bubble_rounded,
            onTap: () => _open(
                'https://wa.me/?text=${Uri.encodeComponent(_text)}'),
          ),
          const SizedBox(width: 8),
          _SocialBtn(
            label: 'Telegram',
            color: const Color(0xFF0088CC),
            icon: Icons.near_me_rounded,
            onTap: () => _open(
                'https://t.me/share/url?url=${Uri.encodeComponent(_url)}&text=${Uri.encodeComponent(post.title)}'),
          ),
          const SizedBox(width: 8),
          _SocialBtn(
            label: 'Twitter/X',
            color: const Color(0xFF9CA3AF),
            symbol: 'X',
            onTap: () => _open(
                'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_text)}'),
          ),
          const SizedBox(width: 8),
          _SocialBtn(
            label: 'Copy Link',
            color: AppColors.emerald,
            icon: Icons.link_rounded,
            onTap: () {
              Clipboard.setData(ClipboardData(text: _url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Link copied!'),
                    duration: Duration(seconds: 2)),
              );
            },
          ),
        ]),
      ],
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final String? symbol;
  final VoidCallback onTap;
  const _SocialBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon!, size: 18, color: color)
              else
                Text(symbol!,
                    style: TextStyle(fontSize: 16, color: color,
                        fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 9, color: color,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tags Row ─────────────────────────────────────────────────────────────────

class _TagsRow extends StatelessWidget {
  final BlogPost post;
  const _TagsRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final tickers = post.tickers ?? [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TagChip(
          label: '#${post.category}',
          color: _catColors[post.category] ?? AppColors.emerald,
        ),
        ...tickers.map((t) => GestureDetector(
          onTap: () => context.push('/stocks/$t'),
          child: _TagChip(label: '\$$t', color: const Color(0xFFF59E0B)),
        )),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Tab Button ───────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.colors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Category Badge ────────────────────────────────────────────────────────────

class _CatBadge extends StatelessWidget {
  final String category;
  final bool small;
  const _CatBadge({required this.category, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = _catColors[category] ?? AppColors.emerald;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(category,
          style: TextStyle(
              fontSize: small ? 9 : 10,
              color: color,
              fontWeight: FontWeight.w700)),
    );
  }
}
