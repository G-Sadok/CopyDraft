# CopyDraft

*[Version française](README.md)*

Clipboard history for macOS. The Windows `Win + V` gesture, on a Mac: one shortcut, a small
window at the pointer, and what you copied comes back where you are working.

**Everything stays local.** No account, no server, no telemetry. The history is encrypted on
disk.

---

## What CopyDraft does

- Continuously captures what you copy — plain text, rich text, images — along with the
  application it came from.
- Opens at the pointer on `⇧⌘V`, a 360 pt palette that **never steals focus** from the app
  you are working in.
- Is driven entirely from the keyboard: typing searches, `↑↓` selects, `↩︎` really pastes into
  the active app, `⌘1`–`⌘9` paste directly, `⌘P` pins.
- Ignores what must not be recorded: passwords and content flagged as confidential, apps you
  exclude, and anything copied while capture is paused.

## Installation

1. Download the package from the **[Releases page](../../releases/latest)**, open it, drag
   **CopyDraft** into *Applications*.
2. **First launch: macOS refuses to open the app** and offers "Move to Trash" — this build is
   not notarised by Apple, for want of a paid developer account. Click "Done", then open
   *System Settings → Privacy & Security*, scroll to the "Security" section and click
   **"Open Anyway"**. Confirm. Once is enough. (Since macOS 15, right-click → "Open" no longer
   bypasses this.) The Terminal equivalent is one line:
   `xattr -dr com.apple.quarantine /Applications/CopyDraft.app`

   The `.dmg` ships a "⚠️ LISEZ-MOI" notice walking through the whole procedure.
3. CopyDraft asks for **Accessibility** access. Click "Open System Settings" and turn on the
   switch next to CopyDraft. This is the **only** permission it asks for, and it exists solely
   so the app can paste on your behalf.
4. The icon appears in the menu bar. That's it.

Without that permission CopyDraft still works: the item you pick goes to the clipboard and you
paste it yourself with `⌘V`.

> **No icon in the menu bar?** If you run a menu bar manager (Hidden Bar, Bartender, Ice…), it
> parks new items in its hidden area. Hold **⌘** and drag the CopyDraft icon to the right of
> the separator to keep it visible.

## User guide

### The gesture, in three seconds

1. Copy as usual, from any application (`⌘C`).
2. Where you want to paste, press **`⇧⌘V`**. The list appears **at the pointer**, and the app
   you are working in keeps focus.
3. Pick one: `↩︎` for the first item, `↑↓` then `↩︎` for another, or `⌘1` to `⌘9` to paste the
   n-th one straight away. The window closes, the text is there.

### Finding something

Open the popup and **start typing** — no need to click into the search field, keystrokes go
there on their own. Search covers the content **and** the source application, so "safari"
brings back what you copied from Safari. `Esc` clears the search; a second `Esc` closes the
window.

### Keeping something at hand

`⌘P` pins the selected item: it moves to the **Pinned** section at the top of the list and is
never removed automatically — not when the history overflows, not on restart. Press `⌘P` again
to unpin. With the mouse, a pin appears on hover: click it and the item is pinned without
being pasted.

### Pasting without formatting

`⇧↩︎` instead of `↩︎`: only plain text goes out, without the original font or colour. A second
global shortcut, `⌥⇧⌘V`, opens the popup directly in that mode.

### Cleaning up

- `⌫` deletes the selected item (when the search field is empty).
- The trash button in the popup footer clears the whole history, behind a confirmation that
  counts the items and offers to keep the pinned ones.
- Right-click an item: paste, paste as plain text, pin, copy, delete, and **"Never record
  *this application*"**.

### Pausing capture

The pause button in the popup footer — or "Pause Capture" in the menu bar menu — stops
recording while you handle something sensitive. An amber banner says so, the menu bar icon
dims, and the existing history stays readable.

### Settings

Menu bar icon → **Settings…** (`⌘,`):

