import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/user_failures.dart';
import '../services/user_service.dart';
import 'admin_users_screen.dart';

/// Écran « Mon Profil » réutilisable pour les 3 rôles (ADMIN, AGENCE, CLIENT).
/// Permet la consultation et la mise à jour des coordonnées personnelles et du mot de passe.
/// L'email, le rôle et le statut sont en lecture seule.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = UserService.instance;

  late final TextEditingController _nom;
  late final TextEditingController _prenom;
  late final TextEditingController _telephone;
  late final TextEditingController _nomAgence;
  late final TextEditingController _adresseAgence;

  late final TextEditingController _oldPassword;
  late final TextEditingController _newPassword;

  bool _saving = false;
  final Map<String, String> _serverErrors = {};
  String? _globalError;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final u = _service.currentUser;
    _nom = TextEditingController(text: u?.nom ?? '');
    _prenom = TextEditingController(text: u?.prenom ?? '');
    _telephone = TextEditingController(text: u?.telephone ?? '');
    _nomAgence = TextEditingController(text: u?.nomAgence ?? '');
    _adresseAgence = TextEditingController(text: u?.adresseAgence ?? '');

    _oldPassword = TextEditingController();
    _newPassword = TextEditingController();

    _service.addListener(_syncUser);
    _init();
  }

  Future<void> _init() async {
    if (_service.currentUser == null) {
      await _service.ensureInitialized();
      _syncUser();
      if (mounted) setState(() {});
    }
  }

  void _syncUser() {
    final u = _service.currentUser;
    if (u != null && mounted) {
      if (_nom.text != u.nom) _nom.text = u.nom;
      if (_prenom.text != u.prenom) _prenom.text = u.prenom;
      if (_telephone.text != u.telephone) _telephone.text = u.telephone;
      if (u.nomAgence != null && _nomAgence.text != u.nomAgence) {
        _nomAgence.text = u.nomAgence!;
      }
      if (u.adresseAgence != null && _adresseAgence.text != u.adresseAgence) {
        _adresseAgence.text = u.adresseAgence!;
      }
    }
  }

  @override
  void dispose() {
    _service.removeListener(_syncUser);
    _nom.dispose();
    _prenom.dispose();
    _telephone.dispose();
    _nomAgence.dispose();
    _adresseAgence.dispose();
    _oldPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentUser = _service.currentUser;
    if (currentUser == null) return;

    setState(() {
      _saving = true;
      _serverErrors.clear();
      _globalError = null;
      _successMessage = null;
    });

    try {
      await _service.updateOwnProfile(
        id: currentUser.id!,
        nom: _nom.text,
        prenom: _prenom.text,
        telephone: _telephone.text,
        nomAgence: currentUser.isAgence ? _nomAgence.text : null,
        adresseAgence: currentUser.isAgence ? _adresseAgence.text : null,
        oldPassword: _oldPassword.text.isEmpty ? null : _oldPassword.text,
        newPassword: _newPassword.text.isEmpty ? null : _newPassword.text,
        actor: currentUser,
      );

      _oldPassword.clear();
      _newPassword.clear();

      setState(() {
        _saving = false;
        _successMessage = 'Votre profil a été mis à jour avec succès.';
      });
    } on UserValidationFailure catch (e) {
      setState(() {
        _saving = false;
        _serverErrors.addAll(e.errors);
      });
    } on UserFailure catch (e) {
      setState(() {
        _saving = false;
        _globalError = e.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _globalError = 'Une erreur inattendue est survenue: $e';
      });
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String fieldKey,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? helperText,
    String? hintText,
  }) {
    final error = _serverErrors[fieldKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hintText,
              helperText: helperText,
              errorText: error,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _service.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Aucune session active')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entête profil
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                      child: Text(
                        user.prenom.isNotEmpty ? user.prenom[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.role.label} • Statut ${user.statut.label}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (user.isAdmin) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminUsersScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Panneau Gestion des utilisateurs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                    side: const BorderSide(color: AppColors.primaryNavy),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.greenDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: AppColors.greenDark, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_globalError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.redBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.redDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _globalError!,
                          style: const TextStyle(color: AppColors.redDark, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Informations non modifiables
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorderSubtle),
                ),
                child: Column(
                  children: [
                    _ReadOnlyRow(
                      label: 'Adresse email',
                      value: user.email,
                      icon: Icons.email_outlined,
                    ),
                    const Divider(height: 18),
                    _ReadOnlyRow(
                      label: 'Rôle attribué',
                      value: user.role.label,
                      icon: Icons.shield_outlined,
                    ),
                  ],
                ),
              ),

              const Text(
                'Coordonnées personnelles',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),

              _buildField(
                label: 'Prénom',
                controller: _prenom,
                fieldKey: 'prenom',
              ),
              _buildField(
                label: 'Nom',
                controller: _nom,
                fieldKey: 'nom',
              ),
              _buildField(
                label: 'Téléphone',
                controller: _telephone,
                fieldKey: 'telephone',
                keyboardType: TextInputType.phone,
              ),

              if (user.isAgence) ...[
                const SizedBox(height: 10),
                const Text(
                  "Coordonnées de l'agence",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: "Nom de l'agence",
                  controller: _nomAgence,
                  fieldKey: 'nomAgence',
                ),
                _buildField(
                  label: "Adresse de l'agence",
                  controller: _adresseAgence,
                  fieldKey: 'adresseAgence',
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              const Text(
                'Changer le mot de passe (optionnel)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),

              _buildField(
                label: 'Ancien mot de passe',
                controller: _oldPassword,
                fieldKey: 'oldPassword',
                obscureText: true,
                hintText: 'Requis uniquement pour changer de mot de passe',
              ),
              _buildField(
                label: 'Nouveau mot de passe',
                controller: _newPassword,
                fieldKey: 'newPassword',
                obscureText: true,
                helperText: 'Au moins 8 caractères, 1 majuscule, 1 minuscule, 1 chiffre',
              ),

              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enregistrer les modifications',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
      ],
    );
  }
}
