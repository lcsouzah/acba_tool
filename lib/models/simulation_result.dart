class SimulationResult {
  final double oldAp;
  final double newAp;
  final double qtyToBuy;
  final double cost;
  final DateTime timestamp;

  SimulationResult({
    required this.oldAp,
    required this.newAp,
    required this.qtyToBuy,
    required this.cost,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'oldAp': oldAp,
    'newAp': newAp,
    'qtyToBuy': qtyToBuy,
    'cost': cost,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      oldAp: json['oldAp'],
      newAp: json['newAp'],
      qtyToBuy: json['qtyToBuy'],
      cost: json['cost'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
