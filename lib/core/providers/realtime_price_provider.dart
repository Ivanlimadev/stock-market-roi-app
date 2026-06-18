import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// CoinGecko ID → Kraken v2 WebSocket symbol
const _idToKraken = <String, String>{
  'bitcoin':      'BTC/USD',
  'ethereum':     'ETH/USD',
  'solana':       'SOL/USD',
  'ripple':       'XRP/USD',
  'cardano':      'ADA/USD',
  'dogecoin':     'DOGE/USD',
  'avalanche-2':  'AVAX/USD',
  'chainlink':    'LINK/USD',
  'litecoin':     'LTC/USD',
  'bitcoin-cash': 'BCH/USD',
  'polkadot':     'DOT/USD',
  'uniswap':      'UNI/USD',
  'cosmos':       'ATOM/USD',
  'near':         'NEAR/USD',
  'shiba-inu':    'SHIB/USD',
  'tron':         'TRX/USD',
  'stellar':      'XLM/USD',
  'monero':       'XMR/USD',
  'pepe':         'PEPE/USD',
  'sui':          'SUI/USD',
  'aave':         'AAVE/USD',
};

// Reverse: Kraken symbol → CoinGecko ID
final _krakenToId = _idToKraken.map((k, v) => MapEntry(v, k));

class RealtimePriceNotifier extends StateNotifier<Map<String, double>> {
  RealtimePriceNotifier() : super({}) {
    _connect();
  }

  WebSocketChannel? _ws;
  Timer? _reconnectTimer;
  bool _disposed = false;

  void _connect() {
    if (_disposed) return;
    try {
      _ws = WebSocketChannel.connect(Uri.parse('wss://ws.kraken.com/v2'));
      _ws!.sink.add(jsonEncode({
        'method': 'subscribe',
        'params': {
          'channel': 'ticker',
          'symbol': _idToKraken.values.toList(),
        },
      }));
      _ws!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['channel'] != 'ticker') return;
      final data = msg['data'] as List?;
      if (data == null) return;

      final updates = <String, double>{};
      for (final item in data) {
        final m      = item as Map<String, dynamic>;
        final symbol = m['symbol'] as String?;
        final last   = (m['last'] as num?)?.toDouble();
        if (symbol == null || last == null || last <= 0) continue;
        final id = _krakenToId[symbol];
        if (id != null) updates[id] = last;
      }
      if (updates.isNotEmpty) state = {...state, ...updates};
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _ws = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _ws?.sink.close();
    super.dispose();
  }
}

/// Live prices keyed by CoinGecko coin ID. Empty map = not yet connected.
final realtimePriceProvider =
    StateNotifierProvider<RealtimePriceNotifier, Map<String, double>>(
  (_) => RealtimePriceNotifier(),
);
