import 'package:cloud_firestore/cloud_firestore.dart';

/// Représente un utilisateur de l'application Stud'Home.
///
/// Un utilisateur peut avoir deux rôles distincts :
/// - "student"  -> peut rechercher des logements, les mettre en favoris,
///                 et bénéficier des offres réservées aux étudiants.
/// - "owner"    -> peut publier des annonces de logement.
///
/// Ce modèle est la traduction Dart de la structure stockée dans la
/// collection Firestore `users`.
class UserModel {
  final String uid;
  final String email;
  final String role; // "student" ou "owner"
  final String fullName;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.fullName,
    required this.createdAt,
  });

  /// Construit un [UserModel] à partir d'un document Firestore.
  ///
  /// [doc] est le DocumentSnapshot récupéré depuis la collection `users`.
  /// On utilise `??` pour fournir des valeurs par défaut robustes si un
  /// champ venait à manquer (évite les crashs en cas de document incomplet).
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      fullName: data['fullName'] ?? '',
      // Les dates Firestore sont stockées en Timestamp : on les convertit
      // en DateTime Dart. On protège aussi contre une valeur nulle.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convertit l'instance en Map pour l'écriture dans Firestore.
  ///
  /// Note : on n'inclut volontairement pas `uid` dans le Map, car il
  /// correspond à l'ID du document lui-même (pas un champ interne).
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role,
      'fullName': fullName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Utilitaire pratique pour vérifier rapidement le rôle dans les Views.
  bool get isStudent => role == 'student';
  bool get isOwner => role == 'owner';

  /// Permet de créer une copie modifiée de l'utilisateur (utile pour
  /// les mises à jour partielles côté Controller).
  UserModel copyWith({String? email, String? role, String? fullName}) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt,
    );
  }
}
