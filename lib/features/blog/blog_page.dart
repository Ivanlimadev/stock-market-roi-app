import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/blog_provider.dart';
import '../../core/models/blog_post_model.dart';

class BlogPage extends ConsumerWidget {
  const BlogPage({super.key});

  static const _catColors = {
    'Stocks':     Color(0xFF10B981),
    'Investing':  Color(0xFFF59E0B),
    'Markets':    Color(0xFF6366F1),
    'Economics':  Color(0xFFEF4444),
    'Crypto':     Color(0xFFF97316),
    'Technology': Color(0xFF3B82F6),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blogPostsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blog')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: context.colors.textMuted),
              SizedBox(height: 12),
              Text('Error loading posts',
                  style: TextStyle(color: context.colors.textMuted)),
              SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(blogPostsProvider),
                style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                child: Text('Try again',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text('No articles available',
                  style: TextStyle(color: context.colors.textMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.colors.surfaceAlt),
            itemBuilder: (context, i) =>
                _PostTile(post: posts[i], catColors: _catColors),
          );
        },
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final BlogPost post;
  final Map<String, Color> catColors;
  const _PostTile({required this.post, required this.catColors});

  @override
  Widget build(BuildContext context) {
    final color = catColors[post.category] ?? AppColors.emerald;

    return InkWell(
      onTap: () => context.push('/blog/${post.slug}', extra: post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (post.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  width: 80, height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(context, color),
                ),
              )
            else
              _placeholder(context, color),

            SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(post.category,
                        style: TextStyle(fontSize: 10, color: color,
                            fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(height: 6),
                  // Title
                  Text(post.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary, height: 1.3)),
                  if (post.excerpt != null) ...[
                    SizedBox(height: 4),
                    Text(post.excerpt!,
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12,
                            color: context.colors.textMuted, height: 1.4)),
                  ],
                ],
              ),
            ),

            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, Color color) => Container(
    width: 80, height: 70,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.article_rounded, color: color.withValues(alpha: 0.5), size: 28),
  );
}
