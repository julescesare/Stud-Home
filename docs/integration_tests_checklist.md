# Checklist de tests d'intégration manuels — Stud'Home

**Inscription → Dépôt de bien → Détection de doublon → Filtrage côté étudiant.**

À exécuter avant chaque livraison, sur émulateur Android/iOS ou appareil réel.

---

## 1. Inscription (Écran 5)

- [ ] Sélectionner le rôle "Étudiant(e)" → les champs affichés à l'étape 2 correspondent (encart de vérification universitaire visible)
- [ ] Sélectionner le rôle "Propriétaire" → l'encart universitaire n'apparaît pas
- [ ] Étape 1 : laisser un champ vide → le bouton "Continuer" ne fait pas avancer, message d'erreur affiché
- [ ] Étape 1 → 2 : le bouton "← Retour" ramène bien à l'étape 1 avec les champs déjà remplis conservés
- [ ] Étape 2 : mot de passe < 6 caractères → erreur affichée
- [ ] Étape 2 : mot de passe ≠ confirmation → erreur affichée
- [ ] Étape 2 : case CGU non cochée → message d'erreur au clic sur "Créer mon compte", pas de création
- [ ] Créer un compte étudiant valide → vérifier dans Firebase Auth (Console) que l'utilisateur apparaît
- [ ] Vérifier dans Firestore (`users/{uid}`) que le document a été créé avec `role: "student"` et le bon `fullName`
- [ ] Après création, l'app bascule automatiquement vers l'écran de recherche (pas d'écran intermédiaire)
- [ ] Réessayer avec le même e-mail → message "Cette adresse e-mail est déjà utilisée."

## 2. Connexion (Écran 4)

- [ ] Se déconnecter puis se reconnecter avec les identifiants créés à l'étape 1 → accès à l'écran de recherche
- [ ] Mauvais mot de passe → message "E-mail ou mot de passe incorrect."
- [ ] E-mail mal formé (sans @) → erreur de validation avant même l'appel réseau

## 3. Dépôt de bien (Écran 3 — nécessite un compte "Propriétaire")

- [ ] Se connecter avec un compte propriétaire → le bouton flottant "Déposer" est visible (absent pour un compte étudiant)
- [ ] Ajouter 2-3 photos → vérifier qu'elles s'affichent en miniature avant soumission
- [ ] Soumettre le formulaire sans titre/description → validation bloque l'envoi
- [ ] Soumettre un formulaire complet → loader "Vérification en cours…" affiché, puis confirmation animée
- [ ] Vérifier dans Cloudinary (Media Library) que les photos ont bien été uploadées
- [ ] Vérifier dans Firestore (`properties`) que le document créé contient les bonnes `imageUrls` (URLs Cloudinary, pas des chemins locaux)

## 4. Détection de doublon (DeduplicationController)

- [ ] Déposer une première annonce : ville "Paris", surface 22, adresse "75 Av. d'Ivry"
- [ ] Déposer une deuxième annonce avec un **autre compte propriétaire**, mêmes ville/surface (±2m²)/adresse (même si écrite différemment, ex. sans majuscules ni virgule)
- [ ] Retourner à l'écran de recherche (Écran 1) → les deux annonces affichent le badge violet "Offre regroupée (2 agences)"
- [ ] Déposer une troisième annonce correspondante → le badge passe à "(3 agences)"
- [ ] Déposer une annonce avec une surface qui diffère de plus de 2m² → **pas** de regroupement
- [ ] Déposer une annonce dans une autre ville avec adresse identique → **pas** de regroupement

## 5. Filtrage côté étudiant (Écran 1)

- [ ] Se connecter avec un compte étudiant
- [ ] Activer "Meublé" → seules les annonces meublées restent affichées
- [ ] Activer "Éligible APL" → seules les annonces avec `acceptsHousingAid: true` restent affichées
- [ ] Activer "Budget max" → aucune annonce au-dessus de 800€ ne s'affiche
- [ ] Combiner plusieurs filtres → l'intersection des critères est respectée
- [ ] Désactiver tous les filtres → la liste complète réapparaît
- [ ] Aucun résultat pour une combinaison de filtres → illustration "aucun résultat" affichée (pas d'écran blanc ni de crash)

## 6. Déconnexion (ProfileScreen)

- [ ] Depuis l'écran de recherche, ouvrir le profil via l'icône en haut à droite du header
- [ ] Cliquer sur "Se déconnecter" → la boîte de confirmation s'affiche
- [ ] Cliquer sur "Annuler" → reste sur le profil, toujours connecté
- [ ] Cliquer sur "Se déconnecter" (confirmer) → retour immédiat et **visible** sur LoginScreen (pas d'écran figé ou de superposition résiduelle)
- [ ] Reconnexion possible juste après avec les mêmes identifiants

## 7. Confirmation d'inscription (SignUpScreen)

- [ ] Créer un compte avec des informations valides → une modale de succès s'affiche brièvement
- [ ] La modale se ferme **automatiquement** (pas besoin de cliquer) et redirige vers l'écran de recherche
- [ ] Vérifier qu'on ne reste jamais bloqué sur la modale ou sur SignUpScreen/LoginScreen après une inscription réussie

## 8. Confirmation de dépôt d'annonce

- [ ] Publier une annonce valide → la modale Lottie de succès s'affiche
- [ ] La modale se ferme automatiquement après ~1,2s et ramène à l'écran de recherche (pas de blocage indéfini)

## 9. Carrousel photo (fiche détaillée)

- [ ] Ouvrir une annonce avec plusieurs photos → swipe horizontal fonctionne entre les photos
- [ ] Les points de pagination en bas reflètent la photo actuellement affichée
- [ ] La flèche de retour est visible et cliquable quelle que soit la photo affichée (fond blanc + ombre, pas de zone transparente qui se fond dans une photo claire)
- [ ] La flèche de retour et le bouton favori ne sont pas masqués par la barre de statut/l'encoche du téléphone
- [ ] Annonce avec une seule photo → aucun point de pagination affiché (pas de point unique inutile)
- [ ] Annonce sans photo → zone grise de remplacement affichée, pas de crash

## 10. Favoris

- [ ] Ajouter une annonce en favori (cœur rouge + animation "pop") → se déconnecter/reconnecter → le favori est toujours marqué (persistance Firestore vérifiée)
- [ ] Retirer le favori → vérifier dans Firestore que le document `users/{uid}/favorites/{propertyId}` a bien été supprimé

---

## Environnements à couvrir

- [ ] Android (émulateur ou appareil physique)
- [ ] iOS (simulateur ou appareil physique), si disponible
- [ ] Connexion réseau instable / coupée pendant un upload Cloudinary → message d'erreur clair, pas de crash silencieux