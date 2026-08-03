# CopyDraft

*[English version](README.en.md)*

Historique de presse-papiers pour macOS. Le geste `Win + V` de Windows, sur un Mac : un
raccourci, une petite fenêtre au curseur, l'élément revient là où vous travaillez.

**Traitement 100 % local.** Rien ne quitte votre Mac : pas de compte, pas de serveur, pas de
télémétrie. L'historique est chiffré sur le disque.

---

## Ce que fait CopyDraft

- Capture en continu ce que vous copiez : texte, texte enrichi, images, avec l'application
  d'où vient chaque élément.
- Ouvre au curseur, sur `⇧⌘V`, une palette de 360 pt **sans voler le focus** de l'application
  active.
- Se pilote entièrement au clavier : la frappe cherche, `↑↓` sélectionne, `↩︎` colle vraiment
  dans l'application active, `⌘1`–`⌘9` collent directement, `⌘P` épingle.
- Ignore ce qui ne doit pas être enregistré : mots de passe et contenus marqués confidentiels,
  applications que vous excluez, et tout ce qui passe pendant une pause.

## Installation

1. Téléchargez le paquet depuis la **[page des versions](../../releases)** — ou directement
   **[`releases/CopyDraft-0.1.0.dmg`](releases/CopyDraft-0.1.0.dmg)** — ouvrez-le, glissez
   **CopyDraft** dans *Applications*.
2. **Premier lancement : clic droit sur CopyDraft → « Ouvrir » → « Ouvrir ».** Un double-clic
   afficherait « impossible de vérifier le développeur » : ce paquet est signé localement mais
   pas notarisé par Apple, faute de compte développeur payant. Cette manipulation n'est
   nécessaire qu'une fois.
3. CopyDraft demande l'accès aux **fonctions d'accessibilité**. Cliquez « Ouvrir Réglages
   Système », activez l'interrupteur en face de CopyDraft. C'est la **seule** permission
   demandée, et elle sert uniquement à coller à votre place.
4. L'icône apparaît dans la barre de menus. C'est tout.

Sans cette autorisation, CopyDraft reste utilisable : l'élément choisi est mis dans le
presse-papiers et vous collez vous-même avec `⌘V`.

> **L'icône n'apparaît pas ?** Si vous utilisez un gestionnaire de barre de menus (Hidden Bar,
> Bartender, Ice…), il range les nouveaux éléments dans sa zone masquée. Maintenez **⌘** et
> faites glisser l'icône CopyDraft à droite du séparateur pour la rendre permanente.

## Guide d'utilisation

### Le geste, en trois secondes

1. Copiez comme d'habitude, dans n'importe quelle application (`⌘C`).
2. Là où vous voulez coller, appuyez sur **`⇧⌘V`**. La liste apparaît **au curseur**, et
   l'application où vous travaillez garde le focus.
3. Choisissez : `↩︎` pour le premier élément, `↑↓` puis `↩︎` pour un autre, ou `⌘1` à `⌘9`
   pour coller directement le n-ième. La liste se referme, le texte est là.

### Retrouver quelque chose

Ouvrez la popup et **tapez** : pas besoin de cliquer dans le champ de recherche, la frappe y va
d'elle-même. La recherche porte sur le contenu **et** sur l'application d'origine — « safari »
retrouve ce que vous aviez copié depuis Safari. `Échap` efface la recherche, un second `Échap`
ferme la fenêtre.

### Garder un élément sous la main

`⌘P` épingle l'élément sélectionné : il rejoint la section **Épinglés**, en tête de liste, et
n'est jamais supprimé automatiquement — même quand l'historique déborde, même au redémarrage.
Un second `⌘P` le détache. À la souris, l'épingle apparaît au survol : cliquez-la, elle épingle
sans coller.

### Coller sans la mise en forme

`⇧↩︎` au lieu de `↩︎` : seul le texte brut part, sans police ni couleur d'origine. Un second
raccourci global, `⌥⇧⌘V`, ouvre directement la popup dans ce mode.

### Faire le ménage

- `⌫` supprime l'élément sélectionné (quand la recherche est vide).
- Le bouton corbeille du pied de la popup vide tout l'historique, avec une confirmation qui
  compte les éléments et propose de conserver les épinglés.
- Clic droit sur un élément : coller, coller sans mise en forme, épingler, copier, supprimer,
  et **« Ne jamais enregistrer *cette application* »**.

### Suspendre la capture

Le bouton pause du pied de la popup — ou l'entrée « Suspendre la capture » du menu de la barre
de menus — arrête l'enregistrement le temps d'une manipulation sensible. Un bandeau ambre le
rappelle, l'icône de la barre de menus s'atténue, et l'historique déjà là reste consultable.

### Régler à votre main

Menu de la barre de menus → **Réglages…** (`⌘,`) :

| Onglet | Ce qu'on y règle |
|---|---|
| Général | Lancement à la connexion, taille de l'historique (10 à 500), conservation au redémarrage, langue |
| Raccourci | Le raccourci d'ouverture et celui du collage sans mise en forme, activation de `⌘1`–`⌘9` |
| Popup | Position (au curseur, centrée, sous l'icône), nombre d'éléments visibles, fond translucide |
| Confidentialité | Pause, applications exclues, tout effacer |
| Apparence | Thème clair / sombre / système, couleur d'accent |

### Le menu de la barre de menus

Clic sur l'icône : les cinq derniers éléments (collables d'un clic), la pause, « Tout effacer »,
les réglages, « À propos », « Quitter ». **`⌥`-clic** ouvre directement la popup sous l'icône.

