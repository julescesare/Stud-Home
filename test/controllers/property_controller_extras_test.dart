import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stud_home/controllers/property_controller.dart';
import 'package:stud_home/models/property_model.dart';

void main() {
  group('PropertyController — favoris, regroupement et suivi', () {
    late FakeFirebaseFirestore firestore;
    late PropertyController controller;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      controller = PropertyController(firestore: firestore);
    });

    PropertyModel _property({
      String ownerId = 'owner_1',
      String? clusterId,
      double priceAmount = 750,
      bool isArchived = false,
    }) {
      return PropertyModel(
        id: '',
        ownerId: ownerId,
        clusterId: clusterId,
        title: 'Annonce test',
        description: 'Description',
        propertyType: 'studio',
        priceAmount: priceAmount,
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
        isArchived: isArchived,
      );
    }

    group('Favoris', () {
      test(
        'fetchFavoriteProperties() retourne une liste vide sans favoris',
        () async {
          final result = await controller.fetchFavoriteProperties('user_1');
          expect(result, isEmpty);
        },
      );

      test('fetchFavoriteProperties() ne récupère que les annonces marquées favorites', () async {
        final id1 =
            (await firestore
                    .collection('properties')
                    .add(_property().toFirestore()))
                .id;
        await firestore
            .collection('properties')
            .add(_property().toFirestore()); // pas favori

        await controller.toggleFavorite('user_1', id1);

        final favorites = await controller.fetchFavoriteProperties('user_1');

        expect(favorites.length, 1);
        expect(favorites.first.id, id1);
      });

      test(
        'toggleFavorite() est réversible et reflète bien isFavorite()',
        () async {
          const uid = 'user_1';
          const propertyId = 'prop_1';

          expect(controller.isFavorite(propertyId), isFalse);
          await controller.toggleFavorite(uid, propertyId);
          expect(controller.isFavorite(propertyId), isTrue);
          await controller.toggleFavorite(uid, propertyId);
          expect(controller.isFavorite(propertyId), isFalse);
        },
      );
    });

    group('Regroupement (displayProperties)', () {
      test(
        'un cluster de 3 annonces n\'affiche qu\'une seule carte représentante',
        () async {
          await firestore
              .collection('properties')
              .add(
                _property(
                  clusterId: 'cluster_A',
                  priceAmount: 800,
                ).toFirestore(),
              );
          await firestore
              .collection('properties')
              .add(
                _property(
                  clusterId: 'cluster_A',
                  priceAmount: 750,
                ).toFirestore(),
              );
          await firestore
              .collection('properties')
              .add(
                _property(
                  clusterId: 'cluster_A',
                  priceAmount: 900,
                ).toFirestore(),
              );

          await controller.fetchProperties(const Filters());

          expect(
            controller.properties.length,
            3,
          ); // la liste complète, elle, garde tout
          expect(
            controller.displayProperties.length,
            1,
          ); // mais l'affichage n'en montre qu'une
        },
      );

      test(
        'la carte représentante du cluster est la moins chère du groupe',
        () async {
          await firestore
              .collection('properties')
              .add(
                _property(
                  clusterId: 'cluster_A',
                  priceAmount: 800,
                ).toFirestore(),
              );
          await firestore
              .collection('properties')
              .add(
                _property(
                  clusterId: 'cluster_A',
                  priceAmount: 650,
                ).toFirestore(),
              );

          await controller.fetchProperties(const Filters());

          expect(controller.displayProperties.first.priceAmount, 650);
        },
      );

      test(
        'les annonces indépendantes (sans cluster) apparaissent toutes',
        () async {
          await firestore
              .collection('properties')
              .add(_property(clusterId: null).toFirestore());
          await firestore
              .collection('properties')
              .add(_property(clusterId: null).toFirestore());

          await controller.fetchProperties(const Filters());

          expect(controller.displayProperties.length, 2);
        },
      );

      test('clusterSize() reste calculé sur la liste complète, pas sur displayProperties', () async {
        await firestore
            .collection('properties')
            .add(
              _property(clusterId: 'cluster_A', priceAmount: 800).toFirestore(),
            );
        await firestore
            .collection('properties')
            .add(
              _property(clusterId: 'cluster_A', priceAmount: 650).toFirestore(),
            );

        await controller.fetchProperties(const Filters());

        final representative = controller.displayProperties.first;
        expect(controller.clusterSize(representative), 2);
      });
    });

    group('Suivi des annonces (propriétaire)', () {
      test('fetchMyProperties() ne retourne que les annonces du propriétaire demandé', () async {
        await firestore
            .collection('properties')
            .add(_property(ownerId: 'owner_A').toFirestore());
        await firestore
            .collection('properties')
            .add(_property(ownerId: 'owner_A').toFirestore());
        await firestore
            .collection('properties')
            .add(_property(ownerId: 'owner_B').toFirestore());

        final result = await controller.fetchMyProperties('owner_A');

        expect(result.length, 2);
        expect(result.every((p) => p.ownerId == 'owner_A'), isTrue);
      });

      test('fetchMyProperties() inclut aussi les annonces archivées (contrairement à fetchProperties)', () async {
        await firestore
            .collection('properties')
            .add(_property(ownerId: 'owner_A', isArchived: true).toFirestore());

        final myProperties = await controller.fetchMyProperties('owner_A');
        expect(myProperties.length, 1);

        await controller.fetchProperties(const Filters());
        expect(
          controller.properties,
          isEmpty,
        ); // exclue du fil de recherche étudiant
      });

      test('setArchived() bascule le statut et l\'annonce disparaît du fil de recherche', () async {
        final id =
            (await firestore
                    .collection('properties')
                    .add(_property().toFirestore()))
                .id;

        await controller.fetchProperties(const Filters());
        expect(controller.properties.length, 1);

        final success = await controller.setArchived(id, true);
        expect(success, isTrue);

        await controller.fetchProperties(const Filters());
        expect(controller.properties, isEmpty);
      });

      test(
        'deleteProperty() supprime définitivement le document Firestore',
        () async {
          final id =
              (await firestore
                      .collection('properties')
                      .add(_property().toFirestore()))
                  .id;

          final success = await controller.deleteProperty(id);
          expect(success, isTrue);

          final doc = await firestore.collection('properties').doc(id).get();
          expect(doc.exists, isFalse);
        },
      );
    });
  });
}
