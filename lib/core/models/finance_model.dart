// Personal finance manager (manual-only) — models mirroring the web app.

class FinanceAccount {
  final String id;
  final String name;
  final String type; // checking|savings|cash|credit_card|investment|loan|other
  final double balance;
  final String currency;
  final String? institution;

  const FinanceAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
    this.institution,
  });

  factory FinanceAccount.fromJson(Map<String, dynamic> j) => FinanceAccount(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String? ?? 'checking',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        currency: j['currency'] as String? ?? 'USD',
        institution: j['institution'] as String?,
      );

  bool get isLiability => type == 'credit_card' || type == 'loan';
}

class FinanceTransaction {
  final String id;
  final String? accountId;
  final String? categoryId;
  final String type; // expense|income|transfer
  final double amount;
  final String date; // YYYY-MM-DD
  final String? note;

  const FinanceTransaction({
    required this.id,
    this.accountId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> j) => FinanceTransaction(
        id: j['id'] as String,
        accountId: j['account_id'] as String?,
        categoryId: j['category_id'] as String?,
        type: j['type'] as String? ?? 'expense',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: j['date'] as String,
        note: j['note'] as String?,
      );
}

class FinanceCategory {
  final String id;
  final String name;
  final String kind; // expense|income

  const FinanceCategory({required this.id, required this.name, required this.kind});

  factory FinanceCategory.fromJson(Map<String, dynamic> j) => FinanceCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: j['kind'] as String? ?? 'expense',
      );
}

class FinanceBudget {
  final String id;
  final String categoryId;
  final double amount;

  const FinanceBudget({required this.id, required this.categoryId, required this.amount});

  factory FinanceBudget.fromJson(Map<String, dynamic> j) => FinanceBudget(
        id: j['id'] as String,
        categoryId: j['category_id'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

class FinanceRecurring {
  final String id;
  final String name;
  final double amount;
  final String? categoryId;
  final String frequency; // weekly|monthly|quarterly|yearly
  final String? nextDue; // YYYY-MM-DD
  final String type; // expense|income
  final bool active;

  const FinanceRecurring({
    required this.id,
    required this.name,
    required this.amount,
    this.categoryId,
    required this.frequency,
    this.nextDue,
    required this.type,
    required this.active,
  });

  factory FinanceRecurring.fromJson(Map<String, dynamic> j) => FinanceRecurring(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        categoryId: j['category_id'] as String?,
        frequency: j['frequency'] as String? ?? 'monthly',
        nextDue: j['next_due'] as String?,
        type: j['type'] as String? ?? 'expense',
        active: j['active'] as bool? ?? true,
      );

  double get perMonth => switch (frequency) {
        'weekly' => amount * 4.345,
        'quarterly' => amount / 3,
        'yearly' => amount / 12,
        _ => amount,
      };
}

class FinanceGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? targetDate;

  const FinanceGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
  });

  factory FinanceGoal.fromJson(Map<String, dynamic> j) => FinanceGoal(
        id: j['id'] as String,
        name: j['name'] as String,
        targetAmount: (j['target_amount'] as num?)?.toDouble() ?? 0,
        currentAmount: (j['current_amount'] as num?)?.toDouble() ?? 0,
        targetDate: j['target_date'] as String?,
      );
}

const kFrequencies = <String, String>{
  'weekly': 'Weekly',
  'monthly': 'Monthly',
  'quarterly': 'Quarterly',
  'yearly': 'Yearly',
};

// Seeded for new users on first load (US-oriented defaults).
const kDefaultCategories = <List<String>>[
  ['Groceries', 'expense'], ['Dining & Drinks', 'expense'], ['Transport', 'expense'],
  ['Housing & Rent', 'expense'], ['Utilities', 'expense'], ['Shopping', 'expense'],
  ['Health', 'expense'], ['Entertainment', 'expense'], ['Subscriptions', 'expense'],
  ['Travel', 'expense'], ['Fees & Charges', 'expense'], ['Other', 'expense'],
  ['Salary', 'income'], ['Freelance', 'income'], ['Investments', 'income'], ['Other Income', 'income'],
];

const kAccountTypes = <String, String>{
  'checking': 'Checking',
  'savings': 'Savings',
  'cash': 'Cash',
  'credit_card': 'Credit Card',
  'investment': 'Investment',
  'loan': 'Loan',
  'other': 'Other',
};
