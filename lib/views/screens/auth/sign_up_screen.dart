import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stud_home/theme/app_colors.dart';

import '../../../controllers/auth_controller.dart';

const _kIndigo = AppColors.indigo;
const _kViolet = AppColors.violet;
const _kGray400 = AppColors.gray400;
const _kGray200 = AppColors.gray200;
const _kGray100 = AppColors.gray100;
const _kGray800 = AppColors.gray800;
const _kIndigoLight = AppColors.indigoLight;

/// Écran d'inscription en 2 étapes .
///
/// Étape 1 "Identité" : rôle (étudiant/propriétaire), prénom, nom, e-mail.
/// Étape 2 "Sécurité" : mot de passe, confirmation, CGU.
///
/// La création réelle du compte (Firebase Auth + Firestore) n'est
/// déclenchée qu'à la validation finale de l'étape 2, via
/// `AuthController.signUp()`.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _step = 1;
  String _role = "student"; // "student" ou "owner", cohérent avec UserModel

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToStep2() {
    if (_step1FormKey.currentState!.validate()) {
      setState(() => _step = 2);
    }
  }

  Future<void> _handleCreateAccount(AuthController auth) async {
    if (!_step2FormKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Merci d'accepter les conditions d'utilisation"),
        ),
      );
      return;
    }

    final fullName =
        "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

    final success = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: fullName,
      role: _role,
    );

    if (!mounted) return;

    if (success) {
      // Confirmation visuelle avant de rediriger. La modale se ferme
      // toute seule après un court délai — pas besoin d'action de
      // l'utilisateur.
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final navigator = Navigator.of(dialogContext);
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (navigator.mounted && navigator.canPop()) {
              navigator.pop();
            }
          });
          return const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Expanded(child: Text("Compte créé avec succès !")),
              ],
            ),
          );
        },
      );

      // On vide la pile jusqu'à AuthGate : LoginScreen et SignUpScreen
      // sont empilés par-dessus lui, donc sans ce popUntil, AuthGate
      // basculerait bien vers SearchScreen en interne, mais resterait
      // invisible, caché sous ces deux écrans encore affichés.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? "Erreur lors de l'inscription"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTopBand(),
              Transform.translate(
                offset: const Offset(0, -18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildCard(auth),
                      const SizedBox(height: 14),
                      _buildNavButtons(auth),
                      const SizedBox(height: 14),
                      _buildLoginLink(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bandeau du haut avec logo + indicateur d'étapes ---

  Widget _buildTopBand() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kIndigo, _kViolet],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Stud'Home",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Créer un compte",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          _buildStepIndicator(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    Widget dot(int s) {
      final active = _step >= s;
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.25),
        ),
        alignment: Alignment.center,
        child: Text(
          _step > s ? "✓" : "$s",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? _kIndigo : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            dot(1),
            Container(
              width: 32,
              height: 2,
              color: _step > 1
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
            ),
            dot(2),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                "Identité",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                "Sécurité",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Carte principale (contenu qui change selon l'étape) ---

  Widget _buildCard(AuthController auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kIndigo.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _step == 1 ? _buildStep1() : _buildStep2(auth),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionLabel("Je suis…"),
          const SizedBox(height: 8),
          _buildRoleSelector(),
          const SizedBox(height: 16),
          const Text(
            "Vos informations",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kGray800,
            ),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            label: "Prénom",
            controller: _firstNameController,
            placeholder: _role == "student" ? "Lucas" : "Marie",
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Le prénom est requis" : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: "Nom",
            controller: _lastNameController,
            placeholder: _role == "student" ? "Martin" : "Dupont",
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Le nom est requis" : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: "Adresse e-mail",
            controller: _emailController,
            placeholder: _role == "student"
                ? "lucas.martin@univ-paris.fr"
                : "marie.dupont@gmail.com",
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "L'e-mail est requis";
              if (!v.contains('@')) return "E-mail invalide";
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(AuthController auth) {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Sécurité & finalisation",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kGray800,
            ),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            label: "Mot de passe",
            controller: _passwordController,
            placeholder: "••••••••••",
            obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) return "Le mot de passe est requis";
              if (v.length < 6) return "6 caractères minimum";
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: "Confirmer le mot de passe",
            controller: _confirmPasswordController,
            placeholder: "••••••••••",
            obscureText: true,
            validator: (v) {
              if (v != _passwordController.text) {
                return "Les mots de passe ne correspondent pas";
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (_role == "student")
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _kIndigoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: _kIndigo),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Votre adresse universitaire sera vérifiée pour accéder aux offres réservées aux étudiants.",
                      style: TextStyle(
                        fontSize: 11,
                        color: _kIndigo,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                activeColor: _kIndigo,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4B5563),
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: "J'accepte les "),
                        TextSpan(
                          text: "conditions d'utilisation",
                          style: TextStyle(
                            color: _kIndigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: " et la "),
                        TextSpan(
                          text: "politique de confidentialité",
                          style: TextStyle(
                            color: _kIndigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: _kGray400,
      letterSpacing: 0.5,
    ),
  );

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _kGray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _roleButton("student", "🎓 Étudiant(e)"),
          _roleButton("owner", "🏠 Propriétaire"),
        ],
      ),
    );
  }

  Widget _roleButton(String value, String label) {
    final selected = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? _kIndigo : _kGray400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: _kGray400, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _kGray200, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _kGray200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _kIndigo, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // --- Boutons de navigation entre étapes ---

  Widget _buildNavButtons(AuthController auth) {
    return Row(
      children: [
        if (_step == 2)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kIndigo,
                side: const BorderSide(color: _kIndigo, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                "← Retour",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (_step == 2) const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: auth.isLoading
                ? null
                : () => _step == 1 ? _goToStep2() : _handleCreateAccount(auth),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kIndigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _step == 1 ? "Continuer →" : "Créer mon compte",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: const Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 11, color: _kGray400),
          children: [
            TextSpan(text: "Déjà un compte ? "),
            TextSpan(
              text: "Se connecter",
              style: TextStyle(color: _kIndigo, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
