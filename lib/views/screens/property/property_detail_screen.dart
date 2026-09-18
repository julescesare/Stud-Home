import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stud_home/models/user_model.dart';
import 'package:stud_home/theme/app_colors.dart';
import 'package:stud_home/views/widgets/photo_carousel.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/property_controller.dart';
import '../../../models/property_model.dart';

const _kIndigo = AppColors.indigo;
const _kIndigoLight = AppColors.indigoLight;
const _kViolet = AppColors.violet;
const _kGray100 = AppColors.gray100;
const _kGray200 = AppColors.gray200;
const _kGray400 = AppColors.gray400;
const _kGray600 = AppColors.gray600;
const _kGray800 = AppColors.gray800;
const _kGreen = AppColors.green;
const _kOrange = AppColors.orange;

/// Fiche détaillée d'un logement.
///
/// Reçoit le [PropertyModel] déjà chargé depuis l'écran de recherche —
/// pas de nouvel appel Firestore ici, on affiche simplement ce qu'on a.
class PropertyDetailScreen extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  @override
  Widget build(BuildContext context) {
    final propertyController = context.watch<PropertyController>();
    final uid = context.watch<AuthController>().currentUser?.uid;
    final isFavorite = propertyController.isFavorite(property.id);

    return Scaffold(
      backgroundColor: Colors.white,
      // `top: true` réserve une bande de fond derrière la barre de statut,
      // au lieu de laisser la photo passer dessous. `bottom: false` car
      // le bouton CTA fixe gère déjà son propre padding en bas de l'écran.
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhotoCarousel(
                    imageUrls: property.imageUrls,
                    isFavorite: isFavorite,
                    onBack: () => Navigator.of(context).pop(),
                    onFavoriteTap: uid == null
                        ? null
                        : () => context
                              .read<PropertyController>()
                              .toggleFavorite(uid, property.id),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _kGray800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "📍 ${property.streetAddress}, ${property.city}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kGray400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPricingBlock(),
                        const SizedBox(height: 14),
                        _buildBadges(),
                        const SizedBox(height: 14),
                        Text(
                          property.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kGray600,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          property.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kGray600,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (property.isPartOfCluster) ...[
                          _buildClusterOffers(context),
                          const SizedBox(height: 14),
                        ],
                        _buildMapPlaceholder(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomCTA(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingBlock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kIndigoLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _pricingColumn(
            "Loyer mensuel",
            property.formattedPrice,
            property.chargesIncluded ? "charges incluses" : "hors charges",
            _kIndigo,
          ),
          Container(width: 1, height: 40, color: _kGray200),
          _pricingColumn(
            "Dépôt de garantie",
            property.formattedPrice,
            "1 mois de loyer",
            _kGray800,
          ),
        ],
      ),
    );
  }

  Widget _pricingColumn(
    String label,
    String value,
    String hint,
    Color valueColor,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _kGray600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        Text(hint, style: const TextStyle(fontSize: 10, color: _kGray400)),
      ],
    );
  }

  Widget _buildBadges() {
    final badges = <Widget>[];
    if (property.acceptsHousingAid)
      badges.add(
        _badge("✓ Aides au logement", _kGreen, const Color(0xFFD1FAE5)),
      );
    if (property.acceptsPublicGuarantee)
      badges.add(
        _badge("✓ Garanties publiques", _kViolet, const Color(0xFFEDE9FE)),
      );
    if (property.isFurnished)
      badges.add(_badge("🛋️ Meublé", _kOrange, const Color(0xFFFEF3C7)));
    badges.add(_badge(property.propertyType, _kGray600, _kGray100));

    return Wrap(spacing: 6, runSpacing: 6, children: badges);
  }

  Widget _badge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildClusterOffers(BuildContext context) {
    return FutureBuilder<List<PropertyModel>>(
      future: context.read<PropertyController>().fetchClusterMembers(
        property.clusterId!,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 40,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: _kIndigo),
            ),
          );
        }

        // On exclut l'annonce actuellement affichée de la liste.
        final otherOffers = snapshot.data!
            .where((p) => p.id != property.id)
            .toList();
        if (otherOffers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_outlined, size: 16, color: _kViolet),
                const SizedBox(width: 6),
                Text(
                  "Ce logement est aussi proposé par ${otherOffers.length} autre${otherOffers.length > 1 ? 's' : ''} agence${otherOffers.length > 1 ? 's' : ''}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kGray800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...otherOffers.map(
              (offer) => _buildClusterOfferTile(context, offer),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClusterOfferTile(BuildContext context, PropertyModel offer) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PropertyDetailScreen(property: offer),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kIndigoLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                offer.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kGray800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              offer.formattedPrice,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kIndigo,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: _kIndigo),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    // TODO : intégrer google_maps_flutter avec les coordonnées géocodées
    // de streetAddress/city (hors scope du prototype pour l'instant).
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: _kGray100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGray200),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, color: Color(0xFF818CF8)),
          SizedBox(height: 2),
          Text(
            "Voir sur la carte",
            style: TextStyle(fontSize: 10, color: _kGray400),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _kGray200)),
        ),
        child: ElevatedButton(
          onPressed: () => _showContactModal(context, property.ownerId),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kIndigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: const Text(
            "Contacter le propriétaire",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  /// Affiche une modale avec le nom complet et l'e-mail du propriétaire
  /// de l'annonce, récupérés depuis Firestore via son uid (`property.ownerId`).
  void _showContactModal(BuildContext context, String ownerId) {
    showDialog(
      context: context,
      builder: (_) => FutureBuilder<UserModel?>(
        future: context.read<AuthController>().fetchUserById(ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 60,
                child: Center(
                  child: CircularProgressIndicator(color: _kIndigo),
                ),
              ),
            );
          }

          final owner = snapshot.data;
          if (owner == null) {
            return AlertDialog(
              title: const Text("Propriétaire introuvable"),
              content: const Text(
                "Impossible de récupérer les coordonnées du propriétaire.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Fermer"),
                ),
              ],
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Coordonnées du propriétaire",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: _kGray600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        owner.fullName,
                        style: const TextStyle(fontSize: 13, color: _kGray800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: _kGray600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        owner.email,
                        style: const TextStyle(fontSize: 13, color: _kGray800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Fermer"),
              ),
            ],
          );
        },
      ),
    );
  }
}
