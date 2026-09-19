# Stud'Home

Application mobile de logement étudiant — prototype développé en Flutter avec une architecture **MVC**, un backend **Firebase** (Auth + Firestore) et un hébergement photo **Cloudinary**.

## Objectif

Stud'Home met en relation étudiants et propriétaires autour de la recherche de logement. L'étudiant peut chercher, filtrer, mettre en favori et contacter un propriétaire ; le propriétaire peut publier, suivre et gérer ses annonces. Un algorithme de détection de doublons évite qu'une même offre publiée par plusieurs agences ne pollue le fil de recherche.

Ce projet est un prototype réalisé dans le cadre d'un cours de développement mobile — il suit le dossier de conception technique fourni (architecture MVC, Firebase, Provider) tout en documentant les écarts et ajouts survenus en cours de réalisation.

## Fonctionnalités principales

- **Authentification** : inscription en 2 étapes (choix du rôle étudiant/propriétaire), connexion, déconnexion sécurisée
- **Recherche** : filtres (budget, meublé, aides au logement, garantie Visale), recherche texte (ville/titre), tirer-pour-actualiser
- **Fiche détaillée** : carrousel photo swipable avec pagination, badges, prix, description, carte (placeholder)
- **Dépôt d'annonce** : formulaire complet avec upload multi-photos vers Cloudinary
- **Détection de doublons** : regroupement automatique des annonces similaires (ville + surface ± 2m² + adresse) — une seule carte affichée par groupe dans le fil de recherche, avec accès aux offres alternatives depuis la fiche détaillée
- **Favoris** : ajout/retrait depuis le fil ou la fiche détaillée, écran dédié de consultation
- **Prise de contact** : modale affichant le nom et l'e-mail du propriétaire d'une annonce
- **Suivi des annonces (propriétaire)** : consultation, archivage réversible et suppression définitive de ses propres annonces
- **Animations** : apparition en cascade des cartes, retour visuel animé sur le bouton favori, confirmations animées (Lottie) lors de l'inscription et de la publication d'une annonce

## Technologies et packages utilisés

| Composant                          | Techno                                                              |
| ---------------------------------- | ------------------------------------------------------------------- |
| Frontend                           | Flutter (Dart)                                                      |
| Authentification                   | Firebase Authentication (e-mail / mot de passe)                     |
| Base de données                   | Cloud Firestore                                                     |
| Stockage photos                    | Cloudinary (voir*Difficultés rencontrées*)                      |
| Gestion d'état                    | Provider (`ChangeNotifier`)                                       |
| Sélection de photos               | `image_picker`                                                    |
| Requêtes HTTP (upload Cloudinary) | `http`                                                            |
| Animations                         | `flutter_animate`, `lottie`                                     |
| Tests                              | `flutter_test`, `fake_cloud_firestore`, `firebase_auth_mocks` |

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

## Installation

### 1. Cloner le projet et installer les dépendances

```bash
flutter pub get
```

### 2. Configurer Firebase

