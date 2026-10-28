import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/user.dart';
import '../domain/user_failures.dart';
import '../services/user_service.dart';

/// Écran d'inscription en libre-service pour les CLIENTS et les AGENCES.
/// Les comptes administrateurs ne peuvent pas être créés depuis cet écran.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _service = UserService.instance;

  UserRole _selectedRole = UserRole.client;

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nomAgenceController = TextEditingController();
  final TextEditingController _adresseAgenceController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _globalError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nomAgenceController.dispose();
    _adresseAgenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _globalError = null;
      _fieldErrors = const {};
    });

    try {
      final user = await _service.register(
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        email: _emailController.text.trim(),
        motDePasse: _passwordController.text,
        confirmationMotDePasse: _confirmPasswordController.text,
        telephone: _telephoneController.text.trim(),
        role: _selectedRole,
        nomAgence: _selectedRole == UserRole.agence ? _nomAgenceController.text.trim() : null,
        adresseAgence: _selectedRole == UserRole.agence ? _adresseAgenceController.text.trim() : null,
      );

      if (!mounted) return;
      // Renvoie l'adresse email enregistrée à l'écran de Login pour pré-remplissage
      Navigator.of(context).pop(user.email);
    } on UserValidationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fieldErrors = e.errors;
      });
    } on UserConflictFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fieldErrors = {e.field: e.message};
      });
    } on UserFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _globalError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _globalError = 'Une erreur inattendue est survenue : $e';
      });
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String fieldKey,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    IconData? prefixIcon,
    String? hintText,
    String? helperText,
  }) {
    final error = _fieldErrors[fieldKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
              helperMaxLines: 2,
              errorText: error,
              errorMaxLines: 2,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: AppColors.cardSubtleBg,
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
    final isAgency = _selectedRole == UserRole.agence;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inscription'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.primaryNavy,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [AppColors.softShadow],
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Créer un compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rejoignez la plateforme Ekrili Karhba',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),

                  // Message d'erreur global
                  if (_globalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.redLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.redBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.redDark, size: 20),
                          const SizedBox(width: 10),
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

                  // Carte Formulaire
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: const [AppColors.softShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sélecteur de rôle (Client / Agence)
                        const Text(
                          'Vous êtes :',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment<UserRole>(
                              value: UserRole.client,
                              label: Text('Client'),
                              icon: Icon(Icons.person_outline, size: 18),
                            ),
                            ButtonSegment<UserRole>(
                              value: UserRole.agence,
                              label: Text('Agence'),
                              icon: Icon(Icons.store_outlined, size: 18),
                            ),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              _selectedRole = newSelection.first;
                              _fieldErrors = const {};
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.primaryNavy,
                            selectedForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Champs spécifiques à l'agence
                        if (isAgency) ...[
                          _buildField(
                            label: "Nom de l'agence *",
                            controller: _nomAgenceController,
                            fieldKey: 'nomAgence',
                            prefixIcon: Icons.business_outlined,
                            hintText: 'Ex: Carthage Rent a Car',
                          ),
                          _buildField(
                            label: "Adresse de l'agence *",
                            controller: _adresseAgenceController,
                            fieldKey: 'adresseAgence',
                            prefixIcon: Icons.location_on_outlined,
                            hintText: 'Ex: Avenue Habib Bourguiba, Tunis',
                          ),
                          const Divider(height: 24),
                        ],

                        // Champs Personne / Responsable
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                label: 'Prénom *',
                                controller: _prenomController,
                                fieldKey: 'prenom',
                                hintText: 'Mohamed',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildField(
                                label: 'Nom *',
                                controller: _nomController,
                                fieldKey: 'nom',
                                hintText: 'Trabelsi',
                              ),
                            ),
                          ],
                        ),

                        _buildField(
                          label: 'Adresse email *',
                          controller: _emailController,
                          fieldKey: 'email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          hintText: 'exemple@domaine.tn',
                        ),

                        _buildField(
                          label: 'Numéro de téléphone *',
                          controller: _telephoneController,
                          fieldKey: 'telephone',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          hintText: '20123456 ou 71123456',
                          helperText: '8 chiffres tunisiens (ex: 20123456)',
                        ),

                        _buildField(
                          label: 'Mot de passe *',
                          controller: _passwordController,
                          fieldKey: 'motDePasse',
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline,
                          hintText: 'Minimum 8 caractères',
                          helperText: 'Au moins 8 caractères, 1 majuscule, 1 minuscule, 1 chiffre',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),

                        _buildField(
                          label: 'Confirmation du mot de passe *',
                          controller: _confirmPasswordController,
                          fieldKey: 'confirmationMotDePasse',
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_reset_outlined,
                          hintText: 'Répétez votre mot de passe',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),

                        const SizedBox(height: 12),

                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "S'inscrire",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Lien retour vers Login
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Déjà un compte ?',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
