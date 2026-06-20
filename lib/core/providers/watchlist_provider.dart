import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class WatchlistItem {
  final String id, symbol, name, assetType;
  final String? coingeckoId, image;
  final DateTime addedAt;

  const WatchlistItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.assetType,
    this.coingeckoId,
    this.image,
    required this.addedAt,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> j) => WatchlistItem(
        id:          j['id']           as String,
        symbol:      j['symbol']       as String,
        name:        j['name']         as String,
        assetType:   j['asset_type']   as String? ?? 'stock',
        coingeckoId: j['coingecko_id'] as String?,
        image:       j['image']        as String?,
        addedAt: DateTime.tryParse(j['added_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class PriceAlert {
  final String id, symbol, name, assetType, condition;
  final String? coingeckoId, image;
  final double targetPrice;
  final double? targetPct, referencePrice;
  final bool triggered;
  final DateTime? triggeredAt;
  final DateTime createdAt;

  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.condition,
    this.coingeckoId,
    this.image,
    required this.targetPrice,
    this.targetPct,
    this.referencePrice,
    required this.triggered,
    this.triggeredAt,
    required this.createdAt,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> j) => PriceAlert(
        id:             j['id']              as String,
        symbol:         j['symbol']          as String,
        name:           j['name']            as String,
        assetType:      j['asset_type']      as String? ?? 'stock',
        condition:      j['condition']       as String,
        coingeckoId:    j['coingecko_id']    as String?,
        image:          j['image']           as String?,
        targetPrice:    (j['target_price']   as num).toDouble(),
        targetPct:      (j['target_pct']     as num?)?.toDouble(),
        referencePrice: (j['reference_price'] as num?)?.toDouble(),
        triggered:      j['triggered']       as bool? ?? false,
        triggeredAt: j['triggered_at'] != null
            ? DateTime.tryParse(j['triggered_at'] as String)
            : null,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ── Stream providers ──────────────────────────────────────────────────────────

final watchlistProvider =
    StreamProvider.autoDispose<List<WatchlistItem>>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return Stream.value([]);
  return Supabase.instance.client
      .from('watchlist')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .order('added_at', ascending: false)
      .map((rows) => rows.map(WatchlistItem.fromJson).toList());
});

final alertsProvider =
    StreamProvider.autoDispose<List<PriceAlert>>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return Stream.value([]);
  return Supabase.instance.client
      .from('price_alerts')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(PriceAlert.fromJson).toList());
});

/// Set of stock symbols currently in the watchlist.
final watchlistSymbolsProvider = Provider.autoDispose<Set<String>>((ref) =>
    ref.watch(watchlistProvider).maybeWhen(
      data: (items) => items.map((i) => i.symbol).toSet(),
      orElse: () => {},
    ));

/// Set of symbols that have at least one active (non-triggered) price alert.
final alertSymbolsProvider = Provider.autoDispose<Set<String>>((ref) =>
    ref.watch(alertsProvider).maybeWhen(
      data: (alerts) => alerts
          .where((a) => !a.triggered)
          .map((a) => a.symbol)
          .toSet(),
      orElse: () => {},
    ));

/// Set of coingecko IDs currently in the watchlist (for crypto).
final watchlistCryptoIdsProvider = Provider.autoDispose<Set<String>>((ref) =>
    ref.watch(watchlistProvider).maybeWhen(
      data: (items) => items
          .where((i) => i.assetType == 'crypto')
          .map((i) => i.coingeckoId ?? i.symbol.toLowerCase())
          .toSet(),
      orElse: () => {},
    ));

// ── CRUD service ──────────────────────────────────────────────────────────────

class WatchlistService {
  static final _db = Supabase.instance.client;

  static String _wlId(String uid, String key) =>
      '${uid}_${key.toLowerCase()}';

  static Future<void> addStock({
    required String symbol,
    required String name,
    String assetType = 'stock',
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('watchlist').upsert({
      'id':         _wlId(uid, symbol),
      'user_id':    uid,
      'symbol':     symbol,
      'name':       name,
      'asset_type': assetType,
    });
  }

  static Future<void> addCrypto({
    required String coinId,
    required String symbol,
    required String name,
    String? image,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('watchlist').upsert({
      'id':           _wlId(uid, coinId),
      'user_id':      uid,
      'symbol':       symbol.toUpperCase(),
      'name':         name,
      'asset_type':   'crypto',
      'coingecko_id': coinId,
      'image':        image,
    });
  }

  static Future<void> removeStock(String symbol) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('watchlist').delete().eq('id', _wlId(uid, symbol));
  }

  static Future<void> removeCrypto(String coinId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('watchlist').delete().eq('id', _wlId(uid, coinId));
  }

  static Future<void> addAlert({
    required String symbol,
    required String name,
    required String assetType,
    required String condition,
    required double targetPrice,
    double? referencePrice,
    String? coingeckoId,
    String? image,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final id =
        '${uid}_${symbol.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    await _db.from('price_alerts').insert({
      'id':              id,
      'user_id':         uid,
      'symbol':          symbol,
      'name':            name,
      'asset_type':      assetType,
      'condition':       condition,
      'target_price':    targetPrice,
      'reference_price': referencePrice,
      'coingecko_id':    coingeckoId,
      'image':           image,
    });
  }

  static Future<void> deleteAlert(String alertId) async {
    await _db.from('price_alerts').delete().eq('id', alertId);
  }
}
