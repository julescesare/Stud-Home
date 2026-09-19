import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:stud_home/models/property_model.dart';
import 'package:stud_home/theme/app_colors.dart';
import 'package:stud_home/theme/app_text_styles.dart';
import 'package:stud_home/views/screens/profile/profile_screen.dart';
import 'package:stud_home/views/widgets/property_card.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/property_controller.dart';
import '../property/add_property_screen.dart';
import '../property/property_detail_screen.dart';

const _kIndigo = AppColors.indigo;
const _kGray50 = AppColors.gray50;
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
  // est arbitrairement fixée à 1200€ pour ce prototype ; en une itération
  // future on pourra remplacer ce chip par un vrai sélecteur (slider/bottom sheet).
  bool _budgetActive = false;
  bool _furnishedActive = false;
  bool _housingAidActive = false;
  bool _publicGuaranteeActive = false;
  final _searchController = TextEditingController();
  String _searchQuery = "";

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _applyFilters() {
    return context.read<PropertyController>().fetchProperties(
      Filters(
        budgetMax: _budgetActive ? 1200 : null,
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
                    style: AppTextStyles.caption.copyWith(color: _kGray400),
                  ),
                  Text(
                    "Trouvez votre logement",
                    style: AppTextStyles.title.copyWith(color: _kGray800),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: _kGray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGray200, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: _kGray400),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    // Recherche appliquée côté client, sur la liste déjà
                    // récupérée — pas de nouvelle requête Firestore à
                    // chaque frappe (Firestore ne fait pas de recherche
                    // plein texte nativement).
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: "Ville, école ou campus…",
                      hintStyle: AppTextStyles.body.copyWith(color: _kGray400),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    },
                    child: const Icon(Icons.close, size: 20, color: _kGray400),
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
          style: AppTextStyles.caption.copyWith(
            color: active ? Colors.white : _kGray600,
          ),
        ),
      ),
    );
  }

  List<PropertyModel> _visibleProperties(PropertyController controller) {
    final grouped = controller.displayProperties;
    if (_searchQuery.trim().isEmpty) return grouped;

    final query = _searchQuery.trim().toLowerCase();
    return grouped
        .where(
          (p) =>
              p.city.toLowerCase().contains(query) ||
              p.title.toLowerCase().contains(query) ||
              p.priceAmount.toString().contains(query),
        )
        .toList();
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

    final visibleProperties = _visibleProperties(controller);

    // `AlwaysScrollableScrollPhysics` est nécessaire même quand le contenu
    // ne remplit pas l'écran (ex: état vide) : sans ça, le geste de
    // tirer-pour-actualiser ne serait pas détecté.
    if (visibleProperties.isEmpty) {
      return RefreshIndicator(
        color: _kIndigo,
        onRefresh: _applyFilters,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
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
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kIndigo,
      onRefresh: _applyFilters,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        children: [
          Text(
            "${visibleProperties.length} logements trouvés".toUpperCase(),
            style: AppTextStyles.label.copyWith(
              color: _kGray400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...visibleProperties.asMap().entries.map((entry) {
            final index = entry.key;
            final property = entry.value;
            return PropertyCard(
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
      ),
    );
  }
}
