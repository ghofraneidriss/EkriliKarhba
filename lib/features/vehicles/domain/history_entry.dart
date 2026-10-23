import 'enums.dart';

/// Une ligne de l'historique d'un véhicule : qui a changé quoi, quand,
/// et la valeur avant / après. L'historique est conservé même après
/// la suppression du véhicule.
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.vehicleId,
    required this.timestamp,
    required this.actor,
    required this.action,
    this.field,
    this.oldValue,
    this.newValue,
    this.comment,
  });

  final int? id;
  final String vehicleId;
  final DateTime timestamp;

  /// Libellé de l'auteur (Administrateur, Agence, Module Réservations…).
  final String actor;
  final HistoryAction action;

  /// Champ concerné, en français (ex. « Prix par jour »).
  final String? field;
  final String? oldValue;
  final String? newValue;
  final String? comment;

  /// Résumé d'une ligne, ex. « Prix par jour : 160 DT → 180 DT ».
  String get summary {
    final buffer = StringBuffer(field ?? action.label);
    if (oldValue != null || newValue != null) {
      buffer.write(' : ${oldValue ?? '—'} → ${newValue ?? '—'}');
    }
    return buffer.toString();
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'timestamp': timestamp.toIso8601String(),
        'actor': actor,
        'action': action.name,
        'field': field,
        'old_value': oldValue,
        'new_value': newValue,
        'comment': comment,
      };

  factory HistoryEntry.fromMap(Map<String, Object?> map) => HistoryEntry(
        id: map['id'] as int?,
        vehicleId: map['vehicle_id'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        actor: map['actor'] as String,
        action: HistoryAction.fromName(map['action'] as String?),
        field: map['field'] as String?,
        oldValue: map['old_value'] as String?,
        newValue: map['new_value'] as String?,
        comment: map['comment'] as String?,
      );
}
