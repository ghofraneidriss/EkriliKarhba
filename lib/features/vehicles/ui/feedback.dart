import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/fleet_exceptions.dart';

/// Message en français pour une erreur du module.
String fleetErrorMessage(Object error) {
  if (error is FleetRuleException) return error.message;
  if (error is FleetValidationException) return error.message;
  if (error is FleetPermissionException) return error.message;
  if (error is FleetNotFoundException) return error.message;
  return 'Une erreur est survenue : $error';
}

/// Petit message en bas de l'écran.
void showFleetSnack(
  ScaffoldMessengerState messenger,
  String message, {
  bool error = false,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.redDark : AppColors.primaryNavy,
      ),
    );
}

/// Boîte de confirmation ; renvoie true si l'utilisateur confirme.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.red)
              : FilledButton.styleFrom(backgroundColor: AppColors.primaryNavy),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Demande un texte (motif, commentaire). Renvoie null si annulé.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
  bool mandatory = false,
  String confirmLabel = 'Valider',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      hint: hint,
      mandatory: mandatory,
      confirmLabel: confirmLabel,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.mandatory,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final bool mandatory;
  final String confirmLabel;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (widget.mandatory && text.isEmpty) {
      setState(() => _error = 'Champ obligatoire');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(hintText: widget.hint, errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryNavy),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
