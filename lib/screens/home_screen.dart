import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/simulation_result.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class AcbaHomeScreen extends StatefulWidget {

  const AcbaHomeScreen({super.key});


  @override
  State<AcbaHomeScreen> createState() => _AcbaHomeScreenState();
}

class _AcbaHomeScreenState extends State<AcbaHomeScreen> {

  String _formatWhen(DateTime t) {
    // e.g., "Aug 8 · 18:42"
    return DateFormat('MMM d · HH:mm').format(t);
  }

  bool _lastRunAllowed = false;

  IconData get _statusIcon => _lastRunAllowed ? Icons.check_circle : Icons.error;
  Color get _statusColor =>
      _lastRunAllowed ? Colors.green.shade600 : Colors.red.shade700;
  String get _statusText =>
      _lastRunAllowed ? 'Allowed (AP will decrease)' : 'Not Allowed';

  final _avgPriceController = TextEditingController();
  final _tokenQtyController = TextEditingController();
  final _tokenPriceController = TextEditingController();
  final _targetAvgController = TextEditingController();

  String? _resultText;
  Color _resultColor = Colors.transparent;

  final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);
  //✅ Add History
  List<SimulationResult> _history = [];


  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  @override
  void dispose() {
    _avgPriceController.dispose();
    _tokenQtyController.dispose();
    _tokenPriceController.dispose();
    _targetAvgController.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    if (_history.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No history to export')),
        );
      }
      return;
    }

    // Build CSV
    final buffer = StringBuffer();
    buffer.writeln('timestamp,old_ap,new_ap,qty_to_buy,cost');
    for (final r in _history) {
      buffer.writeln([
        r.timestamp.toIso8601String(),
        r.oldAp.toStringAsFixed(6),
        r.newAp.toStringAsFixed(6),
        r.qtyToBuy.toStringAsFixed(6),
        r.cost.toStringAsFixed(6),
      ].join(','));
    }

    // Save to temp file
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/acba_history.csv');
    await file.writeAsString(buffer.toString());

    // Share
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'ACBA Tool – Simulation History (CSV)',
        subject: 'ACBA Simulation History',
      );
    } finally {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Failed to delete export file: $e');
      }
    }
  }


  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('history', saved);
  }

  void _resetInputs(){
    _avgPriceController.clear();
    _tokenQtyController.clear();
    _tokenPriceController.clear();
    _targetAvgController.clear();

    setState(() {
      _resultText = null;
      _resultColor = Colors.transparent;
      _lastRunAllowed = false;
    });
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyData = prefs.getStringList('history') ?? [];
    if (!mounted) return;
    setState(() {
      _history = historyData
          .map((entry) => SimulationResult.fromJson(jsonDecode(entry)))
          .toList();
    });
  }

  void _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    if (!mounted) return;
    setState(() {
      _history.clear();
    });
  }

  void _calculate() async {
    final double? avgPrice = double.tryParse(_avgPriceController.text.trim().replaceAll(',', '.'));
    final double? tokenQty = double.tryParse(_tokenQtyController.text.trim().replaceAll(',', '.'));
    final double? tokenPrice = double.tryParse(_tokenPriceController.text.trim().replaceAll(',', '.'));
    final double? targetAvg = double.tryParse(_targetAvgController.text.trim().replaceAll(',', '.'));

    if (avgPrice == null || avgPrice <= 0 ||
        tokenQty == null || tokenQty <= 0 ||
        tokenPrice == null || tokenPrice <= 0 ||
        targetAvg == null || targetAvg <= 0) {
      setState(() {
        _resultText = '❌ Please enter numbers greater than zero.';
        _resultColor = Colors.red.shade100;
        _lastRunAllowed = false;
      });
      return;
    }

    // 🧠 ACBA Rule: Only allow if you're lowering average price
    if (targetAvg >= avgPrice) {
      setState(() {
        _resultText =
        '❌ Not allowed: Target average must be lower than current average.';
        _resultColor = Colors.red.shade100;
        _lastRunAllowed = false;
      });
      return;
    }

    // 🧠 Also block if trying to lower average to or below current price
    if (targetAvg <= tokenPrice) {
      setState(() {
        _resultText =
        '❌ Not allowed: Target average must be higher than current token price.';
        _resultColor = Colors.red.shade100;
        _lastRunAllowed = false;
      });
      return;
    }

    // ✅ ACBA Buy Formula
    double q2 = ((targetAvg - avgPrice) * tokenQty) / (tokenPrice - targetAvg);
    double newQty = tokenQty + q2;
    double newAvg = ((avgPrice * tokenQty) + (tokenPrice * q2)) / newQty;
    double cost = q2 * tokenPrice;

    final simulationResult = SimulationResult(
      oldAp: avgPrice,
      newAp: newAvg,
      qtyToBuy: q2,
      cost: cost,
      timestamp: DateTime.now(),
    );

    setState(() {
      _history.insert(0, simulationResult);
    });

    await _saveHistory();

    _lastRunAllowed = newAvg < avgPrice;

    if (mounted && _lastRunAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simulation saved'),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _resultText =
      '✅ ACBA Buy Approved\n\n'
          'Current AP: ${currencyFormat.format(avgPrice)}\n'
          'Target AP: ${currencyFormat.format(targetAvg)}\n'
          'New AP: ${currencyFormat.format(newAvg)}\n'
          'Buy ${q2.toStringAsFixed(2)} tokens for ${currencyFormat.format(cost)}';
      _resultColor =
      _lastRunAllowed ? Colors.green.shade100 : Colors.red.shade100;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('ACBA Tool'),
        actions: [
          IconButton(
          tooltip: 'Export CSV',
          icon: const Icon(Icons.ios_share),
          onPressed: _exportCsv,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Discipline Calculator',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _avgPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Current Average Price',
                        prefixIcon: Icon(Icons.trending_down),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tokenQtyController,
                      decoration: const InputDecoration(
                        labelText: 'Current Token Quantity',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tokenPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Current Token Price',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetAvgController,
                      decoration: const InputDecoration(
                        labelText: 'Target Average Price',
                        prefixIcon: Icon(Icons.flag),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculate'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetInputs,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_resultText != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _lastRunAllowed ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Icon(_statusIcon, color: _statusColor),
                          const SizedBox(width: 8),
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _statusColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Details
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Text(
                        _resultText!,
                        style: const TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

            // Clear History Button

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _history.isEmpty ? null :_clearHistory,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Clear History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                  ),
              ),

            ),

            // ✅ Fix: Wrap history section in Expanded
            Expanded(
              child: _history.isEmpty
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("No history yet.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              )
                  : ListView.separated(
                itemCount: _history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final sim = _history[index];
                  final wasImprovement = sim.newAp < sim.oldAp;

                  return Dismissible(
                    key: ValueKey(sim.timestamp.toIso8601String()), // unique key
                    background: Container(
                      color: Colors.red.shade100,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.delete, color: Colors.red.shade700),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red.shade100,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.delete, color: Colors.red.shade700),
                    ),
                    onDismissed: (direction) async {
                      // Capture before removing
                      final removed = sim;
                      final removedIndex = index;

                      // Remove from list + persist
                      setState(() {
                        _history.removeAt(removedIndex);
                      });
                      await _saveHistory();

                      if (!mounted) return;

                      // Show snackbar with Undo
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: const Text('Entry removed'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () async {
                                // Restore item at the same position + persist
                                setState(() {
                                  _history.insert(removedIndex, removed);
                                });
                                await _saveHistory();
                              },
                            ),
                          ),
                        );
                    },
                    child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      wasImprovement ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        wasImprovement ? Icons.trending_down : Icons.block,
                        color: wasImprovement ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    title: Text(
                      'Old: ${currencyFormat.format(sim.oldAp)} → New: ${currencyFormat.format(sim.newAp)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          // Qty + Cost
                          Text(
                            'Buy ${sim.qtyToBuy.toStringAsFixed(2)} '
                                'for ${currencyFormat.format(sim.cost)}',
                          ),
                          const SizedBox(width: 12),
                          // Time chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _formatWhen(sim.timestamp),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(
                      wasImprovement ? Icons.check_circle : Icons.error_outline,
                      color: wasImprovement ? Colors.green.shade600 : Colors.red.shade700,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),

                  );
                },
              ),
            )

          ],
        ),
      ),

    );
  }
}
