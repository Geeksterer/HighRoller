# High Roller

**By Copper**

**High Roller** is a lightweight, zero-dependency World of Warcraft **3.3.5a (Wrath of the Lich King)** addon that combines a profile-based **Group Loot Auto-Roller** with a compact **Raid Roll & Bid Tracker** and multi-format **Loot Reporter**.

---

## Features

### Profile-Based Auto-Roller
- **5 Built-In Profiles:** Includes `Typical PUG` (default), `DE Everything`, `Need Everything`, `Pass on Everything`, and `No Automation`.
- **Granular Loot Rules:** Configure separate actions (`Need`, `Greed`, `Disenchant`, `Pass`, or `Do not Automate`) for:
  - Uncommon (Green) Loot, Rare (Blue) BoE / General, Epic BoE Items, Blue BoP Gear, and Epic BoP Items
  - **Orbs & High-Value Mats:** Rare/Epic Trade Goods plus explicit WotLK drops (Primordial Saronite, Crusader Orb, Runed Orb, Frozen Orb, Battered Hilt, Book of Glyph Mastery, Damaged Necklace)
  - **Recipes (BoE vs. BoP Split):** Separate rules for BoE Recipes, unlearned BoP Recipes for your known professions, known/unusable BoP Recipes, plus a toggle to always **Pass on BoP Jewelcrafting Recipes**
  - **Mounts & Companion Pets:** Automatically detects whether you already know a mount or pet and rolls accordingly
  - **Fallbacks & Popups:** Configurable No-Enchanter fallback and optional auto-confirm/cancel handling for BoP Disenchant and BoP Need/Greed popups
- **Copy & Customize Profiles:** Duplicate any built-in or custom profile with one click (`Copy`) to tweak a few rules without starting from scratch. Active profiles save per character.
- **Custom Item Overrides (Priority 0):** Force a specific action (`Need`, `Greed`, `Disenchant`, `Pass`, or `Do not Automate`) on any Item ID or Shift-clicked item link, overriding all profile rules.
- **Instance Auto-Switching:** Optionally assign a profile for **5-Man Dungeons** and a profile for **Raids** so High Roller switches automatically when you zone in (while still letting you switch manually mid-run).
- **Optional Roll Delay:** Choose `Instant (0s)`, `0.5s`, `1.0s`, or `1.5s` in Config for natural roll timing.

### Compact Raid Roll & Bid Tracker
- **Automatic `/rw` Detection:** Automatically starts tracking (and opens the tracker if enabled) whenever a Raid Leader or Assist links an item in Raid Warning. Stays open until you close it manually.
- **Bids & Rolls Tabs:**
  - **Bids:** Tracks strict numerical bids in Raid chat, plus automatic `[OS]` tagging when a player types `os` / `OS` / `Os` on the very next line. Includes an optional **MS Bids Sort Above [OS] Bids** setting in Config.
  - **Rolls:** Locks each player to their first `/roll` per item, automatically categorizing Main Spec (`1-100`), Off Spec (`1-99`), and flagging invalid ranges.
- **Live Win Counter:** Displays a compact `[1]`, `[2]`, etc. badge next to each player's class-colored name showing how many items they have won in the current run.
- **Quick Controls:** Left-click a player row to cycle marks (`(W)`, `(MS)`, `(OS)`, `[!]`); Right-click to ignore/unignore an entry.
- **Raid Leader Tools:** 10-second `Countdown` (with 5-second warning and auto-announce), `Announce`, `Tie-Break`, Master Loot `Award #1` and `To DE`, `Boss Loot` queue (quick MS / OS / Bid `/rw` buttons), item history (`<` / `>`), and automatic clearing when joining a new group.

### Loot Summary & Export Reports
- View **Winners** and **All Drops** for the current run with class-colored names and detailed hover tooltips showing all bids and rolls.
- **Post Chat:** Posts a clean, text-only loot summary to Raid/Party chat.
- **Copy-Ready Reports (No WoW Link Clutter):** Export your run's loot in four formats:
  - **Plain Text**
  - **Discord** (Markdown formatted)
  - **HTML** (Dark-mode table with class colors)
  - **Excel / TSV** (Tab-separated columns: `Item`, `Winner`, `Class`, `Winning Bid/Roll`, `Bids`, `Rolls`)

### Built-In Solo Test Mode
- Run `/hr test` (or click **Test Mode** in Config) to populate the Tracker, Boss Loot Queue, Win Counters, Loot Summary, and all four Report formats with sample WotLK raid data so you can test everything solo. Click **Clear** in the Tracker to reset.

