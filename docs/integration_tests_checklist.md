# Checklist de tests d'intégration manuels — Stud'Home

Conforme au parcours défini dans le dossier de conception (section 6) :
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

- [ ] Se connecter avec un compte propriétaire → dans le profil, le menu "Mes annonces" est visible (absent pour un compte étudiant, remplacé par "Mes favoris")
- [ ] Depuis "Mes annonces", le bouton flottant "Déposer" est visible et ouvre bien le formulaire
- [ ] Ajouter 2-3 photos → vérifier qu'elles s'affichent en miniature avant soumission
- [ ] Soumettre le formulaire sans titre/description → validation bloque l'envoi
- [ ] Soumettre un formulaire complet → loader "Vérification en cours…" affiché, puis confirmation animée
- [ ] Vérifier dans Cloudinary (Media Library) que les photos ont bien été uploadées
- [ ] Vérifier dans Firestore (`properties`) que le document créé contient les bonnes `imageUrls` (URLs Cloudinary, pas des chemins locaux)

## 4. Détection de doublon (DeduplicationController)

- [ ] Déposer une première annonce : ville "Paris", surface 22, adresse "75 Av. d'Ivry"
- [ ] Déposer une deuxième annonce avec un **autre compte propriétaire**, mêmes ville/surface (±2m²)/adresse (même si écrite différemment, ex. sans majuscules ni virgule)
- [ ] Retourner à l'écran de recherche (Écran 1) → **une seule carte** apparaît pour les deux annonces (pas deux cartes distinctes), avec le badge violet "Offre regroupée (2 agences)"
- [ ] Déposer une troisième annonce correspondante → toujours une seule carte dans le fil, badge mis à jour "(3 agences)"
- [ ] Ouvrir la fiche détaillée de l'annonce affichée → une section "Ce logement est aussi proposé par 2 autres agences" liste les offres alternatives (titre + prix)
- [ ] Cliquer sur une offre alternative → la fiche se remplace par celle de cette annonce (pas d'empilement infini d'écrans si on clique plusieurs fois de suite)
- [ ] Vérifier que le bouton "Contacter le propriétaire" pointe vers le **bon** propriétaire selon l'annonce du groupe actuellement affichée
- [ ] Déposer une annonce avec une surface qui diffère de plus de 2m² → **pas** de regroupement (carte séparée, pas de badge)
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

- [ ] Ajouter une annonce en favori depuis le fil de recherche (cœur rouge + animation "pop") → se déconnecter/reconnecter → le favori est toujours marqué (persistance Firestore vérifiée)
- [ ] Retirer le favori depuis le fil de recherche → vérifier dans Firestore que le document `users/{uid}/favorites/{propertyId}` a bien été supprimé
- [ ] Ouvrir "Mes favoris" depuis le profil (compte étudiant) → les annonces mises en favori s'affichent, avec les mêmes informations que dans le fil de recherche
- [ ] Retirer un favori **depuis l'écran "Mes favoris"** → la carte disparaît immédiatement de la liste, sans avoir à quitter/rouvrir l'écran
- [ ] Aucun favori enregistré → message "Aucune annonce en favori pour l'instant." affiché, pas d'écran vide sans explication
- [ ] Compte propriétaire → le menu "Mes favoris" n'apparaît pas dans le profil (remplacé par "Mes annonces")

## 11. Prise de contact

- [ ] Sur la fiche détaillée d'une annonce, cliquer sur "Contacter le propriétaire" → une modale s'affiche avec un loader bref
- [ ] La modale affiche le **nom complet** et l'**e-mail** du propriétaire ayant publié cette annonce précise
- [ ] Vérifier avec deux annonces de deux propriétaires différents que les coordonnées affichées changent bien en conséquence (pas de coordonnées "figées" ou du mauvais utilisateur)
- [ ] Cas limite : propriétaire supprimé de Firestore après publication de son annonce → message "Propriétaire introuvable" affiché, pas de crash

## 12. Suivi des annonces (MyPropertiesScreen — compte propriétaire)

- [ ] Ouvrir "Mes annonces" depuis le profil → toutes les annonces publiées par ce compte s'affichent (actives ET archivées)
- [ ] Aucune annonce publiée → message "Vous n'avez publié aucune annonce." affiché
- [ ] Depuis cet écran, déposer une nouvelle annonce (bouton "Déposer") → au retour, la liste se rafraîchit automatiquement et la nouvelle annonce apparaît sans action manuelle
- [ ] Archiver une annonce (menu ⋮ → "Archiver") → la carte reste visible ici mais grisée (opacité réduite) avec le badge "Archivée"
- [ ] Vérifier que l'annonce archivée **n'apparaît plus** dans le fil de recherche étudiant (Écran 1)
- [ ] Désarchiver la même annonce (menu ⋮ → "Désarchiver") → redevient visible dans le fil de recherche étudiant
- [ ] Supprimer une annonce (menu ⋮ → "Supprimer") → boîte de confirmation affichée avant toute suppression
- [ ] Confirmer la suppression → l'annonce disparaît de "Mes annonces" ET du fil de recherche étudiant, document bien supprimé dans Firestore
- [ ] Supprimer une annonce qui fait partie d'un cluster → vérifier que le badge "Offre regroupée" des annonces restantes du groupe se met à jour (ex: passe de "3 agences" à "2 agences")
- [ ] Cliquer sur une annonce dans "Mes annonces" → ouvre la fiche détaillée normale (même écran que côté étudiant)

---

## Environnements à couvrir

- [ ] Android (émulateur ou appareil physique)
- [ ] iOS (simulateur ou appareil physique), si disponible
- [ ] Connexion réseau instable / coupée pendant un upload Cloudinary → message d'erreur clair, pas de crash silencieux