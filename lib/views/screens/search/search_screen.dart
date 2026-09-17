import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:stud_home/theme/app_colors.dart';
import 'package:stud_home/views/screens/profile/profile_screen.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/property_controller.dart';
import '../../../models/property_model.dart';
import '../property/add_property_screen.dart';
import '../property/property_detail_screen.dart';

const _kIndigo = AppColors.indigo;
const _kViolet = AppColors.violet;
const _kGray50 = AppColors.gray50;
const _kGray100 = AppColors.gray100;
const _kGray200 = AppColors.gray200;
const _kGray400 = AppColors.gray400;
const _kGray600 = AppColors.gray600;
const _kGray800 = AppColors.gray800;

/// Écran de recherche.
///
/// Au chargement, déclenche `fetchProperties()` avec des filtres vides.
/// Chaque interaction avec un filtre relance une requête via le Controller —
/// cet écran ne fait aucun calcul de filtrage lui-même.
///
/// Un bouton flottant "Déposer" n'apparaît que pour les utilisateurs
/// ayant le rôle "owner" (cf. UserModel.isOwner, Phase 1).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // État local des filtres actifs (UI uniquement). La valeur "budget max"
  // est arbitrairement fixée à 800€ pour ce prototype ; en une itération
  // future on pourra remplacer ce chip par un vrai sélecteur (slider/bottom sheet).
  bool _budgetActive = false;
  bool _furnishedActive = false;
  bool _housingAidActive = false;
  bool _publicGuaranteeActive = false;

  @override
  void initState() {
    super.initState();
    // On attend la fin du build pour accéder au Controller sans erreur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final propertyController = context.read<PropertyController>();
      propertyController.fetchProperties(const Filters());

      final uid = context.read<AuthController>().currentUser?.uid;
      if (uid != null) propertyController.loadFavorites(uid);
    });
  }

  void _applyFilters() {
    context.read<PropertyController>().fetchProperties(
      Filters(
        budgetMax: _budgetActive ? 800 : null,
        furnishedOnly: _furnishedActive,
        housingAidEligible: _housingAidActive,
        publicGuaranteeAccepted: _publicGuaranteeActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyController = context.watch<PropertyController>();
    final currentUser = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(currentUser?.fullName ?? ""),
            Expanded(
              child: Container(
                color: _kGray50,
                child: _buildBody(propertyController, currentUser?.uid),
              ),
            ),
          ],
        ),
      ),
      // Le dépôt d'annonce n'est proposé qu'aux propriétaires.
      floatingActionButton: currentUser?.isOwner == true
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
              ),
              backgroundColor: _kIndigo,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Déposer",
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bonjour${userName.isNotEmpty ? ', ${userName.split(' ').first}' : ''} 👋",
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kGray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    "Trouvez votre logement",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _kGray800,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                icon: const Icon(Icons.person_outline, color: _kGray600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _kGray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGray200, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 16, color: _kGray400),
                SizedBox(width: 8),
                Text(
                  "Ville, école ou campus…",
                  style: TextStyle(fontSize: 13, color: _kGray400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("Budget max", _budgetActive, () {
                  setState(() => _budgetActive = !_budgetActive);
                  _applyFilters();
                }),
                const SizedBox(width: 6),
                _filterChip("Meublé", _furnishedActive, () {
                  setState(() => _furnishedActive = !_furnishedActive);
                  _applyFilters();
                }),
                const SizedBox(width: 6),
                _filterChip("Éligible APL", _housingAidActive, () {
                  setState(() => _housingAidActive = !_housingAidActive);
                  _applyFilters();
                }),
                const SizedBox(width: 6),
                _filterChip("Garantie Visale", _publicGuaranteeActive, () {
                  setState(
                    () => _publicGuaranteeActive = !_publicGuaranteeActive,
                  );
                  _applyFilters();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _kIndigo : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kIndigo : _kGray200, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : _kGray600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(PropertyController controller, String? uid) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kIndigo));
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            controller.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kGray600),
          ),
        ),
      );
    }

    if (controller.properties.isEmpty) {
      // Illustration Lottie affichée quand aucun logement ne correspond
      // aux filtres actifs — remplace l'ancien texte seul.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/empty_state.json',
              width: 160,
              repeat: true,
            ),
            const SizedBox(height: 8),
            const Text(
              "Aucun logement ne correspond à vos critères.",
              style: TextStyle(color: _kGray400),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: [
        Text(
          "${controller.properties.length} logements trouvés".toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kGray400,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        // Apparition en cascade : chaque carte est décalée de 60ms par
        // rapport à la précédente (fade + léger slide vers le haut).
        ...controller.properties.asMap().entries.map((entry) {
          final index = entry.key;
          final property = entry.value;
          return _PropertyCard(
                property: property,
                clusterSize: controller.clusterSize(property),
                isFavorite: controller.isFavorite(property.id),
                onFavoriteTap: uid == null
                    ? null
                    : () => controller.toggleFavorite(uid, property.id),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PropertyDetailScreen(property: property),
                  ),
                ),
              )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: index * 60),
                duration: 300.ms,
              )
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
        }),
      ],
    );
  }
}

/// Carte d'annonce affichée dans la liste de résultats.
/// Widget purement présentationnel : toutes les données lui sont passées
/// en paramètres, aucune logique métier ni accès direct au Controller.
class _PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final int clusterSize;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback onTap;

  const _PropertyCard({
    required this.property,
    required this.clusterSize,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGray200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: property.imageUrls.isNotEmpty
                      ? Image.network(
                          property.imageUrls.first,
                          fit: BoxFit.cover,
                        )
                      : Container(color: _kGray100),
                ),
                if (clusterSize > 1)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kViolet,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Offre regroupée ($clusterSize agences)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child:
                        Container(
                              // Clé liée à l'état pour forcer flutter_animate à
                              // rejouer l'animation à chaque bascule favori/non-favori.
                              key: ValueKey(isFavorite),
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Colors.white70,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
                                color: isFavorite
                                    ? Colors.redAccent
                                    : _kGray400,
                              ),
                            )
                            // Petit "pop" : agrandissement puis retour à la taille
                            // normale, pour donner un feedback tactile satisfaisant.
                            .animate(target: isFavorite ? 1 : 0)
                            .scaleXY(
                              begin: 1,
                              end: 1.25,
                              duration: 150.ms,
                              curve: Curves.easeOut,
                            )
                            .then()
                            .scaleXY(begin: 1.25, end: 1, duration: 100.ms),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kGray800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: property.formattedPrice,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _kIndigo,
                              ),
                            ),
                            const TextSpan(
                              text: "/mois",
                              style: TextStyle(fontSize: 11, color: _kGray400),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _kGray100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${property.surfaceSqm.toStringAsFixed(0)} m²",
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kGray600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