---

## Installation

High Roller is built for **World of Warcraft 3.3.5a (Interface 30300)** and requires **no external libraries**.

### Option 1: Download the Latest Release (Recommended)
1. Click **Releases** on the right-hand side of this GitHub page and open the latest release.
2. Under **Assets**, download the `HighRoller` `.zip` file.
3. Extract the `.zip` archive.
4. Copy the extracted `HighRoller` folder into your WoW AddOns directory:
   ```text
   World of Warcraft\Interface\AddOns\HighRoller\
   ```
5. Restart World of Warcraft (or reload if already open) and verify **High Roller** is enabled in the **AddOns** menu on the Character Select screen.

### Option 2: Download ZIP from the Green `<> Code` Button
1. Click the green **`<> Code`** button near the top right of this repository.
2. Click **Download ZIP** from the dropdown menu.
3. Extract the downloaded `.zip` file.
4. **Rename the extracted folder** from `HighRoller-main` (or `HighRoller-master`) to **`HighRoller`**. *(WoW will not load the addon if the folder name has `-main` or `-master` at the end.)*
5. Move the renamed `HighRoller` folder into your WoW AddOns directory:
   ```text
   World of Warcraft\Interface\AddOns\HighRoller\
   ```
6. Make sure the folder structure looks like this (no extra nested `HighRoller\HighRoller\` folder):
   ```text
   World of Warcraft\Interface\AddOns\HighRoller\
   ├── HighRoller.lua
   └── HighRoller.toc
   ```
7. Launch World of Warcraft and confirm **High Roller** is checked under **AddOns** on the Character Select screen.

---

## Usage & Slash Commands

### Minimap Button
- **Left-Click:** Open the **Profile Switcher**
- **Right-Click:** Open the **Config** panel
- **Drag:** Move the button around the minimap *(can be locked in Config)*

### Slash Commands
You can use `/hr` or `/highroller`:

| Command | Description |
| :--- | :--- |
| `/hr` | Open or close the Profile Switcher |
| `/hr config` | Open or close the Config panel |
| `/hr tracker` *(or `/hr raid`)* | Toggle the Raid Roll & Bid Tracker window |
| `/hr loot` | Open Loot Summary & Reports (Text / Discord / HTML / TSV) |
| `/hr overrides` *(or `/hr exceptions`)* | Open the Custom Item Overrides panel |
| `/hr test` | Load Solo Test Mode sample data into the Tracker & Reports |
| `/hr profile <name>` | Switch directly to a saved profile |
| `/hr assign de <player>` | Assign a Disenchanter for Master Loot (`To DE` button) |
| `/hr pause` / `/hr resume` | Pause or resume automatic loot rolling |
| `/hr reset` | Reset all High Roller window positions to center screen |
| `/hr status` | Display auto-roll status, active profile, and version |
| `/hr help` | Print the full command list in chat |

---

## Built-In Profile Defaults

| Loot Category | Typical PUG *(Default)* | DE Everything | Need Everything | Pass on Everything | No Automation |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Uncommon (Green) Loot** | Disenchant | Disenchant | Need | Pass | Do not Automate |
| **Rare (Blue) BoE / General** | Disenchant | Disenchant | Need | Pass | Do not Automate |
| **Epic BoE Items** | Need | Disenchant | Need | Pass | Do not Automate |
| **Blue BoP Equip & Weapons** | Pass | Disenchant | Need | Pass | Do not Automate |
| **Epic BoP Items** | Do not Automate | Disenchant | Need | Pass | Do not Automate |
| **Orbs & High-Value Mats** | Need | Need | Need | Pass | Do not Automate |
| **BoE Recipes** | Need | Need | Need | Pass | Do not Automate |
| **BoP Recipes (Known Prof, Unlearned)** | Need | Greed | Need | Pass | Do not Automate |
| **BoP Recipes (Known / Unusable)** | Pass | Greed | Need | Pass | Do not Automate |
| **Mounts (Don't Know)** | Need | Need | Need | Pass | Do not Automate |
| **Mounts (Already Know)** | Pass | Pass | Need | Pass | Do not Automate |
| **Pets (Don't Know)** | Need | Need | Need | Pass | Do not Automate |
| **Pets (Already Know)** | Pass | Pass | Need | Pass | Do not Automate |
| **No-Enchanter Fallback** | Greed | Greed | Need | Pass | Do not Automate |

---

## Credits

Created by **Copper** for World of Warcraft 3.3.5a.
