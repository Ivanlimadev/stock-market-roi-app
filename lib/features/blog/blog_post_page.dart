import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/blog_post_model.dart';

const _catColors = {
  'Stocks':     Color(0xFF10B981),
  'Investing':  Color(0xFFF59E0B),
  'Markets':    Color(0xFF6366F1),
  'Economics':  Color(0xFFEF4444),
  'Crypto':     Color(0xFFF97316),
  'Technology': Color(0xFF3B82F6),
};

class BlogPostPage extends StatelessWidget {
  final String slug;
  final BlogPost? post; // passed from nav with full content when available

  const BlogPostPage({super.key, required this.slug, this.post});

  @override
  Widget build(BuildContext context) {
    // Full content available → render natively
    if (post?.content != null) {
      return _PostBody(post: post!);
    }
    // Only excerpt available → show preview card
    if (post != null) {
      return _PostPreview(post: post!);
    }
    // Nothing passed — should not happen, show empty
    return Scaffold(
      appBar: AppBar(title: const Text('Artigo')),
      body: const Center(child: CircularProgressIndicator()),
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
            // Imagem
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

            // Badge + data
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

            // Título
            Text(post.title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary, height: 1.3)),
            SizedBox(height: 16),

            // Excerpt
            if (post.excerpt != null && post.excerpt!.isNotEmpty)
              Text(post.excerpt!,
                  style: TextStyle(fontSize: 15, color: context.colors.textSecond,
                      height: 1.7)),
            SizedBox(height: 32),

            // Botão para ler completo
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

class _PostBody extends StatelessWidget {
  final BlogPost post;
  const _PostBody({required this.post});

  @override
  Widget build(BuildContext context) {
    final catColor = _catColors[post.category] ?? AppColors.emerald;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in browser',
            onPressed: () => launchUrl(
              Uri.parse('https://stockmarketroi.com/blog/${post.slug}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Markdown(
        selectable: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        onTapLink: (text, href, title) {
          if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        },
        styleSheet: MarkdownStyleSheet(
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
        ),
        builders: {},
        data: _buildMarkdown(post, catColor),
      ),
    );
  }

  String _buildMarkdown(BlogPost post, Color catColor) {
    final buf = StringBuffer();

    // Cover image
    if (post.imageUrl != null) {
      buf.writeln('![${post.title}](${post.imageUrl})\n');
    }

    // Category + date
    buf.writeln('**${post.category}** · ${_timeAgo(post.publishedAt)}\n');

    // Title
    buf.writeln('# ${post.title}\n');

    // Excerpt as intro
    if (post.excerpt != null && post.excerpt!.isNotEmpty) {
      buf.writeln('> ${post.excerpt}\n');
    }

    // Full content
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
