import 'package:flutter/material.dart';

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

// ----- Screen: add/list/delete with Undo (in-memory) -----
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final List<TransactionModel> _tx = [];

  void _addTx(TransactionModel t) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
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
      body: _tx.isEmpty
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
    );
  }

  String _label(TxType type) => switch (type) {
    TxType.buy => 'BUY',
    TxType.sell => 'SELL',
    TxType.fee => 'FEE',
    TxType.note => 'NOTE',
  };

  String _quantityStr(TransactionModel t) => t.quantity == 0 ? '-' : t.quantity.toStringAsFixed(4);
  String _priceStr(TransactionModel t) => t.price == 0 ? '-' : '\$${t.price.toStringAsFixed(2)}';
  String _subtitle(TransactionModel t) => [
    if (t.fee != 0) 'fee: \$${t.fee.toStringAsFixed(2)}',
    if ((t.note ?? '').isNotEmpty) t.note!,
  ].join('  •  ');
  String _dateStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ----- Bottom sheet form -----
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
                      DropdownMenuItem(value: TxType.fee, child: Text('Fee')),
                      DropdownMenuItem(value: TxType.note, child: Text('Note')),
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
        final parsed = double.tryParse(v ?? '');
        if (parsed == null) return 'Enter a number';
        if (parsed < 0) return 'Must be ≥ 0';
        return null;
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final fee = double.tryParse(_feeCtrl.text) ?? 0;
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
