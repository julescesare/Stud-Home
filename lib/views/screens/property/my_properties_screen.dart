import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/property_controller.dart';
import '../../../models/property_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../property/add_property_screen.dart';
import '../property/property_detail_screen.dart';

/// Écran de suivi des annonces d'un propriétaire : consultation,
/// archivage (masquage réversible) et suppression définitive.
///
/// Contrairement à l'écran de recherche, celui-ci affiche l'intégralité
/// du catalogue du propriétaire, y compris les annonces archivées —
/// distinguées visuellement (opacité réduite + badge "Archivée").
class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  late Future<List<PropertyModel>> _propertiesFuture;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  void _loadProperties() {
    final uid = context.read<AuthController>().currentUser?.uid;
    final controller = context.read<PropertyController>();
    _propertiesFuture = uid == null
        ? Future.value([])
        : controller.fetchMyProperties(uid);
  }

  Future<void> _handleToggleArchive(PropertyModel property) async {
    final controller = context.read<PropertyController>();
    final success = await controller.setArchived(
      property.id,
      !property.isArchived,
    );

    if (!mounted) return;
    if (success) {
      setState(_loadProperties);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? "Erreur")),
      );
    }
  }

  Future<void> _handleDelete(PropertyModel property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Supprimer cette annonce ?"),
        content: Text(
          "« ${property.title} » sera définitivement supprimée. Cette action est irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              "Supprimer",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final controller = context.read<PropertyController>();
    final success = await controller.deleteProperty(property.id);

    if (!mounted) return;
    if (success) {
      setState(_loadProperties);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? "Erreur")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Mes annonces",
          style: AppTextStyles.button.copyWith(color: AppColors.gray800),
        ),
        iconTheme: const IconThemeData(color: AppColors.gray800),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddPropertyScreen()));
          // Au retour du formulaire de dépôt, on recharge la liste pour
          // que la nouvelle annonce apparaisse immédiatement.
          setState(_loadProperties);
        },
        backgroundColor: AppColors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Déposer", style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<PropertyModel>>(
        future: _propertiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.indigo),
            );
          }

          final properties = snapshot.data ?? [];

          if (properties.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 40,
                      color: AppColors.gray400,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Vous n'avez publié aucune annonce.",
                      style: TextStyle(color: AppColors.gray400),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: properties.length,
            itemBuilder: (context, index) => _MyPropertyTile(
              property: properties[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PropertyDetailScreen(property: properties[index]),
                ),
              ),
              onToggleArchive: () => _handleToggleArchive(properties[index]),
              onDelete: () => _handleDelete(properties[index]),
            ),
          );
        },
      ),
    );
  }
}

/// Ligne représentant une annonce dans la liste "Mes annonces", avec
/// ses actions de gestion (contrairement à `PropertyCard`, destinée au
/// fil de recherche étudiant — les besoins d'affichage diffèrent assez
/// pour justifier un widget dédié plutôt qu'une variante conditionnelle
/// de `PropertyCard`).
class _MyPropertyTile extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  const _MyPropertyTile({
    required this.property,
    required this.onTap,
    required this.onToggleArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: property.isArchived ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: property.imageUrls.isNotEmpty
                  ? Image.network(property.imageUrls.first, fit: BoxFit.cover)
                  : Container(color: AppColors.gray100),
            ),
          ),
          title: Text(
            property.title,
            style: AppTextStyles.bodyBold.copyWith(color: AppColors.gray800),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                property.formattedPrice,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.indigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (property.isArchived) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Archivée",
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gray600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.gray600),
            onSelected: (value) {
              if (value == 'archive') onToggleArchive();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(property.isArchived ? "Désarchiver" : "Archiver"),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  "Supprimer",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
