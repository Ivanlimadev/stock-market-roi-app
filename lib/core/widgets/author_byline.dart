import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Author card shown at the end of a blog post — compact by default, expands on
/// tap to reveal the full bio and social links (mirrors the website byline).
class AuthorByline extends StatefulWidget {
  const AuthorByline({super.key});

  @override
  State<AuthorByline> createState() => _AuthorBylineState();
}

class _AuthorBylineState extends State<AuthorByline> {
  bool _expanded = false;

  static const _bio =
      'Systems Analysis & Development student and active US stock market '
      'investor since 2018. Ivan built Stock Market ROI to give retail investors '
      'direct access to the same data and analytical tools he wished existed when '
      'he started. Every article is written from the perspective of someone with '
      'real skin in the game — tracking earnings, reading SEC filings, and '
      'following market cycles for over eight years.';

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.network(
                    'https://stockmarketroi.com/ivan-lima.jpg',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: AppColors.emerald.withValues(alpha: 0.15),
                      alignment: Alignment.center,
                      child: Text('IL',
                          style: TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: 'Ivan Lima',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                        TextSpan(
                            text: '  · Author',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.emerald)),
                      ])),
                      const SizedBox(height: 3),
                      Text(
                        _bio,
                        maxLines: _expanded ? null : 1,
                        overflow:
                            _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, height: 1.5, color: c.textMuted),
                      ),
                      if (!_expanded) ...[
                        const SizedBox(height: 4),
                        Text('Tap to read more',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emerald)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: c.textMuted, size: 22),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Row(children: [
                _SocialBtn(
                  gradient: const LinearGradient(colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFEC4899),
                    Color(0xFFF59E0B),
                  ]),
                  icon: Icons.camera_alt_rounded,
                  onTap: () => _open('https://www.instagram.com/ivan_lima_dev'),
                ),
                const SizedBox(width: 8),
                _SocialBtn(
                  color: const Color(0xFF0A66C2),
                  label: 'in',
                  onTap: () => _open('https://www.linkedin.com/in/ivanlimadev/'),
                ),
                const SizedBox(width: 8),
                _SocialBtn(
                  border: c.surfaceAlt,
                  icon: Icons.mail_outline_rounded,
                  iconColor: c.textSecond,
                  onTap: () => _open('mailto:contato@ivanlimadev.com'),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _open('https://stockmarketroi.com/about'),
                  child: Text('About the author →',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final Gradient? gradient;
  final Color? color;
  final Color? border;
  final Color? iconColor;
  final VoidCallback onTap;
  const _SocialBtn({
    this.icon,
    this.label,
    this.gradient,
    this.color,
    this.border,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: gradient,
            color: color,
            borderRadius: BorderRadius.circular(9),
            border: border != null ? Border.all(color: border!) : null,
          ),
          alignment: Alignment.center,
          child: label != null
              ? Text(label!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13))
              : Icon(icon, size: 16, color: iconColor ?? Colors.white),
        ),
      );
}
