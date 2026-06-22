import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/models/finance_model.dart';
import '../../core/providers/finance_provider.dart';

final _money = NumberFormat.currency(locale: 'en_US', symbol: '\$');
String _monthKey() => DateFormat('yyyy-MM').format(DateTime.now());

// Selected month (YYYY-MM) driving the "this month" views.
final _selMonthProvider = StateProvider.autoDispose<String>((ref) => _monthKey());

String _shiftMonth(String mk, int delta) {
  final p = mk.split('-');
  final d = DateTime(int.parse(p[0]), int.parse(p[1]) - 1 + delta, 1);
  return DateFormat('yyyy-MM').format(d);
}

/// Personal finance manager — accounts, net worth and spending (manual-only).
class FinanceManagerPage extends ConsumerWidget {
  const FinanceManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'categories') _manageCategories(context, ref);
                if (v == 'import') _importCsv(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'categories', child: Text('Manage categories')),
                PopupMenuItem(value: 'import', child: Text('Import CSV')),
              ],
            ),
          MainShellMenu.themeButton(),
          MainShellMenu.settingsButton(),
        ],
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addTransaction(context, ref),
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Transaction'),
            ),
      body: user == null
          ? _Guest()
          : _Dashboard(),
    );
  }
}

class _Guest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_rounded, size: 40, color: AppColors.emerald),
            const SizedBox(height: 16),
            Text('Your money, all in one place',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text('Track accounts, net worth and spending. Sign in to start.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textMuted)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push('/login'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final accountsAsync = ref.watch(financeAccountsProvider);
    final txnsAsync = ref.watch(financeTransactionsProvider);

    final accounts = accountsAsync.valueOrNull ?? [];
    final txns = txnsAsync.valueOrNull ?? [];

    final assets = accounts.where((a) => !a.isLiability).fold(0.0, (s, a) => s + a.balance);
    final liabilities = accounts.where((a) => a.isLiability).fold(0.0, (s, a) => s + a.balance);
    final netWorth = assets - liabilities;

    final selMonth = ref.watch(_selMonthProvider);
    final mk = selMonth;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.parse('$mk-01'));
    final isCurrentMonth = mk == _monthKey();
    final month = txns.where((t) => t.date.startsWith(mk));
    final income = month.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final expense = month.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

    final categories = ref.watch(financeCategoriesProvider).valueOrNull ?? [];
    final budgets = ref.watch(financeBudgetsProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};
    final spentByCat = <String, double>{};
    for (final t in month) {
      if (t.type == 'expense' && t.categoryId != null) {
        spentByCat[t.categoryId!] = (spentByCat[t.categoryId!] ?? 0) + t.amount;
      }
    }
    final budgetRows = budgets
        .map((b) => (b: b, name: catName[b.categoryId] ?? '—', spent: spentByCat[b.categoryId] ?? 0.0))
        .toList()
      ..sort((a, b) => (b.spent / (b.b.amount == 0 ? 1 : b.b.amount)).compareTo(a.spent / (a.b.amount == 0 ? 1 : a.b.amount)));

    final recurring = ref.watch(financeRecurringProvider).valueOrNull ?? [];
    final goals = ref.watch(financeGoalsProvider).valueOrNull ?? [];
    final monthlySubs = recurring.where((r) => r.active && r.type == 'expense').fold(0.0, (s, r) => s + r.perMonth);

    // Reports: spending by category (selected month)
    final spendCats = spentByCat.entries.map((e) => (name: catName[e.key] ?? 'Uncategorized', amount: e.value)).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    // Reports: income vs spending, last 6 months
    final now = DateTime.now();
    final last6 = <({String label, double income, double expense})>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('yyyy-MM').format(d);
      final inM = txns.where((t) => t.date.startsWith(key));
      last6.add((
        label: DateFormat('MMM').format(d),
        income: inM.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount),
        expense: inM.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount),
      ));
    }
    final max6 = last6.fold(1.0, (m, x) => [m, x.income, x.expense].reduce((a, b) => a > b ? a : b));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(financeAccountsProvider);
        ref.invalidate(financeTransactionsProvider);
        ref.invalidate(financeCategoriesProvider);
        ref.invalidate(financeBudgetsProvider);
        ref.invalidate(financeRecurringProvider);
        ref.invalidate(financeGoalsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // Month selector
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: () => ref.read(_selMonthProvider.notifier).state = _shiftMonth(mk, -1), icon: const Icon(Icons.chevron_left_rounded)),
            Text(monthLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            IconButton(onPressed: isCurrentMonth ? null : () => ref.read(_selMonthProvider.notifier).state = _shiftMonth(mk, 1), icon: const Icon(Icons.chevron_right_rounded)),
          ])),
          const SizedBox(height: 8),
          // Net worth
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Net Worth', style: TextStyle(fontSize: 12, color: c.textMuted)),
            const SizedBox(height: 4),
            Text(_money.format(netWorth),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                    color: netWorth >= 0 ? c.textPrimary : AppColors.red)),
            const SizedBox(height: 4),
            Text('Assets ${_money.format(assets)} · Liabilities ${_money.format(liabilities)}',
                style: TextStyle(fontSize: 11, color: c.textMuted)),
          ])),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(label: 'Income · $monthLabel', value: income, color: AppColors.emerald, up: true)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Spending · $monthLabel', value: expense, color: AppColors.red, up: false)),
          ]),
          const SizedBox(height: 24),

          // Accounts
          _SectionHeader(title: 'Accounts', action: 'Add', onAction: () => _addAccount(context, ref)),
          const SizedBox(height: 8),
          if (accountsAsync.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (accounts.isEmpty)
            _Empty('No accounts yet. Add your bank, card or cash to start your net worth.')
          else
            ...accounts.map((a) => _AccountTile(
                  account: a,
                  onEdit: () => _addAccount(context, ref, account: a),
                  onDelete: () async {
                    await FinanceRepo.deleteAccount(a.id);
                    ref.invalidate(financeAccountsProvider);
                  },
                )),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Budgets · $monthLabel', action: 'Manage', onAction: () => _manageBudgets(context, ref, categories, budgets)),
          const SizedBox(height: 8),
          if (budgetRows.isEmpty)
            _Empty('No budgets yet. Tap “Manage” to set a monthly limit per category.')
          else
            ...budgetRows.map((r) => _BudgetTile(name: r.name, spent: r.spent, limit: r.b.amount)),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Subscriptions & bills', action: 'Add', onAction: () => _addRecurring(context, ref)),
          if (monthlySubs > 0)
            Text('~${_money.format(monthlySubs)}/mo', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          const SizedBox(height: 8),
          if (recurring.isEmpty)
            _Empty('No subscriptions yet. Add Netflix, rent, gym… to track due dates.')
          else
            ...recurring.map((r) => _RecurringTile(
                  recurring: r,
                  onToggle: () async {
                    await FinanceRepo.toggleRecurring(r.id, !r.active);
                    ref.invalidate(financeRecurringProvider);
                  },
                  onDelete: () async {
                    await FinanceRepo.deleteRecurring(r.id);
                    ref.invalidate(financeRecurringProvider);
                  },
                )),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Recent transactions'),
          const SizedBox(height: 8),
          if (txnsAsync.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (txns.isEmpty)
            _Empty('No transactions yet. Tap “Transaction” to log your first one.')
          else
            ...txns.take(15).map((t) => _TxnTile(
                  txn: t,
                  categoryName: t.categoryId != null ? catName[t.categoryId] : null,
                  onEdit: () => _addTransaction(context, ref, txn: t),
                  onDelete: () async {
                    await FinanceRepo.deleteTransaction(t.id);
                    ref.invalidate(financeTransactionsProvider);
                  },
                )),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Goals', action: 'Add', onAction: () => _editGoal(context, ref, null)),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            _Empty('No goals yet. Set a target — emergency fund, vacation… and track progress.')
          else
            ...goals.map((g) => _GoalCard(
                  goal: g,
                  onEdit: () => _editGoal(context, ref, g),
                  onDelete: () async {
                    await FinanceRepo.deleteGoal(g.id);
                    ref.invalidate(financeGoalsProvider);
                  },
                )),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Spending by category · $monthLabel'),
          const SizedBox(height: 8),
          _Card(child: spendCats.isEmpty
              ? Text('No spending yet this month.', style: TextStyle(fontSize: 13, color: context.colors.textMuted))
              : Column(children: [
                  for (final s in spendCats.take(8)) _SpendRow(name: s.name, amount: s.amount, total: expense),
                ])),

          const SizedBox(height: 16),
          _SectionHeader(title: 'Income vs spending · last 6 months'),
          const SizedBox(height: 8),
          _Card(child: Column(children: [
            SizedBox(height: 110, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final m in last6)
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  SizedBox(height: 86, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Bar(height: (m.income / max6 * 86).clamp(0.0, 86.0), color: AppColors.emerald),
                    const SizedBox(width: 3),
                    _Bar(height: (m.expense / max6 * 86).clamp(0.0, 86.0), color: AppColors.red),
                  ])),
                  const SizedBox(height: 4),
                  Text(m.label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                ])),
            ])),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _LegendDot(color: AppColors.emerald, label: 'Income'),
              const SizedBox(width: 16),
              _LegendDot(color: AppColors.red, label: 'Spending'),
            ]),
          ])),
        ],
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.surfaceAlt),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool up;
  const _StatCard({required this.label, required this.value, required this.color, required this.up});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: c.textMuted)),
      const SizedBox(height: 4),
      Row(children: [
        Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(_money.format(value),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
      ]),
    ]));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
      if (action != null)
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add, size: 16),
          label: Text(action!),
          style: TextButton.styleFrom(foregroundColor: AppColors.emerald, visualDensity: VisualDensity.compact),
        ),
    ]);
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Card(child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textMuted)));
  }
}

