import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/news_provider.dart';
import '../../core/models/news_model.dart';

class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(marketNewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(marketNewsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: () async {
          ref.invalidate(marketNewsProvider);
          await ref.read(marketNewsProvider.future).then((_) {}).catchError((_) {});
        },
        child: newsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text('Could not load news', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(marketNewsProvider),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emerald,
                    side: const BorderSide(color: AppColors.emerald),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (news) => ListView.separated(
            itemCount: news.length,
            separatorBuilder: (_ , $) => const Divider(height: 1, color: AppColors.surfaceAlt),
            itemBuilder: (_, i) => _NewsListTile(item: news[i]),
          ),
        ),
      ),
    );
  }
}

class _NewsListTile extends StatelessWidget {
  final NewsItem item;
  const _NewsListTile({required this.item});

  Color _sentimentColor() {
    switch (item.sentiment) {
      case 'Positive': return AppColors.emerald;
      case 'Negative': return AppColors.red;
      default:         return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (item.image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.image!,
                  width: 80, height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            if (item.image != null) const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: _sentimentColor(), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(item.source,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const Spacer(),
                      Text(_timeAgo(item.publishedAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary, height: 1.35)),
                  if (item.tickers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: item.tickers.take(4).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(t,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                      )).toList(),
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
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)    return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}
