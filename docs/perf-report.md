---
title: Mesures de performance — CopyDraft
phase: 4 — Implémentation (BMAD), story S-9.1
date: 2026-08-03
author: Sadok
status: partiel — à compléter avant la livraison
---

# Mesures de performance

Cibles du PRD §5 et du brief. Chaque mesure indique comment la reproduire.

## Conditions

- Machine : Apple Silicon, macOS 26.6.
- Build : `./Scripts/build-app.sh` (release, universel arm64 + x86_64), signature ad hoc.
- Application lancée en agent, capture active, historique de 3 éléments.

## Résultats

| Cible | Exigence | Mesuré | Verdict |
|---|---|---|---|
| CPU au repos, capture active | < 0,5 % (NFR-1) | **0,0 %** sur 5 relevés espacés de 5 s | ✅ |
| Mémoire résidente | < 80 Mo (NFR-2) | **41 Mo** (historique quasi vide) | ✅ partiel |
| Filtrage de la recherche | < 16 ms sur 500 éléments (FR-36) | à mesurer | ⏳ |
| Ouverture de la popup | < 150 ms perçus (NFR-3) | à mesurer | ⏳ |
| Popup sans vol de focus | panneau non clé, app inactive (FR-19) | **vérifié** : journal `mode eventTap, clé false, active false` | ✅ |
| Collage réel dans l'app active | contenu inséré (FR-33) | **vérifié** : `⌘2` et `↩︎` insèrent dans TextEdit, focus conservé | ✅ |
| Repli sans autorisation | copie seule (FR-34) | **vérifié** : presse-papiers rempli, aucune frappe synthétisée | ✅ |
| Connexions réseau | aucune (NFR-5) | aucune API réseau liée ; à confirmer par `nettop` | ⏳ |
| Chiffrement effectif sur disque | contenu illisible (NFR-6) | **vérifié** : aucun contenu copié retrouvé dans `history.sqlite` ni son WAL | ✅ |

### Reproduire

```sh
# CPU et mémoire au repos
open dist/CopyDraft.app
for i in 1 2 3 4 5; do ps -o %cpu=,rss= -p $(pgrep -x CopyDraft); sleep 5; done

# Absence de contenu en clair sur le disque
printf 'phrase-temoin-unique' | pbcopy && sleep 2
strings ~/Library/Application\ Support/CopyDraft/history.sqlite* | grep -c 'phrase-temoin-unique'   # doit rendre 0

# Permissions
stat -f "%Sp %N" ~/Library/Application\ Support/CopyDraft/history.sqlite*
```

## Restant à mesurer

1. **Latence d'ouverture de la popup** — instrumenter `PopupController.show()` avec
   `ContinuousClock` et relever la médiane sur 20 ouvertures, historique plein.
2. **Filtrage** — jeu de 500 éléments, mesurer `HistoryStore.filter` sur des requêtes de 1 à
   5 caractères.
3. **Mémoire à 500 éléments dont 20 images** — remplir l'historique, relever le RSS.
4. **Absence de trafic réseau** — `nettop -p $(pgrep -x CopyDraft)` pendant une session
   d'usage normal.
5. **Consommation d'énergie** — laisser tourner une heure et relever l'impact énergétique
   dans le moniteur d'activité, capture active à 0,4 s.

Ces mesures sont à faire une fois toutes les surfaces livrées : elles conditionnent la
clôture de la story S-9.1 et le critère d'acceptation n° 8 du cahier des charges.
