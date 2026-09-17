import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Carrousel photo réutilisable : swipe horizontal entre plusieurs photos,
/// points de pagination, flèche de retour et bouton favori en overlay.
///
/// Conçu pour être importé par n'importe quel écran ayant besoin d'afficher
/// une galerie de photos en en-tête (fiche détaillée, aperçu avant
/// publication, etc.) — aucune dépendance à un écran ou un Controller
/// particulier, tout lui est passé en paramètres (widget purement
/// présentationnel, conforme au principe MVC).
///
/// Utilisation :
/// ```dart
/// PhotoCarousel(
///   imageUrls: property.imageUrls,
///   isFavorite: controller.isFavorite(property.id),
///   onBack: () => Navigator.of(context).pop(),
///   onFavoriteTap: () => controller.toggleFavorite(uid, property.id),
/// )
/// ```
class PhotoCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final bool isFavorite;
  final VoidCallback? onBack;
  final VoidCallback? onFavoriteTap;

  const PhotoCarousel({
    super.key,
    required this.imageUrls,
    this.height = 220,
    this.isFavorite = false,
    this.onBack,
    this.onFavoriteTap,
  });

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = widget.imageUrls.isNotEmpty;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          if (hasImages)
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (_, index) => Image.network(
                widget.imageUrls[index],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
          else
            Container(color: AppColors.gray100),

          // Points de pagination — un par photo, celui de la page
          // courante est plus large. N'apparaît que s'il y a plusieurs photos.
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),

          if (widget.onBack != null)
            Positioned(
              top: 12,
              left: 12,
              child: _circleButton(
                icon: Icons.arrow_back,
                onTap: widget.onBack,
              ),
            ),
          if (widget.onFavoriteTap != null)
            Positioned(
              top: 12,
              right: 12,
              child: _circleButton(
                icon: widget.isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: widget.isFavorite ? Colors.redAccent : AppColors.gray600,
                onTap: widget.onFavoriteTap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    Color color = AppColors.gray800,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
          ],
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
