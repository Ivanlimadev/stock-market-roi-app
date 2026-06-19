import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/blog_post_model.dart';
import '../../core/providers/blog_provider.dart';

// Busca o post completo pelo slug quando content não vem na navegação
final _fullPostProvider = FutureProvider.autoDispose
    .family<BlogPost, String>((ref, slug) async {
  final data = await Supabase.instance.client
      .from('blog_posts')
      .select('slug, title, excerpt, content, image_url, category, published_at')
      .eq('slug', slug)
      .single();
  return BlogPost.fromJson(data);
});

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
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Erro ao carregar artigo')),
      ),
      data: (full) => _PostBody(post: full),
    );
  }
}

// ── Preview (sem conteúdo completo) ──────────────────────────────────────────

class _PostPreview extends StatelessWidget {
  final BlogPost post;
  const _PostPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final catColor = _catColors[post.category] ?? AppColors.emerald;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity, height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(post.category,
                    style: TextStyle(fontSize: 11, color: catColor,
                        fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: 10),
              Text(_timeAgo(post.publishedAt),
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
            ]),
            SizedBox(height: 14),
            Text(post.title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary, height: 1.3)),
            SizedBox(height: 16),
            if (post.excerpt != null && post.excerpt!.isNotEmpty)
              Text(post.excerpt!,
                  style: TextStyle(fontSize: 15, color: context.colors.textSecond,
                      height: 1.7)),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://stockmarketroi.com/blog/${post.slug}'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Read full article'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 24)  return '${diff.inHours}h ago';
      if (diff.inDays < 7)    return '${diff.inDays}d ago';
      if (diff.inDays < 30)   return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) { return ''; }
  }
}

// ── Leitor nativo completo ────────────────────────────────────────────────────

class _PostBody extends ConsumerWidget {
  final BlogPost post;
  const _PostBody({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catColor = _catColors[post.category] ?? AppColors.emerald;

    final mdSheet = MarkdownStyleSheet(
      p:               TextStyle(fontSize: 15, color: context.colors.textSecond, height: 1.7),
      h1:              TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colors.textPrimary, height: 1.3),
      h2:              TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary, height: 1.35),
      h3:              TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
      strong:          TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary),
      em:              TextStyle(fontStyle: FontStyle.italic, color: context.colors.textSecond),
      a:               TextStyle(color: AppColors.emerald, decoration: TextDecoration.underline),
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

    final mdContent = _buildMarkdown(post, catColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: () {
              final size = MediaQuery.sizeOf(context);
              Share.share(
                '${post.title}\nhttps://stockmarketroi.com/blog/${post.slug}',
                sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        children: [
          // ── Conteúdo do post ─────────────────────────────────────────────
          MarkdownBody(
            selectable: true,
            onTapLink: (text, href, title) {
              if (href != null) launchUrl(Uri.parse(href),
                  mode: LaunchMode.externalApplication);
            },
            styleSheet: mdSheet,
            data: mdContent,
          ),

          SizedBox(height: 40),
          Divider(color: context.colors.surfaceAlt),
          SizedBox(height: 20),

          // ── Mais artigos ─────────────────────────────────────────────────
          _MoreArticles(currentSlug: post.slug, category: post.category),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  String _buildMarkdown(BlogPost post, Color catColor) {
    final buf = StringBuffer();
    if (post.imageUrl != null) buf.writeln('![${post.title}](${post.imageUrl})\n');
    buf.writeln('**${post.category}** · ${_timeAgo(post.publishedAt)}\n');
    buf.writeln('# ${post.title}\n');
    if (post.excerpt != null && post.excerpt!.isNotEmpty) {
      buf.writeln('> ${post.excerpt}\n');
    }
    if (post.content != null && post.content!.isNotEmpty) {
      buf.writeln(post.content);
    }
    return buf.toString();
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

// ── Mais Artigos ─────────────────────────────────────────────────────────────

class _MoreArticles extends ConsumerWidget {
  final String currentSlug;
  final String category;
  const _MoreArticles({required this.currentSlug, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blogPostsProvider);
    final c = context.colors;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (all) {
        // Mesma categoria primeiro, depois outros; exclui o post atual
        final same  = all.where((p) => p.slug != currentSlug && p.category == category).take(4).toList();
        final other = all.where((p) => p.slug != currentSlug && p.category != category).toList();
        final posts = [...same, ...other].take(4).toList();
        if (posts.isEmpty) return const SizedBox.shrink();

        final featured = posts.first;
        final rest     = posts.skip(1).where((p) => p.imageUrl != null).take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Related Articles',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            SizedBox(height: 16),

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
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CatBadge(category: featured.category),
                          SizedBox(height: 8),
                          Text(featured.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary, height: 1.3)),
                          if (featured.excerpt != null && featured.excerpt!.isNotEmpty) ...[
                            SizedBox(height: 6),
                            Text(featured.excerpt!,
                                maxLines: 3, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13,
                                    color: c.textMuted, height: 1.5)),
                          ],
                          SizedBox(height: 10),
                          Row(children: [
                            Text('Read article',
                                style: TextStyle(fontSize: 12,
                                    color: AppColors.emerald,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
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

            SizedBox(height: 14),

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
                      // Imagem
                      if (p.imageUrl != null)
                        SizedBox(
                          width: 88, height: 88,
                          child: Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
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
                      // Título
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CatBadge(category: p.category, small: true),
                              SizedBox(height: 5),
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
