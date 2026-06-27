/// Blog author registry (mirrors the website's src/lib/authors.ts).
///
/// Posts carry an `author_slug`; this resolves it to a display author. Falls
/// back to the founder (Ivan) for unknown/empty slugs.
class BlogAuthor {
  final String slug;
  final String name;
  final String role;
  final String initials;
  final String photo; // bundled asset path
  final String bio;
  final bool founder; // only the founder shows social links + About page

  const BlogAuthor({
    required this.slug,
    required this.name,
    required this.role,
    required this.initials,
    required this.photo,
    required this.bio,
    this.founder = false,
  });
}

const _ivan = BlogAuthor(
  slug: 'ivan-lima',
  name: 'Ivan Lima',
  role: 'Author',
  initials: 'IL',
  photo: 'assets/images/ivan-lima.jpg',
  founder: true,
  bio:
      'Systems Analysis & Development student and active US stock market investor '
      'since 2018. Ivan built Stock Market ROI to give retail investors direct '
      'access to the same data and analytical tools he wished existed when he '
      'started. Every article is written from the perspective of someone with '
      'real skin in the game - tracking earnings, reading SEC filings, and '
      'following market cycles for over eight years.',
);

const _jennifer = BlogAuthor(
  slug: 'jennifer-moore',
  name: 'Jennifer Moore',
  role: 'Markets Correspondent',
  initials: 'JM',
  photo: 'assets/images/jennifer-moore.jpg',
  bio:
      'Jennifer Moore is a financial journalist covering the U.S. stock market '
      'for Stock Market ROI. She got her start in local radio, where she learned '
      'to report clearly and stay calm under pressure - the same instinct she now '
      'brings to breaking down earnings, market swings, and the economic forces '
      'behind them. To Jennifer, good financial journalism is the foundation of a '
      'confident, well-informed investor.',
);

const _maya = BlogAuthor(
  slug: 'maya-bennett',
  name: 'Maya Bennett',
  role: 'Technology & Crypto Correspondent',
  initials: 'MB',
  photo: 'assets/images/maya-bennett.jpg',
  bio:
      'Maya Bennett covers technology, crypto, and personal finance for Stock '
      'Market ROI. She is drawn to where innovation meets money - semiconductors, '
      'AI, digital assets, and the tools reshaping how people build wealth. Her '
      'goal is simple: explain fast-moving markets in plain English, separate '
      'signal from noise, and help readers decide with clarity instead of FOMO.',
);

const _bySlug = <String, BlogAuthor>{
  'ivan-lima': _ivan,
  'jennifer-moore': _jennifer,
  'maya-bennett': _maya,
};

BlogAuthor authorForSlug(String? slug) => _bySlug[slug] ?? _ivan;
