# Stud'Home — Documentation du projet

Application mobile de logement étudiant. Prototype développé en Flutter avec une architecture **MVC**, un backend **Firebase** (Auth + Firestore) et un hébergement photo **Cloudinary**.

Ce document est destiné à toute personne reprenant le projet — il couvre l'architecture, la configuration, ce qui est fait, ce qui ne l'est pas, et les pièges déjà rencontrés.

---

## 1. Stack technique

| Composant | Techno | Rôle |
|---|---|---|
| Frontend | Flutter (Dart) | UI mobile, 100 % en français |
| Auth | Firebase Authentication | E-mail / mot de passe |
| Base de données | Cloud Firestore | Utilisateurs, annonces, favoris |
| Stockage photos | **Cloudinary** (pas Firebase Storage) | Voir §2 pour le pourquoi |
| State management | Provider (`ChangeNotifier`) | Un Controller par domaine métier |
| Animations | `flutter_animate` + `lottie` | Transitions UI et retours visuels |

## 2. Pourquoi Cloudinary et pas Firebase Storage

Depuis février 2026, Firebase Storage exige le plan **Blaze** (facturation à l'usage, carte bancaire obligatoire) même pour rester dans le quota gratuit. Cloudinary offre 25 Go gratuits sans CB et gère la compression d'image via des transformations d'URL — d'où son choix ici. Si Firebase Storage redevient accessible sans CB un jour, la bascule ne toucherait que `CloudinaryService` et `CloudinaryConfig` ; le reste de l'app (Models, Controllers) n'a aucune dépendance directe à ce choix.

## 3. Configuration requise avant de lancer le projet

### 3.1 Firebase
1. Créer un projet sur [console.firebase.google.com](https://console.firebase.google.com)
2. Activer **Authentication** (méthode e-mail/mot de passe) et **Cloud Firestore**
3. **Ne pas activer Storage** (inutile, cf. §2)
4. Depuis la racine du projet :
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   → génère `lib/firebase_options.dart` (fichier généré, ne pas versionner de vraies clés si le repo est public)

### 3.2 Cloudinary
1. Créer un compte sur [cloudinary.com](https://cloudinary.com)
2. Noter le **Cloud name** (Dashboard)
3. Créer un **Upload preset** en mode **Unsigned** (Settings → Upload)
4. Remplir `lib/config/cloudinary_config.dart` avec ces deux valeurs

### 3.3 Dépendances

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  provider: ^6.1.2
  image_picker: ^1.1.2
  flutter_animate: ^4.5.0
  lottie: ^3.1.3
  http: ^1.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  fake_cloud_firestore: ^3.1.0
  firebase_auth_mocks: ^0.14.1
```

### 3.4 Assets Lottie
Télécharger 3 animations gratuites depuis [LottieFiles](https://lottiefiles.com) et les placer dans :
```
assets/animations/loading.json
assets/animations/success.json
assets/animations/empty_state.json
```
Déclarer le dossier dans `pubspec.yaml` (`flutter: assets: - assets/animations/`).

### 3.5 ⚠️ Règles de sécurité Firestore — À FAIRE AVANT TOUTE MISE EN LIGNE

**Le projet est actuellement en mode test Firestore** (lecture/écriture ouvertes à tous, sans authentification). C'est acceptable pour développer, **dangereux pour toute démo publique ou mise en production**. Ce point n'a pas encore été traité — c'est la priorité n°1 pour la personne qui reprend le projet.

### 3.6 Index Firestore composites nécessaires
Ces requêtes nécessitent un index composite (Firestore le propose automatiquement via un lien dans les logs d'erreur la première fois qu'elles s'exécutent) :
- `properties` : `countryCode` (==) + `city` (==) — utilisé par `DeduplicationController`
- `properties` : `ownerId` (==) + `createdAt` (desc) — utilisé par `fetchMyProperties()`
- `properties` : `city` (==) + `createdAt` (desc) — utilisé par `fetchProperties()` quand un filtre de ville est actif

## 4. Architecture (MVC)

```
lib/
  models/                    # UserModel, PropertyModel — sérialisation Firestore
  controllers/                # ChangeNotifier — logique métier, aucun widget ici
    auth_controller.dart
    property_controller.dart
    deduplication_controller.dart   # PAS un ChangeNotifier, utilisé ponctuellement
  services/
    cloudinary_service.dart   # Upload photo — aucune logique métier, juste I/O
  config/
    cloudinary_config.dart
  theme/
    app_colors.dart           # Palette centralisée — TOUJOURS importer plutôt que redéfinir
  views/
    screens/
      auth/          → login_screen.dart, sign_up_screen.dart
      search/        → search_screen.dart
      property/      → property_detail_screen.dart, add_property_screen.dart, my_properties_screen.dart
      favorites/     → favorites_screen.dart
      profile/       → profile_screen.dart
    widgets/                   # Composants réutilisables entre écrans
      property_card.dart
      photo_carousel.dart
  main.dart                    # Init Firebase + Provider + AuthGate (routage selon session)
test/
  models/
  controllers/
docs/
  integration_tests_checklist.md
```

**Règle à respecter en continuant le projet** : une View ne parle jamais directement à Firestore — toujours via un Controller. Un widget qui dépasse une simple ligne de style et pourrait resservir va dans `views/widgets/`, pas dans l'écran qui l'utilise en premier.

## 5. Modèle de données Firestore

```
users/{uid}
  email, role ("student"|"owner"), fullName, createdAt
  favorites/{propertyId}        # sous-collection — juste addedAt, existence = favori

properties/{propertyId}
  ownerId, clusterId (nullable), title, description, propertyType,
  priceAmount, currencyCode, chargesIncluded,
  streetAddress, city, postalCode, countryCode,
  surfaceSqm, isFurnished, acceptsHousingAid, acceptsPublicGuarantee,
  imageUrls (URLs Cloudinary), createdAt, isArchived
```

## 6. Fonctionnalités implémentées

- **Authentification** : inscription 2 étapes (rôle étudiant/propriétaire), connexion, déconnexion
- **Recherche** : filtres (budget, meublé, aides, garantie), recherche texte (ville/titre), pull-to-refresh
- **Fiche détaillée** : carrousel photo swipable, badges, prix, description
- **Dépôt d'annonce** : upload multi-photos vers Cloudinary, formulaire complet
- **Anti-doublons** : détection par ville + surface (±2m²) + adresse normalisée, regroupement d'affichage (une seule carte par cluster dans le fil, avec liste des offres alternatives sur la fiche détaillée)
- **Favoris** : ajout/retrait, écran dédié de consultation
- **Prise de contact** : modale avec nom + e-mail du propriétaire
- **Suivi propriétaire** : écran "Mes annonces" — consultation, archivage réversible, suppression définitive
- **Animations** : apparition en cascade des cartes, pop du bouton favori, loaders Lottie

## 7. Ce qui N'EST PAS fait (dette technique connue)

| Sujet | État |
|---|---|
| **Règles de sécurité Firestore** | En mode test — à sécuriser avant toute mise en ligne (§3.5) |
| Téléphone du propriétaire | Aucun champ "Téléphone" n'existe dans le formulaire d'inscription (`SignUpScreen`), ni pour les étudiants ni pour les propriétaires — `UserModel` n'a pas non plus de champ `phone`. La modale de contact n'affiche donc que l'e-mail. À ajouter si besoin : champ dans `SignUpScreen` (rôle propriétaire), `phone` dans `UserModel`, paramètre dans `AuthController.signUp()` |
| Édition d'une annonce existante | Possible de créer/archiver/supprimer, mais pas de modifier les champs d'une annonce déjà publiée |
| Réinitialisation de mot de passe | Bouton "Mot de passe oublié ?" présent sur l'écran de connexion mais non câblé |
| Carte interactive | Simple placeholder visuel sur la fiche détaillée, pas de vraie carte (Google Maps) |
| Recherche | Filtrage texte côté client (sous-chaîne sur ville/titre), pas de recherche plein texte — Firestore ne le supporte pas nativement |
| Pagination | `fetchProperties()`/`fetchMyProperties()` récupèrent tout en un bloc — à revoir si le catalogue grossit significativement |
| Notifications push | Non implémentées |
| Tests `AuthController.signUp/signIn` | Non testés unitairement (nécessiteraient de mocker les erreurs `FirebaseAuthException`) — seul `fetchUserById()` est couvert |

## 8. Lancer les tests

```bash
flutter test
```
Tests unitaires sur les Models et Controllers (Firestore simulé via `fake_cloud_firestore`, Auth simulée via `firebase_auth_mocks` — aucune connexion réseau nécessaire).

La checklist de tests d'intégration manuels (parcours complet à vérifier avant chaque livraison) est dans `docs/integration_tests_checklist.md`.
