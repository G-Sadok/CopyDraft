---
title: Epics et stories — CopyDraft
phase: 2/4 — Planification & Implémentation (BMAD)
date: 2026-08-03
author: Sadok
version: 1.0
inputDocuments:
  - docs/prd.md
  - docs/architecture.md
  - docs/ux-design.md
status: à valider
---

# Epics et stories — CopyDraft

**Convention** — `S-x.y` : story. Chaque story se développe sur une branche
`feature/s-x-y-<nom-court>` issue de `dev`, fait l'objet de commits atomiques, et n'est
fusionnée qu'après validation QA de ses critères d'acceptation.

**Definition of Done (toutes stories)** : fonctionne sans bug constaté · respecte le design
system · critères d'acceptation vérifiés · tests pertinents verts (`swift test`) · aucune chaîne
codée en dur · aucune mention d'assistant IA dans l'historique Git.

**Ordre d'exécution** : E0 → E1 → E2 → E3 → E4 → E5 → E6 → E7 → E8 → E9. E10 n'est entrepris
que si tout le reste est jugé parfait.

| Epic | Titre | Stories | Priorité | État |
|---|---|---|---|---|
| E0 | Fondations du projet | 4 | P0 | ✅ terminé |
| E1 | Capture du presse-papiers | 5 | P0 | ✅ terminé |
| E2 | Historique et persistance chiffrée | 4 | P0 | ✅ terminé |
| E3 | Popup flottante | 6 | P0 | ✅ terminé |
| E4 | Collage et permission | 3 | P0 | ✅ terminé |
| E5 | Barre de menus | 2 | P0/P1 | ✅ terminé |
| E6 | Réglages | 5 | P0/P1 | ✅ terminé |
| E7 | Onboarding | 1 | P0 | ✅ terminé |
| E8 | Finition : états, mouvement, accessibilité, langues | 4 | P0 | 🔄 langues, états et annonces VoiceOver faits |
| E9 | Performance, livraison, documentation | 4 | P0 | 🔄 icône et docs faites, mesures partielles |
| E10 | Édition d'élément | 1 | P2 | ⏸ non entamé |

*Dernière mise à jour : 2026-08-03. `dev` compile sans avertissement, 423 tests verts. Application vérifiée sur un lancement à froid : capture, classification et chiffrement fonctionnels, 0,0 % de CPU au repos.*

---

## E0 — Fondations du projet

### S-0.1 — Squelette du paquet et cycle de vie de l'agent
*En tant que* développeur, *je veux* un projet qui compile et se lance en agent de barre de
menus, *afin de* disposer d'un socle exécutable.
**Exigences** : NFR-7, FR-39.
**Critères d'acceptation**
- `Package.swift` définit `CopyDraftCore`, `CopyDraftUI`, l'exécutable `CopyDraft` et les cibles de tests, en Swift 6 avec concurrence stricte, macOS 14 minimum.
- `Scripts/build-app.sh` produit un `CopyDraft.app` universel (arm64 + x86_64) lançable.
- L'application démarre sans icône de Dock ni fenêtre (`LSUIElement`), avec une icône temporaire en barre de menus et un item « Quitter » fonctionnel.
- `swift build` et `swift test` passent ; `.gitignore` couvre `.build/`, `.DS_Store`, artefacts de build.

### S-0.2 — Tokens du design system
*En tant que* développeur d'interface, *je veux* les tokens transcrits, *afin de* n'écrire aucune
valeur littérale dans les vues.
**Exigences** : NFR-10, DS §1.
**Critères d'acceptation**
- `Tokens.swift` reprend `CD.Color`, `CD.Radius`, `CD.Space`, `CD.Metric`, `CD.Font` du §1.6, plus `CD.Motion` (durées et courbe du §10) et `CD.Material`.
- Les rôles de couleur pointent sur les `NSColor` système lorsqu'un équivalent existe (accent, sélection, séparateur, remplissage).
- `design-system/tokens.json` est extrait du document et versionné comme source de vérité.
- Une vue de démonstration interne affiche tous les tokens en clair et en sombre, et sert de contrôle visuel.

