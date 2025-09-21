import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ----- Minimal model (local-only) -----
enum TxType { buy, sell, fee, note }

class TransactionModel {
  final String id;
  final TxType type;
  final double quantity; // for fee/note, can be 0
  final double price;    // for fee/note, can be 0
  final double fee;      // optional extra fee for buy/sell
  final DateTime ts;
  final String? note;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.quantity,
    required this.price,
    this.fee = 0,
    required this.ts,
    this.note,
  });
}

class AcbaRules {
  double buyThreshold;   // allow BUY if price <= avg * buyThreshold (e.g., 0.98)
  int cooldownDays;      // min days between BUYs
  double maxDailySpend;  // cap daily buy spend (price*qty + fee)
  AcbaRules({
    this.buyThreshold = 0.98,
    this.cooldownDays = 3,
    this.maxDailySpend = 500.0,
  });
}

class _Stats {
  final double qty;
  final double avg;
  final double? unrealized; // null if market price not set
  const _Stats(this.qty, this.avg, this.unrealized);
}

_Stats computeStats(List<TransactionModel> tx, {double? marketPrice}) {
  double qty = 0.0;
  double cost = 0.0; // running cost basis (includes fees)

  // Process from oldest to newest so cost/qty evolve correctly
  final reversed = tx.reversed.toList();
  for (final t in reversed) {
    switch (t.type) {
      case TxType.buy:
        cost += t.quantity * t.price + t.fee;
        qty += t.quantity;
        break;
      case TxType.sell:
      // reduce quantity; keep avg cost basis for remaining
        final sellQty = t.quantity.clamp(0, qty);
        final avg = qty == 0 ? 0.0 : cost / qty;
        qty -= sellQty;
        cost -= avg * sellQty; // remove proportional cost basis
        break;
      case TxType.fee:
        cost += t.fee; // fees increase cost basis
        break;
      case TxType.note:
      // no-op
        break;
    }
  }

  final avg = qty == 0 ? 0.0 : cost / qty;
  double? unrealized;
  if (marketPrice != null && qty > 0) {
    unrealized = (marketPrice - avg) * qty;
  }
  return _Stats(qty, avg, unrealized);
}

