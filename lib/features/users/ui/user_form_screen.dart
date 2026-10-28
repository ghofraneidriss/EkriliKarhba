import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/user.dart';
import '../domain/user_failures.dart';
import '../services/user_service.dart';

/// Écran d'ajout ou modification d'un utilisateur par l'administrateur.
/// Les champs s'adaptent dynamiquement au rôle sélectionné :
/// - AGENCE : Nom de l'agence et Adresse obligatoires
/// - ADMIN : Niveau d'accès optionnel
/// - CLIENT : Champs de base uniquement
/// Les erreurs renvoyées par le service sont affichées sous chaque champ concerné.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user});

  final User? user;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _service = UserService.instance;

  late final TextEditingController _nom;
  late final TextEditingController _prenom;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _telephone;
  late final TextEditingController _nomAgence;
  late final TextEditingController _adresseAgence;
  late final TextEditingController _niveauAcces;

  late UserRole _role;
  late UserStatus _statut;

  bool _saving = false;
  final Map<String, String> _serverErrors = {};
  String? _globalError;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nom = TextEditingController(text: u?.nom ?? '');
    _prenom = TextEditingController(text: u?.prenom ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _password = TextEditingController();
    _telephone = TextEditingController(text: u?.telephone ?? '');
    _nomAgence = TextEditingController(text: u?.nomAgence ?? '');
    _adresseAgence = TextEditingController(text: u?.adresseAgence ?? '');
    _niveauAcces = TextEditingController(text: u?.niveauAcces ?? '');

    _role = u?.role ?? UserRole.client;
    _statut = u?.statut ?? UserStatus.actif;
  }

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _email.dispose();
    _password.dispose();
    _telephone.dispose();
    _nomAgence.dispose();
    _adresseAgence.dispose();
    _niveauAcces.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _serverErrors.clear();
      _globalError = null;
    });

    final currentAdmin = _service.currentUser;
    if (currentAdmin == null) {
      setState(() => _globalError = 'Session expirée. Veuillez vous reconnecter.');
      return;
    }

    setState(() => _saving = true);

    try {
      if (isEditing) {
        await _service.updateUser(
          id: widget.user!.id!,
          nom: _nom.text,
          prenom: _prenom.text,
          email: _email.text,
          motDePasse: _password.text.isEmpty ? null : _password.text,
          telephone: _telephone.text,
          role: _role,
          statut: _statut,
          nomAgence: _role == UserRole.agence ? _nomAgence.text : null,
          adresseAgence: _role == UserRole.agence ? _adresseAgence.text : null,
          niveauAcces: _role == UserRole.admin ? _niveauAcces.text : null,
          actor: currentAdmin,
        );
      } else {
        await _service.createUser(
          nom: _nom.text,
          prenom: _prenom.text,
          email: _email.text,
          motDePasse: _password.text,
          telephone: _telephone.text,
          role: _role,
          statut: _statut,
          nomAgence: _role == UserRole.agence ? _nomAgence.text : null,
          adresseAgence: _role == UserRole.agence ? _adresseAgence.text : null,
          niveauAcces: _role == UserRole.admin ? _niveauAcces.text : null,
          actor: currentAdmin,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on UserValidationFailure catch (e) {
      setState(() {
        _saving = false;
        _serverErrors.addAll(e.errors);
      });
    } on UserConflictFailure catch (e) {
      setState(() {
        _saving = false;
        _serverErrors[e.field] = e.message;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? "Modifier l'utilisateur" : 'Nouvel utilisateur'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                // Choix du rôle
                const Text(
                  'Rôle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole>(
                      value: _role,
                      isExpanded: true,
                      onChanged: (r) {
                        if (r != null) setState(() => _role = r);
                      },
                      items: UserRole.values.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Statut
                const Text(
                  'Statut',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserStatus>(
                      value: _statut,
                      isExpanded: true,
                      onChanged: (s) {
                        if (s != null) setState(() => _statut = s);
                      },
                      items: UserStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Divider(),
                const SizedBox(height: 12),

                // Champs communs
                _buildField(
                  label: 'Prénom',
                  controller: _prenom,
                  fieldKey: 'prenom',
                  hintText: 'Ex: Karim',
                ),
                _buildField(
                  label: 'Nom',
                  controller: _nom,
                  fieldKey: 'nom',
                  hintText: 'Ex: Gharbi',
                ),
                _buildField(
                  label: 'Email',
                  controller: _email,
                  fieldKey: 'email',
                  keyboardType: TextInputType.emailAddress,
                  hintText: 'exemple@domaine.tn',
                ),
                _buildField(
                  label: isEditing ? 'Nouveau mot de passe (optionnel)' : 'Mot de passe',
                  controller: _password,
                  fieldKey: 'motDePasse',
                  obscureText: true,
                  helperText: 'Au moins 8 caractères, 1 majuscule, 1 minuscule et 1 chiffre',
                ),
                _buildField(
                  label: 'Téléphone',
                  controller: _telephone,
                  fieldKey: 'telephone',
                  keyboardType: TextInputType.phone,
                  hintText: 'Ex: 98123456 ou +216 98 123 456',
                ),

                // Champs spécifiques AGENCE
                if (_role == UserRole.agence) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Informations de l'agence",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  _buildField(
                    label: "Nom de l'agence",
                    controller: _nomAgence,
                    fieldKey: 'nomAgence',
                    hintText: 'Ex: Sahel Rent Car',
                  ),
                  _buildField(
                    label: "Adresse de l'agence",
                    controller: _adresseAgence,
                    fieldKey: 'adresseAgence',
                    hintText: 'Ex: Avenue Hédi Chaker, Sousse',
                  ),
                ],

                // Champs spécifiques ADMIN
                if (_role == UserRole.admin) ...[
                  const Divider(),
                  _buildField(
                    label: "Niveau d'accès (optionnel)",
                    controller: _niveauAcces,
                    fieldKey: 'niveauAcces',
                    hintText: 'Ex: Super Admin, Support...',
                  ),
                ],

                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Enregistrer les modifications' : 'Créer le compte',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