1. Créer un projet sur [console.firebase.google.com](https://console.firebase.google.com)
2. Activer **Authentication** (e-mail/mot de passe) et **Cloud Firestore**
3. Ne pas activer Firebase Storage (non utilisé, voir *Difficultés rencontrées*)
4. Depuis la racine du projet :
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   → génère `lib/firebase_options.dart`

### 3. Configurer Cloudinary

1. Créer un compte sur [cloudinary.com](https://cloudinary.com)
2. Récupérer le **Cloud name** (Dashboard)
3. Créer un **Upload preset** en mode **Unsigned** (Settings → Upload)
4. Renseigner ces deux valeurs dans `lib/config/cloudinary_config.dart`

### 4. Ajouter les animations Lottie

Télécharger 3 animations gratuites depuis [LottieFiles](https://lottiefiles.com) et les placer dans :

```
assets/animations/loading.json
assets/animations/success.json
assets/animations/empty_state.json
```

### 5. ⚠️ Sécuriser les règles Firestore avant toute démo publique

Le projet est actuellement en mode test Firestore (lecture/écriture ouvertes à tous). À corriger avant toute mise en ligne — voir *Difficultés rencontrées*.

### 6. Index Firestore composites

Ces requêtes nécessitent un index composite (Firestore fournit un lien de création automatique dans les logs d'erreur au premier lancement) :

- `properties` : `countryCode` (==) + `city` (==)
- `properties` : `ownerId` (==) + `createdAt` (desc)
- `properties` : `city` (==) + `createdAt` (desc)

## Lancement de l'application

```bash
flutter run
```

Sélectionner un émulateur Android/iOS ou un appareil physique connecté. Créer d'abord un compte (rôle étudiant ou propriétaire) depuis l'écran d'inscription — aucune donnée de démo n'est pré-chargée dans Firestore.

## Tests réalisés

### Tests unitaires

```bash
flutter test
```

| Fichier                                                   | Couverture                                                                          |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `test/models/user_model_test.dart`                      | Sérialisation`UserModel`, valeurs par défaut, getters de rôle                  |
| `test/models/property_model_test.dart`                  | Sérialisation`PropertyModel`, `formattedPrice`, `copyWith`                   |
| `test/controllers/deduplication_controller_test.dart`   | 7 scénarios de détection de doublons                                              |
| `test/controllers/property_controller_test.dart`        | Création Firestore, filtrage, favoris, comptage de cluster                         |
| `test/controllers/property_controller_extras_test.dart` | Favoris (récupération complète), regroupement d'affichage, archivage/suppression |
| `test/controllers/auth_controller_test.dart`            | Récupération de profil tiers (prise de contact)                                   |

Firestore et Firebase Auth sont simulés en mémoire (`fake_cloud_firestore`, `firebase_auth_mocks`) — aucune connexion réseau ni vrai projet Firebase requis pour lancer les tests.

### Tests d'intégration manuels

Une checklist complète du parcours utilisateur (inscription → dépôt → détection de doublon → filtrage → favoris → contact → suivi propriétaire) est disponible dans `docs/integration_tests_checklist.md`, à exécuter avant chaque livraison.

## Captures d'écran

```markdown
![demonstration](assets\demo\demo_studhome.mp4)
```

## Difficultés rencontrées

- **Firebase Storage devenu payant** : depuis février 2026, Firebase Storage exige le plan Blaze (carte bancaire requise) même pour un usage restant dans le quota gratuit. Bascule vers **Cloudinary** pour l'hébergement des photos, sans impact sur le reste de l'architecture (seuls `CloudinaryService` et `CloudinaryConfig` en dépendent).
- **Bugs de redirection liés à la pile de navigation** : après une déconnexion ou une inscription réussie, `AuthGate` changeait bien d'état en interne, mais restait invisible car caché sous des écrans empilés via `Navigator.push`. Correction par `Navigator.popUntil((route) => route.isFirst)` pour revenir explicitement à la racine de la pile.
- **Modale de confirmation bloquante** : une `showDialog(barrierDismissible: false, ...)` censée se fermer seule après un délai ne se fermait jamais, car le `Future.delayed` était placé après le `await showDialog(...)` (donc inatteignable) plutôt qu'à l'intérieur du `builder`.
- **Requêtes Firestore invalides** : combiner un filtre d'inégalité (`where('priceAmount', isLessThanOrEqualTo: ...)`) avec un tri sur un champ différent (`orderBy('createdAt')`) est rejeté par Firestore — règle qui impose que le premier tri porte sur le même champ que l'inégalité filtrée. Résolu en traitant ce filtre côté client, comme les autres filtres booléens.
- **Erreurs silencieuses sur index manquant** : certaines requêtes composées (ex: `where('ownerId', ...) + orderBy('createdAt', ...)`) nécessitent un index Firestore composite à créer manuellement au premier lancement — sans `try/catch` explicite, l'erreur était masquée et l'écran affichait à tort "aucune annonce" au lieu du vrai message d'erreur.
- **Tailles d'interface trop petites à l'usage réel** : les écrans Flutter ont été traduits depuis une maquette React affichée dans un cadre de démo fixe (320×680px, pensé pour un aperçu desktop). Les tailles de police copiées telles quelles (10-17px) se sont révélées nettement en-dessous des conventions mobiles standard une fois rendues sur un vrai appareil — correction en cours via une échelle de texte centralisée.

## Auteur

**Jules Matiéyendou DJANGBADJA**
*Cours de développement mobile — Niveau avancé*
