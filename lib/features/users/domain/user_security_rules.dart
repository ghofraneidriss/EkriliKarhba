import 'user.dart';
import 'user_failures.dart';

/// Règles de sécurité et d'intégrité métier pour les opérations utilisateurs.
/// Ce fichier est en Dart pur (aucun import Flutter).
class UserSecurityRules {
  UserSecurityRules._();

  /// Vérifie qu'un acteur a le droit d'effectuer une action d'administration.
  static void ensureAdmin(User actor) {
    if (!actor.isAdmin) {
      throw const UserPermissionFailure(
          'Cette action est strictement réservée aux administrateurs.');
    }
  }

  /// Vérifie si le changement de statut est autorisé :
  /// - Un admin ne peut pas se bannir ni se désactiver lui-même.
  /// - On ne peut pas désactiver ou bannir le dernier administrateur actif.
  static void ensureCanChangeStatus({
    required User actor,
    required User target,
    required UserStatus newStatus,
    required int activeAdminCount,
  }) {
    ensureAdmin(actor);

    // L'acteur ne peut pas modifier son propre statut vers inactif/banni
    if (actor.id != null && actor.id == target.id && newStatus != UserStatus.actif) {
      throw const UserRuleFailure(
          'Vous ne pouvez pas désactiver ou bannir votre propre compte administrateur.');
    }

    // Protection du dernier admin actif
    if (target.isAdmin && target.isActif && newStatus != UserStatus.actif) {
      if (activeAdminCount <= 1) {
        throw const UserRuleFailure(
            'Impossible de désactiver ou bannir le dernier administrateur actif du système.');
      }
    }
  }

  /// Vérifie si la suppression est autorisée :
  /// - Un admin ne peut pas se supprimer lui-même.
  /// - On ne peut pas supprimer le dernier administrateur actif.
  /// - On ne peut pas supprimer une agence possédant des véhicules (proposer de la désactiver/bannir).
  static void ensureCanDelete({
    required User actor,
    required User target,
    required int activeAdminCount,
    required int vehicleCount,
  }) {
    ensureAdmin(actor);

    if (actor.id != null && actor.id == target.id) {
      throw const UserRuleFailure(
          'Vous ne pouvez pas supprimer votre propre compte administrateur.');
    }

    if (target.isAdmin && target.isActif) {
      if (activeAdminCount <= 1) {
        throw const UserRuleFailure(
            'Impossible de supprimer le dernier administrateur actif du système.');
      }
    }

    if (target.isAgence && vehicleCount > 0) {
      throw UserRuleFailure(
          "Impossible de supprimer l'agence « ${target.displayName} » car elle possède encore "
          "$vehicleCount véhicule(s). Vous pouvez désactiver ou bannir ce compte, ou transférer ses véhicules.");
    }
  }
}

