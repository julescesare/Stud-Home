import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stud_home/controllers/property_controller.dart';
import 'package:stud_home/models/property_model.dart';

void main() {
  group('PropertyController', () {
    late FakeFirebaseFirestore firestore;
    late PropertyController controller;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      controller = PropertyController(firestore: firestore);
    });

    PropertyModel _property({String? clusterId}) {
      return PropertyModel(
        id: '',
        ownerId: 'owner_1',
        clusterId: clusterId,
        title: 'Studio test',
        description: 'Description',
        propertyType: 'studio',
        priceAmount: 750,
        currencyCode: 'EUR',
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

    test('createProperty() persiste bien l\'annonce dans Firestore et retourne true', () async {
      final success = await controller.createProperty(_property());

      expect(success, isTrue);
      final snapshot = await firestore.collection('properties').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['title'], 'Studio test');
    });

    test('fetchProperties() applique le filtre de prix maximum', () async {
      await firestore
          .collection('properties')
          .add(_property().toFirestore()..['priceAmount'] = 500);
      await firestore
          .collection('properties')
          .add(_property().toFirestore()..['priceAmount'] = 900);

      await controller.fetchProperties(const Filters(budgetMax: 700));

      expect(controller.properties.length, 1);
      expect(controller.properties.first.priceAmount, 500);
    });

    test(
      'clusterSize() compte correctement les annonces partageant un clusterId',
      () async {
        await firestore
            .collection('properties')
            .add(_property(clusterId: 'cluster_A').toFirestore());
        await firestore
            .collection('properties')
            .add(_property(clusterId: 'cluster_A').toFirestore());
        await firestore
            .collection('properties')
            .add(_property(clusterId: null).toFirestore());

        await controller.fetchProperties(const Filters());

        final clustered = controller.properties.firstWhere(
          (p) => p.clusterId == 'cluster_A',
        );
        final standalone = controller.properties.firstWhere(
          (p) => p.clusterId == null,
        );

        expect(controller.clusterSize(clustered), 2);
        expect(controller.clusterSize(standalone), 1);
      },
    );

    test(
      'toggleFavorite() ajoute puis retire un favori dans Firestore',
      () async {
        const uid = 'user_1';
        const propertyId = 'prop_1';

        expect(controller.isFavorite(propertyId), isFalse);

        await controller.toggleFavorite(uid, propertyId);
        expect(controller.isFavorite(propertyId), isTrue);

        final favDoc = await firestore
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .doc(propertyId)
            .get();
        expect(favDoc.exists, isTrue);

        await controller.toggleFavorite(uid, propertyId);
        expect(controller.isFavorite(propertyId), isFalse);

        final favDocAfter = await firestore
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .doc(propertyId)
            .get();
        expect(favDocAfter.exists, isFalse);
      },
    );
  });
}
