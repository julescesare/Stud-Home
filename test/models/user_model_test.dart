import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stud_home/models/user_model.dart';

void main() {
  group('UserModel', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      // Un Firestore simulé en mémoire : on peut y écrire/lire de vrais
      // documents sans jamais toucher au réseau ni à un vrai projet Firebase.
      firestore = FakeFirebaseFirestore();
    });

    test(
      'fromFirestore() reconstruit correctement un utilisateur complet',
      () async {
        final docRef = firestore.collection('users').doc('user_123');
        await docRef.set({
          'email': 'lucas.martin@univ-paris.fr',
          'role': 'student',
          'fullName': 'Lucas Martin',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        });

        final snapshot = await docRef.get();
        final user = UserModel.fromFirestore(snapshot);

        expect(user.uid, 'user_123');
        expect(user.email, 'lucas.martin@univ-paris.fr');
        expect(user.role, 'student');
        expect(user.fullName, 'Lucas Martin');
        expect(user.createdAt, DateTime(2026, 1, 15));
      },
    );

    test(
      'fromFirestore() applique des valeurs par défaut si des champs manquent',
      () async {
        final docRef = firestore.collection('users').doc('user_incomplet');
        // Document volontairement incomplet, pour vérifier la robustesse du parsing.
        await docRef.set({'email': 'test@test.fr'});

        final snapshot = await docRef.get();
        final user = UserModel.fromFirestore(snapshot);

        expect(user.role, 'student'); // valeur par défaut
        expect(user.fullName, ''); // valeur par défaut
      },
    );

    test('toFirestore() ne réécrit pas le uid comme un champ', () {
      final user = UserModel(
        uid: 'abc',
        email: 'test@test.fr',
        role: 'owner',
        fullName: 'Marie Dupont',
        createdAt: DateTime(2026, 3, 1),
      );

      final data = user.toFirestore();

      expect(data.containsKey('uid'), isFalse);
      expect(data['email'], 'test@test.fr');
      expect(data['role'], 'owner');
    });

    test('isStudent et isOwner reflètent correctement le rôle', () {
      final student = UserModel(
        uid: '1',
        email: 'a@a.fr',
        role: 'student',
        fullName: 'A',
        createdAt: DateTime.now(),
      );
      final owner = UserModel(
        uid: '2',
        email: 'b@b.fr',
        role: 'owner',
        fullName: 'B',
        createdAt: DateTime.now(),
      );

      expect(student.isStudent, isTrue);
      expect(student.isOwner, isFalse);
      expect(owner.isOwner, isTrue);
      expect(owner.isStudent, isFalse);
    });

    test('copyWith() ne modifie que les champs fournis', () {
      final original = UserModel(
        uid: '1',
        email: 'a@a.fr',
        role: 'student',
        fullName: 'Alice',
        createdAt: DateTime(2026, 1, 1),
      );
      final updated = original.copyWith(fullName: 'Alice Dupont');

      expect(updated.fullName, 'Alice Dupont');
      expect(updated.email, original.email); // inchangé
      expect(updated.uid, original.uid); // inchangé
      expect(updated.createdAt, original.createdAt); // inchangé
    });
  });
}
