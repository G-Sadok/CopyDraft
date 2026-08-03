---
title: Product Brief — CopyDraft
phase: 1 — Analyse (BMAD)
date: 2026-08-03
author: Sadok
version: 1.0
inputDocuments:
  - Cahier des charges copyDraft v1.3
  - design-system/CopyDraft Design System.dc.html (v1.0)
  - design-system/screenshots/*.png
status: à valider
---

# Product Brief — CopyDraft

## Résumé exécutif

CopyDraft est un gestionnaire d'historique de presse-papiers pour macOS, résident dans la barre
de menus, qui reproduit le geste `Win + V` de Windows : un raccourci global fait apparaître une
petite fenêtre flottante **au curseur**, sans voler le focus de l'application active, dans
laquelle on retrouve, filtre, épingle et recolle instantanément tout ce qui a été copié.

Le produit vise l'irréprochable sur un périmètre volontairement étroit : capturer, retrouver,
coller. Traitement 100 % local, aucune donnée transmise. Distribution hors App Store
(Developer ID + notarisation), open source, macOS 14+.

---

## Vision produit

### Énoncé du problème

macOS ne conserve qu'**un seul** élément dans le presse-papiers. Toute copie écrase la
précédente. Les conséquences quotidiennes :

- on recopie plusieurs fois la même chose (jeton, URL, extrait de code, adresse) faute de
  pouvoir la retrouver ;
- on perd un contenu long parce qu'une copie intermédiaire l'a écrasé ;
- on maintient des « brouillons tampons » (Notes, TextEdit, un fichier scratch) uniquement pour
  contourner l'absence d'historique ;
- on aller-retourne entre deux fenêtres pour transporter trois valeurs, une par une.

### Impact du problème

Le coût est diffus mais permanent : quelques secondes perdues, dizaines de fois par jour, chez
des profils dont le copier-coller est l'outil principal (développeurs, rédacteurs, support).
S'y ajoute une perte franche — un contenu écrasé et non récupérable — plusieurs fois par
semaine. Les utilisateurs venant de Windows vivent la situation comme une **régression**, le
système d'en face ayant intégré l'historique depuis 2018.

### Pourquoi les solutions existantes ne suffisent pas

| Solution | Ce qu'elle apporte | Où elle s'arrête |
|---|---|---|
| **Presse-papiers Windows (`Win + V`)** | Le bon geste : popup à l'écran, appel immédiat, épinglage | N'existe pas sur macOS. Pas de recherche, pas d'exclusion d'apps |
| **CopyClip** | Léger, discret, barre de menus, exclusion d'apps | L'historique s'ouvre dans un **menu déroulant ancré à la barre de menus** : le regard et la souris doivent remonter en haut de l'écran, loin du point de travail |
| **Maccy / Paste / Raycast** | Fonctionnalités riches | Fenêtre centrée façon lanceur, ou surface large et « app-like » ; certaines sont payantes, lourdes, ou noient l'historique dans une suite d'outils |
| **Brouillon tampon manuel** | Zéro installation | Manuel, désordonné, jamais là quand il faut |

Le manque n'est donc pas « un historique de presse-papiers » — il en existe. Le manque est
**l'ergonomie exacte de Windows sur macOS** : la liste apparaît là où sont déjà les yeux et la
souris, et disparaît aussitôt le collage fait.

### Solution proposée

Un utilitaire de barre de menus qui :

1. capture en continu le presse-papiers (texte, texte enrichi, images) avec l'application
   source, en ignorant les contenus marqués confidentiels ;
2. ouvre sur raccourci global (`⇧⌘V` par défaut, personnalisable) une palette de **360 pt**
   positionnée à `+12/+12` du curseur, non activante — l'application active garde le focus ;
3. se pilote entièrement au clavier : frappe = recherche, `↑↓` = sélection, `↩︎` = collage réel
   dans l'app active, `⌘1–⌘9` = collage direct, `⌘P` = épinglage, `Échap` = fermeture ;
4. persiste les épinglés, purge le reste selon la limite configurée, et n'envoie rien nulle part.

### Différenciateurs

- **Le geste Windows, fidèlement** : au curseur, non activant, refermé après collage. Aucun
  concurrent macOS grand public ne place la liste au curseur par défaut.
- **La recherche que Windows n'a pas**, sur le contenu *et* l'application source.
- **L'exclusion d'applications** que Windows n'a pas (1Password, Trousseau, terminal bancaire).
- **Sobriété assumée** : une seule permission demandée, aucun compte, aucun réseau, un design
  system aligné au pixel sur les conventions macOS plutôt qu'une identité visuelle importée.
- **Ouverture** : code source public, historique local chiffré, vérifiable.

---

## Utilisateurs cibles

### Persona 1 — « Le transfuge Windows » (primaire)

Développeur ou analyste passé sur Mac depuis peu. Son réflexe `Win + V` tombe dans le vide
plusieurs fois par jour. Il ne veut pas apprendre un nouvel outil : il veut retrouver son geste.
**Critère de réussite :** au bout de 10 minutes, le raccourci est dans les doigts et il n'y
pense plus.

### Persona 2 — « Le copieur intensif » (primaire)

Développeur, rédacteur technique, agent de support. Enchaîne des dizaines de copier-coller par
heure entre éditeur, terminal, navigateur, messagerie. A besoin d'épingler 2–3 valeurs de
travail (identifiant de ticket, URL d'environnement, requête SQL) pour la journée.
**Critère de réussite :** ses éléments épinglés restent en tête de liste et survivent au
redémarrage ; `⌘1–⌘3` deviennent des réflexes.

### Persona 3 — « Le prudent » (secondaire)

Utilisateur attentif à la vie privée, réticent à installer un logiciel qui lit tout ce qu'il
copie. **Critère de réussite :** il constate que les mots de passe ne sont jamais enregistrés,
qu'il peut exclure ses applications sensibles, suspendre la capture d'un clic, et que rien ne
sort du Mac.

---

## Objectifs et mesures de succès

| Objectif | Indicateur | Cible v1 |
|---|---|---|
| Le geste est instantané | Délai perçu entre raccourci et popup affichée | < 150 ms |
| L'outil se fait oublier | CPU au repos, capture active | ≈ 0 % (< 0,5 %) |
| L'outil ne pèse rien | Mémoire résidente, 500 éléments | < 80 Mo |
| Le collage aboutit | Taux de collage réussi quand Accessibilité est accordée | 100 % |
| La recherche est immédiate | Filtrage sur 500 éléments | < 16 ms, aucun debounce |
| Rien de sensible n'est capturé | Contenus `ConcealedType` / transitoires enregistrés | 0 |
| Aucune perte | Éléments épinglés perdus après arrêt brutal | 0 |
| Zéro fuite | Connexions réseau sortantes | 0 |

---

## Périmètre

### MVP (v1)

- Capture continue : texte brut, texte enrichi (RTF/HTML), images ; déduplication consécutive.
- Métadonnées par élément : type, contenu, horodatage, application source, taille.
- Historique borné (10 à 500, défaut 25), purge des plus anciens non épinglés.
- Épinglage persistant, section « Épinglés » en tête.
- Popup flottante non activante au curseur, avec repli de bord, recherche live, navigation
  clavier complète, collage réel (`CGEvent ⌘V`) et repli sans permission.
- Collage sans mise en forme (`⇧↩︎`).
- Raccourcis rapides `⌘1–⌘9`, `⌘0`.
- Barre de menus : 5 derniers éléments, pause, tout effacer, réglages, quitter.
- Confidentialité : respect des marqueurs confidentiels, pause manuelle, exclusion
  d'applications, tout effacer avec confirmation.
- Réglages en 5 onglets (Général, Raccourci, Popup, Confidentialité, Apparence).
- Onboarding permission Accessibilité.
- Stockage local chiffré, images en fichiers référencés.
- Localisation FR / EN.

### Hors périmètre v1

| Écarté | Raison |
|---|---|
| Synchronisation iCloud | Rompt la promesse « rien ne quitte le Mac » et double la complexité du modèle de données. Réévalué en v2 |
| Application iOS/iPadOS | Sans synchro, sans objet |
| OCR, transformations IA | Hors du cœur « capturer / retrouver / coller » |
| Fichiers et dossiers copiés | Modèle de données et collage différents (promesses de fichiers) ; v2 |
| Mise à jour automatique (Sparkle) | Le design system prévoit un bouton « Rechercher les mises à jour » ; reporté après la v1, distribution manuelle du `.dmg` d'abord |
| Édition/renommage d'élément | Documenté par le design system (§9) mais non essentiel au geste ; dernier lot du backlog, livré si la v1 est parfaite |

---

## Décisions arbitrées (§12 du cahier des charges)

| # | Question | Décision | Motif |
|---|---|---|---|
| 1 | Distribution | **Hors App Store** — Developer ID + notarisation | Le sandbox du MAS rend `CGEvent`, l'app frontale et l'exclusion d'apps fragiles ou refusables |
| 2 | macOS minimum | **macOS 14 Sonoma** | `MenuBarExtra`, `@Observable`, `Settings` stables ; parc largement couvert en 2026 |
| 3 | Modèle | **Open source, gratuit (MIT)** | Aucune infrastructure de licence ; la vérifiabilité sert l'argument vie privée |
| 4 | Synchro iCloud | **Reportée v2** | Cf. hors périmètre |
| 5 | Fichiers/dossiers | **Reportés v2** | Cf. hors périmètre |
| 6 | Limite par élément | **4 Mo** (aligné Windows) ; au-delà, l'élément est ignoré silencieusement | Protège la base et la mémoire |
| 7 | Identité visuelle | **Définie par le design system §9** : deux feuilles décalées, dégradé bleu-ardoise 165°, gabarit 824/1024, r 24 % ; icône de barre 18×18 en *template image* | Fournie, à produire en asset |
| — | Stockage | **SQLite via GRDB** (choix utilisateur) | Recherche rapide sur des centaines d'éléments, migrations explicites |

---

## Risques et parades

| Risque | Impact | Parade |
|---|---|---|
| Permission Accessibilité refusée ou révoquée | Le collage automatique ne marche plus | Repli documenté : l'élément est mis dans le presse-papiers, toast « Copié — collez avec ⌘V » ; onboarding réaffiché à la révocation |
| `⇧⌘V` entre en conflit (dans plusieurs apps = « coller en adaptant le style ») | Le raccourci par défaut gêne l'utilisateur | Raccourci entièrement personnalisable, enregistreur avec détection de conflits ; défaut du design system conservé, réévalué au test |
| Le sondage du `changeCount` coûte de la batterie | Contredit ENF-1 | Timer à 0,4 s sur `RunLoop.common`, suspendu quand la session est verrouillée ou l'écran endormi ; mesure obligatoire avant livraison |
| Fuite du contenu d'un gestionnaire de mots de passe | Rupture de confiance | Triple barrière : types confidentiels/transitoires, exclusion d'apps, pause manuelle. Testée explicitement |
| La popup vole le focus | Le collage devient impossible | `NSPanel.nonactivatingPanel` + `canBecomeKey` maîtrisé ; test d'acceptation dédié |
| Dérive de périmètre | Fragilise la promesse « simple et parfaite » | Le hors-périmètre ci-dessus fait foi ; toute addition passe par une révision de ce document |

---

## Contraintes

- **Design system** : `design-system/` fait foi pour toute décision visuelle et
  comportementale d'interface. Aucun composant inventé sans validation préalable.
- **Méthode** : BMAD — Analyse → Planification → Conception → Implémentation, artefacts dans
  `docs/`, aucun code applicatif avant validation du plan.
- **Git** : une branche par story issue de `dev`, commits atomiques, jamais de commit direct sur
  `main` ni `dev`, aucune mention d'assistant IA dans l'historique.

---

## Suite

Phase 2 — Planification : `docs/prd.md` (exigences détaillées) puis `docs/epics.md`
(epics et stories). Phase 3 — Conception : `docs/architecture.md` et `docs/ux-design.md`.
