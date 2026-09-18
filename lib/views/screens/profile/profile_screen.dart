import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stud_home/views/screens/favorites/favorites_screen.dart';
import 'package:stud_home/views/screens/property/my_properties_screen.dart';

import '../../../controllers/auth_controller.dart';
import '../../../theme/app_colors.dart';

const _kIndigo = AppColors.indigo;
const _kIndigoLight = AppColors.indigoLight;
const _kGray200 = AppColors.gray200;
const _kGray400 = AppColors.gray400;
const _kGray600 = AppColors.gray600;
const _kGray800 = AppColors.gray800;

/// Écran de profil : affiche l'identité de l'utilisateur connecté et
/// propose la déconnexion.

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Se déconnecter ?"),
        content: const Text(
          "Vous devrez vous reconnecter pour accéder à votre compte.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              "Se déconnecter",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authController = context.read<AuthController>();
      await authController.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profil",
          style: TextStyle(
            color: _kGray800,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _kGray800),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kIndigoLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _kIndigo,
                  child: Text(
                    (user?.fullName.isNotEmpty == true
                            ? user!.fullName[0]
                            : "?")
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? "",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kGray800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? "",
                  style: const TextStyle(fontSize: 12, color: _kGray600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.isOwner == true
                        ? "🏠 Propriétaire"
                        : "🎓 Étudiant(e)",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kIndigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (user?.isStudent == true)
            _menuTile(
              icon: Icons.favorite_border,
              label: "Mes favoris",
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              ),
            ),
          if (user?.isOwner == true)
            _menuTile(
              icon: Icons.home_work_outlined,
              label: "Mes annonces",
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyPropertiesScreen()),
              ),
            ),
          _menuTile(
            icon: Icons.settings_outlined,
            label: "Paramètres",
            onTap: () {},
          ),
          _menuTile(
            icon: Icons.help_outline,
            label: "Aide & support",
            onTap: () {},
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
            label: const Text(
              "Se déconnecter",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: _kGray600, size: 20),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: _kGray800),
      ),
      trailing: const Icon(Icons.chevron_right, color: _kGray400, size: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _kGray200),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minLeadingWidth: 0,
    );
  }
}
