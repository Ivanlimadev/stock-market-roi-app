import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ad_manager.dart';
import 'rewarded_unlocks.dart';

/// Wraps a premium section behind a rewarded-ad gate. While locked it shows a
/// compact teaser card with a "Watch a short ad to unlock" CTA; once the user
/// earns the reward (or no ad is available) it reveals [child] and stays
/// unlocked for the rest of the session via [RewardedUnlocks].
class RewardedGate extends StatefulWidget {
  final String featureKey;
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  const RewardedGate({
    super.key,
    required this.featureKey,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  State<RewardedGate> createState() => _RewardedGateState();
}

class _RewardedGateState extends State<RewardedGate> {
  bool _loading = false;

  void _unlock() {
    setState(() => _loading = true);
    AdManager.instance.showRewarded(
      onReward: () => RewardedUnlocks.unlock(widget.featureKey),
      onUnavailable: () {
        if (!mounted) return;
        setState(() => _loading = false);
        // Don't punish the user when no ad could be served.
        RewardedUnlocks.unlock(widget.featureKey);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: RewardedUnlocks.listenable,
      builder: (context, unlocked, _) {
        if (unlocked.contains(widget.featureKey)) return widget.child;
        return _locked(context);
      },
    );
  }

  Widget _locked(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(widget.title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.surfaceAlt),
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: AppColors.emerald, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textMuted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _unlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: Text(_loading ? 'Loading ad…' : 'Watch a short ad to unlock',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              Text('Free — unlocks for this session',
                  style: TextStyle(fontSize: 10.5, color: c.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
