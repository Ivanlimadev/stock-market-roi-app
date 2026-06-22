import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/finance_model.dart';

SupabaseClient get _db => Supabase.instance.client;

final financeAccountsProvider =
    FutureProvider.autoDispose<List<FinanceAccount>>((ref) async {
  final user = _db.auth.currentUser;
  if (user == null) return [];
  final res = await _db
      .from('finance_accounts')
      .select('id, name, type, balance, currency, institution')
      .eq('user_id', user.id)
      .eq('archived', false)
      .order('created_at', ascending: true);
  return (res as List)
      .map((e) => FinanceAccount.fromJson(e as Map<String, dynamic>))
      .toList();
});

final financeTransactionsProvider =
    FutureProvider.autoDispose<List<FinanceTransaction>>((ref) async {
  final user = _db.auth.currentUser;
  if (user == null) return [];
  final res = await _db
      .from('finance_transactions')
      .select('id, account_id, category_id, type, amount, date, note')
      .eq('user_id', user.id)
      .order('date', ascending: false)
      .limit(500);
  return (res as List)
      .map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
});

final financeCategoriesProvider =
    FutureProvider.autoDispose<List<FinanceCategory>>((ref) async {
  final user = _db.auth.currentUser;
  if (user == null) return [];
  const sel = 'id, name, kind';
  List<dynamic> data = await _db.from('finance_categories').select(sel).eq('user_id', user.id).order('kind').order('name');
  // Seed defaults on first use.
  if (data.isEmpty) {
    final rows = kDefaultCategories.map((c) => {'user_id': user.id, 'name': c[0], 'kind': c[1]}).toList();
    data = await _db.from('finance_categories').insert(rows).select(sel);
  }
  return data
      .map((e) => FinanceCategory.fromJson(e as Map<String, dynamic>))
      .toList();
});

final financeBudgetsProvider =
    FutureProvider.autoDispose<List<FinanceBudget>>((ref) async {
  final user = _db.auth.currentUser;
  if (user == null) return [];
  final res = await _db.from('finance_budgets').select('id, category_id, amount').eq('user_id', user.id);
  return (res as List)
      .map((e) => FinanceBudget.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Mutations. RLS scopes everything to the signed-in user; we also set user_id
/// on insert so the WITH CHECK policy passes.
class FinanceRepo {
  static String get _uid => _db.auth.currentUser!.id;

  static Future<void> addCategory(String name, String kind) =>
      _db.from('finance_categories').insert({'user_id': _uid, 'name': name, 'kind': kind});

  static Future<void> renameCategory(String id, String name) =>
      _db.from('finance_categories').update({'name': name}).eq('id', id).eq('user_id', _uid);

  static Future<void> deleteCategory(String id) =>
      _db.from('finance_categories').delete().eq('id', id).eq('user_id', _uid);

  static Future<void> setBudget(String categoryId, double amount) async {
    if (amount <= 0) {
      await _db.from('finance_budgets').delete().eq('user_id', _uid).eq('category_id', categoryId).eq('period', 'monthly');
      return;
    }
    await _db.from('finance_budgets').upsert(
      {'user_id': _uid, 'category_id': categoryId, 'amount': amount, 'period': 'monthly'},
      onConflict: 'user_id,category_id,period',
    );
  }

  static Future<void> addAccount({
    required String name,
    required String type,
    required double balance,
    String? institution,
  }) =>
      _db.from('finance_accounts').insert({
        'user_id': _uid,
        'name': name,
        'type': type,
        'balance': balance,
        'institution': institution,
      });

  static Future<void> deleteAccount(String id) =>
      _db.from('finance_accounts').delete().eq('id', id).eq('user_id', _uid);

  static Future<void> addTransaction({
    required String type,
    required double amount,
    required String date,
    String? accountId,
    String? categoryId,
    String? note,
  }) =>
      _db.from('finance_transactions').insert({
        'user_id': _uid,
        'type': type,
        'amount': amount,
        'date': date,
        'account_id': accountId,
        'category_id': categoryId,
        'note': note,
      });

  static Future<void> deleteTransaction(String id) =>
      _db.from('finance_transactions').delete().eq('id', id).eq('user_id', _uid);
}
