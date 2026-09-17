import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/property_model.dart';

/// Détecte si une nouvelle annonce correspond à un bien déjà publié par
/// une autre agence/propriétaire, et regroupe les annonces concernées
/// sous un même `clusterId`.
///
/// Logique (cf. dossier de conception, section 3) :
/// 1. Requête Firestore restreinte à `countryCode` + `city` (les champs
///    les plus discriminants et les moins coûteux à indexer).
/// 2. Parmi les résultats, on cherche une correspondance sur la surface
///    (± 2 m²) ET l'adresse (comparée après normalisation).
/// 3. Si un match est trouvé :
///    - s'il a déjà un clusterId, on le réutilise (rejoindre le groupe existant) ;
///    - sinon, on crée un nouveau clusterId et on met à jour l'annonce
///      existante pour qu'elle le porte aussi (elle rejoint le groupe
///      qu'on vient de créer).
/// 4. Si aucun match, retourne `null` : l'annonce reste indépendante.
///
/// Ce n'est volontairement PAS un ChangeNotifier : c'est un utilitaire
/// à usage ponctuel appelé depuis le flux de dépôt d'annonce, sans état
/// à observer par une View.
class DeduplicationController {
  final FirebaseFirestore _firestore;

  DeduplicationController({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const double _surfaceTolerance = 2.0; // m²

  /// Détermine le clusterId à attribuer à [candidate] avant sa création.
  /// Retourne `null` si aucune annonce similaire n'existe déjà.
  Future<String?> resolveClusterId(PropertyModel candidate) async {
    final snapshot = await _firestore
        .collection('properties')
        .where('countryCode', isEqualTo: candidate.countryCode)
        .where('city', isEqualTo: candidate.city)
        .get();

    final normalizedCandidateAddress = _normalizeAddress(
      candidate.streetAddress,
    );

    for (final doc in snapshot.docs) {
      final existing = PropertyModel.fromFirestore(doc);

      final surfaceMatches =
          (existing.surfaceSqm - candidate.surfaceSqm).abs() <=
          _surfaceTolerance;
      final addressMatches =
          _normalizeAddress(existing.streetAddress) ==
          normalizedCandidateAddress;

      if (surfaceMatches && addressMatches) {
        if (existing.isPartOfCluster) {
          // L'annonce existante appartient déjà à un groupe : on le rejoint.
          return existing.clusterId;
        }

        // Aucun groupe encore formé : on en crée un et on y rattache
        // rétroactivement l'annonce existante.
        final newClusterId = _firestore.collection('properties').doc().id;
        await _firestore.collection('properties').doc(existing.id).update({
          'clusterId': newClusterId,
        });
        return newClusterId;
      }
    }

    return null; // Aucune correspondance : annonce indépendante.
  }

  /// Normalise une adresse pour la comparaison : minuscules, espaces
  /// multiples réduits, accents simplifiés, ponctuation retirée.
  /// Objectif : "12 Rue de la Paix" et "12, rue de la paix" doivent matcher.
  String _normalizeAddress(String address) {
    var normalized = address.toLowerCase().trim();

    const accentsMap = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    accentsMap.forEach((accented, plain) {
      normalized = normalized.replaceAll(accented, plain);
    });

    normalized = normalized.replaceAll(RegExp(r'[,.\-]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }
}