### S-0.3 — Préférences typées
*En tant qu'*utilisateur, *je veux* que mes réglages soient conservés, *afin de* retrouver mon
paramétrage à chaque lancement.
**Exigences** : FR-46, FR-13, FR-16, FR-22, FR-37, FR-45.
**Critères d'acceptation**
- Un type `Preferences` observable expose tous les réglages du PRD avec leurs valeurs par défaut (historique 25, éléments visibles 8, position « au curseur », thème système, conservation activée).
- La lecture et l'écriture passent par `UserDefaults`, sans chaîne de clé dupliquée.
- Toute modification est appliquée immédiatement par les composants concernés, sans redémarrage.
- Tests : valeurs par défaut, persistance, bornes (10–500, 5–12).

### S-0.4 — Chiffrement et clé de trousseau
*En tant qu'*utilisateur, *je veux* que mon historique soit illisible sur disque, *afin de*
protéger ce que je copie.
**Exigences** : NFR-6, ADR-2.
**Critères d'acceptation**
- Une clé AES 256 bits est générée au premier lancement et stockée dans le Trousseau (`AfterFirstUnlockThisDeviceOnly`, non synchronisable).
- `Cipher` chiffre/déchiffre `Data` en AES-GCM ; `ContentHasher` produit un HMAC-SHA256 stable pour la déduplication.
- Le dossier `~/Library/Application Support/CopyDraft/` est créé en `0700`.
- Tests : aller-retour chiffrement, stabilité du HMAC, comportement si la clé est absente (réinitialisation propre, aucun plantage).

---

## E1 — Capture du presse-papiers

### S-1.1 — Moniteur de presse-papiers
**Exigences** : FR-1, FR-8, NFR-1, NFR-4.
**Critères d'acceptation**
- Un timer de 0,4 s sur `RunLoop.common` compare `changeCount` ; aucune lecture du presse-papiers tant que la valeur n'a pas changé.
- Le timer est suspendu à l'endormissement, au verrouillage et à la désactivation de session, repris au réveil sans capturer rétroactivement.
- CPU mesuré < 0,5 % en moyenne sur 5 minutes, capture active.
- Tests : simulation de changements successifs, absence de capture à l'état stable, reprise après suspension.

### S-1.2 — Lecture typée du presse-papiers
**Exigences** : FR-2, FR-3, FR-5, FR-7.
**Critères d'acceptation**
- Lecture par ordre de préférence : image, texte enrichi (RTF/HTML), texte brut ; les représentations utiles au collage fidèle sont conservées.
- Chaque élément porte type, horodatage, application source (identifiant de bundle et nom), taille, dimensions ou nombre de caractères.
- Un contenu de plus de 4 Mo est ignoré silencieusement.
- Tests : chacun des trois types, contenu vide, contenu surdimensionné, presse-papiers sans représentation exploitable.

### S-1.3 — Filtre de confidentialité
**Exigences** : FR-9, FR-10, FR-11.
**Critères d'acceptation**
- `ConcealedType`, `TransientType`, `AutoGeneratedType` et le type 1Password sont rejetés avant toute lecture du contenu, sans réglage permettant de les accepter.
- Une application présente dans la liste d'exclusion voit ses copies ignorées.
- En pause, aucune écriture n'a lieu ; l'historique existant reste lisible.
- Tests : un cas par marqueur, un cas d'exclusion, un cas de pause. **Test de non-régression obligatoire** : copie depuis un gestionnaire de mots de passe → aucune entrée.