const _accountIcons = <String, IconData>{
  'checking': Icons.account_balance_rounded,
  'savings': Icons.savings_rounded,
  'cash': Icons.payments_rounded,
  'credit_card': Icons.credit_card_rounded,
  'investment': Icons.trending_up_rounded,
  'loan': Icons.account_balance_rounded,
  'other': Icons.account_balance_wallet_rounded,
};

class _AccountTile extends StatelessWidget {
  final FinanceAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AccountTile({required this.account, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.surfaceAlt)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.surfaceAlt, child: Icon(_accountIcons[account.type] ?? Icons.account_balance_wallet_rounded, size: 18, color: c.textSecond)),
        title: Text(account.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
        subtitle: Text(kAccountTypes[account.type] ?? account.type, style: TextStyle(fontSize: 11, color: c.textMuted)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${account.isLiability ? '-' : ''}${_money.format(account.balance)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: account.isLiability ? AppColors.red : c.textPrimary)),
          IconButton(icon: Icon(Icons.edit_rounded, size: 16, color: c.textMuted), onPressed: onEdit),
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted), onPressed: onDelete),
        ]),
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final FinanceTransaction txn;
  final String? categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TxnTile({required this.txn, this.categoryName, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final income = txn.type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.surfaceAlt)),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: income ? AppColors.emerald.withValues(alpha: 0.15) : c.surfaceAlt,
          child: Icon(income ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: income ? AppColors.emerald : c.textSecond),
        ),
        title: Text(txn.note?.isNotEmpty == true ? txn.note! : (income ? 'Income' : 'Expense'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
        subtitle: Text('${txn.date}${categoryName != null ? ' · $categoryName' : ''}', style: TextStyle(fontSize: 11, color: c.textMuted)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${income ? '+' : '-'}${_money.format(txn.amount)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: income ? AppColors.emerald : c.textPrimary)),
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted), onPressed: onDelete),
        ]),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final String name;
  final double spent;
  final double limit;
  const _BudgetTile({required this.name, required this.spent, required this.limit});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final over = spent > limit;
    final color = over ? AppColors.red : (pct > 0.8 ? AppColors.orange : AppColors.emerald);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.surfaceAlt)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textPrimary)),
          Text('${_money.format(spent)} / ${_money.format(limit)}', style: TextStyle(fontSize: 12, color: over ? AppColors.red : c.textMuted)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: c.surfaceAlt, color: color),
        ),
      ]),
    );
  }
}

