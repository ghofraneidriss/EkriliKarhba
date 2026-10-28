import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Cycle de vie d'un véhicule.
///
/// Les changements autorisés sont définis dans [allowedNext] :
/// Disponible → Réservé → Loué → Contrôle retour → Disponible,
/// avec les branches Maintenance, Hors service et Archivé.
enum VehicleStatus {
  disponible('Disponible', AppColors.green, AppColors.greenLight),
  reserve('Réservé', AppColors.primaryBlue, AppColors.blueLight),
  loue('Loué', AppColors.orange, AppColors.orangeLight),
  controleRetour('Contrôle retour', AppColors.cyanIcon, AppColors.cyanLight),
  maintenance('Maintenance', AppColors.orangeDark, AppColors.orangePillBg),
  horsService('Hors service', AppColors.redDark, AppColors.redLight),
  archive('Archivé', AppColors.textMuted, AppColors.sectionBg);

  const VehicleStatus(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;

  /// Statuts vers lesquels on peut passer depuis ce statut.
  Set<VehicleStatus> get allowedNext => switch (this) {
        VehicleStatus.disponible => {
            VehicleStatus.reserve,
            VehicleStatus.maintenance,
            VehicleStatus.horsService,
            VehicleStatus.archive,
          },
        VehicleStatus.reserve => {
            VehicleStatus.loue,
            VehicleStatus.disponible,
          },
        VehicleStatus.loue => {VehicleStatus.controleRetour},
        VehicleStatus.controleRetour => {
            VehicleStatus.disponible,
            VehicleStatus.maintenance,
          },
        VehicleStatus.maintenance => {
            VehicleStatus.disponible,
            VehicleStatus.horsService,
          },
        VehicleStatus.horsService => {
            VehicleStatus.maintenance,
            VehicleStatus.disponible,
            VehicleStatus.archive,
          },
        VehicleStatus.archive => {VehicleStatus.disponible},
      };

  bool canMoveTo(VehicleStatus next) => allowedNext.contains(next);

  /// Statuts posés uniquement par le module Réservations.
  static const Set<VehicleStatus> occupiedStatuses = {
    reserve,
    loue,
    controleRetour,
  };

  /// Véhicule occupé par une réservation ou une location en cours.
  /// Dans la gestion des véhicules, on affiche seulement « Occupé » :
  /// le détail (réservé, loué, retour) appartient au module Réservations.
  bool get isOccupied => occupiedStatuses.contains(this);

  /// Libellé côté gestion : « Occupé » ou le statut lui-même.
  String get fleetLabel => isOccupied ? 'Occupé' : label;

  /// Couleurs côté gestion : une seule couleur pour « Occupé ».
  Color get fleetColor => isOccupied ? AppColors.primaryBlue : color;
  Color get fleetBackground => isOccupied ? AppColors.blueLight : background;

  /// Un véhicule occupé est engagé auprès d'un client :
  /// il ne peut être ni supprimé, ni transféré.
  bool get isEngaged => isOccupied;

  static VehicleStatus fromName(String? name) => VehicleStatus.values
      .firstWhere((s) => s.name == name, orElse: () => disponible);
}

/// Validation par l'administrateur d'un véhicule ajouté par une agence.
enum ValidationStatus {
  enAttente('En attente de validation', AppColors.orange),
  valide('Validé', AppColors.green),
  refuse('Refusé', AppColors.red);

  const ValidationStatus(this.label, this.color);

  final String label;
  final Color color;

  static ValidationStatus fromName(String? name) => ValidationStatus.values
      .firstWhere((s) => s.name == name, orElse: () => enAttente);
}

enum FuelType {
  essence('Essence'),
  diesel('Diesel'),
  hybride('Hybride'),
  electrique('Électrique');

  const FuelType(this.label);
  final String label;

  static FuelType fromName(String? name) =>
      FuelType.values.firstWhere((f) => f.name == name, orElse: () => essence);
}

enum Transmission {
  manuelle('Manuelle', 'Manuelle'),
  automatique('Automatique', 'Auto.');

  const Transmission(this.label, this.shortLabel);
  final String label;
  final String shortLabel;

  static Transmission fromName(String? name) => Transmission.values
      .firstWhere((t) => t.name == name, orElse: () => manuelle);
}

/// Documents administratifs d'un véhicule.
enum DocumentType {
  assurance('Assurance', true),
  visiteTechnique('Visite technique', true),
  vignette('Vignette', false),
  carteGrise('Carte grise', false);

  const DocumentType(this.label, this.blocksRentalWhenExpired);

  final String label;

  /// Si ce document est expiré, le véhicule ne peut pas être loué
  /// et passe automatiquement « Hors service ».
  final bool blocksRentalWhenExpired;

  static DocumentType fromName(String? name) => DocumentType.values
      .firstWhere((d) => d.name == name, orElse: () => assurance);
}

/// Nature d'une ligne de l'historique d'un véhicule.
enum HistoryAction {
  creation('Création'),
  modification('Modification'),
  statut('Changement de statut'),
  prix('Changement de prix'),
  kilometrage('Kilométrage'),
  transfert('Transfert d\'agence'),
  validation('Validation'),
  document('Document'),
  indisponibilite('Indisponibilité'),
  suppression('Suppression');

  const HistoryAction(this.label);
  final String label;

  static HistoryAction fromName(String? name) => HistoryAction.values
      .firstWhere((a) => a.name == name, orElse: () => modification);
}

/// Tri disponible dans la recherche.
enum VehicleSort {
  plusRecents('Plus récents'),
  prixCroissant('Prix croissant'),
  prixDecroissant('Prix décroissant'),
  kilometrage('Kilométrage'),
  marqueAZ('Marque A → Z');

  const VehicleSort(this.label);
  final String label;
}
