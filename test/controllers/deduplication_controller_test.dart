import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stud_home/controllers/deduplication_controller.dart';
import 'package:stud_home/models/property_model.dart';

void main() {
  group('DeduplicationController', () {
    late FakeFirebaseFirestore firestore;
    late DeduplicationController controller;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      controller = DeduplicationController(firestore: firestore);
    });

    /// Insère directement une annonce dans le Firestore simulé, en
    /// contournant le Controller — on veut tester `resolveClusterId()`
    /// isolément, pas le flux complet de création.
    Future<String> _seedProperty({
      required String city,
      required String countryCode,
      required double surfaceSqm,
      required String streetAddress,
      String? clusterId,
    }) async {
      final doc = await firestore.collection('properties').add({
        'ownerId': 'owner_seed',
        'clusterId': clusterId,
        'title': 'Annonce existante',
        'description': '',
        'propertyType': 'studio',
        'priceAmount': 700,
        'currencyCode': 'EUR',
        'chargesIncluded': false,
        'streetAddress': streetAddress,
        'city': city,
        'postalCode': '75000',
        'countryCode': countryCode,
        'surfaceSqm': surfaceSqm,
        'isFurnished': false,
        'acceptsHousingAid': false,
        'acceptsPublicGuarantee': false,
        'imageUrls': [],
        'createdAt': DateTime.now(),
      });
      return doc.id;
    }

    PropertyModel _candidate({
      required String city,
      required String countryCode,
      required double surfaceSqm,
      required String streetAddress,
    }) {
      return PropertyModel(
        id: 'candidate',
        ownerId: 'owner_new',
        title: 'Nouvelle annonce',
        description: '',
        propertyType: 'studio',
        priceAmount: 720,
        currencyCode: 'EUR',
        chargesIncluded: false,
        streetAddress: streetAddress,
        city: city,
        postalCode: '75000',
        countryCode: countryCode,
        surfaceSqm: surfaceSqm,
        isFurnished: false,
        acceptsHousingAid: false,
        acceptsPublicGuarantee: false,
        imageUrls: const [],
        createdAt: DateTime.now(),
        isArchived: false,
      );
    }

    test('retourne null quand aucune annonce similaire n\'existe', () async {
      await _seedProperty(
        city: 'Lyon',
        countryCode: 'FR',
        surfaceSqm: 20,
        streetAddress: '5 rue de la Paix',
      );
      // Candidate dans une autre ville : pas de doublon.
      final candidate = _candidate(
        city: 'Paris',
        countryCode: 'FR',
        surfaceSqm: 22,
        streetAddress: '75 Av. d\'Ivry',
      );
      final result = await controller.resolveClusterId(candidate);

      expect(result, isNull);
    });

    test(
      'détecte un doublon quand ville + surface (±2m²) + adresse correspondent',
      () async {
        await _seedProperty(
          city: 'Paris',
          countryCode: 'FR',
          surfaceSqm: 22,
          streetAddress: "75 Av. d'Ivry",
        );

        final candidate = _candidate(
          city: 'Paris',
          countryCode: 'FR',
          surfaceSqm: 23,
          streetAddress: "75 Av. d'Ivry",
        );
        final result = await controller.resolveClusterId(candidate);

        expect(result, isNotNull);
      },
    );

    test(
      'ne détecte pas de doublon si la différence de surface dépasse 2m²',
      () async {
        await _seedProperty(
          city: 'Paris',
          countryCode: 'FR',
          surfaceSqm: 22,
          streetAddress: "75 Av. d'Ivry",
        );

        // Écart de 3m² : hors tolérance.
        final candidate = _candidate(
          city: 'Paris',
          countryCode: 'FR',
          surfaceSqm: 25,
          streetAddress: "75 Av. d'Ivry",
        );
        final result = await controller.resolveClusterId(candidate);

        expect(result, isNull);
      },
    );

    test('l\'adresse est comparée après normalisation (accents, casse, ponctuation)', () async {
      await _seedProperty(
        city: 'Paris',
        countryCode: 'FR',
        surfaceSqm: 22,
        streetAddress: '12, Rue de la Paix',
      );

      // Même adresse, mais écrite différemment : minuscules, sans virgule, avec accent.
      final candidate = _candidate(
        city: 'Paris',
        countryCode: 'FR',
        surfaceSqm: 22,
        streetAddress: '12 rue de la paix',
      );
      final result = await controller.resolveClusterId(candidate);

      expect(result, isNotNull);
    });

    test(
      'rejoint un cluster déjà existant plutôt que d\'en créer un nouveau',
      () async {
        await _seedProperty(
          city: 'Paris',
          countryCode: 'FR',
          surfaceSqm: 22,
          streetAddress: "75 Av. d'Ivry",
          clusterId: 'cluster_existant',
        );

        final candidate = _candidate(
          city: 'Paris',
          countryCode: 'FR',
          surfaceSqm: 22,
          streetAddress: "75 Av. d'Ivry",
        );
        final result = await controller.resolveClusterId(candidate);

        expect(result, 'cluster_existant');
      },
    );

    test('crée un nouveau clusterId et met à jour rétroactivement l\'annonce existante', () async {
      final existingId = await _seedProperty(
        city: 'Paris',
        countryCode: 'FR',
        surfaceSqm: 22,
        streetAddress: "75 Av. d'Ivry",
        clusterId: null, // pas encore de cluster
      );

      final candidate = _candidate(
        city: 'Paris',
        countryCode: 'FR',
        surfaceSqm: 22,
        streetAddress: "75 Av. d'Ivry",
      );
      final newClusterId = await controller.resolveClusterId(candidate);

      expect(newClusterId, isNotNull);

      // Vérifie que l'annonce existante a bien été mise à jour avec le
      // même clusterId — c'est ce qui garantit que les deux annonces
      // se retrouvent groupées à l'affichage (PropertyController.clusterSize()).
      final updatedDoc = await firestore
          .collection('properties')
          .doc(existingId)
          .get();
      expect(updatedDoc.data()?['clusterId'], newClusterId);
    });

    test('ignore les annonces d\'une autre ville même avec surface/adresse identiques', () async {
      await _seedProperty(
        city: 'Lyon',
        countryCode: 'FR',
        surfaceSqm: 22,
        streetAddress: "75 Av. d'Ivry",
      );

      final candidate = _candidate(
        city: 'Paris',
        countryCode: 'FR',
        surfaceSqm: 22,
        streetAddress: "75 Av. d'Ivry",
      );
      final result = await controller.resolveClusterId(candidate);

      expect(result, isNull);
    });
  });
}
