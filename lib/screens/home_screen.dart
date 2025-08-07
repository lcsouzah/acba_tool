import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/simulation_result.dart';
import 'dart:convert';


class AcbaHomeScreen extends StatefulWidget {
  const AcbaHomeScreen({super.key});


  @override
  State<AcbaHomeScreen> createState() => _AcbaHomeScreenState();
}

class _AcbaHomeScreenState extends State<AcbaHomeScreen> {

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

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyData = prefs.getStringList('history') ?? [];

    setState(() {
      _history = historyData
          .map((entry) => SimulationResult.fromJson(jsonDecode(entry)))
          .toList();
    });
  }

  void _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    setState(() {
      _history.clear();
    });
  }

  void _calculate() async {
    final double? avgPrice = double.tryParse(_avgPriceController.text.trim().replaceAll(',', '.'));
    final double? tokenQty = double.tryParse(_tokenQtyController.text.trim().replaceAll(',', '.'));
    final double? tokenPrice = double.tryParse(_tokenPriceController.text.trim().replaceAll(',', '.'));
    final double? targetAvg = double.tryParse(_targetAvgController.text.trim().replaceAll(',', '.'));

    if (avgPrice == null || tokenQty == null || tokenPrice == null || targetAvg == null || tokenQty == 0) {
      setState(() {
        _resultText = '❌ Please enter valid numbers.';
        _resultColor = Colors.red.shade100;
      });
      return;
    }

    // 🧠 ACBA Rule: Only allow if you're lowering average price
    if (targetAvg >= avgPrice) {
      setState(() {
        _resultText = '❌ Not allowed: Target average must be lower than current average.';
        _resultColor = Colors.red.shade100;
      });
      return;
    }

    // 🧠 Also block if trying to lower average to or below current price
    if (targetAvg <= tokenPrice) {
      setState(() {
        _resultText = '❌ Not allowed: Target average must be higher than current token price.';
        _resultColor = Colors.red.shade100;
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

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final saved = _history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('history', saved);

    setState(() {
      _resultText =
      '✅ ACBA Buy Approved\n\n'
          'Current AP: ${currencyFormat.format(avgPrice)}\n'
          'Target AP: ${currencyFormat.format(targetAvg)}\n'
          'New AP: ${currencyFormat.format(newAvg)}\n'
          'Buy ${q2.toStringAsFixed(2)} tokens for ${currencyFormat.format(cost)}';
      _resultColor = Colors.green.shade100;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ACBA Tool')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField( // Average Price
              controller: _avgPriceController,
              decoration: const InputDecoration(labelText: 'Current Average Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(  // Token Qty
              controller: _tokenQtyController,
              decoration: const InputDecoration(labelText: 'Current Token Quantity'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField( // Token Price
              controller: _tokenPriceController,
              decoration: const InputDecoration(labelText: 'Current Token Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField( //🆕 Target Avg
              controller: _targetAvgController,
              decoration: const InputDecoration(labelText: 'Target Average Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculate,
              child: const Text('Calculate'),
            ),
            const SizedBox(height: 20),
            if (_resultText != null)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                color: _resultColor,
                child: Text(
                  _resultText!,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            const Divider(height: 40),
            const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Clear History Button

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _history.isEmpty ? null :_clearHistory,
                icon: const Icon(Icons.delete),
                label: const Text('Clear History'),
              ),
            ),

            // ✅ Fix: Wrap history section in Expanded
            Expanded(
              child: _history.isEmpty
                  ? const Center(child: Text("No history yet."))
                  : ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final sim = _history[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        'Old: ${currencyFormat.format(sim.oldAp)} → New: ${currencyFormat.format(sim.newAp)}',
                      ),
                      subtitle: Text(
                        'Buy ${sim.qtyToBuy.toStringAsFixed(2)} for ${currencyFormat.format(sim.cost)}',
                      ),
                      trailing: Text(
                        '${sim.timestamp.hour.toString().padLeft(2, '0')}:${sim.timestamp.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

    );
  }
}
