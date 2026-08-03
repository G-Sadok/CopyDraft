════════════════════════════════════════════════════════════════════════════
  COPYDRAFT — À LIRE EN PREMIER
  Historique de presse-papiers pour macOS
════════════════════════════════════════════════════════════════════════════

  (English version below — scroll down)


  ⚠️  macOS VA REFUSER D'OUVRIR L'APPLICATION AU PREMIER LANCEMENT.
      C'est normal, et ce n'est pas un virus. Explication et marche à
      suivre juste en dessous.


────────────────────────────────────────────────────────────────────────────
  POURQUOI CE REFUS
────────────────────────────────────────────────────────────────────────────

  macOS n'ouvre sans broncher que les applications « notarisées » : leur
  auteur a payé un compte Apple Developer (99 €/an) et a soumis le logiciel
  à Apple pour analyse.

  CopyDraft est gratuit et ouvert : son code est public, mais il n'est pas
  notarisé. macOS ne peut donc pas garantir son innocuité, et affiche :

      « Apple n'a pas pu vérifier que "CopyDraft" ne contenait pas
        de logiciel malveillant. »

  Le bouton proposé est « Déplacer vers la corbeille ». NE CLIQUEZ PAS
  DESSUS. Suivez les étapes ci-dessous.

  Vous pouvez vérifier par vous-même ce que fait l'application : tout le
  code source est lisible sur https://github.com/G-Sadok/CopyDraft


────────────────────────────────────────────────────────────────────────────
  ÉTAPE 1 — INSTALLER
────────────────────────────────────────────────────────────────────────────

  Dans la fenêtre du disque que vous venez d'ouvrir, faites glisser l'icône
  CopyDraft sur le dossier Applications, juste à côté.


────────────────────────────────────────────────────────────────────────────
  ÉTAPE 2 — AUTORISER L'OUVERTURE
────────────────────────────────────────────────────────────────────────────

  1. Ouvrez le dossier Applications, double-cliquez sur CopyDraft.

  2. Le refus s'affiche. Cliquez sur « Terminé » ou « Annuler ».
     Surtout pas sur « Déplacer vers la corbeille ».

  3. Ouvrez  Réglages Système  →  Confidentialité et sécurité.

  4. Descendez jusqu'à la section « Sécurité », en bas. Vous y lirez :

         « "CopyDraft" a été bloqué car il ne provient pas d'un
           développeur identifié. »

     Cliquez sur le bouton  « Ouvrir quand même »  à droite de ce message.

  5. Confirmez avec votre mot de passe ou Touch ID, puis cliquez une
     dernière fois sur « Ouvrir » dans la fenêtre qui suit.

  Ce parcours n'est à faire qu'une seule fois.

  ┌──────────────────────────────────────────────────────────────────────┐
  │  Variante en une commande, si vous êtes à l'aise avec le Terminal :  │
  │                                                                      │
  │      xattr -dr com.apple.quarantine /Applications/CopyDraft.app     │
  │                                                                      │
  │  Elle retire la marque de mise en quarantaine posée sur tout         │
  │  téléchargement, après quoi l'application s'ouvre normalement.       │
  └──────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────
  ÉTAPE 3 — ACCORDER L'ACCESSIBILITÉ
────────────────────────────────────────────────────────────────────────────

  Au lancement, CopyDraft demande l'accès aux fonctions d'accessibilité.
  C'est la SEULE permission demandée, et elle sert uniquement à coller à
  votre place — c'est-à-dire à taper ⌘V dans l'application où vous êtes.

  1. Cliquez « Ouvrir Réglages Système » dans la fenêtre de CopyDraft.
  2. Activez l'interrupteur en face de CopyDraft.
  3. Revenez à CopyDraft : la fenêtre se met à jour toute seule.

  Sans cette autorisation, l'application reste utilisable : l'élément
  choisi est simplement placé dans le presse-papiers, et vous le collez
  vous-même avec ⌘V.

  ┌──────────────────────────────────────────────────────────────────────┐
  │  L'INTERRUPTEUR EST ACTIVÉ MAIS RIEN NE CHANGE ?                     │
  │                                                                      │
  │  macOS attache l'autorisation à une signature précise, pas à un nom  │
  │  d'application. Une entrée laissée par une version précédente reste  │
  │  visible et cochée, alors qu'elle ne correspond plus à l'application │
  │  installée : vous cochez, et rien ne se passe.                       │
  │                                                                      │
  │  Sélectionnez CopyDraft dans la liste, retirez-le avec le bouton     │
  │  « − », puis rajoutez-le avec « + » en désignant                     │
  │  /Applications/CopyDraft.app. Relancez l'application.                │
  │                                                                      │
  │  À prévoir aussi après chaque mise à jour, tant que l'application    │
  │  n'est pas notarisée par Apple.                                      │
  └──────────────────────────────────────────────────────────────────────┘


