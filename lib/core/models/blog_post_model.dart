class BlogPost {
  final String slug;
  final String title;
  final String? excerpt;
  final String? content;
  final String? imageUrl;
  final String category;
  final String publishedAt;

  const BlogPost({
    required this.slug,
    required this.title,
    this.excerpt,
    this.content,
    this.imageUrl,
    required this.category,
    required this.publishedAt,
  });

  factory BlogPost.fromJson(Map<String, dynamic> j) => BlogPost(
    slug:        j['slug'] as String,
    title:       j['title'] as String,
    excerpt:     j['excerpt'] as String?,
    content:     j['content'] as String?,
    imageUrl:    j['image_url'] as String?,
    category:    j['category'] as String? ?? 'General',
    publishedAt: j['published_at'] as String? ?? '',
  );
}
