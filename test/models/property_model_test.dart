import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stud_home/models/property_model.dart';

void main() {
  group('PropertyModel', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test(
      'fromFirestore() reconstruit correctement une annonce complète',
      () async {
        final docRef = firestore.collection('properties').doc('prop_1');
        await docRef.set({
          'ownerId': 'owner_1',
          'clusterId': null,
          'title': 'Studio moderne — Paris 13e',
          'description': 'Beau studio meublé.',
          'propertyType': 'studio',
          'priceAmount': 750,
          'currencyCode': 'EUR',
          'chargesIncluded': true,
          'streetAddress': "75 Av. d'Ivry",
          'city': 'Paris',
          'postalCode': '75013',
          'countryCode': 'FR',
          'surfaceSqm': 22,
          'isFurnished': true,
          'acceptsHousingAid': true,
          'acceptsPublicGuarantee': true,
          'imageUrls': ['https://example.com/photo1.jpg'],
          'createdAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
        });

        final snapshot = await docRef.get();
        final property = PropertyModel.fromFirestore(snapshot);

        expect(property.id, 'prop_1');
        expect(property.title, 'Studio moderne — Paris 13e');
        expect(property.priceAmount, 750.0);
        expect(property.surfaceSqm, 22.0);
        expect(property.isFurnished, isTrue);
        expect(property.imageUrls, ['https://example.com/photo1.jpg']);
        expect(property.clusterId, isNull);
      },
    );

    test(
      'fromFirestore() gère les nombres entiers Firestore comme des doubles',
      () async {
        // Firestore peut stocker 750 comme un int : le modèle doit convertir
        // proprement en double sans planter (num? -> toDouble()).
        final docRef = firestore.collection('properties').doc('prop_int');
        await docRef.set({'priceAmount': 800, 'surfaceSqm': 18});

        final snapshot = await docRef.get();
        final property = PropertyModel.fromFirestore(snapshot);

        expect(property.priceAmount, 800.0);
        expect(property.surfaceSqm, 18.0);
      },
    );

    test('toFirestore() sérialise correctement tous les champs', () {
      final property = PropertyModel(
        id: 'ignored',
        ownerId: 'owner_1',
        clusterId: null,
        title: 'T1 lumineux',
        description: 'Description',
        propertyType: 'T1',
        priceAmount: 590,
        currencyCode: 'EUR',
        chargesIncluded: false,
        streetAddress: '10 rue de Lyon',
        city: 'Lyon',
        postalCode: '69000',
        countryCode: 'FR',
        surfaceSqm: 28,
        isFurnished: false,
        acceptsHousingAid: false,
        acceptsPublicGuarantee: false,
        imageUrls: const [],
        createdAt: DateTime(2026, 1, 1),
        isArchived: false,
      );

      final data = property.toFirestore();

      expect(
        data.containsKey('id'),
        isFalse,
      ); // l'id n'est jamais un champ du document
      expect(data['ownerId'], 'owner_1');
      expect(data['priceAmount'], 590.0);
    });

    test('formattedPrice affiche le symbole € pour la devise EUR', () {
      final property = _buildProperty(priceAmount: 750, currencyCode: 'EUR');
      expect(property.formattedPrice, '750 €');
    });

    test('formattedPrice affiche le code de la devise si non-EUR', () {
      final property = _buildProperty(priceAmount: 1200, currencyCode: 'USD');
      expect(property.formattedPrice, '1200 USD');
    });

    test('isPartOfCluster est faux quand clusterId est null ou vide', () {
      expect(_buildProperty(clusterId: null).isPartOfCluster, isFalse);
      expect(_buildProperty(clusterId: '').isPartOfCluster, isFalse);
      expect(_buildProperty(clusterId: 'cluster_1').isPartOfCluster, isTrue);
    });

    test('copyWith() met à jour clusterId sans toucher aux autres champs', () {
      final original = _buildProperty(clusterId: null);
      final updated = original.copyWith(clusterId: 'cluster_42');

      expect(updated.clusterId, 'cluster_42');
      expect(updated.title, original.title);
      expect(updated.priceAmount, original.priceAmount);
    });
  });
}

/// Fabrique un PropertyModel minimal pour les tests qui ne portent
/// que sur un ou deux champs spécifiques — évite de répéter tous les
/// paramètres requis dans chaque test.
PropertyModel _buildProperty({
  double priceAmount = 750,
  String currencyCode = 'EUR',
  String? clusterId,
}) {
  return PropertyModel(
    id: 'test_id',
    ownerId: 'owner_1',
    clusterId: clusterId,
    title: 'Titre test',
    description: 'Description test',
    propertyType: 'studio',
    priceAmount: priceAmount,
    currencyCode: currencyCode,
    chargesIncluded: true,
    streetAddress: '1 rue Test',
    city: 'Paris',
    postalCode: '75001',
    countryCode: 'FR',
    surfaceSqm: 20,
    isFurnished: true,
    acceptsHousingAid: false,
    acceptsPublicGuarantee: false,
    imageUrls: const [],
    createdAt: DateTime(2026, 1, 1),
    isArchived: false,
  );
}