## Raccourcis

| Touche | Action |
|---|---|
| `⇧⌘V` | Ouvre la popup (personnalisable) |
| `⌥⇧⌘V` | Ouvre la popup en mode « coller sans mise en forme » |
| `↑` `↓` | Déplace la sélection |
| `⌥↑` `⌥↓` | Début / fin de liste |
| `↩︎` | Colle et ferme |
| `⇧↩︎` | Colle sans mise en forme |
| `⌘1`–`⌘9`, `⌘0` | Colle directement le *n*-ième élément |
| `⌘P` | Épingle / désépingle |
| `⌘C` | Copie sans coller |
| `⌫` | Supprime la sélection (recherche vide) |
| `Échap` | Vide la recherche, puis ferme |

Toute lettre tapée alimente la recherche, qui porte sur le contenu **et** sur l'application
source.

## Vie privée

- **Rien n'est envoyé nulle part.** Aucune API réseau n'est liée à l'application.
- **Les contenus confidentiels ne sont jamais enregistrés** : les types `ConcealedType`,
  `TransientType` et `AutoGeneratedType` — ceux qu'emploient les gestionnaires de mots de
  passe — sont rejetés avant même d'être lus. Ce comportement n'est pas désactivable.
- **Vous pouvez exclure des applications** (gestionnaire de mots de passe, application
  bancaire) : rien de ce qui en est copié n'entre dans l'historique.
- **Vous pouvez suspendre la capture** d'un clic, le temps d'une manipulation sensible.
- **L'historique est chiffré** (AES-GCM) dans `~/Library/Application Support/CopyDraft`, avec
  une clé rangée dans le Trousseau et propre à ce Mac.
- **Le clavier n'est écouté que pendant l'ouverture de la popup**, jamais en arrière-plan :
  le tap d'événements est installé à l'affichage et retiré à la fermeture.

## Compiler depuis les sources

Prérequis : macOS 14+, Xcode 16 ou ultérieur.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # si Xcode n'est pas actif
swift test                      # plus de 430 tests
./Scripts/make-dev-identity.sh  # une seule fois, voir ci-dessous
./Scripts/build-app.sh          # produit dist/CopyDraft.app (universel)
```

> **L'autorisation d'accessibilité disparaît à chaque recompilation ?** C'est attendu avec une
> signature *ad hoc* : le bundle change d'empreinte, macOS y voit une autre application et
> révoque l'autorisation — la case peut même rester cochée dans les Réglages système alors que
> l'application n'est plus reconnue. `./Scripts/make-dev-identity.sh` crée une identité de
> signature locale et stable ; après un dernier octroi, l'autorisation survit aux builds
> suivants. Si l'onboarding réapparaît malgré tout, décochez puis recochez CopyDraft dans
> *Réglages système → Confidentialité et sécurité → Accessibilité*, ou retirez-le de la liste
> avec le bouton « − » avant de le rajouter.

> Le SwiftPM livré avec les seuls *Command Line Tools* ne sait pas charger de manifeste sur
> certaines installations (`PackageDescription` désynchronisé de sa bibliothèque) :
> `Scripts/build-app.sh` sélectionne automatiquement une installation d'Xcode.

Distribution signée et notarisée :

```sh
CODESIGN_IDENTITY="Developer ID Application: …" \
NOTARY_PROFILE="copydraft" \
./Scripts/sign-notarize.sh
```

## Structure du dépôt

| Dossier | Contenu |
|---|---|
| `Sources/CopyDraftCore` | Capture, confidentialité, historique chiffré, collage, entrées clavier |
| `Sources/CopyDraftUI` | Design system, composants, popup, barre de menus, réglages, onboarding |
| `Sources/CopyDraft` | Assemblage de l'application |
| `design-system/` | Design system de référence et `tokens.json`, source de vérité visuelle |
| `docs/` | Brief produit, PRD, architecture, UX, epics et stories |
| `Scripts/` | Build du bundle, icône, signature et notarisation |

## Publier une version

Un tag `vX.Y.Z` poussé sur le dépôt déclenche `.github/workflows/release.yml`, qui exécute les
tests, construit le paquet universel et **publie une version téléchargeable** sur la page des
versions de GitHub. Le paquet produit par l'automate est signé *ad hoc* : il n'est pas
notarisé, faute de certificat Developer ID côté GitHub.

```sh
git tag -a v0.2.0 -m "CopyDraft v0.2.0"
git push origin v0.2.0
```

La publication peut aussi être relancée à la main depuis l'onglet *Actions* du dépôt.

## Feuille de route

Hors périmètre de cette première version, envisagé ensuite : synchronisation iCloud entre
plusieurs Mac, prise en charge des fichiers et dossiers copiés, édition et renommage des
éléments, mise à jour automatique.

## Licence

MIT. Voir [LICENSE](LICENSE).
