import 'package:intl/intl.dart';

final _twoDecimals  = NumberFormat('#,##0.00',         'en_US');
final _fourDecimals = NumberFormat('#,##0.0000',        'en_US');
final _eightDec     = NumberFormat('#,##0.00000000',    'en_US');
final _noDecimals   = NumberFormat('#,##0',             'en_US');

/// Formata preço de cripto: $65,877.10 | $0.0000 | $0.00000012
String fmtCryptoPrice(double price) {
  if (price >= 1)     return '\$${_twoDecimals.format(price)}';
  if (price >= 0.01)  return '\$${_fourDecimals.format(price)}';
  return '\$${_eightDec.format(price)}';
}

/// Formata preço de ação: $297.06 | $1,234.56
String fmtStockPrice(double price) => '\$${_twoDecimals.format(price)}';

/// Formata número grande: $2.94T | $98.5B | $1.23M
String fmtBigUsd(double? v) {
  if (v == null || v == 0) return '—';
  if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(2)}T';
  if (v >= 1e9)  return '\$${(v / 1e9).toStringAsFixed(2)}B';
  if (v >= 1e6)  return '\$${(v / 1e6).toStringAsFixed(2)}M';
  return '\$${_noDecimals.format(v)}';
}

/// Formata supply: 21.00M | 1.50B | 19,743,000
String fmtSupply(double v) {
  if (v >= 1e9)  return '${(v / 1e9).toStringAsFixed(2)}B';
  if (v >= 1e6)  return '${(v / 1e6).toStringAsFixed(2)}M';
  if (v >= 1e3)  return _noDecimals.format(v);
  return v.toStringAsFixed(0);
}

/// Formata contagem: 16,847 ou 16.8K
String fmtCount(int v) {
  if (v >= 1000) return _noDecimals.format(v);
  return '$v';
}
