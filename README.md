# High Roller

**By Copper** | [GitHub Repository](https://github.com/Geeksterer/HighRoller/)

**High Roller** is a lightweight, zero-dependency World of Warcraft **3.3.5a (Wrath of the Lich King)** addon built for raiders who want to see exactly where they stand in raid rolls and bids, paired with a profile-based **Group Loot Auto-Roller** and multi-format **Loot Reporter**.

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
- **Automatic `/rw` Detection:** Opens a fresh tracking view every time a Raid Leader or Assist links an item in Raid Warning—even when the exact same item is linked again for duplicate boss drops or re-rolls—while archiving earlier items in history (`<` / `>`). Stays open until you close it manually.
- **Bids & Rolls Tabs:**
  - **Bids:** Tracks strict numerical bids in Raid chat, plus automatic `[OS]` tagging when a player types `os` / `OS` / `Os` on the very next line. **MS Bids Sort Above [OS] Bids** is enabled by default in Config (uncheck it if you want MS and OS bids to compete purely by amount).
  - **Rolls:** Locks each player to their first `/roll` per item, automatically categorizing Main Spec (`1-100`), Off Spec (`1-99`), and flagging invalid ranges.
- **Live Win Counter:** Displays a compact `[1]`, `[2]`, etc. badge next to each player's class-colored name showing how many qualifying items they have won in the current run.
- **Share to Raid Chat (`Post Bids` / `Post Rolls`):** One-click button on the tracker sends the current ranked bids or rolls list directly to Raid chat (without announcing winners), branded with High Roller by Copper and the addon URL.
- **Quick Controls:** Left-click a player row to cycle marks (`(W)`, `(MS)`, `(OS)`, `[!]`); Right-click to ignore/unignore an entry. Includes `Countdown` (10-second timer with 5-second warning and local finish notice), `Tie-Break`, Master Loot `Award #1` and `To DE`, `Boss Loot` queue, and item history (`<` / `>`).

### Persistent Loot Summary & Export Reports
- **Focused Boss Drop Tracking:** Tracks **Epic/Legendary BoP items, Tier Tokens, and Boss Mounts & Companion Pets** (filtering out Emblems/Badges, BoE trash, Trade Goods, and Recipes).
- **Accurate Winner & Queue Handling:**
  - Records winners **only** when won via **Group Loot** or a **`/rw` bid/roll session**.
  - **Master Looter & Bulk Loot Queuing:** When a Master Looter loots boss drops to themselves or hands out loot in bulk to a loot holder to roll later, those items are logged as **Queued** (never falsely listing the holder as a winner) and automatically transition into the active session once linked in `/rw`.
  - **Complete Drop Log:** Preserves **Unclaimed** and **Queued** items alongside won items in **All Drops** and all export reports so you never lose track of a boss drop.
- **Saves Across Logout & Group Prompt:** Your last raid's loot table persists after you leave a raid or log out and is still there when you log back in. When you join a new group, High Roller prompts you with **Accept** or **Cancel** to decide whether to clear the saved loot table (or run `/hr clear` manually anytime).
- **Post Chat & Copy-Ready Reports (No WoW Link Clutter):** Post a text-only summary to Raid/Party chat or export your run's complete loot table in four formats—each branded with the addon link:
  - **Plain Text**
  - **Discord** (Markdown formatted)
  - **HTML** (Dark-mode table with class colors and clickable link)
  - **Excel / TSV** (Tab-separated columns: `Item`, `Winner`, `Class`, `Winning Bid/Roll`, `Bids`, `Rolls`)

### Built-In Solo Test Mode
- Run `/hr test` (or click **Test Mode** in Config) to populate the Tracker, Boss Loot Queue, Win Counters, Loot Summary, and all four Report formats with sample WotLK raid data—including Epic BoP gear, a Tier Token, a Boss Mount, Queued ML loot, and an Unclaimed drop—without overwriting your real saved raid loot table. Click **Clear** in the Tracker to exit Test Mode and restore your saved data.

---

## Changelog

### v1.0.3 (Current)
- **Fresh View on Every `/rw` Item Link:** Linking the same item again in Raid Warning (duplicate drops or re-rolls) now always opens a brand-new tracker view and archives the previous one in history, instead of reusing the prior view. High Roller's own countdown warnings are also guarded so they never trigger blank views.
- **Raider-First `Post Bids` / `Post Rolls` Button:** Replaced the old winner `Announce` button on the Raid Tracker with a dynamic `Post Bids` / `Post Rolls` button that sends the ranked list to Raid chat with High Roller branding and website URL. Countdown completion now prints a local notice instead of announcing winners in chat.
- **MS Over OS Enabled by Default:** `MS Bids Sort Above [OS] Bids` is now checked by default in Config (with a one-time upgrade for existing installs) and can still be unchecked at any time if you want MS and OS bids to compete purely by amount.
- **Smart Boss Loot Table & Queued ML/Bulk Loot:**
  - Loot Summary and Reports now track **Epic/Legendary BoP items, Tier Tokens, and Boss Mounts & Companion Pets**.
  - Winners are recorded strictly from **Group Loot** wins or **`/rw` bid/roll** sessions—never listing a Raid Leader or loot holder as a winner when they loot items to distribute later.
  - Items looted by the Master Looter to themselves or distributed in bulk to a holder are logged as **Queued** in the loot table and Boss Loot Queue, and transition cleanly once put up for bid or roll in `/rw`.
  - **Unclaimed** and **Queued** items are now preserved in the loot table and all export formats for a complete boss drop record.
- **Persistent Raid Loot Table & Join-Group Prompt:** Your last raid's loot table now persists across leaving a raid and logging out/back in. Joining a group when saved loot exists now opens an **Accept / Cancel** confirmation dialog asking whether to clear the loot table, and `/hr clear` has been added for manual clearing.
- **Website Branding in Reports:** Added `https://github.com/Geeksterer/HighRoller/` to Plain Text, Discord, HTML, Excel/TSV reports, and Loot Summary chat posts.
- **Bug Fix:** Fixed a `SendChatMessage(): Invalid escape code in chat message` error when posting bids or rolls to Raid chat by replacing pipe (`|`) separators with commas and adding outgoing chat sanitization.

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
| `/hr clear` | Clear the saved raid loot table |
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

Created by **Copper** for World of Warcraft 3.3.5a — [https://github.com/Geeksterer/HighRoller/](https://github.com/Geeksterer/HighRoller/)
