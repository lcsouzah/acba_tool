/// Represents the results of a simulation.
///
/// Expected JSON schema:
/// ```json
/// {
///   "oldAp": double,
///   "newAp": double,
///   "qtyToBuy": double,
///   "cost": double,
///   "timestamp": String, // ISO8601 date
///   "committed": bool, // optional
///   "committedAt": String? // ISO8601 date, optional
/// }
/// ```
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
    DateTime parsedTimestamp;
    try {
      parsedTimestamp = DateTime.parse(json['timestamp'] as String);
    } catch (_) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parsedCommittedAt;
    if (json['committedAt'] != null) {
      try {
        parsedCommittedAt =
            DateTime.parse(json['committedAt'] as String);
      } catch (_) {
        parsedCommittedAt = null;
      }
    }

    return SimulationResult(
      oldAp: (json['oldAp'] as num).toDouble(),
      newAp: (json['newAp'] as num).toDouble(),
      qtyToBuy: (json['qtyToBuy'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
      timestamp: parsedTimestamp,

      // 🔒 If loading old entries, default to false/null
      committed: (json['committed'] as bool?) ?? false,
      committedAt: parsedCommittedAt,
    );
  }
}