({String label, int level})? _dueBadge(String? nextDue) {
  if (nextDue == null) return null;
  final due = DateTime.tryParse(nextDue);
  if (due == null) return null;
  final now = DateTime.now();
  final days = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days < 0) return (label: 'Overdue ${-days}d', level: 2);
  if (days == 0) return (label: 'Due today', level: 1);
  if (days <= 7) return (label: 'Due in ${days}d', level: 1);
  return (label: 'in ${days}d', level: 0);
}

class _RecurringTile extends StatelessWidget {
  final FinanceRecurring recurring;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _RecurringTile({required this.recurring, required this.onToggle, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = recurring;
    final income = r.type == 'income';
    final badge = _dueBadge(r.nextDue);
    final badgeColor = badge == null ? c.textMuted : (badge.level == 2 ? AppColors.red : badge.level == 1 ? AppColors.orange : c.textMuted);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.surfaceAlt)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.surfaceAlt, child: Icon(Icons.autorenew_rounded, size: 18, color: c.textSecond)),
        title: Text('${r.name}${r.active ? '' : '  (paused)'}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
        subtitle: Row(children: [
          Text(kFrequencies[r.frequency] ?? r.frequency, style: TextStyle(fontSize: 11, color: c.textMuted)),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(badge.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeColor)),
            ),
          ],
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${income ? '+' : '-'}${_money.format(r.amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: income ? AppColors.emerald : c.textPrimary)),
          IconButton(icon: Icon(r.active ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18, color: c.textMuted), onPressed: onToggle),
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted), onPressed: onDelete),
        ]),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final FinanceGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _GoalCard({required this.goal, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
    final done = goal.currentAmount >= goal.targetAmount && goal.targetAmount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.surfaceAlt)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flag_rounded, size: 16, color: done ? AppColors.emerald : c.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(goal.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary))),
          IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.edit_rounded, size: 16, color: c.textMuted), onPressed: onEdit),
          IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.delete_outline_rounded, size: 16, color: c.textMuted), onPressed: onDelete),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(_money.format(goal.currentAmount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
          Text('of ${_money.format(goal.targetAmount)}', style: TextStyle(fontSize: 12, color: c.textMuted)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: c.surfaceAlt, color: AppColors.emerald)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pct * 100).toStringAsFixed(0)}%${done ? ' · reached 🎉' : ''}', style: TextStyle(fontSize: 11, color: c.textMuted)),
          if (goal.targetDate != null) Text('by ${goal.targetDate}', style: TextStyle(fontSize: 11, color: c.textMuted)),
        ]),
      ]),
    );
  }
}

