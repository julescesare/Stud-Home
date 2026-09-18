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

  /// Liste "propre" à afficher dans le fil de recherche : une seule
  /// annonce "représentante" par groupe de doublons (la moins chère du
  /// groupe), plus toutes les annonces indépendantes. C'est ce qui évite
  /// de polluer le fil avec plusieurs cartes identiques pour la même offre
  /// publiée par différentes agences — `clusterSize()` reste calculé sur
  /// `_properties` (la liste complète), donc le badge affiche toujours
  /// le vrai nombre d'agences.
  List<PropertyModel> get displayProperties {
    final Map<String, PropertyModel> representatives = {};
    final List<PropertyModel> standalone = [];

    for (final property in _properties) {
      if (property.isPartOfCluster) {
        final existing = representatives[property.clusterId];
        if (existing == null || property.priceAmount < existing.priceAmount) {
          representatives[property.clusterId!] = property;
        }
      } else {
        standalone.add(property);
      }
    }

    return [...standalone, ...representatives.values]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Filters get activeFilters => _activeFilters;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isFavorite(String propertyId) => _favoriteIds.contains(propertyId);

  /// Exposé pour permettre à une View de savoir *quels* ids sont favoris
  /// (au-delà du simple `isFavorite(id)` booléen déjà disponible).
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

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
      Query query = _firestore.collection('properties');

      final snapshot = await query.get();
      var results = snapshot.docs
          .map((doc) => PropertyModel.fromFirestore(doc))
          .toList();
      results = results.where((p) => !p.isArchived).toList();

      if (filters.budgetMax != null) {
        results = results
            .where((p) => p.priceAmount <= filters.budgetMax!)
            .toList();
      }
      if (filters.city != null && filters.city!.isNotEmpty) {
        query = query.where('city', isEqualTo: filters.city);
      }

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

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _properties = results;
    } catch (e) {
      _errorMessage = "Impossible de charger les logements pour le moment.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Récupère toutes les annonces appartenant au même groupe que [clusterId]
  /// (ex: la même chambre publiée par plusieurs agences) — utilisé sur la
  /// fiche détaillée pour permettre à l'étudiant de comparer les offres.
  Future<List<PropertyModel>> fetchClusterMembers(String clusterId) async {
    final snapshot = await _firestore
        .collection('properties')
        .where('clusterId', isEqualTo: clusterId)
        .get();
    return snapshot.docs
        .map((doc) => PropertyModel.fromFirestore(doc))
        .toList();
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

  /// Récupère les annonces complètes correspondant aux favoris de [uid].
  /// Recharge d'abord la liste des ids favoris pour être sûr d'avoir
  /// l'état le plus à jour (utile si l'écran des favoris est ouvert
  /// directement, sans passer par l'écran de recherche au préalable).
  Future<List<PropertyModel>> fetchFavoriteProperties(String uid) async {
    await loadFavorites(uid);
    if (_favoriteIds.isEmpty) return [];

    // Note : `whereIn` est limité à 30 valeurs par Firestore. Largement
    // suffisant pour un prototype ; au-delà, il faudrait paginer par lots.
    final snapshot = await _firestore
        .collection('properties')
        .where(FieldPath.documentId, whereIn: _favoriteIds.toList())
        .get();

    return snapshot.docs
        .map((doc) => PropertyModel.fromFirestore(doc))
        .toList();
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

  /// Récupère toutes les annonces publiées par [ownerId] (actives ET
  /// archivées) — contrairement à `fetchProperties()`, destiné au fil de
  /// recherche étudiant, cette méthode alimente l'écran "Mes annonces"
  /// du propriétaire, qui doit voir l'intégralité de son propre catalogue.
  Future<List<PropertyModel>> fetchMyProperties(String ownerId) async {
    final snapshot = await _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final properties = snapshot.docs
        .map((doc) => PropertyModel.fromFirestore(doc))
        .toList();
    properties.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return properties;
  }

  /// Archive ou désarchive une annonce (soft delete) : elle disparaît du
  /// fil de recherche étudiant sans perdre les données, contrairement à
  /// `deleteProperty()` qui est irréversible.
  Future<bool> setArchived(String propertyId, bool archived) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'isArchived': archived,
      });
      return true;
    } catch (e) {
      _errorMessage = "Impossible de mettre à jour l'annonce.";
      notifyListeners();
      return false;
    }
  }

  /// Supprime définitivement une annonce. Si elle appartenait à un
  /// cluster, le badge "Offre regroupée" des annonces restantes du
  /// groupe se réajuste automatiquement au prochain fetch, puisque
  /// `clusterSize()` recompte simplement les annonces partageant le
  /// même clusterId parmi celles encore présentes.
  Future<bool> deleteProperty(String propertyId) async {
    try {
      await _firestore.collection('properties').doc(propertyId).delete();
      return true;
    } catch (e) {
      _errorMessage = "Impossible de supprimer l'annonce.";
      notifyListeners();
      return false;
    }
  }
}