────────────────────────────────────────────────────────────────────────────
  ÉTAPE 4 — S'EN SERVIR
────────────────────────────────────────────────────────────────────────────

  CopyDraft vit dans la barre de menus, en haut à droite : une petite icône
  de presse-papiers. Il n'y a ni icône dans le Dock, ni fenêtre au
  démarrage — c'est voulu.

  LE GESTE, EN TROIS SECONDES

      1. Copiez comme d'habitude, n'importe où (⌘C).
      2. Là où vous voulez coller, appuyez sur  ⇧⌘V  (maj + cmd + V).
         La liste apparaît au curseur, sans voler le focus.
      3. Appuyez sur ↩︎ pour le premier élément, ou ⌘1 à ⌘9 pour coller
         directement le n-ième.

  TOUS LES RACCOURCIS, POPUP OUVERTE

      ⇧⌘V           Ouvre la popup (modifiable dans les réglages)
      ⌥⇧⌘V          Ouvre la popup en mode « coller sans mise en forme »
      ↑ ↓           Déplace la sélection
      ⌥↑ ⌥↓         Début / fin de liste
      ↩︎             Colle dans l'application active et ferme
      ⇧↩︎            Colle sans mise en forme
      ⌘1 … ⌘9, ⌘0   Colle directement le n-ième élément
      ⌘P            Épingle / désépingle l'élément sélectionné
      ⌘C            Copie sans coller
      ⌫             Supprime l'élément sélectionné
      Échap         Vide la recherche, puis ferme la popup
      A-Z, 0-9      Tapez : la recherche se remplit toute seule

  RECHERCHER
      Ouvrez la popup et tapez. La recherche porte sur le contenu ET sur
      l'application d'origine : taper « safari » retrouve ce que vous aviez
      copié depuis Safari.

  ÉPINGLER
      ⌘P met l'élément dans la section « Épinglés », en tête de liste. Il
      n'est jamais supprimé automatiquement, même au redémarrage.

  SUSPENDRE LA CAPTURE
      Le bouton pause, en bas de la popup, arrête l'enregistrement le temps
      d'une manipulation sensible. Un bandeau ambre le rappelle.

  RÉGLAGES
      Clic sur l'icône de la barre de menus → Réglages… (⌘,)
      Cinq onglets : Général, Raccourci, Popup, Confidentialité, Apparence.
      Vous y changez le raccourci, la taille de l'historique (10 à 500), la
      position de la popup, la liste des applications exclues, le thème.

  L'ICÔNE N'APPARAÎT PAS DANS LA BARRE DE MENUS ?
      Si vous utilisez Hidden Bar, Bartender ou Ice, ils rangent les
      nouveaux éléments dans leur zone masquée. Maintenez ⌘ et faites
      glisser l'icône à droite du séparateur pour la rendre permanente.


────────────────────────────────────────────────────────────────────────────
  CE QUE COPYDRAFT NE FAIT PAS
────────────────────────────────────────────────────────────────────────────

  • Rien ne quitte votre Mac. Aucun compte, aucun serveur, aucune mesure
    d'audience. L'application n'embarque même pas de code réseau.

  • Les mots de passe ne sont jamais enregistrés. Les contenus marqués
    confidentiels par les gestionnaires de mots de passe sont rejetés avant
    même d'être lus, et ce comportement ne peut pas être désactivé.

  • Le clavier n'est écouté que pendant que la popup est ouverte, jamais en
    arrière-plan.

  • L'historique est chiffré sur le disque, avec une clé propre à votre Mac
    rangée dans le Trousseau.


────────────────────────────────────────────────────────────────────────────
  DÉSINSTALLER
────────────────────────────────────────────────────────────────────────────

  Quittez CopyDraft (icône de la barre de menus → Quitter), puis mettez
  /Applications/CopyDraft.app à la corbeille. Pour effacer aussi
  l'historique :

      rm -rf ~/Library/Application\ Support/CopyDraft


  Code source, questions et signalements :
  https://github.com/G-Sadok/CopyDraft


════════════════════════════════════════════════════════════════════════════
  ENGLISH
