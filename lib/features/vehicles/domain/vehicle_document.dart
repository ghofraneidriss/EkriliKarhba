import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'enums.dart';
import 'fleet_dates.dart';

enum DocumentState {
  valide('Valide', AppColors.green, AppColors.greenLight),
  expireBientot('Expire bientôt', AppColors.orange, AppColors.orangeLight),
  expire('Expiré', AppColors.redDark, AppColors.redLight),
  sansExpiration('Sans expiration', AppColors.textMuted, AppColors.sectionBg);

  const DocumentState(this.label, this.color, this.background);
  final String label;
  final Color color;
  final Color background;
}

/// Document administratif d'un véhicule (assurance, visite technique…).
class VehicleDocument {
  const VehicleDocument({
    this.id,
    required this.vehicleId,
    required this.type,
    this.reference = '',
    this.expiryDate,
    this.note = '',
  });

  /// Nombre de jours avant expiration à partir duquel on alerte.
  static const int warningDays = 30;

  final int? id;
  final String vehicleId;
  final DocumentType type;
  final String reference;
  final DateTime? expiryDate;
  final String note;

  DocumentState stateAt(DateTime now) {
    final expiry = expiryDate;
    if (expiry == null) return DocumentState.sansExpiration;
    final today = FleetDates.dayOnly(now);
    final end = FleetDates.dayOnly(expiry);
    if (end.isBefore(today)) return DocumentState.expire;
    if (end.difference(today).inDays <= warningDays) {
      return DocumentState.expireBientot;
    }
    return DocumentState.valide;
  }

  /// Vrai si ce document expiré empêche la location.
  bool blocksRentalAt(DateTime now) =>
      type.blocksRentalWhenExpired && stateAt(now) == DocumentState.expire;

  VehicleDocument copyWith({
    int? id,
    DocumentType? type,
    String? reference,
    DateTime? expiryDate,
    bool clearExpiry = false,
    String? note,
  }) {
    return VehicleDocument(
      id: id ?? this.id,
      vehicleId: vehicleId,
      type: type ?? this.type,
      reference: reference ?? this.reference,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'type': type.name,
        'reference': reference,
        'expiry_date':
            expiryDate == null ? null : FleetDates.toDbDay(expiryDate!),
        'note': note,
      };

  factory VehicleDocument.fromMap(Map<String, Object?> map) {
    final expiry = map['expiry_date'] as String?;
    return VehicleDocument(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as String,
      type: DocumentType.fromName(map['type'] as String?),
      reference: (map['reference'] as String?) ?? '',
      expiryDate: expiry == null ? null : FleetDates.fromDbDay(expiry),
      note: (map['note'] as String?) ?? '',
    );
  }
}