// ----- Screen: add/list/delete with Undo (in-memory) + Stats header + ACBA validator -----
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final List<TransactionModel> _tx = [];
  final _marketPriceCtrl = TextEditingController();
  double? _marketPrice; // user-entered market price for unrealized P/L
  AcbaRules _rules = AcbaRules();

  @override
  void dispose() {
    _marketPriceCtrl.dispose();
    super.dispose();
  }

  void _addTx(TransactionModel t) async {
    // ACBA validation only for BUY
    if (t.type == TxType.buy) {
      final failMsg = _validateBuy(t);
      if (failMsg != null) {
        _showValidationDialog(failMsg);
        return; // block save
      }
    }
    setState(() => _tx.insert(0, t));
  }

  void _deleteTx(int index) {
    final removed = _tx.removeAt(index);
    setState(() {});
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _tx.insert(index, removed));
          },
        ),
      ),
    );
  }

  String? _validateBuy(TransactionModel buy) {
    final stats = computeStats(_tx, marketPrice: _marketPrice);

    // Rule 1: first buy always allowed
    if (stats.qty == 0) return null;

    final avg = stats.avg;
    final thresholdPrice = avg * _rules.buyThreshold;
    if (buy.price > thresholdPrice) {
      return 'Price too high for discipline.\n\nCurrent Avg: \$${avg.toStringAsFixed(2)}\nThreshold: ${(( 1- _rules.buyThreshold ) * 100).toStringAsFixed(2)}% below avg\nMax allowed price now: \$${thresholdPrice.toStringAsFixed(2)}\nYour price: \$${buy.price.toStringAsFixed(2)}';
    }

    // Rule 2: cooldown between BUYs
    final lastBuy = _lastBuyAt();
    if (lastBuy != null) {
      final days = DateTime.now().difference(lastBuy).inDays;
      if (days < _rules.cooldownDays) {
        final nextDate = lastBuy.add(Duration(days: _rules.cooldownDays));
        final y = nextDate.year;
        final m = nextDate.month.toString().padLeft(2, '0');
        final d = nextDate.day.toString().padLeft(2, '0');
        return 'Cooldown active. Next eligible buy: $y-$m-$d (in ${_rules.cooldownDays - days} day(s)).';
      }
    }

    // Rule 3: daily spend cap
    final todaySpend = _todayBuySpend();
    final thisSpend = buy.quantity * buy.price + buy.fee;
    if (todaySpend + thisSpend > _rules.maxDailySpend) {
      final remain = (_rules.maxDailySpend - todaySpend).clamp(0, _rules.maxDailySpend);
      return 'Daily spend limit reached.\nLimit: \$${_rules.maxDailySpend.toStringAsFixed(2)}\nUsed today: \$${todaySpend.toStringAsFixed(2)}\nRemaining: \$${remain.toStringAsFixed(2)}\nYour buy would add: \$${thisSpend.toStringAsFixed(2)}';
    }

    return null; // allowed
  }

  DateTime? _lastBuyAt() {
    for (final t in _tx) {
      if (t.type == TxType.buy) return t.ts; // list is newest-first
    }
    return null;
  }

  double _todayBuySpend() {
    final now = DateTime.now();
    double sum = 0.0;
    for (final t in _tx) {
      if (t.type != TxType.buy) continue;
      if (t.ts.year == now.year && t.ts.month == now.month && t.ts.day == now.day) {
        sum += t.quantity * t.price + t.fee;
      }
    }
    return sum;
  }

  // Stats are now computed via the top-level [computeStats] helper.

  void _openRules() async {
    final updated = await showModalBottomSheet<AcbaRules>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RulesSheet(rules: _rules),
    );
    if (updated != null) {
      setState(() => _rules = updated);
    }
  }

  void _showValidationDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buy not approved'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = computeStats(_tx, marketPrice: _marketPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'ACBA Rules',
            icon: const Icon(Icons.rule),
            onPressed: _openRules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showModalBottomSheet<TransactionModel>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddTransactionSheet(),
          );
          if (result != null) _addTx(result);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // --- Stats Header Card ---
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assessment),
                        const SizedBox(width: 8),
                        Text('Position Overview', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _marketPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Market price',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (v) {
                              final p = double.tryParse(v);
                              setState(() => _marketPrice = p);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _statChip('Qty', stats.qty.toStringAsFixed(4)),
                        _statChip('Avg Price', stats.avg == 0 ? '-' : _money(stats.avg)),
                        _statChip(
                          'Unrealized P/L',
                          stats.unrealized == null ? '— set market —' : _money(stats.unrealized!),
                          color: stats.unrealized == null
                              ? Colors.grey
                              : (stats.unrealized! >= 0 ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 0),

          // --- List ---
          Expanded(
            child: _tx.isEmpty
                ? const Center(child: Text('No transactions yet. Tap + to add.'))
                : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final t = _tx[index];
                return Dismissible(
                  key: ValueKey(t.id),
                  background: Container(
                    color: Colors.red.withOpacity(0.85),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _deleteTx(index),
                  child: ListTile(
                    title: Text('${_label(t.type)}  •  ${_quantityStr(t)} @ ${_priceStr(t)}'),
                    subtitle: Text(_subtitle(t)),
                    trailing: Text(_dateStr(t.ts), style: const TextStyle(fontSize: 12)),
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemCount: _tx.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, {Color? color}) {
    final fg = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: fg)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  String _label(TxType type) => switch (type) {
    TxType.buy => 'BUY',
    TxType.sell => 'SELL',
    TxType.fee => 'FEE',
    TxType.note => 'NOTE',
  };

  String _quantityStr(TransactionModel t) => t.quantity == 0 ? '-' : t.quantity.toStringAsFixed(4);
  String _priceStr(TransactionModel t) => t.price == 0 ? '-' : _money(t.price);
  String _subtitle(TransactionModel t) => [
    if (t.fee != 0) 'fee: ${_money(t.fee)}',
    if ((t.note ?? '').isNotEmpty) t.note!,
  ].join('  •  ');
  String _dateStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ----- Bottom sheet: Add Transaction -----
class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet();
  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  TxType _type = TxType.buy;
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _feeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Type:'),
                  const SizedBox(width: 12),
                  DropdownButton<TxType>(
                    value: _type,
                    onChanged: (v) => setState(() => _type = v ?? TxType.buy),
                    items: const [
                      DropdownMenuItem(value: TxType.buy, child: Text('Buy')),
                      DropdownMenuItem(value: TxType.sell, child: Text('Sell')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _numField(_qtyCtrl, label: 'Quantity', requiredFor: const {TxType.buy, TxType.sell}),
              const SizedBox(height: 8),
              _numField(_priceCtrl, label: 'Price', requiredFor: const {TxType.buy, TxType.sell}),
              const SizedBox(height: 8),
              _numField(_feeCtrl, label: 'Fee (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, {required String label, Set<TxType> requiredFor = const {}}) {
    final isRequired = requiredFor.contains(_type);
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (!isRequired && (v == null || v.trim().isEmpty)) return null;
        final parsed = _parseLocalizedNumber(v);
        if (parsed == null) return 'Enter a number';
        if (parsed < 0) return 'Must be ≥ 0';
        return null;
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final qty = _parseLocalizedNumber(_qtyCtrl.text) ?? 0;
    final price = _parseLocalizedNumber(_priceCtrl.text) ?? 0;
    final fee = _parseLocalizedNumber(_feeCtrl.text) ?? 0;
    final now = DateTime.now();
    final tx = TransactionModel(
      id: '${now.microsecondsSinceEpoch}',
      type: _type,
      quantity: qty,
      price: price,
      fee: fee,
      ts: now,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    );
    Navigator.of(context).pop(tx);
  }
}

// ----- Bottom sheet: ACBA Rules -----
class _RulesSheet extends StatefulWidget {
  final AcbaRules rules;
  const _RulesSheet({required this.rules});
  @override
  State<_RulesSheet> createState() => _RulesSheetState();
}

class _RulesSheetState extends State<_RulesSheet> {
  late final TextEditingController _thresholdCtrl;
  late final TextEditingController _cooldownCtrl;
  late final TextEditingController _dailyCtrl;

  @override
  void initState() {
    super.initState();
    _thresholdCtrl = TextEditingController(text: widget.rules.buyThreshold.toString());
    _cooldownCtrl = TextEditingController(text: widget.rules.cooldownDays.toString());
    _dailyCtrl = TextEditingController(text: widget.rules.maxDailySpend.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    _cooldownCtrl.dispose();
    _dailyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule),
                const SizedBox(width: 8),
                Text('ACBA Rules', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () {
                    final t = _parseLocalizedNumber(_thresholdCtrl.text);
                    final c = int.tryParse(_cooldownCtrl.text);
                    final d = _parseLocalizedNumber(_dailyCtrl.text);
                    if (t == null || t <= 0 || c == null || c < 0 || d == null || d < 0) {

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid rule values')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(
                      AcbaRules(buyThreshold: t, cooldownDays: c, maxDailySpend: d),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Buy threshold (multiplier):'),
            const SizedBox(height: 4),
            TextField(
              controller: _thresholdCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'e.g., 0.98 means price must be ≤ 98% of current avg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Cooldown days between buys:'),
            const SizedBox(height: 4),
            TextField(
              controller: _cooldownCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Max daily spend (USD):'),
            const SizedBox(height: 4),
            TextField(
              controller: _dailyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }
}

double? _parseLocalizedNumber(String? input) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final format = NumberFormat.decimalPattern();
  try {
    final parsed = format.parse(trimmed);
    return parsed.toDouble();
  } on FormatException {
    return null;
  }
}