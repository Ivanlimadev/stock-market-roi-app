import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/models/finance_model.dart';
import '../../core/providers/finance_provider.dart';

final _money = NumberFormat.currency(locale: 'en_US', symbol: '\$');
String _monthKey() => DateFormat('yyyy-MM').format(DateTime.now());

/// Personal finance manager — accounts, net worth and spending (manual-only).
class FinanceManagerPage extends ConsumerWidget {
  const FinanceManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [MainShellMenu.themeButton(), MainShellMenu.settingsButton()],
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

    final mk = _monthKey();
    final month = txns.where((t) => t.date.startsWith(mk));
    final income = month.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final expense = month.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(financeAccountsProvider);
        ref.invalidate(financeTransactionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
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
            Expanded(child: _StatCard(label: 'Income · this month', value: income, color: AppColors.emerald, up: true)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Spending · this month', value: expense, color: AppColors.red, up: false)),
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
            ...accounts.map((a) => _AccountTile(account: a, onDelete: () async {
                  await FinanceRepo.deleteAccount(a.id);
                  ref.invalidate(financeAccountsProvider);
                })),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Recent transactions'),
          const SizedBox(height: 8),
          if (txnsAsync.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (txns.isEmpty)
            _Empty('No transactions yet. Tap “Transaction” to log your first one.')
          else
            ...txns.take(15).map((t) => _TxnTile(txn: t, onDelete: () async {
                  await FinanceRepo.deleteTransaction(t.id);
                  ref.invalidate(financeTransactionsProvider);
                })),
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
  final VoidCallback onDelete;
  const _AccountTile({required this.account, required this.onDelete});
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
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted), onPressed: onDelete),
        ]),
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final FinanceTransaction txn;
  final VoidCallback onDelete;
  const _TxnTile({required this.txn, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final income = txn.type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.surfaceAlt)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: income ? AppColors.emerald.withValues(alpha: 0.15) : c.surfaceAlt,
          child: Icon(income ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: income ? AppColors.emerald : c.textSecond),
        ),
        title: Text(txn.note?.isNotEmpty == true ? txn.note! : (income ? 'Income' : 'Expense'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
        subtitle: Text(txn.date, style: TextStyle(fontSize: 11, color: c.textMuted)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${income ? '+' : '-'}${_money.format(txn.amount)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: income ? AppColors.emerald : c.textPrimary)),
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted), onPressed: onDelete),
        ]),
      ),
    );
  }
}

// ── Add sheets ────────────────────────────────────────────────────────────────

Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final balCtrl = TextEditingController();
  String type = 'checking';
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
            Text('Add account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
              child: const Text('Add account'),
            ),
          ]),
        );
      }),
    ),
  );
  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
    await FinanceRepo.addAccount(name: nameCtrl.text.trim(), type: type, balance: double.tryParse(balCtrl.text) ?? 0);
    ref.invalidate(financeAccountsProvider);
  }
}

Future<void> _addTransaction(BuildContext context, WidgetRef ref) async {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String type = 'expense';
  DateTime date = DateTime.now();
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
            Text('Add transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              for (final t in ['expense', 'income'])
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: t == 'expense' ? 8 : 0),
                  child: ChoiceChip(
                    label: Text(t == 'expense' ? 'Expense' : 'Income'),
                    selected: type == t,
                    onSelected: (_) => setS(() => type = t),
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
    await FinanceRepo.addTransaction(
      type: type, amount: amt,
      date: DateFormat('yyyy-MM-dd').format(date),
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );
    ref.invalidate(financeTransactionsProvider);
  }
}
