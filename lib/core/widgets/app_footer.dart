import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand ────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 16, color: AppColors.emerald),
              SizedBox(width: 6),
              Text('Stock Market ROI',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'US stock market data — quotes, charts, earnings, dividends, '
            'portfolio tracker and market screener.',
            style: TextStyle(fontSize: 11, color: c.textMuted, height: 1.5),
          ),

          SizedBox(height: 14),
          Divider(color: c.surfaceAlt, height: 1),
          SizedBox(height: 12),

          // ── Legal links ───────────────────────────────────────────────
          Text('LEGAL & COMPLIANCE',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: c.textMuted, letterSpacing: 0.8)),
          SizedBox(height: 10),
          Row(
            children: [
              _FooterLink(icon: Icons.info_outline_rounded,   label: 'About Us',
                  onTap: () => context.push('/about')),
              SizedBox(width: 16),
              _FooterLink(icon: Icons.shield_outlined,        label: 'Privacy Policy',
                  onTap: () => context.push('/privacy')),
              SizedBox(width: 16),
              _FooterLink(icon: Icons.description_outlined,   label: 'Terms of Use',
                  onTap: () => context.push('/terms')),
            ],
          ),

          SizedBox(height: 14),

          // ── Follow us ─────────────────────────────────────────────────
          Text('FOLLOW US',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: c.textMuted, letterSpacing: 0.8)),
          SizedBox(height: 10),
          Row(
            children: [
              _SocialLink(icon: Icons.smart_display_rounded, label: 'YouTube',
                  color: AppColors.red,
                  url: 'https://www.youtube.com/@StockMarketRoi'),
              SizedBox(width: 16),
              _SocialLink(icon: Icons.music_note_rounded, label: 'TikTok',
                  color: c.textPrimary,
                  url: 'https://www.tiktok.com/@stock.market.roi'),
            ],
          ),

          SizedBox(height: 14),
          Divider(color: c.surfaceAlt, height: 1),
          SizedBox(height: 12),

          // ── Disclaimer ────────────────────────────────────────────────
          Text('DISCLAIMER',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: c.textMuted, letterSpacing: 0.8)),
          SizedBox(height: 6),
          Text(
            'Stock Market ROI does not provide investment advice. All information '
            'is provided for educational and informational purposes only. Past '
            'performance does not guarantee future results. Always consult a '
            'qualified financial advisor before making investment decisions.',
            style: TextStyle(fontSize: 10, color: c.textMuted, height: 1.55),
          ),
          SizedBox(height: 6),
          Text(
            'Market data is provided for informational purposes only and may be delayed.',
            style: TextStyle(fontSize: 10, color: c.textMuted),
          ),

          SizedBox(height: 12),
          Divider(color: c.surfaceAlt, height: 1),
          SizedBox(height: 10),

          // ── Bottom bar ────────────────────────────────────────────────
          Row(
            children: [
              Text(
                '© ${DateTime.now().year} Stock Market ROI',
                style: TextStyle(fontSize: 10, color: c.textMuted),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('mailto:contact@stockmarketroi.com'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email_outlined, size: 11, color: c.textMuted),
                    SizedBox(width: 4),
                    Text('contact@stockmarketroi.com',
                        style: TextStyle(fontSize: 10, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.emerald),
        SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.emerald,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _SocialLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String url;
  const _SocialLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