class _SpendRow extends StatelessWidget {
  final String name;
  final double amount;
  final double total;
  const _SpendRow({required this.name, required this.amount, required this.total});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(name, style: TextStyle(fontSize: 12, color: c.textPrimary)),
          Text('${_money.format(amount)} · ${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: c.textMuted)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: c.surfaceAlt, color: AppColors.emerald)),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  const _Bar({required this.height, required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: height, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))));
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
      ]);
}

// ── Add sheets ────────────────────────────────────────────────────────────────

Future<void> _manageBudgets(BuildContext context, WidgetRef ref, List<FinanceCategory> categories, List<FinanceBudget> budgets) async {
  final expenseCats = categories.where((c) => c.kind == 'expense').toList();
  final original = {for (final b in budgets) b.categoryId: b.amount};
  final ctrls = {for (final c in expenseCats) c.id: TextEditingController(text: original[c.id] != null ? original[c.id]!.toStringAsFixed(0) : '')};
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (ctx, scroll) {
          final c = ctx.colors;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Text('Monthly budgets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                  child: const Text('Save'),
                ),
              ]),
            ),
            Expanded(
              child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                for (final cat in expenseCats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(cat.name, style: TextStyle(fontSize: 14, color: c.textPrimary))),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: ctrls[cat.id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(prefixText: '\$ ', hintText: '0'),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      ),
    ),
  );
  if (saved == true) {
    for (final cat in expenseCats) {
      final v = double.tryParse(ctrls[cat.id]!.text) ?? 0;
      if (v != (original[cat.id] ?? 0)) await FinanceRepo.setBudget(cat.id, v);
    }
    ref.invalidate(financeBudgetsProvider);
  }
}

Future<void> _addAccount(BuildContext context, WidgetRef ref, {FinanceAccount? account}) async {
  final nameCtrl = TextEditingController(text: account?.name ?? '');
  final balCtrl = TextEditingController(text: account != null ? account.balance.toString() : '');
  final instCtrl = TextEditingController(text: account?.institution ?? '');
  String type = account?.type ?? 'checking';
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(builder: (ctx, setS) {
        final c = ctx.colors;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(account == null ? 'Add account' : 'Edit account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Account name (e.g. Chase Checking)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: kAccountTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setS(() => type = v ?? 'checking'),
            ),
            const SizedBox(height: 12),
            TextField(controller: balCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Current balance')),
            const SizedBox(height: 12),
            TextField(controller: instCtrl, decoration: const InputDecoration(hintText: 'Institution (optional)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
              child: Text(account == null ? 'Add account' : 'Save'),
            ),
          ]),
        );
      }),
    ),
  );
  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
    final inst = instCtrl.text.trim().isEmpty ? null : instCtrl.text.trim();
    final bal = double.tryParse(balCtrl.text) ?? 0;
    if (account != null) {
      await FinanceRepo.updateAccount(id: account.id, name: nameCtrl.text.trim(), type: type, balance: bal, institution: inst);
    } else {
      await FinanceRepo.addAccount(name: nameCtrl.text.trim(), type: type, balance: bal, institution: inst);
    }
    ref.invalidate(financeAccountsProvider);
  }
}

