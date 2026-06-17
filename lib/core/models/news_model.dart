class NewsItem {
  final String title;
  final String url;
  final String? image;
  final String source;
  final String publishedAt;
  final String summary;
  final String sentiment; // Positive | Negative | Neutral
  final List<String> tickers;

  const NewsItem({
    required this.title,
    required this.url,
    this.image,
    required this.source,
    required this.publishedAt,
    required this.summary,
    required this.sentiment,
    required this.tickers,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
    title:       j['title'] as String,
    url:         j['url'] as String,
    image:       j['image'] as String?,
    source:      j['source'] as String,
    publishedAt: j['publishedAt'] as String,
    summary:     j['summary'] as String? ?? '',
    sentiment:   j['sentiment'] as String? ?? 'Neutral',
    tickers:     (j['tickers'] as List?)?.cast<String>() ?? [],
  );
}
