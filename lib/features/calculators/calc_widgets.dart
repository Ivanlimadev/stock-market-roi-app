import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class CalcCard extends StatelessWidget {
  final Widget child;
  const CalcCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

class CalcLabel extends StatelessWidget {
  final String text;
  const CalcLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: context.colors.textMuted,
          letterSpacing: 0.7,
        ),
      );
}

class CalcField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefix;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final Color? focusColor;

  const CalcField({
    super.key,
    required this.controller,
    required this.label,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.focusColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeColor = focusColor ?? AppColors.emerald;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: TextStyle(fontSize: 15, color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: activeColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: c.textMuted, fontSize: 13),
        prefixStyle: TextStyle(color: c.textMuted),
        suffixStyle: TextStyle(color: c.textMuted),
      ),
    );
  }
}

class CalcToggle extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color color;

  const CalcToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((e) {
          final active = e.key == selected;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: active ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : c.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CalcChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const CalcChip({
    super.key,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : c.surfaceAlt,
          border: Border.all(
            color: active ? color.withValues(alpha: 0.45) : c.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? color : c.textMuted,
          ),
        ),
      ),
    );
  }
}

class CalcKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? sub;

  const CalcKpi({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: c.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? c.textPrimary,
            ),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub!, style: TextStyle(fontSize: 10, color: c.textMuted)),
            ),
        ],
      ),
    );
  }
}