### S-1.4 — Classification du contenu
**Exigences** : FR-4, FR-24.
**Critères d'acceptation**
- Détection de `code`, `lien`, `chemin`, `couleur`, `texte enrichi`, `image`, `texte` par heuristiques documentées.
- La projection d'aperçu aplatit les retours à la ligne, tronque en fin de ligne, et au milieu pour URLs et chemins.
- Le texte enrichi conserve gras et italique dans l'aperçu, rien d'autre.
- Tests : un jeu d'exemples par sous-type, y compris cas ambigus.

### S-1.5 — Déduplication
**Exigences** : FR-6.
**Critères d'acceptation**
- Une copie identique au plus récent élément (même type, même HMAC) ne crée pas d'entrée : l'horodatage est mis à jour et l'élément remonte en tête.
- Une copie identique à un élément **plus ancien** crée bien une nouvelle entrée en tête et supprime l'ancienne occurrence.
- Tests : trois copies alternées A, A, B, A.

---

## E2 — Historique et persistance chiffrée

### S-2.1 — Base et migrations
**Exigences** : FR-18, NFR-6.
**Critères d'acceptation**
- Schéma `clip_item` conforme à `docs/architecture.md` §3.2, créé par migration nommée et versionnée.
- Écritures transactionnelles ; une interruption ne laisse jamais de ligne partielle.
- Tests : création à froid, réouverture, migration rejouée sans effet.

### S-2.2 — Stockage des images
**Exigences** : FR-3, FR-23, NFR-2, NFR-6.
**Critères d'acceptation**
- Image d'origine et vignette 56×56 @2× écrites chiffrées dans `Images/` et `Thumbs/`.
- La suppression d'un élément supprime ses fichiers dans la même opération ; aucun orphelin après purge.
- La mémoire résidente reste sous 80 Mo avec 500 éléments dont 20 images.
- Tests : cycle complet écriture/lecture/suppression, détection d'orphelins.

### S-2.3 — Historique en mémoire, limite et purge
**Exigences** : FR-13, FR-14, FR-15, FR-17, NFR-2, ADR-4.
**Critères d'acceptation**
- `HistoryStore` expose la liste ordonnée : épinglés d'abord, puis récents, chacun par date décroissante.
- Au dépassement de la limite configurée, les plus anciens **non épinglés** sont supprimés, fichiers compris ; un épinglé n'est jamais supprimé automatiquement.
- Le contenu complet n'est pas conservé en mémoire : seule une projection de 2 048 caractères et un aperçu de 2 lignes le sont.
- Tests : limite atteinte avec et sans épinglés, changement de limite à chaud (500 → 10).

### S-2.4 — Persistance au redémarrage
**Exigences** : FR-15, FR-16, FR-51, NFR-14.
**Critères d'acceptation**
- Réglage « Conserver l'historique » respecté : décoché, l'historique non épinglé est vidé à l'extinction ; les épinglés survivent dans les deux cas.
- Au premier lancement après redémarrage, l'écran de restauration s'affiche uniquement si le chargement dépasse quelques dizaines de millisecondes.
- Test `kill -9` pendant la capture : aucun élément épinglé perdu.

---

## E3 — Popup flottante

### S-3.1 — Panneau non activant
**Exigences** : FR-19, NFR-3.
**Critères d'acceptation**
- `NSPanel` sans titre ni bordure, `.nonactivatingPanel`, niveau `.floating`, visible sur tous les Spaces, non redimensionnable.
- Le panneau et son contenu sont créés au lancement et réutilisés ; l'ouverture mesure moins de 150 ms du raccourci à l'affichage.
- L'application au premier plan conserve son apparence active à l'ouverture de la popup.
- Test manuel : ouverture au-dessus de Xcode, Safari et Mail, en plein écran comme en fenêtré.

### S-3.2 — Positionnement
**Exigences** : FR-21, FR-22.
**Critères d'acceptation**
- Coin supérieur gauche à `+12/+12` du curseur ; retournement sur l'axe débordant plutôt que décalage ; marge minimale de 8 pt hors barre de menus et Dock.
- La popup est toujours entièrement sur l'écran du curseur, jamais à cheval.
- Les positions « centrée » et « sous l'icône de la barre de menus » suivent les mêmes règles.
- Tests unitaires : les quatre coins d'écran, deux écrans de tailles et d'échelles différentes, Dock à gauche/en bas.

