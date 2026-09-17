import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/property_model.dart';

/// Représente l'état des filtres appliqués à la recherche de logements.
///
/// Ce n'est pas un Model métier stocké dans Firestore (contrairement à
/// UserModel/PropertyModel) : c'est un objet de transport utilisé
/// uniquement entre la View (Écran 1) et le PropertyController.
class Filters {
  final double? budgetMax;
  final bool furnishedOnly;
  final bool housingAidEligible; // APL/ALS
  final bool publicGuaranteeAccepted; // Visale/Garant
  final String? city;

  const Filters({
    this.budgetMax,
    this.furnishedOnly = false,
    this.housingAidEligible = false,
    this.publicGuaranteeAccepted = false,
    this.city,
  });

  Filters copyWith({
    double? budgetMax,
    bool? furnishedOnly,
    bool? housingAidEligible,
    bool? publicGuaranteeAccepted,
    String? city,
  }) {
    return Filters(
      budgetMax: budgetMax ?? this.budgetMax,
      furnishedOnly: furnishedOnly ?? this.furnishedOnly,
      housingAidEligible: housingAidEligible ?? this.housingAidEligible,
      publicGuaranteeAccepted:
          publicGuaranteeAccepted ?? this.publicGuaranteeAccepted,
      city: city ?? this.city,
    );
  }
}

/// Contrôleur responsable du catalogue d'annonces affiché à l'étudiant.
///
/// Rôle dans l'architecture MVC :
/// - Interroge Firestore (collection `properties`) selon les [Filters]
///   actifs et expose la liste résultante aux Views.
/// - Gère les favoris de l'utilisateur courant.
/// - Calcule les regroupements (clusters) pour l'affichage du badge
///   "Offre regroupée (X agences)" — la détection elle-même est faite
///   en amont par le DeduplicationController au moment du dépôt d'annonce
///   (Phase 5) ; ici on ne fait qu'exploiter le `clusterId` déjà posé.
class PropertyController extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  List<PropertyModel> _properties = [];
  Filters _activeFilters = const Filters();
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _favoriteIds = {};

  PropertyController({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- Getters exposés aux Views ---

  List<PropertyModel> get properties => _properties;
  Filters get activeFilters => _activeFilters;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isFavorite(String propertyId) => _favoriteIds.contains(propertyId);

  /// Nombre d'annonces regroupées sous le même clusterId que [property].
  /// Retourne 1 si l'annonce n'appartient à aucun cluster (pas de badge à afficher).
  int clusterSize(PropertyModel property) {
    if (!property.isPartOfCluster) return 1;
    return _properties.where((p) => p.clusterId == property.clusterId).length;
  }

  /// Récupère les annonces correspondant aux [filters] fournis.
  ///
  /// Note pédagogique : Firestore ne permet pas de combiner facilement
  /// une inégalité (priceAmount <=) avec plusieurs égalités sur des champs
  /// différents sans index composite. Pour un prototype, on applique donc
  /// le filtre de prix côté Firestore (le plus sélectif), et les filtres
  /// booléens côté client après récupération — un choix pragmatique que
  /// tu pourras optimiser avec des index composites en production.
  Future<void> fetchProperties(Filters filters) async {
    _activeFilters = filters;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query query = _firestore
          .collection('properties')
          .orderBy('createdAt', descending: true);

      if (filters.budgetMax != null) {
        query = query.where(
          'priceAmount',
          isLessThanOrEqualTo: filters.budgetMax,
        );
      }
      if (filters.city != null && filters.city!.isNotEmpty) {
        query = query.where('city', isEqualTo: filters.city);
      }

      final snapshot = await query.get();
      var results = snapshot.docs
          .map((doc) => PropertyModel.fromFirestore(doc))
          .toList();

      // Filtres booléens appliqués côté client.
      if (filters.furnishedOnly) {
        results = results.where((p) => p.isFurnished).toList();
      }
      if (filters.housingAidEligible) {
        results = results.where((p) => p.acceptsHousingAid).toList();
      }
      if (filters.publicGuaranteeAccepted) {
        results = results.where((p) => p.acceptsPublicGuarantee).toList();
      }

      _properties = results;
    } catch (e) {
      _errorMessage = "Impossible de charger les logements pour le moment.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge la liste des favoris existants de l'utilisateur [uid].
  /// À appeler une fois, typiquement quand l'utilisateur se connecte.
  Future<void> loadFavorites(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .get();
      _favoriteIds
        ..clear()
        ..addAll(snapshot.docs.map((d) => d.id));
      notifyListeners();
    } catch (e) {
      // Un échec de chargement des favoris n'est pas bloquant pour l'UX :
      // on log silencieusement plutôt que d'afficher une erreur intrusive.
      debugPrint("Erreur chargement favoris: $e");
    }
  }

  /// Ajoute ou retire [propertyId] des favoris de l'utilisateur [uid].
  ///
  /// Mise à jour optimiste : l'UI réagit immédiatement, puis on synchronise
  /// avec Firestore. En cas d'échec, on annule le changement local.
  Future<void> toggleFavorite(String uid, String propertyId) async {
    final wasAlreadyFavorite = _favoriteIds.contains(propertyId);

    void setState_() {
      if (wasAlreadyFavorite) {
        _favoriteIds.remove(propertyId);
      } else {
        _favoriteIds.add(propertyId);
      }
      notifyListeners();
    }

    setState_();

    final favRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(propertyId);
    try {
      if (wasAlreadyFavorite) {
        await favRef.delete();
      } else {
        await favRef.set({'addedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      // Rollback en cas d'échec réseau/permissions.
      setState_();
      debugPrint("Erreur toggleFavorite: $e");
    }
  }

  /// Publie une nouvelle annonce dans Firestore.
  /// Les URLs d'images doivent déjà avoir été uploadées (via CloudinaryService)
  /// avant l'appel — ce Controller ne gère que la persistance des métadonnées.
  Future<bool> createProperty(PropertyModel property) async {
    try {
      await _firestore.collection('properties').add(property.toFirestore());
      return true;
    } catch (e) {
      _errorMessage = "Impossible de publier l'annonce.";
      notifyListeners();
      return false;
    }
  }
}
