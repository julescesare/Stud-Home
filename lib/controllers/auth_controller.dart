import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

/// Contrôleur responsable de toute la logique d'authentification.
///
/// Rôle dans l'architecture MVC :
/// - Fait le lien entre Firebase Auth (identifiants email/mot de passe)
///   et Firestore (profil métier stocké dans `UserModel`).
/// - Expose `currentUser` aux Views via Provider ; toute vue qui écoute
///   ce Controller se reconstruit automatiquement quand l'utilisateur
///   se connecte, se déconnecte, ou que son profil change.
///
/// Utilisation typique dans une View :
/// ```dart
/// final auth = context.watch<AuthController>();
/// if (auth.currentUser == null) return LoginScreen();
/// ```
class AuthController extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthController({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    // On écoute les changements de session Firebase (connexion, déconnexion,
    // expiration du token) pour garder `_currentUser` synchronisé en
    // permanence, même si l'utilisateur ne passe pas par nos méthodes
    // signIn()/signOut() (ex: token expiré).
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  // --- Getters exposés aux Views ---

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Réagit à chaque changement d'état d'authentification Firebase.
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }
    // L'utilisateur est authentifié côté Firebase Auth : on va chercher
    // son profil métier complet dans Firestore (rôle, nom, etc.).
    await _loadUserProfile(firebaseUser.uid);
  }

  /// Charge le document Firestore `users/{uid}` et met à jour `_currentUser`.
  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      _errorMessage = "Impossible de charger le profil utilisateur.";
    }
    notifyListeners();
  }

  /// Inscription d'un nouvel utilisateur.
  ///
  /// Crée d'abord le compte dans Firebase Auth, puis écrit le profil
  /// métier correspondant dans Firestore (`UserModel`). Les deux étapes
  /// sont nécessaires : Firebase Auth ne connaît que l'email/mot de passe,
  /// c'est Firestore qui porte le rôle (étudiant/propriétaire) et le nom.
  ///
  /// Retourne `true` en cas de succès, `false` sinon (voir [errorMessage]).
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role, // "student" ou "owner"
  }) async {
    _setLoading(true);
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final newUser = UserModel(
        uid: uid,
        email: email,
        role: role,
        fullName: fullName,
        createdAt: DateTime.now(),
      );

      // Écriture du profil métier dans Firestore.
      await _firestore.collection('users').doc(uid).set(newUser.toFirestore());

      _currentUser = newUser;
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = "Une erreur inattendue est survenue.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Connexion d'un utilisateur existant.
  ///
  /// Le profil Firestore est ensuite chargé automatiquement via
  /// [_onAuthStateChanged], déclenché par Firebase Auth après succès.
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = "Une erreur inattendue est survenue.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Déconnexion. `_currentUser` repasse à `null` via [_onAuthStateChanged].
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Récupère le profil d'un utilisateur quelconque à partir de son uid —
  /// utilisé notamment pour afficher les coordonnées d'un propriétaire
  /// sur la fiche détaillée d'une annonce (property.ownerId).
  /// Contrairement à `_loadUserProfile()`, ne modifie pas `_currentUser`.
  Future<UserModel?> fetchUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Traduit les codes d'erreur Firebase en messages compréhensibles
  /// pour un utilisateur français — évite d'exposer des messages
  /// techniques en anglais dans l'UI.
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "Cette adresse e-mail est déjà utilisée.";
      case 'invalid-email':
        return "L'adresse e-mail n'est pas valide.";
      case 'weak-password':
        return "Le mot de passe doit contenir au moins 6 caractères.";
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return "E-mail ou mot de passe incorrect.";
      case 'user-disabled':
        return "Ce compte a été désactivé.";
      case 'too-many-requests':
        return "Trop de tentatives. Réessayez plus tard.";
      default:
        return "Erreur d'authentification (${e.code}).";
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Permet à une View d'effacer le message d'erreur affiché
  /// (ex: quand l'utilisateur recommence à taper dans un champ).
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
