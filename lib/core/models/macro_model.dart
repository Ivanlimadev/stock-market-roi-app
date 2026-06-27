class MacroIndicator {
  final String id;
  final String label;
  final String unit;
  final String section;
  final int direction;
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

  bool get isImproving => change * direction > 0;
  bool get isWorsening => change * direction < 0;
}

// ── Detail model ──────────────────────────────────────────────────────────────

class MacroDataPoint {
  final String date;
  final double value;
  const MacroDataPoint({required this.date, required this.value});

  factory MacroDataPoint.fromJson(Map<String, dynamic> j) => MacroDataPoint(
    date:  j['date']  as String,
    value: (j['value'] as num).toDouble(),
  );
}

class RecessionPeriod {
  final String start;
  final String end;
  const RecessionPeriod({required this.start, required this.end});

  factory RecessionPeriod.fromJson(Map<String, dynamic> j) => RecessionPeriod(
    start: j['start'] as String,
    end:   j['end']   as String,
  );
}

class MacroDetailData {
  final String id;
  final String label;
  final String unit;
  final String section;
  final int direction;
  final String description;
  final List<MacroDataPoint> data;
  final List<RecessionPeriod> recessions;

  const MacroDetailData({
    required this.id,
    required this.label,
    required this.unit,
    required this.section,
    required this.direction,
    required this.description,
    required this.data,
    required this.recessions,
  });

  factory MacroDetailData.fromJson(Map<String, dynamic> j) => MacroDetailData(
    id:          j['id']          as String,
    label:       j['label']       as String,
    unit:        j['unit']        as String,
    section:     j['section']     as String,
    direction:   j['direction']   as int,
    description: j['description'] as String,
    data:        (j['data']       as List).map((e) => MacroDataPoint.fromJson(e as Map<String, dynamic>)).toList(),
    recessions:  (j['recessions'] as List).map((e) => RecessionPeriod.fromJson(e as Map<String, dynamic>)).toList(),
  );

  List<MacroDataPoint> filter(String range) {
    if (range == 'Max' || data.isEmpty) return data;
    final years = {'1Y': 1, '2Y': 2, '5Y': 5, '10Y': 10}[range] ?? 5;
    final cutoff = DateTime.now().subtract(Duration(days: years * 365));
    final filtered = data.where((p) => DateTime.parse(p.date).isAfter(cutoff)).toList();
    return filtered.isEmpty ? data : filtered;
  }
}
