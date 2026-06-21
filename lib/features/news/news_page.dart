import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/blog_provider.dart';
import '../../core/models/blog_post_model.dart';
import 'package:go_router/go_router.dart';
import '../../core/shell/main_shell.dart';

const _categories = [
  'All',
  'Markets',
  'Stocks',
  'Investing',
  'Economics',
  'Crypto',
  'Technology',
];

const _categoryColors = {
  'Markets':    Color(0xFF6366F1),
  'Stocks':     Color(0xFF10B981),
  'Investing':  Color(0xFFF59E0B),
  'Economics':  Color(0xFFEF4444),
  'Crypto':     Color(0xFFF97316),
  'Technology': Color(0xFF3B82F6),
};

class NewsPage extends ConsumerStatefulWidget {
  const NewsPage({super.key});

  @override
  ConsumerState<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends ConsumerState<NewsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(blogPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('News'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(blogPostsProvider),
          ),
          MainShellMenu.themeButton(),
          MainShellMenu.settingsButton(),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.emerald,
          labelColor: AppColors.emerald,
          unselectedLabelColor: context.colors.textMuted,
          dividerColor: context.colors.surfaceAlt,
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: postsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: context.colors.textMuted, size: 48),
              SizedBox(height: 12),
              Text('Failed to load articles',
                  style: TextStyle(color: context.colors.textMuted)),
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(blogPostsProvider),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: BorderSide(color: AppColors.emerald),
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
        data: (posts) => TabBarView(
          controller: _tab,
          children: _categories.map((cat) {
            final filtered = cat == 'All'
                ? posts
                : posts.where((p) => p.category == cat).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.article_outlined,
                        color: context.colors.textMuted, size: 48),
                    SizedBox(height: 12),
                    Text('No articles yet',
                        style: TextStyle(color: context.colors.textMuted)),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.emerald,
              onRefresh: () async {
                ref.invalidate(blogPostsProvider);
                await ref
                    .read(blogPostsProvider.future)
                    .then((_) {})
                    .catchError((_) {});
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.colors.surfaceAlt,
                    indent: 16,
                    endIndent: 16),
                itemBuilder: (_, i) => _PostTile(post: filtered[i]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final BlogPost post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColors[post.category] ?? AppColors.emerald;
    final ago      = _timeAgo(post.publishedAt);

    return InkWell(
      onTap: () => context.push('/blog/${post.slug}', extra: post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (post.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post.imageUrl!,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _ImagePlaceholder(color: catColor),
                ),
              )
            else
              _ImagePlaceholder(color: catColor),

            SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post.category,
                          style: TextStyle(
                              fontSize: 10,
                              color: catColor,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(ago,
                          style: TextStyle(
                              fontSize: 11, color: context.colors.textMuted)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      post.excerpt!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textMuted,
                          height: 1.4),
                    ),
                  ],
                ],
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
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      if (diff.inDays < 30)    return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365)   return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (_) {
      return '';
    }
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final Color color;
  const _ImagePlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.article_rounded,
          color: color.withValues(alpha: 0.4), size: 32),
    );
  }
}
