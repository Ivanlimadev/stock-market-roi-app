class BlogPost {
  final String slug;
  final String title;
  final String? excerpt;
  final String? content;
  final String? imageUrl;
  final String category;
  final String publishedAt;
  final List<String>? tickers;
  final String? authorSlug;

  const BlogPost({
    required this.slug,
    required this.title,
    this.excerpt,
    this.content,
    this.imageUrl,
    required this.category,
    required this.publishedAt,
    this.tickers,
    this.authorSlug,
  });

  factory BlogPost.fromJson(Map<String, dynamic> j) => BlogPost(
    slug:        j['slug'] as String,
    title:       j['title'] as String,
    excerpt:     j['excerpt'] as String?,
    content:     j['content'] as String?,
    imageUrl:    j['image_url'] as String?,
    category:    j['category'] as String? ?? 'General',
    publishedAt: j['published_at'] as String? ?? '',
    tickers:     (j['tickers'] as List?)?.map((e) => e as String).toList(),
    authorSlug:  j['author_slug'] as String?,
  );
}
