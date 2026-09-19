import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stud_home/models/property_model.dart';
import 'package:stud_home/theme/app_colors.dart';

const _kIndigo = AppColors.indigo;
const _kViolet = AppColors.violet;
const _kGray100 = AppColors.gray100;
const _kGray200 = AppColors.gray200;
const _kGray400 = AppColors.gray400;
const _kGray600 = AppColors.gray600;
const _kGray800 = AppColors.gray800;

/// Carte d'annonce affichée dans la liste de résultats.
/// Widget purement présentationnel : toutes les données lui sont passées
/// en paramètres, aucune logique métier ni accès direct au Controller.
class PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final int clusterSize;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback onTap;

  const PropertyCard({
    super.key,
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