Future<void> _addTransaction(BuildContext context, WidgetRef ref, {FinanceTransaction? txn}) async {
  final amountCtrl = TextEditingController(text: txn != null ? txn.amount.toString() : '');
  final noteCtrl = TextEditingController(text: txn?.note ?? '');
  final categories = ref.read(financeCategoriesProvider).valueOrNull ?? [];
  String type = txn?.type == 'income' ? 'income' : 'expense';
  String? categoryId = txn?.categoryId;
  DateTime date = txn != null ? (DateTime.tryParse(txn.date) ?? DateTime.now()) : DateTime.now();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(builder: (ctx, setS) {
        final c = ctx.colors;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(txn == null ? 'Add transaction' : 'Edit transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              for (final t in ['expense', 'income'])
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: t == 'expense' ? 8 : 0),
                  child: ChoiceChip(
                    label: Text(t == 'expense' ? 'Expense' : 'Income'),
                    selected: type == t,
                    onSelected: (_) => setS(() { type = t; categoryId = null; }),
                  ),
                )),
            ]),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Amount')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat('MMM d, yyyy').format(date), style: TextStyle(color: c.textPrimary)),
              trailing: Icon(Icons.calendar_today_rounded, size: 18, color: c.textMuted),
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (picked != null) setS(() => date = picked);
              },
            ),
            Builder(builder: (ctx) {
              final catOpts = categories.where((c) => c.kind == type).toList();
              if (catOpts.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String?>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(hintText: 'Category'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('No category')),
                    ...catOpts.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setS(() => categoryId = v),
                ),
              );
            }),
            TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: 'Note (optional)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
              child: const Text('Save'),
            ),
          ]),
        );
      }),
    ),
  );
  final amt = double.tryParse(amountCtrl.text) ?? 0;
  if (ok == true && amt > 0) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
    if (txn != null) {
      await FinanceRepo.updateTransaction(id: txn.id, type: type, amount: amt, date: dateStr, categoryId: categoryId, note: note);
    } else {
      await FinanceRepo.addTransaction(type: type, amount: amt, date: dateStr, categoryId: categoryId, note: note);
    }
    ref.invalidate(financeTransactionsProvider);
  }
}

Future<void> _addRecurring(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final categories = ref.read(financeCategoriesProvider).valueOrNull ?? [];
  String type = 'expense';
  String frequency = 'monthly';
  String? categoryId;
  DateTime? nextDue;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(builder: (ctx, setS) {
        final c = ctx.colors;
        final catOpts = categories.where((cat) => cat.kind == type).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add subscription / bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Name (e.g. Netflix, Rent)')),
            const SizedBox(height: 12),
            Row(children: [
              for (final t in ['expense', 'income'])
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: t == 'expense' ? 8 : 0),
                  child: ChoiceChip(label: Text(t == 'expense' ? 'Expense' : 'Income'), selected: type == t, onSelected: (_) => setS(() { type = t; categoryId = null; })),
                )),
            ]),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Amount')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              items: kFrequencies.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setS(() => frequency = v ?? 'monthly'),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(nextDue == null ? 'Next due date (optional)' : DateFormat('MMM d, yyyy').format(nextDue!), style: TextStyle(color: nextDue == null ? c.textMuted : c.textPrimary)),
              trailing: Icon(Icons.calendar_today_rounded, size: 18, color: c.textMuted),
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: nextDue ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (picked != null) setS(() => nextDue = picked);
              },
            ),
            if (catOpts.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                decoration: const InputDecoration(hintText: 'Category'),
                items: [const DropdownMenuItem<String?>(value: null, child: Text('No category')), ...catOpts.map((cat) => DropdownMenuItem<String?>(value: cat.id, child: Text(cat.name)))],
                onChanged: (v) => setS(() => categoryId = v),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.emerald), child: const Text('Add')),
          ]),
        );
      }),
    ),
  );
  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
    await FinanceRepo.addRecurring(
      name: nameCtrl.text.trim(),
      amount: double.tryParse(amountCtrl.text) ?? 0,
      type: type, frequency: frequency,
      nextDue: nextDue != null ? DateFormat('yyyy-MM-dd').format(nextDue!) : null,
      categoryId: categoryId,
    );
    ref.invalidate(financeRecurringProvider);
  }
}

