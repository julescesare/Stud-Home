import 'package:cloud_firestore/cloud_firestore.dart';

/// Représente une annonce de logement dans Stud'Home.
///
/// C'est la structure "pivot" de l'application : elle est stockée dans la
/// collection Firestore `properties` et alimente à la fois l'écran de
/// recherche (Écran 1), la fiche détaillée (Écran 2) et le formulaire de
/// dépôt d'annonce (Écran 3).
///
/// Le champ [clusterId] est essentiel : il est renseigné par le
/// DeduplicationController lorsque plusieurs annonces correspondent au
/// même bien réel (ex : la même chambre postée par 2 agences). Il permet
/// d'afficher le badge "Offre regroupée (X agences)".
class PropertyModel {
  final String id;
  final String ownerId;
  final String? clusterId; // null si l'annonce n'appartient à aucun groupe

  // Contenu de l'annonce
  final String title;
  final String description;
  final String propertyType; // ex: "studio", "T1", "colocation"

  // Prix
  final double priceAmount;
  final String currencyCode; // ex: "EUR"
  final bool chargesIncluded;

  // Localisation (utilisée par l'algorithme anti-doublons)
  final String streetAddress;
  final String city;
  final String postalCode;
  final String countryCode;

  // Caractéristiques
  final double surfaceSqm;
  final bool isFurnished;
  final bool acceptsHousingAid; // APL / ALS
  final bool acceptsPublicGuarantee; // Visale / Garant

  final List<String> imageUrls;
  final DateTime createdAt;
  final bool isArchived;

  PropertyModel({
    required this.id,
    required this.ownerId,
    this.clusterId,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.priceAmount,
    required this.currencyCode,
    required this.chargesIncluded,
    required this.streetAddress,
    required this.city,
    required this.postalCode,
    required this.countryCode,
    required this.surfaceSqm,
    required this.isFurnished,
    required this.acceptsHousingAid,
    required this.acceptsPublicGuarantee,
    required this.imageUrls,
    required this.createdAt,
    required this.isArchived,
  });

  /// Construit un [PropertyModel] à partir d'un document Firestore.
  factory PropertyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return PropertyModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      clusterId: data['clusterId'], // reste null si absent, pas de valeur par défaut forcée

      title: data['title'] ?? '',
      description: data['description'] ?? '',
      propertyType: data['propertyType'] ?? 'studio',

      // (data['priceAmount'] as num?) permet de gérer indifféremment
      // les int et double renvoyés par Firestore.
      priceAmount: (data['priceAmount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: data['currencyCode'] ?? 'EUR',
      chargesIncluded: data['chargesIncluded'] ?? false,

      streetAddress: data['streetAddress'] ?? '',
      city: data['city'] ?? '',
      postalCode: data['postalCode'] ?? '',
      countryCode: data['countryCode'] ?? 'FR',

      surfaceSqm: (data['surfaceSqm'] as num?)?.toDouble() ?? 0.0,
      isFurnished: data['isFurnished'] ?? false,
      acceptsHousingAid: data['acceptsHousingAid'] ?? false,
      acceptsPublicGuarantee: data['acceptsPublicGuarantee'] ?? false,

      // Cast explicite en List<String> pour éviter les erreurs de type
      // avec les List<dynamic> renvoyées par Firestore.
      imageUrls: List<String>.from(data['imageUrls'] ?? []),

      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isArchived: data['isArchived'] ?? false,
    );
  }

  /// Convertit l'instance en Map pour l'écriture dans Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'clusterId': clusterId,
      'title': title,
      'description': description,
      'propertyType': propertyType,
      'priceAmount': priceAmount,
      'currencyCode': currencyCode,
      'chargesIncluded': chargesIncluded,
      'streetAddress': streetAddress,
      'city': city,
      'postalCode': postalCode,
      'countryCode': countryCode,
      'surfaceSqm': surfaceSqm,
      'isFurnished': isFurnished,
      'acceptsHousingAid': acceptsHousingAid,
      'acceptsPublicGuarantee': acceptsPublicGuarantee,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
    };
  }

  /// Prix total mensuel affiché (loyer, charges comprises ou non selon le cas).
  /// Utile pour l'Écran 1 (carte annonce) sans dupliquer la logique dans la View.
  String get formattedPrice =>
      '${priceAmount.toStringAsFixed(0)} ${currencyCode == 'EUR' ? '€' : currencyCode}';

  /// Vrai si cette annonce fait partie d'un groupe de doublons détectés.
  bool get isPartOfCluster => clusterId != null && clusterId!.isNotEmpty;

  /// Copie modifiée, utile pour `toggleFavorite` ou les mises à jour partielles.
  PropertyModel copyWith({
    String? clusterId,
    List<String>? imageUrls,
    bool? isArchived,
  }) {
    return PropertyModel(
      id: id,
      ownerId: ownerId,
      clusterId: clusterId ?? this.clusterId,
      title: title,
      description: description,
      propertyType: propertyType,
      priceAmount: priceAmount,
      currencyCode: currencyCode,
      chargesIncluded: chargesIncluded,
      streetAddress: streetAddress,
      city: city,
      postalCode: postalCode,
      countryCode: countryCode,
      surfaceSqm: surfaceSqm,
      isFurnished: isFurnished,
      acceptsHousingAid: acceptsHousingAid,
      acceptsPublicGuarantee: acceptsPublicGuarantee,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