| Tab | What it controls |
|---|---|
| General | Launch at login, history size (10 to 500), keep history on restart, language |
| Shortcut | The open shortcut and the plain-text one, `⌘1`–`⌘9` quick paste |
| Popup | Position (at pointer, centred, under the menu bar icon), visible rows, translucency |
| Privacy | Pause, excluded applications, clear everything |
| Appearance | Light / dark / system theme, accent colour |

### The menu bar menu

Click the icon: the five most recent items (click to paste), pause, "Clear All", settings,
"About", "Quit". **`⌥`-click** opens the popup directly under the icon.

## Shortcuts

| Key | Action |
|---|---|
| `⇧⌘V` | Opens the popup (customisable) |
| `⌥⇧⌘V` | Opens the popup in "paste as plain text" mode |
| `↑` `↓` | Moves the selection |
| `⌥↑` `⌥↓` | Jump to start / end of the list |
| `↩︎` | Paste and close |
| `⇧↩︎` | Paste as plain text |
| `⌘1`–`⌘9`, `⌘0` | Paste the *n*-th item directly |
| `⌘P` | Pin / unpin |
| `⌘C` | Copy without pasting |
| `⌫` | Delete the selection (empty search) |
| `Esc` | Clear the search, then close |

Any letter you type feeds the search, which covers the content **and** the source application.

## Privacy

- **Nothing is ever sent anywhere.** No networking API is linked into the app.
- **Confidential content is never recorded**: the `ConcealedType`, `TransientType` and
  `AutoGeneratedType` pasteboard flags — the ones password managers use — are rejected before
  the content is even read. This cannot be turned off.
- **You can exclude applications** (password manager, banking app): nothing copied from them
  enters the history.
- **You can pause capture** in one click while handling something sensitive.
- **The history is encrypted** (AES-GCM) under `~/Library/Application Support/CopyDraft`, with
  a key kept in the Keychain and bound to this Mac.
- **The keyboard is only watched while the popup is open**, never in the background: the event
  tap is installed when it appears and removed when it closes.

## Building from source

Requirements: macOS 14+, Xcode 16 or later.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # if Xcode is not selected
swift test                      # 430+ tests
./Scripts/make-dev-identity.sh  # once — see below
./Scripts/build-app.sh          # produces dist/CopyDraft.app (universal)
./Scripts/make-dmg.sh           # produces dist/CopyDraft-<version>.dmg
```

> **Accessibility permission lost after every rebuild?** That is expected with an *ad hoc*
> signature: the bundle's code hash changes, macOS sees a different application and revokes the
> grant — the checkbox may even stay ticked in System Settings while the app is no longer
> recognised. `./Scripts/make-dev-identity.sh` creates a stable local signing identity; after
> one last grant, the permission survives further builds. If onboarding still reappears, remove
> CopyDraft from *System Settings → Privacy & Security → Accessibility* with the "−" button
> before adding it again.

> The SwiftPM shipped with Command Line Tools alone fails to load any manifest on some
> installs (`PackageDescription` out of sync with its library): `Scripts/build-app.sh` picks an
> Xcode installation automatically.

Signed and notarised distribution:

```sh
CODESIGN_IDENTITY="Developer ID Application: …" \
NOTARY_PROFILE="copydraft" \
TEAM_ID="ABCDE12345" \
./Scripts/sign-notarize.sh
```

## Repository layout

| Folder | Contents |
|---|---|
| `Sources/CopyDraftCore` | Capture, privacy filtering, encrypted history, pasting, keyboard input |
| `Sources/CopyDraftUI` | Design system, components, popup, menu bar, settings, onboarding |
| `Sources/CopyDraft` | Application assembly |
| `design-system/` | Reference design system and `tokens.json`, the visual source of truth |
| `docs/` | Product brief, PRD, architecture, UX, epics and stories |
| `Scripts/` | Bundle build, icon, dmg, signing and notarisation |

## Roadmap

Out of scope for this first version, considered next: iCloud sync across Macs, support for
copied files and folders, editing and renaming items, automatic updates.

## Licence

MIT. See [LICENSE](LICENSE).