Future<void> _editGoal(BuildContext context, WidgetRef ref, FinanceGoal? goal) async {
  final nameCtrl = TextEditingController(text: goal?.name ?? '');
  final targetCtrl = TextEditingController(text: goal != null ? goal.targetAmount.toStringAsFixed(0) : '');
  final currentCtrl = TextEditingController(text: goal != null ? goal.currentAmount.toStringAsFixed(0) : '');
  DateTime? targetDate = goal?.targetDate != null ? DateTime.tryParse(goal!.targetDate!) : null;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(builder: (ctx, setS) {
        final c = ctx.colors;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(goal == null ? 'Add goal' : 'Edit goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Goal name (e.g. Emergency fund)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: targetCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target', prefixText: '\$ '))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: currentCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Saved', prefixText: '\$ '))),
            ]),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(targetDate == null ? 'Target date (optional)' : DateFormat('MMM d, yyyy').format(targetDate!), style: TextStyle(color: targetDate == null ? c.textMuted : c.textPrimary)),
              trailing: Icon(Icons.calendar_today_rounded, size: 18, color: c.textMuted),
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: targetDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (picked != null) setS(() => targetDate = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.emerald), child: Text(goal == null ? 'Add goal' : 'Save')),
          ]),
        );
      }),
    ),
  );
  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
    await FinanceRepo.saveGoal(
      id: goal?.id,
      name: nameCtrl.text.trim(),
      target: double.tryParse(targetCtrl.text) ?? 0,
      current: double.tryParse(currentCtrl.text) ?? 0,
      targetDate: targetDate != null ? DateFormat('yyyy-MM-dd').format(targetDate!) : null,
    );
    ref.invalidate(financeGoalsProvider);
  }
}

Future<void> _manageCategories(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _CategoriesSheet(),
    ),
  );
}

class _CategoriesSheet extends ConsumerStatefulWidget {
  const _CategoriesSheet();
  @override
  ConsumerState<_CategoriesSheet> createState() => _CategoriesSheetState();
}

class _CategoriesSheetState extends ConsumerState<_CategoriesSheet> {
  final _newCtrl = TextEditingController();
  String _newKind = 'expense';

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_newCtrl.text.trim().isEmpty) return;
    await FinanceRepo.addCategory(_newCtrl.text.trim(), _newKind);
    _newCtrl.clear();
    ref.invalidate(financeCategoriesProvider);
  }

  Future<void> _rename(FinanceCategory cat) async {
    final ctrl = TextEditingController(text: cat.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: context.colors.background,
        title: const Text('Rename category'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), style: FilledButton.styleFrom(backgroundColor: AppColors.emerald), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != cat.name) {
      await FinanceRepo.renameCategory(cat.id, name);
      ref.invalidate(financeCategoriesProvider);
    }
  }

  Future<void> _delete(FinanceCategory cat) async {
    await FinanceRepo.deleteCategory(cat.id);
    ref.invalidate(financeCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cats = ref.watch(financeCategoriesProvider).valueOrNull ?? [];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(children: [
            Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: c.textMuted)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: TextField(controller: _newCtrl, decoration: const InputDecoration(hintText: 'New category'))),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _newKind,
              items: const [DropdownMenuItem(value: 'expense', child: Text('Expense')), DropdownMenuItem(value: 'income', child: Text('Income'))],
              onChanged: (v) => setState(() => _newKind = v ?? 'expense'),
            ),
            IconButton(onPressed: _add, icon: const Icon(Icons.add_rounded, color: AppColors.emerald)),
          ]),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(controller: scroll, children: [
            for (final kind in const ['expense', 'income']) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(kind.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textMuted, letterSpacing: 0.8)),
              ),
              for (final cat in cats.where((x) => x.kind == kind))
                ListTile(
                  dense: true,
                  title: Text(cat.name, style: TextStyle(fontSize: 14, color: c.textPrimary)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(Icons.edit_rounded, size: 18, color: c.textMuted), onPressed: () => _rename(cat)),
                    IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted), onPressed: () => _delete(cat)),
                  ]),
                ),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