### S-3.3 — Liste et cellules
**Exigences** : FR-17, FR-20, FR-23, FR-24, FR-27.
**Critères d'acceptation**
- Largeur 360, hauteur adaptative de 148 à 564 plafonnée à 60 % de l'écran, *n* éléments visibles selon le réglage.
- Cellules conformes au §2.5 : vignette 28, aperçu 1–2 lignes, métadonnées, épingle, indice `⌘n`, hauteurs 44/60.
- Sections « Épinglés » et « Récents » avec en-têtes 10 pt semibold ; pied affichant « *n* éléments · *m* épinglé(s) ».
- Les quatre états de cellule sont conformes, sélection prioritaire sur survol.
- Contrôle visuel en clair et en sombre face aux maquettes §3.

### S-3.4 — Recherche
**Exigences** : FR-36, FR-49, FR-50.
**Critères d'acceptation**
- Le champ a le focus dès l'ouverture ; le filtrage est instantané sur le contenu et le nom de l'application source, sans debounce.
- La sélection retombe sur le premier résultat ; les indices `⌘n` disparaissent dès qu'une recherche est active.
- Sans résultat : message reprenant le terme cherché, action « Effacer la recherche », pied « 0 sur *n* éléments ».
- Mesure : filtrage sous 16 ms sur 500 éléments.

### S-3.5 — Clavier
**Exigences** : FR-25, FR-32, ADR-6, NFR-9.
**Critères d'acceptation**
- Toutes les touches de la table `docs/ux-design.md` §5 fonctionnent, popup ouverte, sans que l'application active perde le focus (mode nominal).
- Le tap d'événements est installé à l'ouverture et retiré à la fermeture ; aucune écoute en dehors.
- Mode replié documenté et fonctionnel quand l'Accessibilité manque.
- `Échap` vide la recherche puis ferme au second appui ; clic extérieur et perte d'écran actif ferment aussi.
- Test manuel : parcours complet au clavier seul, sans jamais toucher la souris.

### S-3.6 — Épinglage, suppression, menu contextuel
**Exigences** : FR-17, FR-32, FR-38, FR-26.
**Critères d'acceptation**
- `⌘P` et l'épingle fantôme épinglent/désépinglent ; l'élément rejoint « Épinglés » avec un réordonnancement de 140 ms.
- `⌫` supprime la sélection quand la recherche est vide, avec fondu et repli de hauteur de 120 ms.
- Menu contextuel complet conforme au §9, y compris « Ne jamais enregistrer *App*… » qui ajoute l'application aux exclusions.
- L'infobulle d'aperçu étendu apparaît après 800 ms de survol.

---

## E4 — Collage et permission

### S-4.1 — Permission Accessibilité
**Exigences** : FR-34, FR-47, FR-48.
**Critères d'acceptation**
- L'état de la permission est connu au lancement et surveillé en continu ; sa révocation bascule l'application en mode replié sans redémarrage.
- Une action ouvre directement *Réglages système → Confidentialité et sécurité → Accessibilité*.
- Aucun blocage ni message d'erreur intempestif quand la permission manque.

### S-4.2 — Collage réel
**Exigences** : FR-33, FR-34, FR-35.
**Critères d'acceptation**
- L'élément est écrit dans `NSPasteboard` avec toutes ses représentations ; `⇧↩︎` n'écrit que le texte brut.
- La popup se ferme, l'application mémorisée redevient active, puis `⌘V` est synthétisé : le contenu apparaît dans l'application d'origine.
- Sans permission : copie seule et toast « Copié — collez avec ⌘V ».
- Recette manuelle : collage réussi dans Xcode, Safari, Mail, Terminal et Notes, en texte, texte enrichi et image.