════════════════════════════════════════════════════════════════════════════

  ⚠️  macOS WILL REFUSE TO OPEN THE APP ON FIRST LAUNCH. This is expected
      and it is not a virus. Steps below.


  WHY THE REFUSAL

  macOS only opens "notarised" apps without complaint — apps whose author
  pays for an Apple Developer account (99 €/year) and submits the software
  to Apple for scanning. CopyDraft is free and open source but not
  notarised, so macOS says:

      "Apple could not verify "CopyDraft" is free of malware."

  The button it offers is "Move to Trash". DO NOT CLICK IT. Follow the
  steps below. You can audit the app yourself: the whole source is at
  https://github.com/G-Sadok/CopyDraft


  STEP 1 — INSTALL
  Drag the CopyDraft icon onto the Applications folder next to it.


  STEP 2 — ALLOW IT TO OPEN

  1. Open Applications, double-click CopyDraft.
  2. The refusal appears. Click "Done" or "Cancel" — never "Move to Trash".
  3. Open  System Settings  →  Privacy & Security.
  4. Scroll down to the "Security" section. You will read:

         ""CopyDraft" was blocked because it is not from an
           identified developer."

     Click  "Open Anyway"  next to that message.
  5. Confirm with your password or Touch ID, then click "Open" once more.

  You only do this once.

      Terminal alternative, one command:
          xattr -dr com.apple.quarantine /Applications/CopyDraft.app


  STEP 3 — GRANT ACCESSIBILITY

  On launch, CopyDraft asks for Accessibility access. It is the ONLY
  permission it requests, and it exists solely so the app can paste on your
  behalf — that is, press ⌘V in the app you are working in.

  1. Click "Open System Settings" in the CopyDraft window.
  2. Turn on the switch next to CopyDraft.
  3. Come back: the window updates on its own.

  Without it the app still works: the item you pick goes to the clipboard
  and you paste it yourself with ⌘V.

      SWITCH IS ON BUT NOTHING HAPPENS?
      macOS ties the grant to a precise code signature, not to an app
      name. An entry left by an earlier version stays listed and ticked
      while no longer matching the installed app — you tick it and nothing
      changes. Select CopyDraft in the list, remove it with "−", add it
      again with "+" pointing at /Applications/CopyDraft.app, and relaunch.
      Expect this after each update until the app is notarised by Apple.


  STEP 4 — USE IT

  CopyDraft lives in the menu bar, top right. No Dock icon, no window at
  launch — by design.

  THE GESTURE

      1. Copy as usual, anywhere (⌘C).
      2. Where you want to paste, press  ⇧⌘V  (shift + cmd + V).
         The list appears at the pointer without stealing focus.
      3. Press ↩︎ for the first item, or ⌘1–⌘9 to paste the n-th directly.

  ALL SHORTCUTS, POPUP OPEN

      ⇧⌘V           Open the popup (customisable in Settings)
      ⌥⇧⌘V          Open in "paste as plain text" mode
      ↑ ↓           Move the selection
      ⌥↑ ⌥↓         Jump to start / end of list
      ↩︎             Paste into the active app and close
      ⇧↩︎            Paste as plain text
      ⌘1 … ⌘9, ⌘0   Paste the n-th item directly
      ⌘P            Pin / unpin the selected item
      ⌘C            Copy without pasting
      ⌫             Delete the selected item
      Esc           Clear the search, then close
      A-Z, 0-9      Just type: the search fills itself

  SEARCH covers the content AND the source application — typing "safari"
  brings back what you copied from Safari.

  PIN with ⌘P: the item moves to the "Pinned" section and is never removed
  automatically, not even on restart.

  PAUSE capture with the pause button at the bottom of the popup while you
  handle something sensitive.

  SETTINGS: menu bar icon → Settings… (⌘,). Five tabs: General, Shortcut,
  Popup, Privacy, Appearance.

  NO ICON IN THE MENU BAR? Menu bar managers (Hidden Bar, Bartender, Ice)
  park new items in their hidden area. Hold ⌘ and drag the icon to the
  right of the separator.


  WHAT COPYDRAFT DOES NOT DO

  • Nothing ever leaves your Mac. No account, no server, no analytics — the
    app does not even link any networking code.
  • Passwords are never recorded. Content flagged confidential by password
    managers is rejected before it is even read, and that cannot be
    switched off.
  • The keyboard is only watched while the popup is open, never in the
    background.
  • The history is encrypted on disk with a key bound to your Mac, kept in
    the Keychain.


  UNINSTALL

  Quit CopyDraft (menu bar icon → Quit), move /Applications/CopyDraft.app
  to the Trash. To erase the history too:

      rm -rf ~/Library/Application\ Support/CopyDraft


  Source, questions and issues:
  https://github.com/G-Sadok/CopyDraft

════════════════════════════════════════════════════════════════════════════