List<Map<String, dynamic>> _parseCsv(String text, String def) {
  final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return [];
  final first = lines.first.toLowerCase();
  final start = (first.contains('date') || first.contains('amount')) ? 1 : 0;
  final out = <Map<String, dynamic>>[];
  for (final line in lines.skip(start)) {
    final cols = line.split(',').map((c) => c.trim()).toList();
    if (cols.length < 2) continue;
    var date = cols[0];
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      final d = DateTime.tryParse(date);
      if (d == null) continue;
      date = DateFormat('yyyy-MM-dd').format(d);
    }
    final raw = double.tryParse(cols[1].replaceAll(RegExp(r'[$,]'), ''));
    if (raw == null || raw == 0) continue;
    final c2 = cols.length > 2 ? cols[2].toLowerCase() : '';
    final hasTypeCol = c2 == 'income' || c2 == 'expense';
    String type = def == 'income' ? 'income' : 'expense';
    if (hasTypeCol) {
      type = c2;
    } else if (def == 'sign') {
      type = raw < 0 ? 'expense' : 'income';
    }
    final note = hasTypeCol ? (cols.length > 3 ? cols[3] : null) : (cols.length > 2 ? cols[2] : null);
    out.add({'type': type, 'amount': raw.abs(), 'date': date, 'note': (note == null || note.isEmpty) ? null : note});
  }
  return out;
}

Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
  String def = 'expense';
  String raw = '';
  String fileName = '';
  String err = '';
  bool saving = false;
  List<Map<String, dynamic>> rows = [];

  final imported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(builder: (ctx, setS) {
        final c = ctx.colors;

        void reparse() {
          if (raw.isEmpty) return;
          rows = _parseCsv(raw, def);
          err = rows.isEmpty ? 'No rows parsed. Expected: date, amount, [type], [note].' : '';
        }

        Future<void> pick() async {
          final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
          if (res == null) return;
          final f = res.files.single;
          String? content;
          if (f.bytes != null) {
            content = utf8.decode(f.bytes!);
          } else if (f.path != null) {
            content = await File(f.path!).readAsString();
          }
          if (content == null) {
            setS(() => err = 'Could not read file.');
            return;
          }
          setS(() { raw = content!; fileName = f.name; reparse(); });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Import transactions (CSV)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text('Columns: date, amount, type, note — type and note optional.\nExample: 2026-06-01, 49.90, expense, Internet',
                style: TextStyle(fontSize: 12, color: c.textMuted)),
            const SizedBox(height: 12),
            Text('When the type column is missing, treat amounts as', style: TextStyle(fontSize: 11, color: c.textMuted)),
            const SizedBox(height: 6),
            Row(children: [
              for (final o in const [['expense', 'Expenses'], ['income', 'Income'], ['sign', 'By sign']])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(o[1]), selected: def == o[0], onSelected: (_) => setS(() { def = o[0]; reparse(); })),
                ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pick, icon: const Icon(Icons.upload_file_rounded, size: 18), label: Text(fileName.isEmpty ? 'Choose CSV file' : fileName)),
            if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: TextStyle(fontSize: 12, color: AppColors.red))),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.surfaceAlt)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${rows.length} transactions ready', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 4),
                  for (final r in rows.take(3))
                    Text('${r['date']} · ${r['type'] == 'income' ? '+' : '-'}${_money.format(r['amount'])}${r['note'] != null ? ' · ${r['note']}' : ''}',
                        style: TextStyle(fontSize: 11, color: c.textMuted)),
                  if (rows.length > 3) Text('…and ${rows.length - 3} more', style: TextStyle(fontSize: 11, color: c.textMuted)),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (rows.isEmpty || saving)
                  ? null
                  : () async {
                      setS(() => saving = true);
                      await FinanceRepo.addTransactionsBulk(rows);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
              child: Text(saving ? 'Importing…' : 'Import ${rows.isEmpty ? '' : rows.length} transactions'),
            ),
          ]),
        );
      }),
    ),
  );
  if (imported == true) ref.invalidate(financeTransactionsProvider);
}
