import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';

class CalculatorsHubPage extends StatelessWidget {
  const CalculatorsHubPage({super.key});

  static const _calcs = [
    _CalcEntry(
      path: '/calculators/compound-interest',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF10B981),
      title: 'Compound Interest',
      desc: 'How money grows exponentially with regular contributions.',
      badge: 'Most popular',
    ),
    _CalcEntry(
      path: '/calculators/dca',
      icon: Icons.refresh_rounded,
      color: Color(0xFF06B6D4),
      title: 'DCA Calculator',
      desc: 'Dollar-Cost Averaging: weekly, bi-weekly, or monthly. DCA vs lump sum.',
      badge: 'Trending',
    ),
    _CalcEntry(
      path: '/calculators/roi',
      icon: Icons.arrow_upward_rounded,
      color: Color(0xFFF97316),
      title: 'ROI Calculator',
      desc: 'Total ROI, CAGR, and S&P 500 benchmark comparison.',
      badge: null,
    ),
    _CalcEntry(
      path: '/calculators/first-million',
      icon: Icons.track_changes_rounded,
      color: Color(0xFFF59E0B),
      title: 'First Million',
      desc: 'When will you reach \$1M — or how much to invest monthly.',
      badge: 'Goal-based',
    ),
    _CalcEntry(
      path: '/calculators/simple-interest',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF3B82F6),
      title: 'Simple Interest',
      desc: 'Linear returns on fixed-income investments.',
      badge: null,
    ),
    _CalcEntry(
      path: '/calculators/percentage',
      icon: Icons.percent_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Percentage',
      desc: 'Find percentages, proportions, gains, and losses.',
      badge: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('Calculators')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Free tools to plan your financial future. Every calculator updates in real time.',
                  style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.5),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _CalcCard(entry: _calcs[i]),
                  childCount: _calcs.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcEntry {
  final String path, title, desc;
  final IconData icon;
  final Color color;
  final String? badge;
  const _CalcEntry({
    required this.path,
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.badge,
  });
}

class _CalcCard extends StatelessWidget {
  final _CalcEntry entry;
  const _CalcCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.push(entry.path),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(entry.icon, size: 20, color: entry.color),
                ),
                const Spacer(),
                if (entry.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.badge!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Text(
                entry.desc,
                style: TextStyle(fontSize: 11.5, color: c.textMuted, height: 1.45),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open →',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: entry.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
