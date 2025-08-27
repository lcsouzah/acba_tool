class SimulationResult {
  final double oldAp;
  final double newAp;
  final double qtyToBuy;
  final double cost;
  final DateTime timestamp;

  //🔒 Lock Entries
  final bool committed;
  final DateTime? committedAt;


  SimulationResult({
    required this.oldAp,
    required this.newAp,
    required this.qtyToBuy,
    required this.cost,
    required this.timestamp,
    this.committed = false, // default:not commited
    this.committedAt,  // default:null

  });

  Map<String, dynamic> toJson() => {
    'oldAp': oldAp,
    'newAp': newAp,
    'qtyToBuy': qtyToBuy,
    'cost': cost,
    'timestamp': timestamp.toIso8601String(),

    //🔒 Lock Entries
    'committed': committed,
    'committedAt': committedAt?.toIso8601String(),
  };

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      oldAp: json['oldAp'],
      newAp: json['newAp'],
      qtyToBuy: json['qtyToBuy'],
      cost: json['cost'],
      timestamp: DateTime.parse(json['timestamp']),

      // 🔒 If loading old entries, default to false/null
      committed: (json['committed'] as bool?) ?? false,
      committedAt: (json['commitedAt'] != null)
        ? DateTime.parse(json['committedAt'] as String)
          : null,
    );
  }
}
