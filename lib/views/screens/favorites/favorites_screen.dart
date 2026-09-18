import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/property_controller.dart';
import '../../../models/property_model.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/property_card.dart';
import '../property/property_detail_screen.dart';

/// Écran listant les annonces que l'étudiant a mises en favori.
///
/// Réutilise `PropertyCard`, le même widget que l'écran de recherche —
/// aucune divergence visuelle entre "voir toutes les annonces" et
/// "voir mes favoris", seule la source des données change.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<PropertyModel>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    final uid = context.read<AuthController>().currentUser?.uid;
    final controller = context.read<PropertyController>();
    _favoritesFuture = uid == null
        ? Future.value([])
        : controller.fetchFavoriteProperties(uid);
  }

  @override
  Widget build(BuildContext context) {
    final propertyController = context.watch<PropertyController>();
    final uid = context.watch<AuthController>().currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Mes favoris",
          style: TextStyle(
            color: AppColors.gray800,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.gray800),
      ),
      body: FutureBuilder<List<PropertyModel>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.indigo),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Impossible de charger vos favoris.",
                  style: const TextStyle(color: AppColors.gray600),
                ),
              ),
            );
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 40,
                      color: AppColors.gray400,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Aucune annonce en favori pour l'instant.",
                      style: TextStyle(color: AppColors.gray400),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: favorites.map((property) {
              return PropertyCard(
                property: property,
                clusterSize: propertyController.clusterSize(property),
                isFavorite: true, // on est forcément sur cet écran parce que c'est un favori
                onFavoriteTap: uid == null
                    ? null
                    : () async {
                        await propertyController.toggleFavorite(
                          uid,
                          property.id,
                        );
                        // On retire immédiatement la carte de la liste affichée,
                        // sans attendre une nouvelle requête Firestore complète.
                        setState(() {
                          _favoritesFuture = Future.value(
                            favorites
                                .where((p) => p.id != property.id)
                                .toList(),
                          );
                        });
                      },
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PropertyDetailScreen(property: property),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