### S-4.3 — Toasts
**Exigences** : FR-35.
**Critères d'acceptation**
- Fenêtre non cliquable, centrée, 24 pt au-dessus du bas de l'écran actif ; 180 ms d'entrée, 1,4 s d'affichage, 120 ms de sortie.
- Les quatre libellés du §9 sont couverts ; le nom de l'application cible est correct.
- Deux collages rapprochés ne superposent pas deux toasts.

---

## E5 — Barre de menus

### S-5.1 — Icône et états
**Exigences** : FR-39, FR-40.
**Critères d'acceptation**
- Icône 18×18 en *template image*, opticalement centrée dans 22×22, correcte en clair, en sombre et menu ouvert.
- État pause : même glyphe à 40 % avec deux barres, jamais de pastille rouge.

### S-5.2 — Menu d'accès rapide
**Exigences** : FR-41, FR-12.
**Critères d'acceptation**
- Menu conforme au §6 : 5 derniers éléments avec `⌘1`–`⌘5`, chacun tronqué à une ligne, puis « Ouvrir CopyDraft », pause/reprise à libellé variable, « Tout effacer… », « Réglages… », « À propos », « Quitter ».
- Clic gauche ouvre le menu, `⌥`-clic ouvre la popup sous l'icône.
- Sélectionner un élément du menu le colle comme depuis la popup.
- « Tout effacer… » ouvre l'alerte du §9 avec décompte et case « Conserver les épinglés ».

---

## E6 — Réglages

### S-6.1 — Fenêtre et navigation par onglets
**Exigences** : FR-43, FR-46.
**Critères d'acceptation** : 480 pt de large, hauteur variable, non redimensionnable, 5 onglets en barre d'outils, libellés alignés à droite sur 150 pt et gouttière de 24 pt, conforme au §7 en clair et en sombre.

### S-6.2 — Onglet Général
**Exigences** : FR-42, FR-44, FR-13, FR-16.
**Critères d'acceptation** : démarrage à la connexion via `SMAppService` (bascule vérifiée après redémarrage de session), taille d'historique 10–500 avec texte d'aide, conservation au redémarrage, langue FR/EN appliquée sans redémarrage, version et mention « traitement 100 % local ».

### S-6.3 — Onglet Raccourci
**Exigences** : FR-28, FR-29, FR-30, FR-31, FR-37.
**Critères d'acceptation** : enregistreur avec ses cinq états (repos, défini, écoute, conflit, désactivé), refus argumenté des combinaisons réservées, conservation de l'ancien raccourci en cas de conflit, second raccourci « coller sans mise en forme », bascule du collage rapide `⌘1–⌘9`.

### S-6.4 — Onglets Popup et Apparence
**Exigences** : FR-22, FR-37, FR-45, NFR-8.
**Critères d'acceptation** : position (3 choix), éléments visibles 5–12, fond translucide, affichage de l'application source, fermeture après collage rapide ; thème Clair/Sombre/Système appliqué immédiatement, accent système ou personnalisé, respect de « Réduire les animations ».

### S-6.5 — Onglet Confidentialité
**Exigences** : FR-10, FR-11, FR-12.
**Critères d'acceptation** : bascule d'enregistrement, mention non désactivable des contenus confidentiels, liste d'applications exclues avec ajout par sélecteur et suppression, « Tout effacer… » avec confirmation.

---

## E7 — Onboarding

### S-7.1 — Écran de permission
**Exigences** : FR-47, FR-48.
**Critères d'acceptation**
- 560 × 420 centré non redimensionnable, affiché au premier lancement et à toute révocation.
- État « non accordée » : titre, texte, trois étapes numérotées, indicateur d'état, boutons « Ouvrir les Réglages système » et « Plus tard », note de repli.
- État « accordée » : titre, rappel du raccourci en touches, trois points de confirmation, bouton « Commencer ».
- La bascule entre les deux états se fait **sans action de l'utilisateur** dans la fenêtre.

