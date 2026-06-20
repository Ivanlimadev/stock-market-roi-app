class MacroIndicator {
  final String id;
  final String label;
  final String unit;
  final String section;
  final int direction; // 1 = higher is better, -1 = lower is better
  final double value;
  final double change;
  final List<double> history;

  const MacroIndicator({
    required this.id,
    required this.label,
    required this.unit,
    required this.section,
    required this.direction,
    required this.value,
    required this.change,
    required this.history,
  });

  factory MacroIndicator.fromJson(Map<String, dynamic> j) => MacroIndicator(
    id:        j['id']        as String,
    label:     j['label']     as String,
    unit:      j['unit']      as String,
    section:   j['section']   as String,
    direction: j['direction'] as int,
    value:     (j['value']    as num).toDouble(),
    change:    (j['change']   as num).toDouble(),
    history:   (j['history']  as List).map((v) => (v as num).toDouble()).toList(),
  );

  bool get isImproving  => change * direction > 0;
  bool get isWorsening  => change * direction < 0;
}
