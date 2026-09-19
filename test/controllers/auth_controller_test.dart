import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stud_home/controllers/auth_controller.dart';

void main() {
  group('AuthController.fetchUserById', () {
    late FakeFirebaseFirestore firestore;
    late AuthController authController;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      // MockFirebaseAuth simule la partie authentification (nécessaire
      // car le constructeur d'AuthController s'abonne à
      // authStateChanges() dès sa création) — on ne teste pas cette
      // partie ici, seulement fetchUserById(), qui ne touche que Firestore.
      authController = AuthController(
        firebaseAuth: MockFirebaseAuth(),
        firestore: firestore,
      );
    });

    test(
      'retourne le profil complet du propriétaire pour la modale de contact',
      () async {
        await firestore.collection('users').doc('owner_1').set({
          'email': 'marie.dupont@gmail.com',
          'role': 'owner',
          'fullName': 'Marie Dupont',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });

        final owner = await authController.fetchUserById('owner_1');

        expect(owner, isNotNull);
        expect(owner!.fullName, 'Marie Dupont');
        expect(owner.email, 'marie.dupont@gmail.com');
      },
    );

    test(
      'retourne null si l\'utilisateur n\'existe pas (propriétaire supprimé)',
      () async {
        final result = await authController.fetchUserById('uid_inexistant');
        expect(result, isNull);
      },
    );

    test('ne modifie pas currentUser (contrairement au chargement du profil connecté)', () async {
      await firestore.collection('users').doc('owner_1').set({
        'email': 'marie.dupont@gmail.com',
        'role': 'owner',
        'fullName': 'Marie Dupont',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(authController.currentUser, isNull);
      await authController.fetchUserById('owner_1');
      // fetchUserById() sert à consulter le profil d'un tiers (le
      // propriétaire d'une annonce) — currentUser doit rester inchangé,
      // sans quoi on écraserait la session de l'utilisateur connecté.
      expect(authController.currentUser, isNull);
    });
  });
}