---

## E8 — Finition

### S-8.1 — États vides et particuliers
**Exigences** : FR-49, FR-50, FR-51, FR-10.
**Critères d'acceptation** : historique vide, aucun résultat, capture en pause et restauration conformes au §5 (glyphe 34–36 pt, titre 13 pt semibold, phrase 11,5 pt, action facultative), sans illustration ni ton badin, opacité dégressive seule pour le chargement.

### S-8.2 — Mouvement
**Exigences** : NFR-10, DS §10.
**Critères d'acceptation** : toutes les durées du tableau §10 respectées, courbe unique, rien au-delà de 180 ms, filtrage et bascule de thème sans animation, durées à 0 ms (fondus à 80 ms) si « Réduire les animations » est actif.

### S-8.3 — Accessibilité
**Exigences** : NFR-9, NFR-11, NFR-12.
**Critères d'acceptation** : contrastes du tableau §10 vérifiés en clair et en sombre, cibles ≥ 22 pt, hauteurs en `min-height` supportant les grandes tailles de texte, repli opaque avec « Réduire la transparence », annonces VoiceOver « type, aperçu, application, horodatage, épinglé » puis « rang *n* sur *m* », ordre de tabulation clos dans la popup, focus rendu à l'app active à la fermeture.

### S-8.4 — Localisation FR / EN
**Exigences** : NFR-13, FR-44.
**Critères d'acceptation** : catalogue de chaînes complet dans les deux langues, aucune chaîne codée en dur, formats de date et de taille localisés, contrôle visuel des deux langues sur toutes les surfaces (les libellés anglais ne débordent pas).

---

## E9 — Performance, livraison, documentation

### S-9.1 — Campagne de mesures
**Exigences** : NFR-1, NFR-2, NFR-3, NFR-5, FR-36.
**Critères d'acceptation** : CPU au repos, mémoire à 500 éléments, latence d'ouverture, temps de filtrage et absence de connexion réseau mesurés et consignés dans `docs/perf-report.md` ; toute cible manquée est corrigée avant la suite.

### S-9.2 — Icône d'application
**Exigences** : §12.7, DS §9.
**Critères d'acceptation** : `.icns` complet (1024 à 16) conforme au §9 — deux feuilles décalées, dégradé bleu-ardoise 165°, liseré blanc 25 %, gabarit 824/1024, r 24 %, une seule feuille à 16 pt ; validé visuellement dans le Finder et le Dock d'aperçu.

### S-9.3 — Signature, notarisation, `.dmg`
**Exigences** : NFR-7.
**Critères d'acceptation** : build universel avec *hardened runtime*, signature Developer ID, notarisation acceptée, ticket agrafé, `.dmg` s'ouvrant sans avertissement Gatekeeper sur un Mac vierge. *Dépend de la disponibilité d'un certificat Developer ID.*

### S-9.4 — Documentation
**Exigences** : §9 du cahier des charges.
**Critères d'acceptation** : `README.md` (présentation, installation, permission, raccourcis, promesse de confidentialité, build depuis les sources), `docs/user-guide.md`, `LICENSE` MIT, `CHANGELOG.md`.

---

## E10 — Édition d'élément (P2, dernier lot)

### S-10.1 — Éditeur
**Exigences** : FR-52, DS §9.
**Critères d'acceptation** : nom facultatif et contenu modifiables, enregistrement conservant l'horodatage d'origine, images non éditables hors leur nom, ouverture depuis le menu contextuel « Renommer… », conforme au §9.

---

## Ordre des branches

```
dev
 ├── feature/s-0-1-squelette      → dev
 ├── feature/s-0-2-tokens         → dev
 ├── …                            → dev
 └── feature/s-9-4-documentation  → dev → main (release v1.0)
```
