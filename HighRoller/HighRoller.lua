-- ============================================================================
-- High Roller - World of Warcraft 3.3.5a (Interface 30300)
-- Profile-based Group Loot Auto-Roller + Raid Warning Roll & Bid Tracker
-- Version and Author are read dynamically from HighRoller.toc
-- ============================================================================

local addonName = ...
if type(addonName) ~= "string" or addonName == "" then
    addonName = "HighRoller"
end

local HR = {}
_G.HighRoller = HR

-- ============================================================================
-- 1. Metadata, Constants & Helpers
-- ============================================================================

local ADDON_VERSION = GetAddOnMetadata(addonName, "Version") or "?"
local ADDON_AUTHOR  = GetAddOnMetadata(addonName, "Author") or "Copper"
local ADDON_URL     = "https://github.com/Geeksterer/HighRoller/"

local function GetFooterText()
    return string.format("High Roller v%s by %s", ADDON_VERSION, ADDON_AUTHOR)
end

local ROLL_PASS       = 0
local ROLL_NEED       = 1
local ROLL_GREED      = 2
local ROLL_DISENCHANT = 3

local ACTION_TO_ROLL = {
    PASS       = ROLL_PASS,
    NEED       = ROLL_NEED,
    GREED      = ROLL_GREED,
    DISENCHANT = ROLL_DISENCHANT,
}

local ACTION_LABELS = {
    NEED       = "Need",
    DISENCHANT = "Disenchant",
    GREED      = "Greed",
    PASS       = "Pass",
    MANUAL     = "Do not Automate",
}

-- WotLK 3.3.5a canonical class hex fallbacks (used if RAID_CLASS_COLORS lacks a key)
local FALLBACK_CLASS_HEX = {
    DEATHKNIGHT = "C41F3B",
    DRUID       = "FF7D0A",
    HUNTER      = "ABD473",
    MAGE        = "69CCF0",
    PALADIN     = "F58CBA",
    PRIEST      = "FFFFFF",
    ROGUE       = "FFF569",
    SHAMAN      = "0070DE",
    WARLOCK     = "9482C9",
    WARRIOR     = "C79C6E",
}

-- Locale-safe item classes & subclasses (WotLK 3.3.5a)
local CLASS_WEAPON     = select(1, GetAuctionItemClasses()) or "Weapon"
local CLASS_ARMOR      = select(2, GetAuctionItemClasses()) or "Armor"
local CLASS_CONTAINER  = select(3, GetAuctionItemClasses()) or "Container"
local CLASS_CONSUMABLE = select(4, GetAuctionItemClasses()) or "Consumable"
local CLASS_GLYPH      = select(5, GetAuctionItemClasses()) or "Glyph"
local CLASS_TRADEGOODS = select(6, GetAuctionItemClasses()) or "Trade Goods"
local CLASS_PROJECTILE = select(7, GetAuctionItemClasses()) or "Projectile"
local CLASS_QUIVER     = select(8, GetAuctionItemClasses()) or "Quiver"
local CLASS_RECIPE     = select(9, GetAuctionItemClasses()) or "Recipe"
local CLASS_GEM        = select(10, GetAuctionItemClasses()) or "Gem"
local CLASS_MISC       = select(11, GetAuctionItemClasses()) or "Miscellaneous"
local CLASS_QUEST      = select(12, GetAuctionItemClasses()) or "Quest"
local SUBCLASS_PET     = select(3, GetAuctionItemSubClasses(11)) or "Pet"
local SUBCLASS_MOUNT   = select(6, GetAuctionItemSubClasses(11)) or "Mount"
local PROF_JC_NAME     = GetSpellInfo(25229) or "Jewelcrafting"

-- Explicit 3.3.5a Item IDs for high-value non-DE orbs and special drops
local ORB_ITEM_IDS = {
    [49908] = true, -- Primordial Saronite
    [47556] = true, -- Crusader Orb
    [45087] = true, -- Runed Orb
    [43102] = true, -- Frozen Orb
    [50379] = true, -- Battered Hilt (Alliance)
    [50380] = true, -- Battered Hilt (Horde)
    [45912] = true, -- Book of Glyph Mastery
    [43297] = true, -- Damaged Necklace
}

-- Emblems / badges / currencies that must never appear in the Loot Summary table
local EXCLUDED_LOOT_ITEM_IDS = {
    [49426] = true, -- Emblem of Frost
    [47241] = true, -- Emblem of Triumph
    [45624] = true, -- Emblem of Conquest
    [40753] = true, -- Emblem of Valor
    [40752] = true, -- Emblem of Heroism
    [29434] = true, -- Badge of Justice
    [43228] = true, -- Stone Keeper's Shard
    [43589] = true, -- Wintergrasp Mark of Honor
}

-- WotLK 3.3.5a Tier Token Item IDs (T7 Naxx/OS/EoE, T8 Ulduar, T9 ToC/ToGC, T10 ICC)
local TIER_TOKEN_IDS = {
    -- ICC (T10)
    [52025] = true, [52026] = true, [52027] = true,
    [52028] = true, [52029] = true, [52030] = true,
    -- ToC / ToGC (T9)
    [47242] = true, [47557] = true, [47558] = true, [47559] = true,
}
-- Ulduar (T8: 45632-45661) and Naxx/OS/EoE (T7: 40610-40639)
for id = 45632, 45661 do TIER_TOKEN_IDS[id] = true end
for id = 40610, 40639 do TIER_TOKEN_IDS[id] = true end

-- Notable Classic/TBC/WotLK boss mounts & companion pets (fallback when uncached in WDB)
local BOSS_MOUNT_PET_IDS = {
    -- WotLK raid & dungeon boss mounts
    [50818] = true, -- Invincible's Reins
    [45693] = true, -- Mimiron's Head
    [49636] = true, -- Reins of the Onyxian Drake
    [43986] = true, -- Reins of the Black Drake
    [43954] = true, -- Reins of the Twilight Drake
    [43952] = true, -- Reins of the Azure Drake
    [43953] = true, -- Reins of the Blue Drake
    [43959] = true, -- Reins of the Grand Black War Mammoth (Alliance)
    [44083] = true, -- Reins of the Grand Black War Mammoth (Horde)
    [44151] = true, -- Reins of the Blue Proto-Drake
    [43951] = true, -- Reins of the Bronze Drake
    -- Classic / TBC boss mounts & pets
    [13335] = true, -- Deathcharger's Reins
    [19872] = true, -- Swift Razzashi Raptor
    [19902] = true, -- Swift Zulian Tiger
    [30480] = true, -- Fiery Warhorse's Reins
    [32458] = true, -- Ashes of Al'ar
    [32768] = true, -- Reins of the Raven Lord
    [35513] = true, -- Swift White Hawkstrider
    [35504] = true, -- Phoenix Hatchling
    [33993] = true, -- Mojo
    [29960] = true, -- Captured Firefly
    [44984] = true, -- Ammen Vale Lashling / companion fallback
}

-- Known WotLK Epic BoP item IDs used by Solo Test Mode (fallback if client WDB cache is empty)
local SOLO_TEST_EPIC_BOP_IDS = {
    [50365] = true, -- Phylactery of the Nameless Lich
    [50730] = true, -- Glorenzelg, High-Blade of the Silver Hand
    [50363] = true, -- Deathbringer's Will
    [52026] = true, -- Conqueror's Mark of Sanctification
    [50620] = true, -- Coldwraith Links
    [50618] = true, -- Frostbrood Sapphire Ring
    [50818] = true, -- Invincible's Reins
}

local TIER_TOKEN_NAME_PATTERNS = {
    "mark of sanctification",
    "trophy of the crusade",
    "regalia of the grand",
    "of the lost conqueror",
    "of the lost protector",
    "of the lost vanquisher",
    "of the wayward conqueror",
    "of the wayward protector",
    "of the wayward vanquisher",
    "of the fallen champion",
    "of the fallen defender",
    "of the fallen hero",
    "of the forgotten conqueror",
    "of the forgotten protector",
    "of the forgotten vanquisher",
}

local NON_DE_POLICY_KEYS = {
    "orbs",
    "recipeBoE",
    "recipeBoPKnownUnlearned",
    "recipeBoPOther",
    "mountUnlearned",
    "mountKnown",
    "petUnlearned",
    "petKnown",
}

-- Build localized chat patterns from Blizzard global format strings (handles %s, %d, %1$s, %2$d)
local function GlobalFormatToPattern(fmt)
    local pat = fmt
        :gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        :gsub("%%%%%d+%%%$s", "(.+)")
        :gsub("%%%%%d+%%%$d", "(%%d+)")
        :gsub("%%%%s", "(.+)")
        :gsub("%%%%d", "(%%d+)")
    return "^" .. pat .. "$"
end

local ROLL_MSG_PATTERN             = GlobalFormatToPattern(RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)")
local LOOT_OTHER_PATTERN           = GlobalFormatToPattern(LOOT_ITEM or "%s receives loot: %s.")
local LOOT_OTHER_MULT_PAT          = GlobalFormatToPattern(LOOT_ITEM_MULTIPLE or "%s receives loot: %s x%d.")
local LOOT_SELF_PATTERN            = GlobalFormatToPattern(LOOT_ITEM_SELF or "You receive loot: %s.")
local LOOT_SELF_MULT_PAT           = GlobalFormatToPattern(LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %s x%d.")
local LOOT_WON_OTHER_PATTERN       = GlobalFormatToPattern(LOOT_ROLL_WON or "%s won: %s")
local LOOT_WON_SELF_PATTERN        = GlobalFormatToPattern(LOOT_ROLL_YOU_WON or "You won: %s")
local LOOT_WON_OTHER_NEED_PAT      = GlobalFormatToPattern(LOOT_ROLL_WON_NO_SPAM_NEED or "%1$s won: %3$s | Need - %2$d")
local LOOT_WON_SELF_NEED_PAT       = GlobalFormatToPattern(LOOT_ROLL_YOU_WON_NO_SPAM_NEED or "You won: %2$s | Need - %1$d")
local LOOT_WON_OTHER_GREED_PAT     = GlobalFormatToPattern(LOOT_ROLL_WON_NO_SPAM_GREED or "%1$s won: %3$s | Greed - %2$d")
local LOOT_WON_SELF_GREED_PAT      = GlobalFormatToPattern(LOOT_ROLL_YOU_WON_NO_SPAM_GREED or "You won: %2$s | Greed - %1$d")
local LOOT_WON_OTHER_DE_PAT        = GlobalFormatToPattern(LOOT_ROLL_WON_NO_SPAM_DE or "%1$s won: %3$s | Disenchant - %2$d")
local LOOT_WON_SELF_DE_PAT         = GlobalFormatToPattern(LOOT_ROLL_YOU_WON_NO_SPAM_DE or "You won: %2$s | Disenchant - %1$d")

-- Marks cycled on Left-Click in Raid Loot Tracker (classic RaidRoll style)
local PLAYER_MARKS = { "", "(W)", "(MS)", "(OS)", "[!]" }

local function DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[DeepCopy(k)] = DeepCopy(v)
    end
    return copy
end

local function ShortName(name)
    if not name then return "" end
    local short = strsplit("-", name)
    return short or name
end

local function SortedKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return strlower(a) < strlower(b)
    end)
    return keys
end

local function IsInGroupOrRaid()
    return (GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)
end

-- Non-DEable items (orbs, recipes, mounts, pets) cannot be disenchanted in WoW 3.3.5a
local function SanitizeNonDEAction(action, fallback)
    if action == "DISENCHANT" then
        if fallback == "GREED" or fallback == "PASS" or fallback == "NEED" or fallback == "MANUAL" then
            return fallback
        end
        return "GREED"
    end
    return action
end

local function SanitizeProfileNonDEFields(prof)
    if type(prof) ~= "table" then return end
    for _, key in ipairs(NON_DE_POLICY_KEYS) do
        prof[key] = SanitizeNonDEAction(prof[key], prof.noEnchanterFallback)
    end
end

local function ExtractItemID(itemLink)
    if not itemLink then return nil end
    return tonumber(string.match(itemLink, "item:(%d+)"))
end

-- Extract plain text item name with zero WoW hyperlink/color escape sequences
local function ExtractPlainItemName(itemLink)
    if not itemLink or itemLink == "" then return "Unknown Item" end
    local bracketed = string.match(itemLink, "|h%[([^%]]+)%]|h")
    if bracketed and bracketed ~= "" then
        return bracketed
    end
    local cleaned = itemLink
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|H[^|]+|h", "")
        :gsub("|h", "")
        :gsub("^%[", "")
        :gsub("%]$", "")
    cleaned = strtrim(cleaned)
    return (cleaned ~= "" and cleaned) or "Unknown Item"
end

local function EscapeHTML(str)
    str = tostring(str or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    return str
end

local function CleanTSVField(str)
    str = tostring(str or "")
    str = str:gsub("[\t\r\n]+", " ")
    return strtrim(str)
end

local FALLBACK_CLASS_NAMES = {
    DEATHKNIGHT = "Death Knight",
    DRUID       = "Druid",
    HUNTER      = "Hunter",
    MAGE        = "Mage",
    PALADIN     = "Paladin",
    PRIEST      = "Priest",
    ROGUE       = "Rogue",
    SHAMAN      = "Shaman",
    WARLOCK     = "Warlock",
    WARRIOR     = "Warrior",
}

local function GetClassDisplayName(classFile)
    if not classFile or classFile == "" then return "" end
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] then
        return LOCALIZED_CLASS_NAMES_MALE[classFile]
    end
    return FALLBACK_CLASS_NAMES[classFile] or classFile
end

function HR:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[High Roller]|r " .. tostring(msg))
end

function HR:PrintLoadBannerAndHelp(includeHeader)
    if includeHeader then
        self:Print(string.format("|cffffd100High Roller v%s by %s|r loaded. Active Profile: |cff00ccff%s|r",
            ADDON_VERSION, ADDON_AUTHOR, tostring(self:GetActiveProfileName())))
    else
        self:Print(string.format("|cffffd100High Roller v%s by %s|r - Commands:", ADDON_VERSION, ADDON_AUTHOR))
    end
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr|r - Open Profile Switcher (or Left-Click minimap button)")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr config|r - Open Config panel (or Right-Click minimap button)")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr tracker|r - Toggle Raid Roll/Bid Tracker window")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr loot|r - Open Loot Summary & Reports (Text / Discord / HTML / TSV)")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr overrides|r - Open Custom Item Overrides / Exceptions panel")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr test|r - Load Solo Test Mode sample data into Tracker & Reports")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr profile <name>|r - Switch active rolling profile")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr assign de <player>|r - Assign Disenchanter for Master Loot")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr pause|r / |cffffd100/hr resume|r - Pause or resume auto-rolling")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr clear|r - Clear the saved raid loot table")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr reset|r - Reset all window positions to center screen")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/hr status|r / |cffffd100/hr help|r - Show status or command list")
end

function HR:GetCharKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Realm")
end

-- ============================================================================
-- 2. Default Profiles & SavedVariables
-- ============================================================================

HR.DEFAULT_TEMPLATE = {
    greenLoot                = "DISENCHANT",
    blueGeneral              = "DISENCHANT",
    epicBoE                  = "NEED",
    blueBoPGear              = "PASS",
    epicBoPGear              = "MANUAL",
    orbs                     = "NEED",
    recipeBoE                = "NEED",
    recipeBoPKnownUnlearned  = "NEED",
    recipeBoPOther           = "PASS",
    mountUnlearned           = "NEED",
    mountKnown               = "PASS",
    petUnlearned             = "NEED",
    petKnown                 = "PASS",
    passJCRecipes            = false,
    noEnchanterFallback      = "GREED",
    bopDEConfirm             = "OK",
    bopLootConfirm           = "OK",
}

HR.DEFAULT_PROFILES = {
    ["No Automation"] = {
        greenLoot                = "MANUAL",
        blueGeneral              = "MANUAL",
        epicBoE                  = "MANUAL",
        blueBoPGear              = "MANUAL",
        epicBoPGear              = "MANUAL",
        orbs                     = "MANUAL",
        recipeBoE                = "MANUAL",
        recipeBoPKnownUnlearned  = "MANUAL",
        recipeBoPOther           = "MANUAL",
        mountUnlearned           = "MANUAL",
        mountKnown               = "MANUAL",
        petUnlearned             = "MANUAL",
        petKnown                 = "MANUAL",
        passJCRecipes            = false,
        noEnchanterFallback      = "MANUAL",
        bopDEConfirm             = "MANUAL",
        bopLootConfirm           = "MANUAL",
    },
    ["Pass on Everything"] = {
        greenLoot                = "PASS",
        blueGeneral              = "PASS",
        epicBoE                  = "PASS",
        blueBoPGear              = "PASS",
        epicBoPGear              = "PASS",
        orbs                     = "PASS",
        recipeBoE                = "PASS",
        recipeBoPKnownUnlearned  = "PASS",
        recipeBoPOther           = "PASS",
        mountUnlearned           = "PASS",
        mountKnown               = "PASS",
        petUnlearned             = "PASS",
        petKnown                 = "PASS",
        passJCRecipes            = true,
        noEnchanterFallback      = "PASS",
        bopDEConfirm             = "CANCEL",
        bopLootConfirm           = "CANCEL",
    },
    ["Typical PUG"] = {
        greenLoot                = "DISENCHANT",
        blueGeneral              = "DISENCHANT",
        epicBoE                  = "NEED",
        blueBoPGear              = "PASS",
        epicBoPGear              = "MANUAL",
        orbs                     = "NEED",
        recipeBoE                = "NEED",
        recipeBoPKnownUnlearned  = "NEED",
        recipeBoPOther           = "PASS",
        mountUnlearned           = "NEED",
        mountKnown               = "PASS",
        petUnlearned             = "NEED",
        petKnown                 = "PASS",
        passJCRecipes            = false,
        noEnchanterFallback      = "GREED",
        bopDEConfirm             = "OK",
        bopLootConfirm           = "OK",
    },
    ["DE Everything"] = {
        greenLoot                = "DISENCHANT",
        blueGeneral              = "DISENCHANT",
        epicBoE                  = "DISENCHANT",
        blueBoPGear              = "DISENCHANT",
        epicBoPGear              = "DISENCHANT",
        orbs                     = "NEED",
        recipeBoE                = "NEED",
        recipeBoPKnownUnlearned  = "GREED",
        recipeBoPOther           = "GREED",
        mountUnlearned           = "NEED",
        mountKnown               = "PASS",
        petUnlearned             = "NEED",
        petKnown                 = "PASS",
        passJCRecipes            = false,
        noEnchanterFallback      = "GREED",
        bopDEConfirm             = "OK",
        bopLootConfirm           = "OK",
    },
    ["Need Everything"] = {
        greenLoot                = "NEED",
        blueGeneral              = "NEED",
        epicBoE                  = "NEED",
        blueBoPGear              = "NEED",
        epicBoPGear              = "NEED",
        orbs                     = "NEED",
        recipeBoE                = "NEED",
        recipeBoPKnownUnlearned  = "NEED",
        recipeBoPOther           = "NEED",
        mountUnlearned           = "NEED",
        mountKnown               = "NEED",
        petUnlearned             = "NEED",
        petKnown                 = "NEED",
        passJCRecipes            = false,
        noEnchanterFallback      = "NEED",
        bopDEConfirm             = "CANCEL",
        bopLootConfirm           = "OK",
    },
}

function HR:InitDB()
    if type(HighRollerDB) ~= "table" then
        HighRollerDB = {}
    end

    if type(HighRollerDB.settings) ~= "table" then
        HighRollerDB.settings = {}
    end
    local s = HighRollerDB.settings
    if s.enabled == nil then s.enabled = true end
    if s.logActions == nil then s.logActions = true end
    if s.autoOpenTracker == nil then s.autoOpenTracker = true end
    if s.lockMinimap == nil then s.lockMinimap = false end
    if s.minimapAngle == nil then s.minimapAngle = 225 end
    if s.deTarget == nil then s.deTarget = "" end
    if s.msBidsBeatOS == nil then s.msBidsBeatOS = true end
    if s.autoProfileDungeon == nil then s.autoProfileDungeon = "" end
    if s.autoProfileRaid == nil then s.autoProfileRaid = "" end
    if s.rollDelay ~= 0 and s.rollDelay ~= 0.5 and s.rollDelay ~= 1.0 and s.rollDelay ~= 1.5 then
        s.rollDelay = 0
    end

    if type(HighRollerDB.positions) ~= "table" then
        HighRollerDB.positions = {}
    end

    if type(HighRollerDB.raidTracker) ~= "table" then
        HighRollerDB.raidTracker = {}
    end
    if HighRollerDB.raidTracker.activeView ~= "BIDS" and HighRollerDB.raidTracker.activeView ~= "ROLLS" then
        HighRollerDB.raidTracker.activeView = "BIDS"
    end
    if HighRollerDB.raidTracker.lootSummaryView ~= "WINNERS" and HighRollerDB.raidTracker.lootSummaryView ~= "DROPS" then
        HighRollerDB.raidTracker.lootSummaryView = "WINNERS"
    end
    if HighRollerDB.raidTracker.reportFormat ~= "TEXT"
        and HighRollerDB.raidTracker.reportFormat ~= "DISCORD"
        and HighRollerDB.raidTracker.reportFormat ~= "HTML"
        and HighRollerDB.raidTracker.reportFormat ~= "TSV" then
        HighRollerDB.raidTracker.reportFormat = "TEXT"
    end

    if type(HighRollerDB.activeProfileByChar) ~= "table" then
        HighRollerDB.activeProfileByChar = {}
    end

    if type(HighRollerDB.itemOverrides) ~= "table" then
        HighRollerDB.itemOverrides = {}
    end

    if type(HighRollerDB.profiles) ~= "table" then
        HighRollerDB.profiles = {}
    end

    -- Seed defaults on first install
    if next(HighRollerDB.profiles) == nil then
        for name, data in pairs(self.DEFAULT_PROFILES) do
            HighRollerDB.profiles[name] = DeepCopy(data)
        end
        HighRollerDB.schemaVersion = 4
    else
        local ver = HighRollerDB.schemaVersion or 0
        if ver < 2 then
            -- Upgrade v1 -> v2: add "No Automation" and set Typical PUG Epic BoP to Do not Automate
            if not HighRollerDB.profiles["No Automation"] then
                HighRollerDB.profiles["No Automation"] = DeepCopy(self.DEFAULT_PROFILES["No Automation"])
            end
            if HighRollerDB.profiles["Typical PUG"] and HighRollerDB.profiles["Typical PUG"].epicBoPGear == "PASS" then
                HighRollerDB.profiles["Typical PUG"].epicBoPGear = "MANUAL"
            end
        end

        if ver < 3 then
            -- Upgrade v2 -> v3: populate new Orbs, BoE/BoP Recipe split, Mounts & Pets keys without wiping custom profiles
            for name, defaults in pairs(self.DEFAULT_PROFILES) do
                local existing = HighRollerDB.profiles[name]
                if existing then
                    for _, key in ipairs(NON_DE_POLICY_KEYS) do
                        if existing[key] == nil then
                            existing[key] = defaults[key]
                        end
                    end
                end
            end

            -- Migrate legacy recipe keys on custom profiles
            for _, prof in pairs(HighRollerDB.profiles) do
                if prof.recipeBoPKnownUnlearned == nil and prof.recipeKnownProfUnlearned ~= nil then
                    prof.recipeBoPKnownUnlearned = prof.recipeKnownProfUnlearned
                end
                if prof.recipeBoPOther == nil and prof.recipeOther ~= nil then
                    prof.recipeBoPOther = prof.recipeOther
                end
                prof.recipeKnownProfUnlearned = nil
                prof.recipeOther = nil
            end
        end

        if ver < 4 then
            -- Upgrade v3 -> v4: default MS Bids Sort Above [OS] Bids to checked (users can still uncheck)
            s.msBidsBeatOS = true
            HighRollerDB.schemaVersion = 4
        end
    end

    -- Ensure all profiles contain every expected policy key and never allow Disenchant on non-DEable fields
    for _, prof in pairs(HighRollerDB.profiles) do
        -- Defensive migration if legacy keys are still present
        if prof.recipeBoPKnownUnlearned == nil and prof.recipeKnownProfUnlearned ~= nil then
            prof.recipeBoPKnownUnlearned = prof.recipeKnownProfUnlearned
        end
        if prof.recipeBoPOther == nil and prof.recipeOther ~= nil then
            prof.recipeBoPOther = prof.recipeOther
        end
        prof.recipeKnownProfUnlearned = nil
        prof.recipeOther = nil

        for k, v in pairs(self.DEFAULT_TEMPLATE) do
            if prof[k] == nil then
                prof[k] = v
            end
        end
        SanitizeProfileNonDEFields(prof)
    end

    -- Clear auto-switch targets if their referenced profiles no longer exist
    if s.autoProfileDungeon ~= "" and not HighRollerDB.profiles[s.autoProfileDungeon] then
        s.autoProfileDungeon = ""
    end
    if s.autoProfileRaid ~= "" and not HighRollerDB.profiles[s.autoProfileRaid] then
        s.autoProfileRaid = ""
    end

    if type(HighRollerDB.savedLoot) ~= "table" then
        HighRollerDB.savedLoot = {}
    end

    -- Restore persistent profile for this character
    local charKey = self:GetCharKey()
    local active = HighRollerDB.activeProfileByChar[charKey]
    if not active or not HighRollerDB.profiles[active] then
        if HighRollerDB.profiles["Typical PUG"] then
            active = "Typical PUG"
        else
            local keys = SortedKeys(HighRollerDB.profiles)
            active = keys[1]
        end
        HighRollerDB.activeProfileByChar[charKey] = active
    end
end

function HR:GetActiveProfileName()
    return HighRollerDB.activeProfileByChar[self:GetCharKey()]
end

function HR:GetActiveProfile()
    return HighRollerDB.profiles[self:GetActiveProfileName()]
end

function HR:SetActiveProfile(name, silent)
    if not name or not HighRollerDB.profiles[name] then
        local needle = strlower(strtrim(name or ""))
        for k in pairs(HighRollerDB.profiles) do
            if strlower(k) == needle then
                name = k
                break
            end
        end
    end
    if not name or not HighRollerDB.profiles[name] then
        self:Print("Profile not found: " .. tostring(name))
        return false
    end

    HighRollerDB.activeProfileByChar[self:GetCharKey()] = name
    if not silent then
        self:Print("Active profile switched to: |cffffd100" .. name .. "|r")
    end
    self:RefreshAllUI()
    return true
end

function HR:DeleteProfile(name)
    if not name or not HighRollerDB.profiles[name] then return end
    HighRollerDB.profiles[name] = nil
    if HighRollerDB.settings.autoProfileDungeon == name then
        HighRollerDB.settings.autoProfileDungeon = ""
    end
    if HighRollerDB.settings.autoProfileRaid == name then
        HighRollerDB.settings.autoProfileRaid = ""
    end
    self:Print("Deleted profile: |cffff8888" .. name .. "|r")

    if next(HighRollerDB.profiles) == nil then
        HighRollerDB.profiles["Pass on Everything"] = DeepCopy(self.DEFAULT_PROFILES["Pass on Everything"])
        self:Print("No profiles remained; restored 'Pass on Everything'.")
    end

    if self:GetActiveProfileName() == name then
        local keys = SortedKeys(HighRollerDB.profiles)
        HighRollerDB.activeProfileByChar[self:GetCharKey()] = keys[1]
        self:Print("Active profile is now: |cffffd100" .. keys[1] .. "|r")
    end

    self:RefreshAllUI()
end

function HR:RestoreDefaultProfiles()
    for name, data in pairs(self.DEFAULT_PROFILES) do
        HighRollerDB.profiles[name] = DeepCopy(data)
    end
    self:Print("Default profiles restored.")
    self:RefreshAllUI()
end

function HR:GenerateCopiedProfileName(sourceName)
    local base = strtrim(tostring(sourceName or "Profile"))
    -- Strip an existing trailing number so copying "Typical PUG 2" produces "Typical PUG 3"
    local stripped = string.match(base, "^(.-)%s+%d+$")
    if stripped and stripped ~= "" then
        base = stripped
    end
    if base == "" then
        base = "Profile"
    end

    local function NameExists(candidate)
        if HighRollerDB.profiles[candidate] then return true end
        local lowerCand = strlower(candidate)
        for existing in pairs(HighRollerDB.profiles) do
            if strlower(existing) == lowerCand then
                return true
            end
        end
        return false
    end

    local n = 2
    while true do
        local suffix = " " .. tostring(n)
        local maxBaseLen = 32 - #suffix
        local trimmedBase = (#base > maxBaseLen) and strtrim(string.sub(base, 1, maxBaseLen)) or base
        if trimmedBase == "" then
            trimmedBase = "Profile"
        end
        local candidate = trimmedBase .. suffix
        if not NameExists(candidate) then
            return candidate
        end
        n = n + 1
    end
end

function HR:CopyProfile(sourceName, callerKey)
    if not sourceName or not HighRollerDB.profiles[sourceName] then
        self:Print("Profile not found: " .. tostring(sourceName))
        return
    end

    local copyName = self:GenerateCopiedProfileName(sourceName)
    local duplicated = DeepCopy(HighRollerDB.profiles[sourceName])
    SanitizeProfileNonDEFields(duplicated)
    HighRollerDB.profiles[copyName] = duplicated

    self:Print(string.format("Copied profile |cffffd100%s|r -> |cffffd100%s|r", sourceName, copyName))
    self:RefreshAllUI()
    self:OpenPolicyEditor(copyName, callerKey or "editProfiles", true)
end

HR.lastAutoInstanceKey = nil

function HR:CheckInstanceAutoProfile()
    if not HighRollerDB or not HighRollerDB.settings or not GetInstanceInfo then return end

    local instName, instType = GetInstanceInfo()
    if instType == "party" or instType == "raid" then
        local instKey = instType .. ":" .. (instName or "")
        if instKey == self.lastAutoInstanceKey then
            return
        end
        self.lastAutoInstanceKey = instKey

        local targetProfile = (instType == "raid")
            and HighRollerDB.settings.autoProfileRaid
            or HighRollerDB.settings.autoProfileDungeon

        if targetProfile and targetProfile ~= "" and HighRollerDB.profiles[targetProfile] then
            if self:GetActiveProfileName() ~= targetProfile then
                self:SetActiveProfile(targetProfile, true)
                local kindLabel = (instType == "raid") and "Raid" or "5-Man Dungeon"
                local zoneLabel = (instName and instName ~= "") and (" (" .. instName .. ")") or ""
                self:Print(string.format("Entered %s%s - auto-switched profile to: |cffffd100%s|r",
                    kindLabel, zoneLabel, targetProfile))
            end
        end
    else
        self.lastAutoInstanceKey = nil
    end
end

function HR:GetItemOverride(itemID)
    if not itemID or not HighRollerDB or type(HighRollerDB.itemOverrides) ~= "table" then
        return nil
    end
    local entry = HighRollerDB.itemOverrides[itemID] or HighRollerDB.itemOverrides[tostring(itemID)]
    if type(entry) == "table" then
        return entry.action
    elseif type(entry) == "string" then
        return entry
    end
    return nil
end

function HR:SetItemOverride(itemInput, action)
    local trimmed = strtrim(tostring(itemInput or ""))
    if trimmed == "" then
        self:Print("Enter an Item ID or Shift-click an item link first.")
        return false
    end

    local itemID = tonumber(trimmed) or ExtractItemID(trimmed)
    if not itemID or itemID <= 0 then
        self:Print("Invalid Item ID or item link: " .. trimmed)
        return false
    end
    itemID = math.floor(itemID)

    if not ACTION_LABELS[action] then
        action = "MANUAL"
    end

    local infoName, infoLink = GetItemInfo(itemID)
    local linkFromInput = string.match(trimmed, "(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
    local finalLink = infoLink or linkFromInput
    local finalName = infoName or (finalLink and ExtractPlainItemName(finalLink)) or ("Item #" .. tostring(itemID))

    HighRollerDB.itemOverrides[tostring(itemID)] = nil
    HighRollerDB.itemOverrides[itemID] = {
        action = action,
        name   = finalName,
        link   = finalLink,
    }

    self:Print(string.format("Saved Item Override: %s (ID %d) -> |cff00ccff%s|r",
        finalLink or finalName, itemID, ACTION_LABELS[action]))
    self:RefreshAllUI()
    return true
end

function HR:RemoveItemOverride(itemID)
    if not itemID or not HighRollerDB or type(HighRollerDB.itemOverrides) ~= "table" then return end
    local entry = HighRollerDB.itemOverrides[itemID] or HighRollerDB.itemOverrides[tostring(itemID)]
    if not entry then return end

    local label = (type(entry) == "table" and (entry.link or entry.name)) or ("Item #" .. tostring(itemID))
    HighRollerDB.itemOverrides[itemID] = nil
    HighRollerDB.itemOverrides[tostring(itemID)] = nil
    self:Print("Removed Item Override: " .. tostring(label))
    self:RefreshAllUI()
end

-- ============================================================================
-- 3. Profession & Hidden Tooltip Scanner (3.3.5a)
-- ============================================================================

local scanTooltip = CreateFrame("GameTooltip", "HighRollerScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local knownProfessions = {}

function HR:UpdateKnownProfessions()
    wipe(knownProfessions)
    local numSkills = GetNumSkillLines()
    if not numSkills or numSkills == 0 then return end

    local inProfessionSection = false
    for i = 1, numSkills do
        local skillName, isHeader = GetSkillLineInfo(i)
        if isHeader then
            inProfessionSection = true
        elseif skillName and inProfessionSection then
            knownProfessions[strlower(skillName)] = true
        end
    end
end

function HR:InspectRecipe(itemLink, itemSubType)
    local isAlreadyKnown = false
    local isJC = false
    local knowsProfession = false

    local lowerSub = strlower(itemSubType or "")
    local lowerJC = strlower(PROF_JC_NAME)

    if lowerSub ~= "" then
        if lowerSub == lowerJC then
            isJC = true
        end
        if knownProfessions[lowerSub] then
            knowsProfession = true
        end
    end

    if itemLink then
        scanTooltip:ClearLines()
        scanTooltip:SetHyperlink(itemLink)
        local numLines = scanTooltip:NumLines()
        local alreadyKnownText = ITEM_SPELL_KNOWN or "Already known"

        for i = 1, numLines do
            local leftLine = _G["HighRollerScanTooltipTextLeft" .. i]
            local text = leftLine and leftLine:GetText()
            if text then
                if text == alreadyKnownText or string.find(text, alreadyKnownText, 1, true) then
                    isAlreadyKnown = true
                end
                local lowerText = strlower(text)
                if string.find(lowerText, lowerJC, 1, true) then
                    isJC = true
                end
                if not knowsProfession then
                    for profName in pairs(knownProfessions) do
                        if string.find(lowerText, "requires " .. profName, 1, true) then
                            knowsProfession = true
                            break
                        end
                    end
                end
            end
        end
    end

    return knowsProfession, isAlreadyKnown, isJC
end

function HR:IsTooltipAlreadyKnown(itemLink)
    if not itemLink then return false end
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)
    local numLines = scanTooltip:NumLines()
    local alreadyKnownText = ITEM_SPELL_KNOWN or "Already known"
    for i = 1, numLines do
        local leftLine = _G["HighRollerScanTooltipTextLeft" .. i]
        local text = leftLine and leftLine:GetText()
        if text and (text == alreadyKnownText or string.find(text, alreadyKnownText, 1, true)) then
            return true
        end
    end
    return false
end

function HR:ClassifyMountOrPet(itemType, itemSubType)
    local lowerSub  = strlower(itemSubType or "")
    local lowerType = strlower(itemType or "")
    local isMisc    = (itemType == CLASS_MISC) or (lowerType == "miscellaneous")

    if itemSubType == SUBCLASS_MOUNT or (isMisc and lowerSub == "mount") then
        return "MOUNT"
    end
    if itemSubType == SUBCLASS_PET or (isMisc and (lowerSub == "pet" or lowerSub == "companion pets")) then
        return "PET"
    end
    return nil
end

function HR:IsCompanionLearned(companionType, itemLink, itemName)
    -- 1. Hidden tooltip check for ITEM_SPELL_KNOWN ("Already known")
    if self:IsTooltipAlreadyKnown(itemLink) then
        return true
    end

    -- 2. WotLK 3.3.5a Companion API check ("MOUNT" or "CRITTER")
    if GetNumCompanions and GetCompanionInfo then
        local count = GetNumCompanions(companionType) or 0
        if count > 0 then
            local spellName = itemLink and GetItemSpell(itemLink) or nil
            local targetSpell = spellName and strlower(spellName) or nil
            local targetItem  = itemName and strlower(itemName) or nil

            for i = 1, count do
                local _, creatureName, spellID = GetCompanionInfo(companionType, i)
                local lowerCreature = creatureName and strlower(creatureName) or nil
                local compSpell = spellID and GetSpellInfo(spellID) or nil
                local lowerCompSpell = compSpell and strlower(compSpell) or nil

                if targetSpell and (lowerCreature == targetSpell or lowerCompSpell == targetSpell) then
                    return true
                end
                if targetItem and (lowerCreature == targetItem or lowerCompSpell == targetItem) then
                    return true
                end
            end
        end
    end

    return false
end

function HR:IsTierToken(itemLink, itemID, itemName)
    local id = itemID or ExtractItemID(itemLink)
    if id and TIER_TOKEN_IDS[id] then
        return true
    end

    local plainName = strlower(itemName or ExtractPlainItemName(itemLink) or "")
    if plainName ~= "" then
        for _, pat in ipairs(TIER_TOKEN_NAME_PATTERNS) do
            if string.find(plainName, pat, 1, true) then
                return true
            end
        end
    end

    return false
end

function HR:IsEpicBoPOrTierToken(itemLink)
    if not itemLink or itemLink == "" then return false end

    local itemID = ExtractItemID(itemLink)
    if itemID and EXCLUDED_LOOT_ITEM_IDS[itemID] then
        return false
    end

    local itemName, _, rarity, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)

    -- 1. Tier Tokens (T7/T8/T9/T10 & classic/TBC patterns)
    if self:IsTierToken(itemLink, itemID, itemName) then
        return true
    end

    -- 2. Boss Mounts & Companion Pets (Rare, Epic, or Legendary)
    if (itemID and BOSS_MOUNT_PET_IDS[itemID]) or self:ClassifyMountOrPet(itemType, itemSubType) ~= nil then
        return true
    end

    -- Exclude non-loot item categories early (Trade Goods, Consumables, Quests, Gems, Glyphs, Recipes, Ammo)
    if itemType == CLASS_TRADEGOODS
        or itemType == CLASS_CONSUMABLE
        or itemType == CLASS_QUEST
        or itemType == CLASS_GEM
        or itemType == CLASS_GLYPH
        or itemType == CLASS_RECIPE
        or itemType == CLASS_PROJECTILE
        or itemType == CLASS_QUIVER then
        return false
    end

    -- Scan hidden 3.3.5a tooltip for Mount/Pet text and Bind on Pickup vs Bind on Equip / Use
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)
    local numLines = scanTooltip:NumLines()
    local bopText = ITEM_BIND_ON_PICKUP or "Binds when picked up"
    local boeText = ITEM_BIND_ON_EQUIP or "Binds when equipped"
    local bouText = ITEM_BIND_ON_USE or "Binds when used"
    local isBoP = false
    local isBoEOrBoU = false
    local isTooltipMountOrPet = false
    local hasClassRestriction = false
    local classPrefix = strlower(string.match(ITEM_CLASSES_ALLOWED or "Classes: %s", "^([^:]+:)") or "classes:")

    for i = 1, numLines do
        local leftLine = _G["HighRollerScanTooltipTextLeft" .. i]
        local text = leftLine and leftLine:GetText()
        if text then
            if text == bopText or string.find(text, bopText, 1, true) then
                isBoP = true
            elseif text == boeText or string.find(text, boeText, 1, true)
                or text == bouText or string.find(text, bouText, 1, true) then
                isBoEOrBoU = true
            end
            local lowerText = strlower(text)
            if string.find(lowerText, classPrefix, 1, true) then
                hasClassRestriction = true
            end
            if string.find(lowerText, "teaches you how to summon", 1, true)
                or string.find(lowerText, "right click to summon and dismiss", 1, true) then
                isTooltipMountOrPet = true
            end
        end
    end

    if isTooltipMountOrPet then
        return true
    end

    -- 3. Epic / Legendary BoP items (fall back to hyperlink color if not yet cached)
    local isEpicOrHigher = false
    if rarity ~= nil then
        isEpicOrHigher = (rarity >= 4)
    else
        local lowerLink = strlower(itemLink)
        isEpicOrHigher = (string.find(lowerLink, "|cffa335ee", 1, true) ~= nil)
            or (string.find(lowerLink, "|cffff8000", 1, true) ~= nil)
    end
    if not isEpicOrHigher then
        return false
    end

    if isBoEOrBoU then
        return false
    end

    if isBoP then
        if itemType == CLASS_WEAPON or itemType == CLASS_ARMOR or itemType == CLASS_CONTAINER
            or (itemEquipLoc ~= nil and itemEquipLoc ~= "")
            or hasClassRestriction then
            return true
        end
        -- Allow other Epic BoP Miscellaneous items (e.g., tier tokens, mounts, pets)
        if itemType == CLASS_MISC or itemType == nil then
            return true
        end
        return false
    end

    -- Fallback for uncached Solo Test Mode items on a fresh client cache
    if numLines == 0 and itemID and SOLO_TEST_EPIC_BOP_IDS[itemID] then
        return true
    end

    return false
end

-- ============================================================================
-- 4. Group Loot Roll & BoP Confirmation Engine
-- ============================================================================

HR.initiatedRolls = {}
HR.skippedRolls   = {}
HR.pendingRolls   = {}

local rollDelayFrame = CreateFrame("Frame")
rollDelayFrame:Hide()
rollDelayFrame:SetScript("OnUpdate", function(self, elapsed)
    local hasPending = false
    for rollID, job in pairs(HR.pendingRolls) do
        job.remaining = job.remaining - elapsed
        if job.remaining <= 0 then
            HR.pendingRolls[rollID] = nil
            HR:ExecuteRollJob(job)
        else
            hasPending = true
        end
    end
    if not hasPending then
        self:Hide()
    end
end)

function HR:ExecuteRollJob(job)
    if not job or not job.rollID then return end
    if not HighRollerDB or not HighRollerDB.settings.enabled then
        self.skippedRolls[job.rollID] = true
        return
    end
    RollOnLoot(job.rollID, job.rollType)
    if HighRollerDB.settings.logActions then
        local suffix = job.note and (" (" .. job.note .. ")") or ""
        self:Print(string.format("[|cffffd100%s|r] Rolled |cff00ccff%s|r on %s%s",
            job.profileName, ACTION_LABELS[job.finalAction], job.link, suffix))
    end
end

function HR:CancelPendingRoll(rollID)
    if rollID and self.pendingRolls[rollID] then
        self.pendingRolls[rollID] = nil
        if next(self.pendingRolls) == nil then
            rollDelayFrame:Hide()
        end
    end
end

local function HideConfirmPopup(rollID)
    for i = 1, STATICPOPUP_NUMDIALOGS do
        local dialog = _G["StaticPopup" .. i]
        if dialog and dialog:IsShown() then
            if dialog.which == "CONFIRM_LOOT_ROLL" or dialog.which == "CONFIRM_DISENCHANT_ROLL" then
                if dialog.data == rollID or dialog.data == nil then
                    dialog:Hide()
                end
            end
        end
    end
end

local function ResolveRollAction(primary, fallback, canNeed, canGreed, canDisenchant)
    if primary == "PASS" then
        return "PASS", nil
    elseif primary == "NEED" then
        if canNeed then
            return "NEED", nil
        elseif fallback == "PASS" then
            return "PASS", "Need unavailable -> Pass"
        elseif fallback == "GREED" and canGreed then
            return "GREED", "Need unavailable -> Greed"
        else
            return "MANUAL", "Need unavailable"
        end
    elseif primary == "DISENCHANT" then
        if canDisenchant then
            return "DISENCHANT", nil
        elseif fallback == "GREED" and canGreed then
            return "GREED", "no enchanter / cannot DE -> Greed"
        elseif fallback == "PASS" then
            return "PASS", "no enchanter / cannot DE -> Pass"
        elseif fallback == "NEED" and canNeed then
            return "NEED", "no enchanter / cannot DE -> Need"
        else
            return "MANUAL", "no enchanter / cannot DE"
        end
    elseif primary == "GREED" then
        if canGreed then
            return "GREED", nil
        elseif fallback == "PASS" then
            return "PASS", "Greed unavailable -> Pass"
        else
            return "MANUAL", "Greed unavailable"
        end
    end
    return "MANUAL", nil
end

function HR:OnStartLootRoll(rollID)
    if not HighRollerDB or not HighRollerDB.settings.enabled then return end

    local _, name, _, quality, bindOnPickUp, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollID)
    if not quality then return end

    local profileName = self:GetActiveProfileName()
    local profile = self:GetActiveProfile()
    if not profile then return end

    local link = GetLootRollItemLink(rollID) or name or "Item"
    local itemID = ExtractItemID(link)
    local itemName, _, _, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(link)

    local companionKind   = self:ClassifyMountOrPet(itemType, itemSubType)
    local isMount         = (companionKind == "MOUNT")
    local isPet           = (companionKind == "PET")
    local isOrb           = (itemID and ORB_ITEM_IDS[itemID]) or (itemType == CLASS_TRADEGOODS and quality >= 3)
    local isRecipe        = (itemType == CLASS_RECIPE)
    local isNonDEable     = isMount or isPet or isOrb or isRecipe
    local isEquipOrWeapon = (itemType == CLASS_WEAPON) or (itemType == CLASS_ARMOR)
                         or (itemEquipLoc ~= nil and itemEquipLoc ~= "")

    local primaryAction = "MANUAL"
    local reasonTag = nil
    local customOverrideAction = itemID and self:GetItemOverride(itemID) or nil
    local isCustomOverride = (customOverrideAction ~= nil)

    -- Priority 0: Custom Item Overrides (highest priority, overrides all profile rules)
    if isCustomOverride then
        primaryAction = customOverrideAction
        reasonTag = "custom item override"

    -- Priority 1: Mounts (Don't Know vs. Already Know)
    elseif isMount then
        local alreadyKnown = self:IsCompanionLearned("MOUNT", link, itemName or name)
        if alreadyKnown then
            primaryAction = SanitizeNonDEAction(profile.mountKnown, profile.noEnchanterFallback)
            reasonTag = "already-known mount"
        else
            primaryAction = SanitizeNonDEAction(profile.mountUnlearned, profile.noEnchanterFallback)
            reasonTag = "unlearned mount"
        end

    -- Priority 2: Pets / Companions (Don't Know vs. Already Know)
    elseif isPet then
        local alreadyKnown = self:IsCompanionLearned("CRITTER", link, itemName or name)
        if alreadyKnown then
            primaryAction = SanitizeNonDEAction(profile.petKnown, profile.noEnchanterFallback)
            reasonTag = "already-known pet"
        else
            primaryAction = SanitizeNonDEAction(profile.petUnlearned, profile.noEnchanterFallback)
            reasonTag = "unlearned pet"
        end

    -- Priority 3: Orbs & High-Value Non-DE Mats (Rare/Epic Trade Goods + Explicit 3.3.5a IDs)
    elseif isOrb then
        primaryAction = SanitizeNonDEAction(profile.orbs, profile.noEnchanterFallback)
        reasonTag = "orb / high-value mat"

    -- Priority 4: Recipes (BoE vs. BoP Split + BoP JC Toggle)
    elseif isRecipe then
        if not bindOnPickUp then
            primaryAction = SanitizeNonDEAction(profile.recipeBoE, profile.noEnchanterFallback)
            reasonTag = "BoE recipe"
        else
            self:UpdateKnownProfessions()
            local knowsProf, alreadyKnown, isJC = self:InspectRecipe(link, itemSubType)

            if isJC and profile.passJCRecipes then
                primaryAction = "PASS"
                reasonTag = "BoP JC recipe policy"
            elseif knowsProf and not alreadyKnown then
                primaryAction = SanitizeNonDEAction(profile.recipeBoPKnownUnlearned, profile.noEnchanterFallback)
                reasonTag = "unlearned BoP recipe for your profession"
            else
                primaryAction = SanitizeNonDEAction(profile.recipeBoPOther, profile.noEnchanterFallback)
                reasonTag = alreadyKnown and "already-known BoP recipe" or "unusable BoP recipe"
            end
        end

    -- Priority 5: BoP Equipment & Weapons (Blue / Epic)
    elseif bindOnPickUp and isEquipOrWeapon and quality == 3 then
        primaryAction = profile.blueBoPGear
    elseif bindOnPickUp and isEquipOrWeapon and quality >= 4 then
        primaryAction = profile.epicBoPGear

    -- Priority 6: Epic BoE (or non-gear Epic)
    elseif quality >= 4 and not bindOnPickUp then
        primaryAction = profile.epicBoE
    elseif quality >= 4 and bindOnPickUp then
        primaryAction = profile.epicBoPGear

    -- Priority 7: Rare (Blue) BoE / General
    elseif quality == 3 then
        primaryAction = profile.blueGeneral

    -- Priority 8: Uncommon (Green)
    elseif quality == 2 then
        primaryAction = profile.greenLoot
    end

    if not primaryAction or primaryAction == "MANUAL" then
        self.skippedRolls[rollID] = true
        if isCustomOverride and HighRollerDB.settings.logActions then
            self:Print(string.format("[|cffffd100%s|r] Do not Automate on %s (custom item override)",
                profileName, link))
        end
        return
    end

    local finalAction, fallbackNote = ResolveRollAction(
        primaryAction,
        profile.noEnchanterFallback,
        canNeed,
        canGreed,
        canDisenchant and (isCustomOverride or (not isNonDEable))
    )

    local rollType = ACTION_TO_ROLL[finalAction]
    if rollType ~= nil then
        self.skippedRolls[rollID] = nil
        self.initiatedRolls[rollID] = finalAction
        local delay = tonumber(HighRollerDB.settings.rollDelay) or 0
        local job = {
            rollID      = rollID,
            rollType    = rollType,
            finalAction = finalAction,
            profileName = profileName,
            link        = link,
            note        = fallbackNote or reasonTag,
            remaining   = delay,
        }
        if delay > 0 then
            self.pendingRolls[rollID] = job
            rollDelayFrame:Show()
        else
            self:ExecuteRollJob(job)
        end
    else
        self.skippedRolls[rollID] = true
        if fallbackNote and HighRollerDB.settings.logActions then
            self:Print(string.format("[|cffffd100%s|r] Do not Automate on %s (%s)",
                profileName, link, fallbackNote))
        end
    end
end

function HR:OnConfirmDisenchantRoll(rollID, rollType)
    if not HighRollerDB or not HighRollerDB.settings.enabled then return end
    if self.skippedRolls[rollID] then return end
    local profileName = self:GetActiveProfileName()
    local profile = self:GetActiveProfile()
    if not profile then return end

    local policy = profile.bopDEConfirm
    if policy == "MANUAL" then return end

    local link = GetLootRollItemLink(rollID) or "BoP item"

    if policy == "OK" then
        ConfirmLootRoll(rollID, rollType)
        HideConfirmPopup(rollID)
        if HighRollerDB.settings.logActions then
            self:Print(string.format("[|cffffd100%s|r] Auto-confirmed BoP Disenchant on %s", profileName, link))
        end
    elseif policy == "CANCEL" then
        HideConfirmPopup(rollID)
        if HighRollerDB.settings.logActions then
            self:Print(string.format("[|cffffd100%s|r] Auto-canceled BoP Disenchant on %s", profileName, link))
        end
    elseif policy == "CANCEL_GREED" then
        HideConfirmPopup(rollID)
        local _, _, _, _, _, _, canGreed = GetLootRollItemInfo(rollID)
        if canGreed then
            RollOnLoot(rollID, ROLL_GREED)
            if HighRollerDB.settings.logActions then
                self:Print(string.format("[|cffffd100%s|r] Canceled BoP DE -> Rolled Greed on %s", profileName, link))
            end
        end
    elseif policy == "CANCEL_PASS" then
        HideConfirmPopup(rollID)
        RollOnLoot(rollID, ROLL_PASS)
        if HighRollerDB.settings.logActions then
            self:Print(string.format("[|cffffd100%s|r] Canceled BoP DE -> Passed on %s", profileName, link))
        end
    end
end

function HR:OnConfirmLootRoll(rollID, rollType)
    if not HighRollerDB or not HighRollerDB.settings.enabled then return end
    if self.skippedRolls[rollID] then return end
    if rollType ~= ROLL_GREED and rollType ~= ROLL_NEED then return end

    local profileName = self:GetActiveProfileName()
    local profile = self:GetActiveProfile()
    if not profile then return end

    local policy = profile.bopLootConfirm
    if policy == "MANUAL" then return end

    local link = GetLootRollItemLink(rollID) or "BoP item"
    local kind = (rollType == ROLL_NEED) and "Need" or "Greed"

    if policy == "OK" then
        ConfirmLootRoll(rollID, rollType)
        HideConfirmPopup(rollID)
        if HighRollerDB.settings.logActions then
            self:Print(string.format("[|cffffd100%s|r] Auto-confirmed BoP %s on %s", profileName, kind, link))
        end
    elseif policy == "CANCEL" then
        HideConfirmPopup(rollID)
        if HighRollerDB.settings.logActions then
            self:Print(string.format("[|cffffd100%s|r] Auto-canceled BoP %s on %s", profileName, kind, link))
        end
    end
end

-- ============================================================================
-- 5. Raid Warning Roll & Bid Engine + Persistent Class Cache & Loot History
-- ============================================================================

HR.raidState = {
    sessions            = {},  -- array of roll/bid sessions
    viewIndex           = 0,
    trackingActive      = false,
    marks               = {},  -- persistent raid marks: [shortName] = markIndex
    classCache          = {},  -- persistent class cache: [shortName] = classFileName (e.g. "WARLOCK")
    bossLoot            = {},  -- items on currently/recently looted boss & queued ML/bulk loot
    droppedItems        = {},  -- persistent raid loot table (won, queued, and unclaimed drops)
    scannedCorpses      = {},  -- GUIDs of already-scanned corpses
    countdownActive     = false,
    countdownLeft       = 0,
    countdownWarned5    = false,
    countdownLastSec    = 0,
    ignoreOwnRW         = {},  -- prevents High Roller's own countdown /rw notices from resetting the view
    recentGroupLootWins = {},  -- deduplicates follow-up LOOT_ITEM after LOOT_ROLL_WON
    recentAwardedLoot   = {},  -- deduplicates follow-up LOOT_ITEM after GiveMasterLoot
    pendingBulkLoot     = {},  -- detects ML bulk loot given to a holder (2+ items within 120s)
    isTestMode          = false,
}

StaticPopupDialogs["HIGHROLLER_CONFIRM_CLEAR_LOOT"] = {
    text = "You joined a group. Do you want to clear the saved High Roller loot table?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        HR:ClearRaidTrackerData(true)
        HR:Print("Cleared previous raid loot table.")
    end,
    OnCancel = function()
        HR:Print("Kept previous raid loot table.")
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

HR.groupStateInitialized = false
HR.wasInGroup            = false

local function GetCurrentSession()
    local idx = #HR.raidState.sessions
    if idx == 0 then return nil end
    return HR.raidState.sessions[idx]
end

local function GetViewedSession()
    local idx = HR.raidState.viewIndex
    if idx < 1 or idx > #HR.raidState.sessions then return nil end
    return HR.raidState.sessions[idx]
end

local function ExtractItemLink(msg)
    if not msg then return nil end
    return string.match(msg, "(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
end

function HR:UpdateClassCache()
    local cache = self.raidState.classCache

    -- Player
    local pName = UnitName("player")
    local _, pClass = UnitClass("player")
    if pName and pClass then
        cache[ShortName(pName)] = pClass
    end

    -- Raid members
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
            if name and fileName then
                cache[ShortName(name)] = fileName
            end
        end
    end

    -- Party members
    local numParty = GetNumPartyMembers()
    if numParty > 0 then
        for i = 1, numParty do
            local unit = "party" .. i
            local uName = UnitName(unit)
            local _, uClass = UnitClass(unit)
            if uName and uClass then
                cache[ShortName(uName)] = uClass
            end
        end
    end
end

function HR:GetPlayerClassFile(playerName)
    local short = ShortName(playerName)
    if short == "" then return nil end

    if self.raidState.classCache[short] then
        return self.raidState.classCache[short]
    end

    self:UpdateClassCache()
    if self.raidState.classCache[short] then
        return self.raidState.classCache[short]
    end

    -- Fallback: try UnitClass directly on the player name (works for party/raid/target)
    local _, directClass = UnitClass(short)
    if directClass then
        self.raidState.classCache[short] = directClass
        return directClass
    end

    return nil
end

function HR:GetClassColorHex(playerName, explicitClassFile)
    local classFile = explicitClassFile or self:GetPlayerClassFile(playerName)
    if classFile then
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local c = RAID_CLASS_COLORS[classFile]
            return string.format("%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
        elseif FALLBACK_CLASS_HEX[classFile] then
            return FALLBACK_CLASS_HEX[classFile]
        end
    end
    return "FFFFFF"
end

function HR:IsPlayerRLOrAssist()
    if GetNumRaidMembers() > 0 then
        return (IsRaidLeader() == 1) or (IsRaidOfficer() == 1)
    end
    return false
end

function HR:IsSenderRLOrAssist(sender)
    local shortSender = ShortName(sender)
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name, rank = GetRaidRosterInfo(i)
            if name and ShortName(name) == shortSender then
                return (rank ~= nil and rank >= 1)
            end
        end
        return false
    end
    return false
end

function HR:GetMasterLooterName()
    local lootMethod, mlPartyID, mlRaidID = GetLootMethod()
    if lootMethod ~= "master" then
        return nil
    end
    if mlRaidID and mlRaidID > 0 then
        local name = GetRaidRosterInfo(mlRaidID)
        if name and name ~= "" then
            return ShortName(name)
        end
    end
    if mlPartyID ~= nil then
        if mlPartyID == 0 then
            return ShortName(UnitName("player"))
        elseif mlPartyID > 0 then
            local name = UnitName("party" .. mlPartyID)
            if name and name ~= "" then
                return ShortName(name)
            end
        end
    end
    return nil
end

-- Protect valid WoW hyperlinks while stripping stray pipe ("|") / newline chars
-- that would cause SendChatMessage() to throw "Invalid escape code in chat message".
local function SanitizeOutgoingChatMessage(msg)
    msg = tostring(msg or ""):gsub("[\r\n]+", " ")

    local links = {}
    local shielded = msg:gsub("(|c%x%x%x%x%x%x%x%x|H[^|]+|h%[[^%]]+%]|h|r)", function(link)
        local idx = #links + 1
        links[idx] = link
        return "\001HRLINK" .. idx .. "\002"
    end)

    -- Replace any remaining raw pipe character outside valid hyperlinks
    shielded = shielded:gsub("|", "-")

    local clean = shielded:gsub("\001HRLINK(%d+)\002", function(idx)
        return links[tonumber(idx)] or ""
    end)

    -- Never exceed WoW 3.3.5a's 255-byte SendChatMessage limit or slice inside a hyperlink
    if #clean > 255 then
        local plain = clean:gsub("|c%x%x%x%x%x%x%x%x|H[^|]+|h(%[[^%]]+%])|h|r", "%1")
        plain = plain:gsub("|", "-")
        clean = string.sub(plain, 1, 255)
    end

    return clean
end

function HR:SendRaidMessage(msg, preferRW)
    local safeMsg = SanitizeOutgoingChatMessage(msg)
    if safeMsg == "" then return end

    if GetNumRaidMembers() > 0 then
        if preferRW and self:IsPlayerRLOrAssist() then
            SendChatMessage(safeMsg, "RAID_WARNING")
        else
            SendChatMessage(safeMsg, "RAID")
        end
    elseif GetNumPartyMembers() > 0 then
        SendChatMessage(safeMsg, "PARTY")
    else
        self:Print(safeMsg)
    end
end

function HR:HasAnyLootTableData()
    return (#self.raidState.droppedItems > 0) or (#self.raidState.sessions > 0)
end

function HR:SaveRaidLootState()
    if not HighRollerDB then return end
    -- Never overwrite a real saved raid loot table with Solo Test Mode data
    if self.raidState.isTestMode then return end

    local savedSessions = {}
    local sessionToIndex = {}
    for i, s in ipairs(self.raidState.sessions) do
        sessionToIndex[s] = i
        table.insert(savedSessions, {
            itemLink     = s.itemLink,
            itemName     = s.itemName,
            itemID       = s.itemID,
            itemIcon     = s.itemIcon,
            bids         = DeepCopy(s.bids),
            rolls        = DeepCopy(s.rolls),
            bidOrder     = s.bidOrder or 0,
            rollOrder    = s.rollOrder or 0,
            winnerName   = s.winnerName,
            winnerClass  = s.winnerClass,
            winnerDetail = s.winnerDetail,
        })
    end

    local savedDrops = {}
    for _, d in ipairs(self.raidState.droppedItems) do
        table.insert(savedDrops, {
            itemLink     = d.itemLink,
            itemName     = d.itemName,
            itemID       = d.itemID,
            source       = d.source,
            winner       = d.winner,
            winnerClass  = d.winnerClass,
            winDetail    = d.winDetail,
            winSource    = d.winSource,
            queued       = d.queued and true or false,
            queuedBy     = d.queuedBy,
            sessionIndex = d.session and sessionToIndex[d.session] or nil,
        })
    end

    HighRollerDB.savedLoot = {
        sessions   = savedSessions,
        dropped    = savedDrops,
        marks      = DeepCopy(self.raidState.marks),
        classCache = DeepCopy(self.raidState.classCache),
        bossLoot   = DeepCopy(self.raidState.bossLoot),
        viewIndex  = self.raidState.viewIndex or 0,
        wasInGroup = IsInGroupOrRaid(),
    }
end

function HR:LoadRaidLootState()
    if not HighRollerDB or type(HighRollerDB.savedLoot) ~= "table" then return end
    local saved = HighRollerDB.savedLoot

    wipe(self.raidState.sessions)
    wipe(self.raidState.droppedItems)
    wipe(self.raidState.marks)
    wipe(self.raidState.classCache)
    wipe(self.raidState.bossLoot)

    if type(saved.marks) == "table" then
        for k, v in pairs(saved.marks) do
            self.raidState.marks[k] = v
        end
    end

    if type(saved.classCache) == "table" then
        for k, v in pairs(saved.classCache) do
            self.raidState.classCache[k] = v
        end
    end

    if type(saved.bossLoot) == "table" then
        for _, item in ipairs(saved.bossLoot) do
            if type(item) == "table" and item.link then
                table.insert(self.raidState.bossLoot, DeepCopy(item))
            end
        end
    end

    if type(saved.sessions) == "table" then
        for _, s in ipairs(saved.sessions) do
            if type(s) == "table" and s.itemLink then
                local restored = {
                    itemLink     = s.itemLink,
                    itemName     = s.itemName or ExtractPlainItemName(s.itemLink),
                    itemID       = s.itemID or ExtractItemID(s.itemLink),
                    itemIcon     = s.itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
                    bids         = DeepCopy(s.bids or {}),
                    rolls        = DeepCopy(s.rolls or {}),
                    bidByName    = {},
                    rollByName   = {},
                    bidOrder     = s.bidOrder or 0,
                    rollOrder    = s.rollOrder or 0,
                    winnerName   = s.winnerName,
                    winnerClass  = s.winnerClass,
                    winnerDetail = s.winnerDetail,
                }
                for _, b in ipairs(restored.bids) do
                    if b.name then restored.bidByName[b.name] = b end
                end
                for _, r in ipairs(restored.rolls) do
                    if r.name then restored.rollByName[r.name] = r end
                end
                table.insert(self.raidState.sessions, restored)
            end
        end
    end

    if type(saved.dropped) == "table" then
        for _, d in ipairs(saved.dropped) do
            if type(d) == "table" and d.itemLink then
                local sessRef = (d.sessionIndex and self.raidState.sessions[d.sessionIndex]) or nil
                table.insert(self.raidState.droppedItems, {
                    itemLink    = d.itemLink,
                    itemName    = d.itemName or ExtractPlainItemName(d.itemLink),
                    itemID      = d.itemID or ExtractItemID(d.itemLink),
                    source      = d.source or "",
                    winner      = d.winner,
                    winnerClass = d.winnerClass,
                    winDetail   = d.winDetail,
                    winSource   = d.winSource,
                    queued      = d.queued and true or false,
                    queuedBy    = d.queuedBy,
                    session     = sessRef,
                })
            end
        end
    end

    local total = #self.raidState.sessions
    local vIdx = tonumber(saved.viewIndex) or total
    if vIdx < 0 then vIdx = 0 end
    if vIdx > total then vIdx = total end
    if total > 0 and vIdx == 0 then vIdx = total end
    self.raidState.viewIndex = vIdx
    self.raidState.trackingActive = false
    self.raidState.isTestMode = false
end

function HR:PromptClearLootTable()
    if StaticPopup_Visible and StaticPopup_Visible("HIGHROLLER_CONFIRM_CLEAR_LOOT") then
        return
    end
    StaticPopup_Show("HIGHROLLER_CONFIRM_CLEAR_LOOT")
end

function HR:ClearRaidTrackerData(silent, skipSave)
    local hadData = (#self.raidState.sessions > 0) or (#self.raidState.droppedItems > 0) or (#self.raidState.bossLoot > 0)
    self:StopCountdown(true)
    wipe(self.raidState.sessions)
    wipe(self.raidState.marks)
    wipe(self.raidState.classCache)
    wipe(self.raidState.bossLoot)
    wipe(self.raidState.droppedItems)
    wipe(self.raidState.scannedCorpses)
    wipe(self.raidState.ignoreOwnRW)
    wipe(self.raidState.recentGroupLootWins)
    wipe(self.raidState.recentAwardedLoot)
    wipe(self.raidState.pendingBulkLoot)
    self.raidState.viewIndex = 0
    self.raidState.trackingActive = false
    self.raidState.isTestMode = false
    self:UpdateClassCache()
    if not skipSave then
        self:SaveRaidLootState()
    end
    self:RefreshAllUI()
    if not silent and hadData then
        self:Print("Cleared previous Raid Tracker and loot table data.")
    end
end

function HR:CheckGroupTransition()
    local inGroup = IsInGroupOrRaid()
    if not self.groupStateInitialized then
        self.groupStateInitialized = true
        self.wasInGroup = inGroup
        self:UpdateClassCache()
        -- If the player logged out solo with a saved loot table and logged back in already in a group, ask to clear
        local wasInGroupBeforeLogout = HighRollerDB and HighRollerDB.savedLoot and HighRollerDB.savedLoot.wasInGroup
        if inGroup and not wasInGroupBeforeLogout and self:HasAnyLootTableData() then
            self:PromptClearLootTable()
        end
        if HighRollerDB and HighRollerDB.savedLoot then
            HighRollerDB.savedLoot.wasInGroup = inGroup
        end
        return
    end

    if inGroup and not self.wasInGroup then
        self:UpdateClassCache()
        if self:HasAnyLootTableData() then
            self:PromptClearLootTable()
        end
    elseif inGroup then
        self:UpdateClassCache()
    end

    if inGroup ~= self.wasInGroup then
        self.wasInGroup = inGroup
        if HighRollerDB and HighRollerDB.savedLoot then
            HighRollerDB.savedLoot.wasInGroup = inGroup
        end
    end
end

function HR:AddToBossLootQueue(itemLink)
    if not itemLink then return end
    local itemName, _, rarity, _, _, _, _, _, _, icon = GetItemInfo(itemLink)
    table.insert(self.raidState.bossLoot, {
        link   = itemLink,
        name   = itemName or ExtractPlainItemName(itemLink),
        icon   = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        rarity = rarity or 4,
    })
end

function HR:RecordDroppedItem(itemLink, sourceName, sessionRef, winSource, isQueued, queuedBy)
    if not itemLink then return nil end
    local itemID = ExtractItemID(itemLink)
    local entry = {
        itemLink    = itemLink,
        itemName    = ExtractPlainItemName(itemLink),
        itemID      = itemID,
        source      = sourceName or "",
        winner      = nil,
        winnerClass = nil,
        winDetail   = nil,
        winSource   = winSource, -- "GROUP_LOOT", "RAID_SESSION", or "QUEUED"
        queued      = isQueued and true or false,
        queuedBy    = queuedBy,
        session     = sessionRef,
    }
    table.insert(self.raidState.droppedItems, entry)
    return entry
end

function HR:QueueLootItem(itemLink, holderName, queueSource)
    if not itemLink or not self:IsEpicBoPOrTierToken(itemLink) then return nil end
    local shortHolder = ShortName(holderName)
    local entry = self:RecordDroppedItem(
        itemLink,
        queueSource or "Queued",
        nil,
        "QUEUED",
        true,
        shortHolder ~= "" and shortHolder or nil
    )
    self:AddToBossLootQueue(itemLink)
    self:SaveRaidLootState()
    self:RefreshAllUI()
    return entry
end

function HR:RecordItemWinner(itemLink, winnerName, detailText, sessionRef, winSource)
    if not itemLink or not winnerName then return end
    local itemID = ExtractItemID(itemLink)
    local shortWin = ShortName(winnerName)
    local winClass = self:GetPlayerClassFile(shortWin)
    local qualifies = self:IsEpicBoPOrTierToken(itemLink)

    -- Update matching session (if this win came from a /rw session)
    local matchedSession = sessionRef
    if matchedSession then
        matchedSession.winnerName   = shortWin
        matchedSession.winnerClass  = winClass
        matchedSession.winnerDetail = detailText or "Won"
    end

    -- Only record Epic BoP items, Tier Tokens, Mounts & Pets in the Loot Summary / Report table
    if not qualifies then
        self:SaveRaidLootState()
        self:RefreshAllUI()
        return
    end

    local matchedDrop = nil
    if matchedSession then
        for i = #self.raidState.droppedItems, 1, -1 do
            if self.raidState.droppedItems[i].session == matchedSession then
                matchedDrop = self.raidState.droppedItems[i]
                break
            end
        end
    end

    if not matchedDrop then
        local srcLabel = (winSource == "GROUP_LOOT") and "Group Loot" or (matchedSession and "Raid Warning" or "")
        matchedDrop = self:RecordDroppedItem(itemLink, srcLabel, matchedSession, winSource, false, nil)
    end

    if matchedDrop then
        matchedDrop.winner      = shortWin
        matchedDrop.winnerClass = winClass or matchedDrop.winnerClass
        matchedDrop.winDetail   = detailText or "Won"
        matchedDrop.winSource   = winSource or matchedDrop.winSource or (matchedSession and "RAID_SESSION" or "GROUP_LOOT")
        matchedDrop.queued      = false
        matchedDrop.queuedBy    = nil
        if matchedSession and not matchedDrop.session then
            matchedDrop.session = matchedSession
        end
    end

    self:SaveRaidLootState()
    self:RefreshAllUI()
end

function HR:StartNewLootSession(itemLink)
    self:UpdateClassCache()
    local newID = ExtractItemID(itemLink)

    -- Always cancel active countdown, archive any previous session, and open a fresh view (even for the same item)
    self:StopCountdown(true)

    local icon = select(10, GetItemInfo(itemLink)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    local session = {
        itemLink     = itemLink,
        itemName     = ExtractPlainItemName(itemLink),
        itemID       = newID,
        itemIcon     = icon,
        bids         = {},
        rolls        = {},
        bidByName    = {},
        rollByName   = {},
        bidOrder     = 0,
        rollOrder    = 0,
        winnerName   = nil,
        winnerClass  = nil,
        winnerDetail = nil,
    }
    table.insert(self.raidState.sessions, session)
    self.raidState.viewIndex = #self.raidState.sessions
    self.raidState.trackingActive = true

    -- Clear any pending single-item bulk buffer entry for this itemID so it won't double-queue
    if newID then
        for _, bucket in pairs(self.raidState.pendingBulkLoot) do
            if type(bucket.items) == "table" then
                for idx = #bucket.items, 1, -1 do
                    if bucket.items[idx].itemID == newID then
                        table.remove(bucket.items, idx)
                        break
                    end
                end
            end
        end
    end

    -- Link to an existing queued/non-session entry for this itemID (e.g. ML self-loot or bulk-queued item,
    -- or an item looted earlier before being put up for bid/roll), clearing any holder/prior name.
    local qualifies = self:IsEpicBoPOrTierToken(itemLink)
    local repurposedDrop = nil
    if newID then
        -- First prefer an explicitly queued item (FIFO: oldest queued copy first)
        for i = 1, #self.raidState.droppedItems do
            local d = self.raidState.droppedItems[i]
            if d.itemID == newID and not d.session and d.queued then
                repurposedDrop = d
                break
            end
        end
        -- Otherwise check if an item looted outside /rw is now being rolled/bid
        if not repurposedDrop then
            for i = #self.raidState.droppedItems, 1, -1 do
                local d = self.raidState.droppedItems[i]
                if d.itemID == newID and not d.session then
                    repurposedDrop = d
                    break
                end
            end
        end
    end

    if repurposedDrop then
        repurposedDrop.winner      = nil
        repurposedDrop.winnerClass = nil
        repurposedDrop.winDetail   = nil
        repurposedDrop.winSource   = "RAID_SESSION"
        repurposedDrop.source      = "Raid Warning"
        repurposedDrop.queued      = false
        repurposedDrop.queuedBy    = nil
        repurposedDrop.session     = session
    elseif qualifies then
        -- Record qualifying /rw items in the loot table immediately (preserved even if unclaimed)
        self:RecordDroppedItem(itemLink, "Raid Warning", session, "RAID_SESSION", false, nil)
    end

    self:SaveRaidLootState()
    if HighRollerDB.settings.autoOpenTracker then
        self:OpenRaidTracker(nil)
    end
    self:RefreshAllUI()
end

function HR:OnRaidWarning(msg, sender)
    if not sender or not self:IsSenderRLOrAssist(sender) then return end

    if msg and self.raidState.ignoreOwnRW[msg] and ShortName(sender) == ShortName(UnitName("player")) then
        self.raidState.ignoreOwnRW[msg] = nil
        return
    end

    local itemLink = ExtractItemLink(msg)
    if itemLink then
        self:StartNewLootSession(itemLink)
    elseif self.raidState.trackingActive then
        self:ProcessPotentialBid(msg, sender)
    end
end

-- Strict numerical-only bid parser + next-line "OS"/"os"/"Os" indicator
function HR:ProcessPotentialBid(msg, sender)
    if not self.raidState.trackingActive then return end
    local session = GetCurrentSession()
    if not session then return end

    local trimmed = strtrim(msg or "")
    if trimmed == "" then return end

    local shortSender = ShortName(sender)
    local classFile = self:GetPlayerClassFile(shortSender)

    -- Rule 1: Pure numerical bid only (no text allowed)
    if string.match(trimmed, "^%d+$") then
        local amount = tonumber(trimmed)
        if not amount or amount <= 0 then return end

        local entry = session.bidByName[shortSender]
        if entry then
            entry.amount     = amount
            entry.isOS       = false
            entry.awaitingOS = true
            entry.ignored    = false
            entry.classFile  = classFile or entry.classFile
            session.bidOrder = session.bidOrder + 1
            entry.order      = session.bidOrder
        else
            session.bidOrder = session.bidOrder + 1
            entry = {
                name       = shortSender,
                classFile  = classFile,
                amount     = amount,
                isOS       = false,
                awaitingOS = true,
                ignored    = false,
                order      = session.bidOrder,
            }
            session.bidByName[shortSender] = entry
            table.insert(session.bids, entry)
        end
        self:SaveRaidLootState()
        self:RefreshAllUI()

    -- Rule 2: Immediate next line from same player is strictly OS / os / Os
    elseif strlower(trimmed) == "os" then
        local entry = session.bidByName[shortSender]
        if entry and entry.awaitingOS then
            entry.isOS = true
            entry.awaitingOS = false
            self:SaveRaidLootState()
            self:RefreshAllUI()
        end
    else
        local entry = session.bidByName[shortSender]
        if entry then
            entry.awaitingOS = false
        end
    end
end

function HR:OnSystemMessage(msg)
    local roller, rollStr, lowStr, highStr = string.match(msg or "", ROLL_MSG_PATTERN)
    if not roller then return end

    local rollVal = tonumber(rollStr)
    local lowVal  = tonumber(lowStr)
    local highVal = tonumber(highStr)
    if not rollVal or not lowVal or not highVal then return end

    if not self.raidState.trackingActive then return end
    local session = GetCurrentSession()
    if not session then return end

    local shortRoller = ShortName(roller)

    -- Lock each player to their FIRST roll per item
    if session.rollByName[shortRoller] then
        return
    end

    local rollCategory = "INVALID"
    if lowVal == 1 and highVal == 100 then
        rollCategory = "MS"
    elseif lowVal == 1 and highVal == 99 then
        rollCategory = "OS"
    end

    local classFile = self:GetPlayerClassFile(shortRoller)

    session.rollOrder = session.rollOrder + 1
    local entry = {
        name      = shortRoller,
        classFile = classFile,
        value     = rollVal,
        low       = lowVal,
        high      = highVal,
        category  = rollCategory,
        ignored   = false,
        order     = session.rollOrder,
    }
    session.rollByName[shortRoller] = entry
    table.insert(session.rolls, entry)
    self:SaveRaidLootState()
    self:RefreshAllUI()
end

function HR:OnLootChatMessage(msg)
    if not msg or msg == "" then return end
    if not IsInGroupOrRaid() and not self.raidState.isTestMode then return end

    -- Ignore Group Loot Disenchant roll wins
    if string.match(msg, LOOT_WON_SELF_DE_PAT) or string.match(msg, LOOT_WON_OTHER_DE_PAT) then
        return
    end

    -- 1. Check Group Loot roll wins ("You won: [Item]" / "<Player> won: [Item]")
    local glWinner, glDetail
    local sVal1, sVal2 = string.match(msg, LOOT_WON_SELF_NEED_PAT)
    if sVal1 then
        glWinner = UnitName("player")
        local num = tonumber(sVal1) or tonumber(sVal2)
        glDetail = num and ("Group Loot (Need " .. tostring(num) .. ")") or "Group Loot (Need)"
    end
    if not glWinner then
        sVal1, sVal2 = string.match(msg, LOOT_WON_SELF_GREED_PAT)
        if sVal1 then
            glWinner = UnitName("player")
            local num = tonumber(sVal1) or tonumber(sVal2)
            glDetail = num and ("Group Loot (Greed " .. tostring(num) .. ")") or "Group Loot (Greed)"
        end
    end
    if not glWinner and string.match(msg, LOOT_WON_SELF_PATTERN) then
        glWinner = UnitName("player")
        glDetail = "Group Loot"
    end
    if not glWinner then
        local pName, pVal1, pVal2 = string.match(msg, LOOT_WON_OTHER_NEED_PAT)
        if pName then
            glWinner = pName
            local num = tonumber(pVal1) or tonumber(pVal2)
            glDetail = num and ("Group Loot (Need " .. tostring(num) .. ")") or "Group Loot (Need)"
        end
    end
    if not glWinner then
        local pName, pVal1, pVal2 = string.match(msg, LOOT_WON_OTHER_GREED_PAT)
        if pName then
            glWinner = pName
            local num = tonumber(pVal1) or tonumber(pVal2)
            glDetail = num and ("Group Loot (Greed " .. tostring(num) .. ")") or "Group Loot (Greed)"
        end
    end
    if not glWinner then
        local pName = string.match(msg, LOOT_WON_OTHER_PATTERN)
        if pName then
            glWinner = pName
            glDetail = "Group Loot"
        end
    end

    if glWinner then
        local itemLink = ExtractItemLink(msg)
        if itemLink and self:IsEpicBoPOrTierToken(itemLink) then
            local itemID = ExtractItemID(itemLink)
            if itemID then
                local dedupeKey = ShortName(glWinner) .. ":" .. tostring(itemID)
                self.raidState.recentGroupLootWins[dedupeKey] = GetTime()
            end
            self:RecordItemWinner(itemLink, glWinner, glDetail or "Group Loot", nil, "GROUP_LOOT")
        end
        return
    end

    -- 2. Check direct loot receipt ("<Player> receives loot: [Item]" / "You receive loot: [Item]")
    local recipient, linkStr
    local p1, p2 = string.match(msg, LOOT_OTHER_MULT_PAT)
    if p1 and p2 then
        recipient, linkStr = p1, p2
    else
        p1, p2 = string.match(msg, LOOT_OTHER_PATTERN)
        if p1 and p2 then
            recipient, linkStr = p1, p2
        else
            local s1 = string.match(msg, LOOT_SELF_MULT_PAT) or string.match(msg, LOOT_SELF_PATTERN)
            if s1 then
                recipient = UnitName("player")
                linkStr = s1
            end
        end
    end

    if not recipient or not linkStr then return end
    local itemLink = ExtractItemLink(linkStr)
    if not itemLink then return end

    local itemID = ExtractItemID(itemLink)
    local shortRec = ShortName(recipient)
    local now = GetTime()

    -- Ignore duplicate LOOT_ITEM firing immediately after a Group Loot win or GiveMasterLoot award
    if itemID then
        local dedupeKey = shortRec .. ":" .. tostring(itemID)
        local glTime = self.raidState.recentGroupLootWins[dedupeKey]
        if glTime and (now - glTime) <= 10 then
            self.raidState.recentGroupLootWins[dedupeKey] = nil
            return
        end
        local awTime = self.raidState.recentAwardedLoot[dedupeKey]
        if awTime and (now - awTime) <= 10 then
            self.raidState.recentAwardedLoot[dedupeKey] = nil
            return
        end
    end

    -- 2a. Finalize a winner ONLY if an unclaimed /rw session exists AND recipient actually bid/rolled on it
    local matchedSession = nil
    for i = #self.raidState.sessions, 1, -1 do
        local s = self.raidState.sessions[i]
        if s.itemID == itemID and not s.winnerName then
            if (s.bidByName[shortRec] and not s.bidByName[shortRec].ignored)
                or (s.rollByName[shortRec] and not s.rollByName[shortRec].ignored) then
                matchedSession = s
                break
            end
        end
    end

    if matchedSession then
        local detail = "Won"
        if matchedSession.bidByName[shortRec] and not matchedSession.bidByName[shortRec].ignored then
            local b = matchedSession.bidByName[shortRec]
            detail = tostring(b.amount) .. (b.isOS and " [OS] Bid" or " Bid")
        elseif matchedSession.rollByName[shortRec] and not matchedSession.rollByName[shortRec].ignored then
            local r = matchedSession.rollByName[shortRec]
            detail = tostring(r.value) .. (r.category == "OS" and " OS Roll" or " Roll")
        end
        self:RecordItemWinner(itemLink, recipient, detail, matchedSession, "RAID_SESSION")
        return
    end

    -- 2b. Master Looter self-loot & bulk loot -> record as Queued loot (never as a winner)
    if not self:IsEpicBoPOrTierToken(itemLink) then return end

    local lootMethod = GetLootMethod()
    local mlName = self:GetMasterLooterName()

    if mlName and strlower(shortRec) == strlower(mlName) then
        self:QueueLootItem(itemLink, shortRec, "Queued (ML)")
        return
    end

    if lootMethod == "master" then
        local BULK_WINDOW = 120
        local bucket = self.raidState.pendingBulkLoot[shortRec]
        if not bucket then
            bucket = { items = {}, lastBulkTime = 0 }
            self.raidState.pendingBulkLoot[shortRec] = bucket
        end

        -- Prune stale single-item entries outside the bulk window
        for idx = #bucket.items, 1, -1 do
            if (now - bucket.items[idx].time) > BULK_WINDOW then
                table.remove(bucket.items, idx)
            end
        end

        -- If this player is already receiving bulk loot in this window, queue immediately
        if bucket.lastBulkTime > 0 and (now - bucket.lastBulkTime) <= BULK_WINDOW then
            bucket.lastBulkTime = now
            self:QueueLootItem(itemLink, shortRec, "Queued (Bulk)")
            return
        end

        table.insert(bucket.items, { link = itemLink, itemID = itemID, time = now })
        if #bucket.items >= 2 then
            bucket.lastBulkTime = now
            for _, it in ipairs(bucket.items) do
                self:QueueLootItem(it.link, shortRec, "Queued (Bulk)")
            end
            wipe(bucket.items)
        end
    end
end

function HR:GetPlayerWinCounts()
    local counts = {}
    local currentSession = GetCurrentSession()
    local coveredSessions = {}

    for _, d in ipairs(self.raidState.droppedItems) do
        if d.session then
            coveredSessions[d.session] = true
        end
        if self:IsEpicBoPOrTierToken(d.itemLink) then
            local winner = d.winner
            -- For completed prior /rw sessions where loot was traded (no loot chat event), count the clear single winner
            if not winner and d.session and d.session ~= currentSession then
                local leaders = self:GetTopContenders(d.session)
                if #leaders == 1 then
                    winner = leaders[1]
                end
            end
            if winner and winner ~= "" then
                local short = ShortName(winner)
                counts[short] = (counts[short] or 0) + 1
            end
        end
    end

    for _, s in ipairs(self.raidState.sessions) do
        if not coveredSessions[s] and self:IsEpicBoPOrTierToken(s.itemLink) then
            local winner = s.winnerName
            if not winner and s ~= currentSession then
                local leaders = self:GetTopContenders(s)
                if #leaders == 1 then
                    winner = leaders[1]
                end
            end
            if winner and winner ~= "" then
                local short = ShortName(winner)
                counts[short] = (counts[short] or 0) + 1
            end
        end
    end

    return counts
end

function HR:GetSortedBids(session)
    local list = {}
    if not session then return list end
    for _, e in ipairs(session.bids) do
        table.insert(list, e)
    end
    local msBeatsOS = HighRollerDB and HighRollerDB.settings and HighRollerDB.settings.msBidsBeatOS
    table.sort(list, function(a, b)
        if a.ignored ~= b.ignored then
            return not a.ignored
        end
        if msBeatsOS then
            local aOS = a.isOS and true or false
            local bOS = b.isOS and true or false
            if aOS ~= bOS then
                return not aOS
            end
        end
        if a.amount ~= b.amount then
            return a.amount > b.amount
        end
        return a.order < b.order
    end)
    return list
end

function HR:GetSortedRolls(session)
    local list = {}
    if not session then return list end
    for _, e in ipairs(session.rolls) do
        table.insert(list, e)
    end
    local catRank = { MS = 1, OS = 2, INVALID = 3 }
    table.sort(list, function(a, b)
        if a.ignored ~= b.ignored then
            return not a.ignored
        end
        local ra = catRank[a.category] or 3
        local rb = catRank[b.category] or 3
        if ra ~= rb then
            return ra < rb
        end
        if a.value ~= b.value then
            return a.value > b.value
        end
        return a.order < b.order
    end)
    return list
end

function HR:GetTopContenders(session)
    if not session then return {}, nil, nil, "" end

    local preferRolls = (HighRollerDB and HighRollerDB.raidTracker and HighRollerDB.raidTracker.activeView == "ROLLS")

    local function EvalBids()
        local sortedBids = self:GetSortedBids(session)
        local validBids = {}
        for _, b in ipairs(sortedBids) do
            if not b.ignored then table.insert(validBids, b) end
        end
        if #validBids > 0 then
            local msBeatsOS = HighRollerDB and HighRollerDB.settings and HighRollerDB.settings.msBidsBeatOS
            local topAmt  = validBids[1].amount
            local topIsOS = validBids[1].isOS and true or false
            local winners = {}
            for _, b in ipairs(validBids) do
                local bIsOS = b.isOS and true or false
                if b.amount == topAmt and ((not msBeatsOS) or (bIsOS == topIsOS)) then
                    table.insert(winners, b.name)
                end
            end
            local tag = topIsOS and " (OS Bid)" or " (Bid)"
            return winners, topAmt, "BID", tag
        end
        return nil
    end

    local function EvalRolls()
        local sortedRolls = self:GetSortedRolls(session)
        local validRolls = {}
        for _, r in ipairs(sortedRolls) do
            if not r.ignored and r.category ~= "INVALID" then table.insert(validRolls, r) end
        end
        if #validRolls > 0 then
            local topCat = validRolls[1].category
            local topVal = validRolls[1].value
            local winners = {}
            for _, r in ipairs(validRolls) do
                if r.category == topCat and r.value == topVal then table.insert(winners, r.name) end
            end
            local tag = (topCat == "OS") and " (OS Roll)" or " (Roll)"
            return winners, topVal, "ROLL", tag
        end
        return nil
    end

    if preferRolls then
        local w, v, m, t = EvalRolls()
        if w then return w, v, m, t end
        w, v, m, t = EvalBids()
        if w then return w, v, m, t end
    else
        local w, v, m, t = EvalBids()
        if w then return w, v, m, t end
        w, v, m, t = EvalRolls()
        if w then return w, v, m, t end
    end

    return {}, nil, nil, ""
end

function HR:PostTrackerViewToRaidChat()
    local session = GetViewedSession()
    if not session then
        self:Print("No tracked item to post.")
        return
    end

    local activeView = (HighRollerDB and HighRollerDB.raidTracker and HighRollerDB.raidTracker.activeView) or "BIDS"
    local itemLabel = session.itemLink or session.itemName or "Item"
    local prefix
    local parts = {}

    if activeView == "BIDS" then
        local sortedBids = self:GetSortedBids(session)
        local rank = 0
        for _, b in ipairs(sortedBids) do
            if not b.ignored then
                rank = rank + 1
                local osTag = b.isOS and " [OS]" or ""
                table.insert(parts, string.format("%d. %s %d%s", rank, b.name, b.amount, osTag))
            end
        end
        if #parts == 0 then
            self:Print("No eligible bids to post for this item.")
            return
        end
        prefix = "Bids for " .. itemLabel .. ": "
    else
        local sortedRolls = self:GetSortedRolls(session)
        local rank = 0
        for _, r in ipairs(sortedRolls) do
            if not r.ignored then
                rank = rank + 1
                local tag = ""
                if r.category == "OS" then
                    tag = " (OS)"
                elseif r.category == "INVALID" then
                    tag = string.format(" (%d-%d)", r.low, r.high)
                end
                table.insert(parts, string.format("%d. %s %d%s", rank, r.name, r.value, tag))
            end
        end
        if #parts == 0 then
            self:Print("No eligible rolls to post for this item.")
            return
        end
        prefix = "Rolls for " .. itemLabel .. ": "
    end

    local MAX_CHAT_LEN = 240
    local contPrefix = (activeView == "BIDS") and "Bids (cont.): " or "Rolls (cont.): "
    if (#prefix + #parts[1]) > MAX_CHAT_LEN then
        prefix = ((activeView == "BIDS") and "Bids for " or "Rolls for ")
            .. (session.itemName or ExtractPlainItemName(itemLabel)) .. ": "
    end

    local currentLine = prefix
    local hasEntriesOnLine = false
    for _, entryStr in ipairs(parts) do
        local sep = hasEntriesOnLine and ", " or ""
        if hasEntriesOnLine and (#currentLine + #sep + #entryStr > MAX_CHAT_LEN) then
            self:SendRaidMessage(currentLine, false)
            currentLine = contPrefix .. entryStr
            hasEntriesOnLine = true
        else
            currentLine = currentLine .. sep .. entryStr
            hasEntriesOnLine = true
        end
    end
    if hasEntriesOnLine then
        self:SendRaidMessage(currentLine, false)
    end

    self:SendRaidMessage(string.format("High Roller by %s - %s", ADDON_AUTHOR, ADDON_URL), false)
end

function HR:AnnounceTieBreak()
    local session = GetViewedSession()
    if not session then return end
    local winners, topVal, _, tag = self:GetTopContenders(session)
    if #winners > 1 then
        self:SendRaidMessage(string.format("Tie-Break for %s (%d%s): %s - /roll now!",
            session.itemLink, topVal, tag, table.concat(winners, ", ")), true)
    else
        self:Print("No tie detected for the current item.")
    end
end

-- Countdown Timer (3.3.5a OnUpdate frame)
local countdownFrame = CreateFrame("Frame")
countdownFrame:Hide()
countdownFrame:SetScript("OnUpdate", function(self, elapsed)
    local st = HR.raidState
    if not st.countdownActive then
        self:Hide()
        return
    end
    st.countdownLeft = st.countdownLeft - elapsed
    local sec = math.ceil(st.countdownLeft)

    if st.countdownLeft <= 0 then
        st.countdownActive = false
        self:Hide()
        local session = GetViewedSession()
        local itemText = (session and session.itemLink) or "loot"
        HR:Print("Countdown finished for " .. itemText .. ".")
        HR:RefreshRaidTrackerUI()
        return
    end

    if sec <= 5 and not st.countdownWarned5 then
        st.countdownWarned5 = true
        local session = GetViewedSession()
        local itemText = (session and session.itemLink) or "loot"
        local cdMsg = "5 seconds left on " .. itemText .. "!"
        if HR:IsPlayerRLOrAssist() then
            st.ignoreOwnRW[cdMsg] = true
        end
        HR:SendRaidMessage(cdMsg, true)
    end

    if sec ~= st.countdownLastSec then
        st.countdownLastSec = sec
        HR:RefreshRaidTrackerUI()
    end
end)

function HR:ToggleCountdown()
    if self.raidState.countdownActive then
        self:StopCountdown(false)
        return
    end
    local session = GetViewedSession()
    if not session then
        self:Print("No item is currently being tracked.")
        return
    end
    self.raidState.countdownActive  = true
    self.raidState.countdownLeft    = 10
    self.raidState.countdownWarned5 = false
    self.raidState.countdownLastSec = 10
    local cdMsg = "10 seconds remaining for " .. session.itemLink .. "!"
    if self:IsPlayerRLOrAssist() then
        self.raidState.ignoreOwnRW[cdMsg] = true
    end
    self:SendRaidMessage(cdMsg, true)
    countdownFrame:Show()
    self:RefreshRaidTrackerUI()
end

function HR:StopCountdown(silent)
    if self.raidState.countdownActive then
        self.raidState.countdownActive = false
        countdownFrame:Hide()
        if not silent then
            self:Print("Countdown canceled.")
        end
        self:RefreshRaidTrackerUI()
    end
end

-- Master Loot Awarding (WotLK 3.3.5a: GetMasterLootCandidate takes 1 argument)
function HR:AwardTrackedItemTo(targetName, reasonDetail)
    if not targetName or targetName == "" then
        self:Print("No target player specified.")
        return
    end

    local lootMethod = GetLootMethod()
    if lootMethod ~= "master" then
        self:Print("Loot method is not Master Looter.")
        return
    end

    local numLoot = GetNumLootItems()
    if not numLoot or numLoot == 0 then
        self:Print("Loot window must be open to award items.")
        return
    end

    local session = GetViewedSession()
    if not session or not session.itemID then
        self:Print("No tracked item selected.")
        return
    end

    local targetSlot = nil
    for slot = 1, numLoot do
        local link = GetLootSlotLink(slot)
        if link and ExtractItemID(link) == session.itemID then
            targetSlot = slot
            break
        end
    end
    if not targetSlot then
        self:Print("Tracked item was not found in the open loot window.")
        return
    end

    local needle = strlower(ShortName(targetName))
    for i = 1, 40 do
        local cand = GetMasterLootCandidate(i)
        if cand and strlower(ShortName(cand)) == needle then
            local dedupeKey = ShortName(cand) .. ":" .. tostring(session.itemID)
            self.raidState.recentAwardedLoot[dedupeKey] = GetTime()
            GiveMasterLoot(targetSlot, i)
            if reasonDetail ~= "Disenchant" then
                self:RecordItemWinner(session.itemLink, cand, reasonDetail or "Awarded", session, "RAID_SESSION")
            end
            self:Print("Awarded " .. session.itemLink .. " to |cffffd100" .. cand .. "|r.")
            return
        end
    end

    self:Print(targetName .. " is not an eligible Master Loot candidate for this item.")
end

function HR:CaptureBossLoot()
    wipe(self.raidState.bossLoot)
    if not IsInGroupOrRaid() then return end
    self:UpdateClassCache()

    local numLoot = GetNumLootItems()
    for slot = 1, numLoot do
        local icon, name, _, rarity = GetLootSlotInfo(slot)
        local link = GetLootSlotLink(slot)
        if link and rarity and rarity >= 3 then
            table.insert(self.raidState.bossLoot, {
                link   = link,
                name   = name or "Item",
                icon   = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                rarity = rarity,
            })
        end
    end

    self:RefreshAllUI()
end

-- Built-In Solo Test Harness (/hr test + Test Mode button in Config)
function HR:RunSoloTest()
    self:ClearRaidTrackerData(true, true)
    self.raidState.isTestMode = true

    -- Populate mock raid roster classes across all 10 WotLK classes
    local mockClasses = {
        Arthas    = "DEATHKNIGHT",
        Jaina     = "MAGE",
        Uther     = "PALADIN",
        Sylvanas  = "HUNTER",
        Thrall    = "SHAMAN",
        Velen     = "PRIEST",
        Malfurion = "DRUID",
        Garrosh   = "WARRIOR",
        Valeera   = "ROGUE",
        Guldan    = "WARLOCK",
    }
    for playerName, classFile in pairs(mockClasses) do
        self.raidState.classCache[playerName] = classFile
    end

    -- Real WotLK 3.3.5a Epic BoP, Tier Token & Boss Mount item hyperlinks
    local linkPhylactery = "|cffa335ee|Hitem:50365:0:0:0:0:0:0:0:80|h[Phylactery of the Nameless Lich]|h|r"
    local linkGlorenzelg = "|cffa335ee|Hitem:50730:0:0:0:0:0:0:0:80|h[Glorenzelg, High-Blade of the Silver Hand]|h|r"
    local linkTierToken  = "|cffa335ee|Hitem:52026:0:0:0:0:0:0:0:80|h[Conqueror's Mark of Sanctification]|h|r"
    local linkInvincible = "|cffa335ee|Hitem:50818:0:0:0:0:0:0:0:80|h[Invincible's Reins]|h|r"
    local linkColdwraith = "|cffa335ee|Hitem:50620:0:0:0:0:0:0:0:80|h[Coldwraith Links]|h|r"
    local linkRingQueued = "|cffa335ee|Hitem:50618:0:0:0:0:0:0:0:80|h[Frostbrood Sapphire Ring]|h|r"
    local linkDBW        = "|cffa335ee|Hitem:50363:0:0:0:0:0:0:0:80|h[Deathbringer's Will]|h|r"

    local rollFmt = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
    local function SimRoll(roller, val, low, high)
        self:OnSystemMessage(string.format(rollFmt, roller, val, low, high))
    end

    -- Populate Boss Loot Queue for solo testing
    local testBossItems = {
        linkPhylactery, linkGlorenzelg, linkTierToken, linkInvincible, linkColdwraith, linkDBW,
    }
    for _, link in ipairs(testBossItems) do
        self:AddToBossLootQueue(link)
    end

    -- Session 1 (Completed): Phylactery -> Guldan wins [1]
    self:StartNewLootSession(linkPhylactery)
    self:ProcessPotentialBid("1200", "Jaina")
    self:ProcessPotentialBid("1500", "Guldan")
    self:ProcessPotentialBid("900",  "Velen")
    self:ProcessPotentialBid("os",   "Velen")
    SimRoll("Guldan", 84, 1, 100)
    SimRoll("Jaina",  62, 1, 100)
    self:RecordItemWinner(linkPhylactery, "Guldan", "1500 (Bid)", GetCurrentSession(), "RAID_SESSION")

    -- Session 2 (Completed): Glorenzelg -> Garrosh wins [1]
    self:StartNewLootSession(linkGlorenzelg)
    self:ProcessPotentialBid("2200", "Arthas")
    self:ProcessPotentialBid("2500", "Garrosh")
    self:ProcessPotentialBid("1800", "Uther")
    self:ProcessPotentialBid("OS",   "Uther")
    SimRoll("Garrosh", 91, 1, 100)
    SimRoll("Arthas",  77, 1, 100)
    SimRoll("Uther",   88, 1, 99)
    self:RecordItemWinner(linkGlorenzelg, "Garrosh", "2500 (Bid)", GetCurrentSession(), "RAID_SESSION")

    -- Tier Token won via Group Loot -> Guldan wins [2]
    self:RecordItemWinner(linkTierToken, "Guldan", "Group Loot (Need 95)", nil, "GROUP_LOOT")

    -- Boss Mount won via Group Loot -> Sylvanas wins [1]
    self:RecordItemWinner(linkInvincible, "Sylvanas", "Group Loot (Need 99)", nil, "GROUP_LOOT")

    -- Session 3 (Unclaimed): Coldwraith Links linked in /rw with 0 bids & 0 rolls (remains in loot table as Unclaimed)
    self:StartNewLootSession(linkColdwraith)

    -- Queued ML loot waiting to be rolled later (shows as Queued in All Drops & Reports, holder name NOT in Winner column)
    self:QueueLootItem(linkRingQueued, "Uther", "Queued (ML)")

    -- Simulate ML (Uther) queuing DBW before putting it up for /rw bid/roll (transitions cleanly from Queued -> active session)
    self:QueueLootItem(linkDBW, "Uther", "Queued (ML)")

    -- Session 4 (Active): Deathbringer's Will (tests MS/OS bids, MS>OS sort toggle, MS/OS/invalid rolls, & [1]/[2] win badges)
    self:StartNewLootSession(linkDBW)
    self:ProcessPotentialBid("3000", "Garrosh")
    self:ProcessPotentialBid("3500", "Valeera")
    self:ProcessPotentialBid("os",   "Valeera")
    self:ProcessPotentialBid("2800", "Sylvanas")
    self:ProcessPotentialBid("2500", "Arthas")
    self:ProcessPotentialBid("1000", "Guldan")
    self:ProcessPotentialBid("Os",   "Guldan")
    SimRoll("Sylvanas", 94, 1, 100)
    SimRoll("Garrosh",  81, 1, 100)
    SimRoll("Arthas",   88, 1, 99)
    SimRoll("Valeera",  73, 1, 99)
    SimRoll("Thrall",   50, 1, 50)

    self:OpenRaidTracker(nil)
    self:RefreshAllUI()
    self:Print("Solo Test Mode loaded: Epic BoP, Tier Token, Boss Mount, Queued ML loot, and Unclaimed drops ready. Click |cffffd100Clear|r in the Tracker to exit Test Mode.")
end

-- ============================================================================
-- 6. Loot Report Data & Formatters (Text-Only, Discord Markdown, Black-BG HTML)
-- ============================================================================

function HR:ResolveLootEntryWinner(dropEntry, sess)
    local winner = (dropEntry and dropEntry.winner) or (sess and sess.winnerName)
    local winnerClass = (dropEntry and dropEntry.winnerClass) or (sess and sess.winnerClass)
    local detail = (dropEntry and dropEntry.winDetail) or (sess and sess.winnerDetail)

    -- If a /rw bid/roll session wasn't finalized via direct loot (e.g. RL traded the item),
    -- use the clear single top bidder/roller from that session.
    if not winner and sess then
        local leaders, topVal, _, tag = self:GetTopContenders(sess)
        if #leaders == 1 then
            winner = leaders[1]
            winnerClass = self:GetPlayerClassFile(winner)
            local isCurrent = (sess == GetCurrentSession())
            detail = (isCurrent and "Leading: " or "") .. tostring(topVal) .. tag
        end
    end

    if winner and not winnerClass then
        winnerClass = self:GetPlayerClassFile(winner)
    end

    return winner, winnerClass, detail
end

function HR:BuildLootReportData()
    local items = {}
    local coveredSessions = {}

    for _, d in ipairs(self.raidState.droppedItems) do
        local sess = d.session
        if sess then
            coveredSessions[sess] = true
        end

        if self:IsEpicBoPOrTierToken(d.itemLink) then
            local winner, winnerClass, detail = self:ResolveLootEntryWinner(d, sess)
            local isQueued = (not winner) and (d.queued and true or false)
            local statusDetail = winner and (detail or "Won") or (isQueued and "Queued" or "Unclaimed")
            table.insert(items, {
                itemLink    = d.itemLink,
                itemName    = d.itemName or ExtractPlainItemName(d.itemLink),
                source      = d.source or "",
                winner      = winner,
                winnerClass = winnerClass,
                detail      = statusDetail,
                winDetail   = winner and (detail or "Won") or nil,
                queued      = isQueued,
                queuedBy    = isQueued and d.queuedBy or nil,
                bids        = sess and self:GetSortedBids(sess) or {},
                rolls       = sess and self:GetSortedRolls(sess) or {},
                session     = sess,
            })
        end
    end

    -- Include any qualifying /rw session that was not linked to a droppedItem (even if unclaimed)
    for _, sess in ipairs(self.raidState.sessions) do
        if not coveredSessions[sess] and self:IsEpicBoPOrTierToken(sess.itemLink) then
            local winner, winnerClass, detail = self:ResolveLootEntryWinner(nil, sess)
            table.insert(items, {
                itemLink    = sess.itemLink,
                itemName    = sess.itemName or ExtractPlainItemName(sess.itemLink),
                source      = "Raid Warning",
                winner      = winner,
                winnerClass = winnerClass,
                detail      = winner and (detail or "Won") or "Unclaimed",
                winDetail   = winner and (detail or "Won") or nil,
                queued      = false,
                queuedBy    = nil,
                bids        = self:GetSortedBids(sess),
                rolls       = self:GetSortedRolls(sess),
                session     = sess,
            })
        end
    end

    return items
end

function HR:HasLootToReport()
    return (#self:BuildLootReportData() > 0)
end

local function FormatBidsPlain(bids)
    local parts = {}
    for _, b in ipairs(bids) do
        if not b.ignored then
            local osStr = b.isOS and " [OS]" or ""
            table.insert(parts, string.format("%s %d%s", b.name, b.amount, osStr))
        end
    end
    return table.concat(parts, ", ")
end

local function FormatRollsPlain(rolls)
    local parts = {}
    for _, r in ipairs(rolls) do
        if not r.ignored then
            local tag = ""
            if r.category == "OS" then
                tag = " (OS 1-99)"
            elseif r.category == "INVALID" then
                tag = string.format(" (Invalid %d-%d)", r.low, r.high)
            end
            table.insert(parts, string.format("%s %d%s", r.name, r.value, tag))
        end
    end
    return table.concat(parts, ", ")
end

function HR:GenerateLootReportText()
    local data = self:BuildLootReportData()
    if #data == 0 then
        return "No loot to report."
    end

    local lines = {}
    table.insert(lines, "High Roller Loot Report (" .. GetFooterText() .. ")")
    table.insert(lines, "Website: " .. ADDON_URL)
    table.insert(lines, "Date: " .. date("%Y-%m-%d %H:%M"))
    table.insert(lines, "========================================")

    for i, item in ipairs(data) do
        table.insert(lines, string.format("%d. %s", i, item.itemName))
        if item.winner then
            table.insert(lines, string.format("   Winner: %s (%s)", item.winner, item.detail))
        elseif item.queued then
            table.insert(lines, "   Status: Queued")
        else
            table.insert(lines, "   Winner: Unclaimed")
        end

        local bidStr = FormatBidsPlain(item.bids)
        if bidStr ~= "" then
            table.insert(lines, "   Bids: " .. bidStr)
        end

        local rollStr = FormatRollsPlain(item.rolls)
        if rollStr ~= "" then
            table.insert(lines, "   Rolls: " .. rollStr)
        end

        if i < #data then
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

function HR:GenerateLootReportDiscord()
    local data = self:BuildLootReportData()
    if #data == 0 then
        return "No loot to report."
    end

    local lines = {}
    table.insert(lines, "**High Roller Loot Report**")
    table.insert(lines, "*" .. GetFooterText() .. " | " .. date("%Y-%m-%d %H:%M") .. "*")
    table.insert(lines, "Website: " .. ADDON_URL)
    table.insert(lines, "")

    for i, item in ipairs(data) do
        table.insert(lines, string.format("**%d. %s**", i, item.itemName))
        if item.winner then
            table.insert(lines, string.format("- **Winner:** %s *(%s)*", item.winner, item.detail))
        elseif item.queued then
            table.insert(lines, "- **Status:** *Queued*")
        else
            table.insert(lines, "- **Winner:** *Unclaimed*")
        end

        local bidParts = {}
        for _, b in ipairs(item.bids) do
            if not b.ignored then
                local osStr = b.isOS and " [OS]" or ""
                table.insert(bidParts, string.format("%s `%d%s`", b.name, b.amount, osStr))
            end
        end
        if #bidParts > 0 then
            table.insert(lines, "- **Bids:** " .. table.concat(bidParts, ", "))
        end

        local rollParts = {}
        for _, r in ipairs(item.rolls) do
            if not r.ignored then
                local tag = ""
                if r.category == "OS" then
                    tag = " OS"
                elseif r.category == "INVALID" then
                    tag = string.format(" %d-%d", r.low, r.high)
                end
                table.insert(rollParts, string.format("%s `%d%s`", r.name, r.value, tag))
            end
        end
        if #rollParts > 0 then
            table.insert(lines, "- **Rolls:** " .. table.concat(rollParts, ", "))
        end

        if i < #data then
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

function HR:GenerateLootReportHTML()
    local data = self:BuildLootReportData()
    if #data == 0 then
        return "<!-- No loot to report -->"
    end

    local lines = {}
    table.insert(lines, "<!DOCTYPE html>")
    table.insert(lines, '<html lang="en">')
    table.insert(lines, "<head>")
    table.insert(lines, '<meta charset="UTF-8">')
    table.insert(lines, "<title>High Roller Loot Report</title>")
    table.insert(lines, "<style>")
    table.insert(lines, "  body { background-color: #000000; color: #FFFFFF; font-family: Arial, Helvetica, sans-serif; font-size: 14px; margin: 20px; }")
    table.insert(lines, "  h2 { color: #FFD100; margin-bottom: 4px; }")
    table.insert(lines, "  .meta { color: #AAAAAA; font-size: 12px; margin-bottom: 16px; }")
    table.insert(lines, "  table { width: 100%; border-collapse: collapse; background-color: #0A0A0A; }")
    table.insert(lines, "  th, td { border: 1px solid #333333; padding: 8px 10px; text-align: left; vertical-align: top; }")
    table.insert(lines, "  th { background-color: #1A1A1A; color: #FFFFFF; }")
    table.insert(lines, "  tr:nth-child(even) { background-color: #111111; }")
    table.insert(lines, "  .unclaimed { color: #888888; font-style: italic; }")
    table.insert(lines, "  .queued { color: #FFCC00; font-style: italic; }")
    table.insert(lines, "  .detail { color: #CCCCCC; }")
    table.insert(lines, "  .os { color: #FF9900; font-weight: bold; }")
    table.insert(lines, "  .footer { margin-top: 14px; color: #888888; font-size: 12px; }")
    table.insert(lines, "  .footer a { color: #33FF99; text-decoration: none; }")
    table.insert(lines, "  .footer a:hover { text-decoration: underline; }")
    table.insert(lines, "</style>")
    table.insert(lines, "</head>")
    table.insert(lines, "<body>")
    table.insert(lines, "<h2>High Roller Loot Report</h2>")
    table.insert(lines, '<div class="meta">Generated: ' .. EscapeHTML(date("%Y-%m-%d %H:%M")) .. "</div>")
    table.insert(lines, "<table>")
    table.insert(lines, "  <thead>")
    table.insert(lines, "    <tr><th>#</th><th>Item</th><th>Winner</th><th>Winning Bid / Roll</th><th>Bids &amp; Rolls</th></tr>")
    table.insert(lines, "  </thead>")
    table.insert(lines, "  <tbody>")

    for i, item in ipairs(data) do
        local winnerHTML
        local detailHTML
        if item.winner then
            local hex = self:GetClassColorHex(item.winner, item.winnerClass)
            winnerHTML = string.format('<span style="color:#%s; font-weight:bold;">%s</span>', hex, EscapeHTML(item.winner))
            detailHTML = '<span class="detail">' .. EscapeHTML(item.detail) .. "</span>"
        elseif item.queued then
            winnerHTML = '<span class="queued">Queued</span>'
            detailHTML = '<span class="queued">-</span>'
        else
            winnerHTML = '<span class="unclaimed">Unclaimed</span>'
            detailHTML = '<span class="unclaimed">-</span>'
        end

        local activityParts = {}

        local bidCells = {}
        for _, b in ipairs(item.bids) do
            if not b.ignored then
                local hex = self:GetClassColorHex(b.name, b.classFile)
                local osHTML = b.isOS and ' <span class="os">[OS]</span>' or ""
                table.insert(bidCells, string.format('<span style="color:#%s; font-weight:bold;">%s</span> %d%s',
                    hex, EscapeHTML(b.name), b.amount, osHTML))
            end
        end
        if #bidCells > 0 then
            table.insert(activityParts, "<strong>Bids:</strong> " .. table.concat(bidCells, ", "))
        end

        local rollCells = {}
        for _, r in ipairs(item.rolls) do
            if not r.ignored then
                local hex = self:GetClassColorHex(r.name, r.classFile)
                local tagHTML = ""
                if r.category == "OS" then
                    tagHTML = ' <span class="os">(OS)</span>'
                elseif r.category == "INVALID" then
                    tagHTML = string.format(' <span style="color:#FF4444;">(%d-%d)</span>', r.low, r.high)
                end
                table.insert(rollCells, string.format('<span style="color:#%s; font-weight:bold;">%s</span> %d%s',
                    hex, EscapeHTML(r.name), r.value, tagHTML))
            end
        end
        if #rollCells > 0 then
            table.insert(activityParts, "<strong>Rolls:</strong> " .. table.concat(rollCells, ", "))
        end

        local activityHTML = (#activityParts > 0) and table.concat(activityParts, "<br>") or '<span class="unclaimed">None</span>'

        table.insert(lines, string.format("    <tr><td>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
            i, EscapeHTML(item.itemName), winnerHTML, detailHTML, activityHTML))
    end

    table.insert(lines, "  </tbody>")
    table.insert(lines, "</table>")
    table.insert(lines, '<div class="footer">' .. EscapeHTML(GetFooterText()) .. ' | <a href="' .. EscapeHTML(ADDON_URL) .. '" target="_blank">' .. EscapeHTML(ADDON_URL) .. "</a></div>")
    table.insert(lines, "</body>")
    table.insert(lines, "</html>")

    return table.concat(lines, "\n")
end

function HR:GenerateLootReportTSV()
    local data = self:BuildLootReportData()
    if #data == 0 then
        return "No loot to report."
    end

    local lines = {}
    table.insert(lines, "Item\tWinner\tClass\tWinning Bid/Roll\tBids\tRolls")

    for _, item in ipairs(data) do
        local winnerName  = item.winner or (item.queued and "Queued" or "Unclaimed")
        local winnerClass = item.winner and GetClassDisplayName(item.winnerClass) or ""
        local winDetail   = item.winner and (item.detail or "Won") or ""
        local bidStr      = FormatBidsPlain(item.bids)
        local rollStr     = FormatRollsPlain(item.rolls)

        table.insert(lines, table.concat({
            CleanTSVField(item.itemName),
            CleanTSVField(winnerName),
            CleanTSVField(winnerClass),
            CleanTSVField(winDetail),
            CleanTSVField(bidStr),
            CleanTSVField(rollStr),
        }, "\t"))
    end

    table.insert(lines, "")
    table.insert(lines, CleanTSVField(GetFooterText()) .. "\t" .. CleanTSVField(ADDON_URL))

    return table.concat(lines, "\n")
end

-- ============================================================================
-- 7. Panel Navigation Manager & Shared UI Utilities
-- ============================================================================

local DIALOG_BACKDROP = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true,
    tileSize = 32,
    edgeSize = 24,
    insets   = { left = 6, right = 6, top = 6, bottom = 6 },
}

local INNER_BOX_BACKDROP = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 16,
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}

HR.managedFrames = {}
HR.navStack      = {}
HR.activeMenuKey = nil

local function SaveFramePosition(frame, key)
    if not HighRollerDB or not HighRollerDB.positions then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        HighRollerDB.positions[key] = { point = point, relPoint = relPoint, x = x, y = y }
    end
end

local function RestoreFramePosition(frame, key)
    frame:ClearAllPoints()
    local pos = HighRollerDB and HighRollerDB.positions and HighRollerDB.positions[key]
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function HR:ResetAllWindowPositions()
    if HighRollerDB and HighRollerDB.positions then
        wipe(HighRollerDB.positions)
    end
    for _, frame in pairs(self.managedFrames) do
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if HighRollerDB and HighRollerDB.settings then
        HighRollerDB.settings.minimapAngle = 225
        if self.UpdateMinimapButtonPosition then
            self:UpdateMinimapButtonPosition()
        end
    end
    self:Print("All High Roller windows reset to center screen.")
end

-- Close all non-tracker panels (raidTracker stays open until manually closed)
function HR:CloseOtherPanels(exceptKey)
    for key, frame in pairs(self.managedFrames) do
        if key ~= "raidTracker" and key ~= exceptKey and frame:IsShown() then
            frame:Hide()
        end
    end
end

function HR:UpdateBackButtonState(frame)
    if not frame or not frame.backBtn then return end
    if frame.posKey == "raidTracker" then
        if frame.openedFrom then
            frame.backBtn:Enable()
        else
            frame.backBtn:Disable()
        end
    else
        if #self.navStack > 0 or frame.openedFrom then
            frame.backBtn:Enable()
        else
            frame.backBtn:Disable()
        end
    end
end

function HR:OpenPanel(targetKey, callerKey)
    local frame = self.managedFrames[targetKey]
    if not frame then return end

    if callerKey and callerKey ~= targetKey then
        if callerKey == "raidTracker" then
            wipe(self.navStack)
        end
        if self.navStack[#self.navStack] ~= callerKey then
            table.insert(self.navStack, callerKey)
        end
        frame.openedFrom = callerKey
    else
        wipe(self.navStack)
        frame.openedFrom = nil
    end

    self:CloseOtherPanels(targetKey)
    self.activeMenuKey = targetKey
    frame:Show()
    frame:Raise()
    self:UpdateBackButtonState(frame)
end

function HR:OpenRaidTracker(callerKey)
    local f = self.raidTrackerFrame
    if not f then return end

    if callerKey and callerKey ~= "raidTracker" then
        f.openedFrom = callerKey
        self:CloseOtherPanels(nil)
    end

    f:Show()
    f:Raise()
    self:UpdateBackButtonState(f)
    self:RefreshRaidTrackerUI()
end

function HR:GoBackFrom(currentKey)
    local currentFrame = self.managedFrames[currentKey]

    if currentKey == "raidTracker" then
        local prev = currentFrame and currentFrame.openedFrom
        if prev and self.managedFrames[prev] then
            self:CloseOtherPanels(prev)
            self.activeMenuKey = prev
            self.managedFrames[prev]:Show()
            self.managedFrames[prev]:Raise()
            self:UpdateBackButtonState(self.managedFrames[prev])
        end
        return
    end

    local prevKey = table.remove(self.navStack)
    if not prevKey and currentFrame then
        prevKey = currentFrame.openedFrom
    end

    if currentFrame then
        currentFrame:Hide()
    end

    if prevKey == "raidTracker" then
        if self.raidTrackerFrame then
            self.raidTrackerFrame:Show()
            self.raidTrackerFrame:Raise()
        end
    elseif prevKey and self.managedFrames[prevKey] then
        self:CloseOtherPanels(prevKey)
        self.activeMenuKey = prevKey
        self.managedFrames[prevKey]:Show()
        self.managedFrames[prevKey]:Raise()
        self:UpdateBackButtonState(self.managedFrames[prevKey])
    else
        self.activeMenuKey = nil
    end
end

local function CreateManagedWindow(globalName, posKey, width, height, titleText, allowEscClose, compactHeader)
    local f = CreateFrame("Frame", globalName, UIParent)
    f:SetSize(width, height)
    f:SetBackdrop(DIALOG_BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePosition(self, posKey)
    end)

    f.posKey = posKey
    if allowEscClose then
        table.insert(UISpecialFrames, globalName)
    end
    HR.managedFrames[posKey] = f

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    if compactHeader then
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    else
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    end
    f.closeBtn = closeBtn

    -- Back button on every panel
    local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    if compactHeader then
        backBtn:SetSize(38, 18)
        backBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -11)
    else
        backBtn:SetSize(44, 20)
        backBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    end
    backBtn:SetText("Back")
    backBtn:SetScript("OnClick", function()
        HR:GoBackFrom(posKey)
    end)
    f.backBtn = backBtn

    -- Title
    local titleFont = compactHeader and "GameFontNormal" or "GameFontNormalLarge"
    local title = f:CreateFontString(nil, "ARTWORK", titleFont)
    title:SetPoint("LEFT", backBtn, "RIGHT", 6, 0)
    title:SetText(titleText)
    f.titleText = title

    -- Dynamic Version + Author Footer
    local footer = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    footer:SetPoint("BOTTOM", f, "BOTTOM", 0, compactHeader and 9 or 12)
    footer:SetText(GetFooterText())
    f.footerText = footer

    RestoreFramePosition(f, posKey)
    f:Hide()
    return f
end

-- Dependency-free 3.3.5a Radio Button
local function CreateRadioButton(parent)
    local rb = CreateFrame("CheckButton", nil, parent)
    rb:SetSize(16, 16)

    local normal = rb:CreateTexture(nil, "BACKGROUND")
    normal:SetTexture("Interface\\Buttons\\UI-RadioButton")
    normal:SetTexCoord(0, 0.25, 0, 1)
    normal:SetAllPoints()
    rb:SetNormalTexture(normal)

    local highlight = rb:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-RadioButton")
    highlight:SetTexCoord(0.5, 0.75, 0, 1)
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()
    rb:SetHighlightTexture(highlight)

    local checked = rb:CreateTexture(nil, "ARTWORK")
    checked:SetTexture("Interface\\Buttons\\UI-RadioButton")
    checked:SetTexCoord(0.25, 0.5, 0, 1)
    checked:SetAllPoints()
    rb:SetCheckedTexture(checked)

    return rb
end

-- ============================================================================
-- 8. Movable Minimap Button
-- ============================================================================

function HR:CreateMinimapButton()
    local btn = CreateFrame("Button", "HighRollerMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetTexture("Interface\\Icons\\INV_Misc_Dice_02")
    bg:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    function HR:UpdateMinimapButtonPosition()
        local angle = math.rad(HighRollerDB.settings.minimapAngle or 225)
        local radius = 80
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    local isDragging = false
    btn:SetScript("OnDragStart", function(self)
        if HighRollerDB.settings.lockMinimap then return end
        isDragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local deg = math.deg(math.atan2(cy - my, cx - mx))
            HighRollerDB.settings.minimapAngle = deg
            HR:UpdateMinimapButtonPosition()
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        if isDragging then
            isDragging = false
            self:SetScript("OnUpdate", nil)
        end
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if HR.switcherFrame:IsShown() then
                HR.switcherFrame:Hide()
            else
                HR:OpenPanel("switcher", nil)
            end
        elseif button == "RightButton" then
            if HR.configFrame:IsShown() then
                HR.configFrame:Hide()
            else
                HR:OpenPanel("config", nil)
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("High Roller", 0.2, 1, 0.6)
        local state = HighRollerDB.settings.enabled and "|cff00ff00Enabled|r" or "|cffff4444Paused|r"
        GameTooltip:AddLine("Status: " .. state, 1, 1, 1)
        GameTooltip:AddLine("Profile: |cffffd100" .. tostring(HR:GetActiveProfileName()) .. "|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ccffLeft-Click:|r Switch Profile", 1, 1, 1)
        GameTooltip:AddLine("|cff00ccffRight-Click:|r Open Config", 1, 1, 1)
        if not HighRollerDB.settings.lockMinimap then
            GameTooltip:AddLine("|cffaaaaaaDrag to move around minimap|r", 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(GetFooterText(), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = btn
    self:UpdateMinimapButtonPosition()
end

-- ============================================================================
-- 9. Profile Switcher Panel (Left-Click Minimap Button)
-- ============================================================================

function HR:CreateSwitcherFrame()
    local f = CreateManagedWindow("HighRollerSwitcherFrame", "switcher", 285, 345, "High Roller", true, false)
    self.switcherFrame = f

    local configBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    configBtn:SetSize(58, 20)
    configBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -12)
    configBtn:SetText("Config")
    configBtn:SetScript("OnClick", function()
        HR:OpenPanel("config", "switcher")
    end)

    local statusText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    f.statusText = statusText

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -58)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 72)
    box:SetBackdrop(INNER_BOX_BACKDROP)
    box:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

    local scroll = CreateFrame("ScrollFrame", "HighRollerSwitcherScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(220, 1)
    scroll:SetScrollChild(content)
    f.scrollContent = content
    f.rows = {}

    local editBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    editBtn:SetSize(120, 24)
    editBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 36)
    editBtn:SetText("Edit Profiles")
    editBtn:SetScript("OnClick", function()
        HR:OpenPanel("editProfiles", "switcher")
    end)

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(120, 24)
    addBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 36)
    addBtn:SetText("Add Profile")
    addBtn:SetScript("OnClick", function()
        HR:OpenPolicyEditor(nil, "switcher")
    end)

    f:SetScript("OnShow", function()
        HR:RefreshSwitcherUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:RefreshSwitcherUI()
    local f = self.switcherFrame
    if not f then return end

    local stateStr = HighRollerDB.settings.enabled and "|cff00ff00Enabled|r" or "|cffff4444Paused|r"
    f.statusText:SetText("Select Profile (Auto-Roll: " .. stateStr .. ")")

    local names = SortedKeys(HighRollerDB.profiles)
    local active = self:GetActiveProfileName()

    for _, row in ipairs(f.rows) do
        row:Hide()
    end

    local rowHeight = 24
    for i, name in ipairs(names) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Button", nil, f.scrollContent)
            row:SetSize(218, rowHeight)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(1, 1, 1, 0.08)

            row.radio = CreateRadioButton(row)
            row.radio:SetPoint("LEFT", row, "LEFT", 4, 0)

            row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.label:SetPoint("LEFT", row.radio, "RIGHT", 6, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.label:SetJustifyH("LEFT")

            f.rows[i] = row
        end

        row:SetPoint("TOPLEFT", f.scrollContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row.profileName = name
        row.label:SetText(name)

        local isSelected = (name == active)
        row.radio:SetChecked(isSelected and 1 or nil)
        if isSelected then
            row.label:SetTextColor(1, 0.85, 0.2)
        else
            row.label:SetTextColor(1, 1, 1)
        end

        local function OnPick()
            HR:SetActiveProfile(name)
        end
        row:SetScript("OnClick", OnPick)
        row.radio:SetScript("OnClick", OnPick)

        row:Show()
    end

    f.scrollContent:SetHeight(math.max(1, #names * rowHeight))
end

-- ============================================================================
-- 10. Config Panel (Right-Click Minimap Button or Config Button)
-- ============================================================================

local function CreateConfigCheckbox(parent, globalName, labelText, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", globalName, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local txt = _G[globalName .. "Text"]
    txt:SetText(labelText)
    txt:SetTextColor(1, 1, 1)
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        HR:RefreshAllUI()
    end)
    cb.Refresh = function()
        cb:SetChecked(getter() and 1 or nil)
    end
    return cb
end

local OPT_ROLL_DELAY = {
    { value = 0,   text = "Instant (0s)" },
    { value = 0.5, text = "0.5s" },
    { value = 1.0, text = "1.0s" },
    { value = 1.5, text = "1.5s" },
}

local function FindDelayLabel(val)
    for _, opt in ipairs(OPT_ROLL_DELAY) do
        if opt.value == val then return opt.text end
    end
    return "Instant (0s)"
end

function HR:CreateConfigFrame()
    local f = CreateManagedWindow("HighRollerConfigFrame", "config", 356, 500, "Config", true, false)
    self.configFrame = f
    f.checks = {}
    f.dropdowns = {}

    table.insert(f.checks, CreateConfigCheckbox(
        f, "HighRollerCfgEnabled", "Enable Automatic Loot Rolling", 18, -44,
        function() return HighRollerDB.settings.enabled end,
        function(v) HighRollerDB.settings.enabled = v end
    ))

    table.insert(f.checks, CreateConfigCheckbox(
        f, "HighRollerCfgLog", "Personal Chat Messages on Roll", 18, -70,
        function() return HighRollerDB.settings.logActions end,
        function(v) HighRollerDB.settings.logActions = v end
    ))

    table.insert(f.checks, CreateConfigCheckbox(
        f, "HighRollerCfgAutoTracker", "Auto-Open Raid Tracker on /rw Item", 18, -96,
        function() return HighRollerDB.settings.autoOpenTracker end,
        function(v) HighRollerDB.settings.autoOpenTracker = v end
    ))

    table.insert(f.checks, CreateConfigCheckbox(
        f, "HighRollerCfgLockMM", "Lock Minimap Button", 18, -122,
        function() return HighRollerDB.settings.lockMinimap end,
        function(v) HighRollerDB.settings.lockMinimap = v end
    ))

    table.insert(f.checks, CreateConfigCheckbox(
        f, "HighRollerCfgMSBeatsOS", "MS Bids Sort Above [OS] Bids", 18, -148,
        function() return HighRollerDB.settings.msBidsBeatOS end,
        function(v) HighRollerDB.settings.msBidsBeatOS = v end
    ))

    -- Roll Delay dropdown
    local delayLbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    delayLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -182)
    delayLbl:SetText("Roll Delay:")
    delayLbl:SetTextColor(1, 1, 1)

    local delayDD = CreateFrame("Frame", "HighRollerCfgRollDelayDD", f, "UIDropDownMenuTemplate")
    delayDD:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -196)
    UIDropDownMenu_SetWidth(delayDD, 290)
    local delayDDText = _G["HighRollerCfgRollDelayDDText"]
    if delayDDText then delayDDText:SetTextColor(1, 1, 1) end

    UIDropDownMenu_Initialize(delayDD, function(self, level)
        local current = HighRollerDB.settings.rollDelay or 0
        for _, opt in ipairs(OPT_ROLL_DELAY) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.checked = (opt.value == current)
            info.func = function()
                HighRollerDB.settings.rollDelay = opt.value
                UIDropDownMenu_SetSelectedValue(delayDD, opt.value)
                UIDropDownMenu_SetText(delayDD, opt.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    delayDD.Refresh = function()
        local val = HighRollerDB.settings.rollDelay or 0
        UIDropDownMenu_SetSelectedValue(delayDD, val)
        UIDropDownMenu_SetText(delayDD, FindDelayLabel(val))
        if delayDDText then delayDDText:SetTextColor(1, 1, 1) end
    end
    table.insert(f.dropdowns, delayDD)

    -- Helper for Instance Auto-Profile dropdowns
    local function AddInstanceProfileDropdown(globalName, labelText, settingKey, y)
        local lbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(1, 1, 1)

        local dd = CreateFrame("Frame", globalName, f, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", f, "TOPLEFT", 4, y - 14)
        UIDropDownMenu_SetWidth(dd, 290)
        local ddText = _G[globalName .. "Text"]
        if ddText then ddText:SetTextColor(1, 1, 1) end

        local NONE_LABEL = "None (Don't Auto-Switch)"

        UIDropDownMenu_Initialize(dd, function(self, level)
            local current = HighRollerDB.settings[settingKey] or ""

            local noneInfo = UIDropDownMenu_CreateInfo()
            noneInfo.text = NONE_LABEL
            noneInfo.value = ""
            noneInfo.checked = (current == "")
            noneInfo.func = function()
                HighRollerDB.settings[settingKey] = ""
                UIDropDownMenu_SetSelectedValue(dd, "")
                UIDropDownMenu_SetText(dd, NONE_LABEL)
            end
            UIDropDownMenu_AddButton(noneInfo, level)

            for _, profName in ipairs(SortedKeys(HighRollerDB.profiles)) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = profName
                info.value = profName
                info.checked = (current == profName)
                info.func = function()
                    HighRollerDB.settings[settingKey] = profName
                    UIDropDownMenu_SetSelectedValue(dd, profName)
                    UIDropDownMenu_SetText(dd, profName)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        dd.Refresh = function()
            local val = HighRollerDB.settings[settingKey] or ""
            if val ~= "" and not HighRollerDB.profiles[val] then
                val = ""
                HighRollerDB.settings[settingKey] = ""
            end
            UIDropDownMenu_SetSelectedValue(dd, val)
            UIDropDownMenu_SetText(dd, (val ~= "") and val or NONE_LABEL)
            if ddText then ddText:SetTextColor(1, 1, 1) end
        end

        table.insert(f.dropdowns, dd)
    end

    AddInstanceProfileDropdown("HighRollerCfgDungeonProfDD", "5-Man Dungeon Profile:", "autoProfileDungeon", -232)
    AddInstanceProfileDropdown("HighRollerCfgRaidProfDD",    "Raid Profile:",          "autoProfileRaid",    -282)

    local editProfilesBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    editProfilesBtn:SetSize(154, 24)
    editProfilesBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -340)
    editProfilesBtn:SetText("Edit Profiles")
    editProfilesBtn:SetScript("OnClick", function()
        HR:OpenPanel("editProfiles", "config")
    end)

    local trackerBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    trackerBtn:SetSize(154, 24)
    trackerBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -340)
    trackerBtn:SetText("Raid Tracker")
    trackerBtn:SetScript("OnClick", function()
        HR:OpenRaidTracker("config")
    end)

    local overridesBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    overridesBtn:SetSize(154, 24)
    overridesBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -372)
    overridesBtn:SetText("Item Overrides")
    overridesBtn:SetScript("OnClick", function()
        HR:OpenPanel("itemOverrides", "config")
    end)

    local testModeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    testModeBtn:SetSize(154, 24)
    testModeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -372)
    testModeBtn:SetText("Test Mode")
    testModeBtn:SetScript("OnClick", function()
        HR:RunSoloTest()
    end)

    local resetPosBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(320, 24)
    resetPosBtn:SetPoint("TOP", f, "TOP", 0, -404)
    resetPosBtn:SetText("Reset Window Positions to Center")
    resetPosBtn:SetScript("OnClick", function()
        HR:ResetAllWindowPositions()
    end)

    local restoreBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    restoreBtn:SetSize(320, 24)
    restoreBtn:SetPoint("TOP", f, "TOP", 0, -436)
    restoreBtn:SetText("Restore Default Profiles")
    restoreBtn:SetScript("OnClick", function()
        HR:RestoreDefaultProfiles()
    end)

    f:SetScript("OnShow", function()
        HR:RefreshConfigUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:RefreshConfigUI()
    local f = self.configFrame
    if not f then return end
    for _, cb in ipairs(f.checks) do
        cb.Refresh()
    end
    for _, dd in ipairs(f.dropdowns) do
        dd.Refresh()
    end
end

-- ============================================================================
-- 11. Edit Profiles Panel & Policy Editor Panel (Pure White Text on Black BG)
-- ============================================================================

StaticPopupDialogs["HIGHROLLER_CONFIRM_DELETE"] = {
    text = "Are you sure you want to delete the policies for \"%s\"?",
    button1 = YES,
    button2 = CANCEL,
    OnAccept = function(self, profileName)
        HR:DeleteProfile(profileName)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function HR:CreateEditProfilesFrame()
    local f = CreateManagedWindow("HighRollerEditProfilesFrame", "editProfiles", 388, 345, "Edit Profiles", true, false)
    self.editProfilesFrame = f

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -44)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 72)
    box:SetBackdrop(INNER_BOX_BACKDROP)
    box:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

    local scroll = CreateFrame("ScrollFrame", "HighRollerEditProfilesScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(322, 1)
    scroll:SetScrollChild(content)
    f.scrollContent = content
    f.rows = {}

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(150, 24)
    addBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 36)
    addBtn:SetText("Add Profile")
    addBtn:SetScript("OnClick", function()
        HR:OpenPolicyEditor(nil, "editProfiles")
    end)

    local switcherBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    switcherBtn:SetSize(150, 24)
    switcherBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 36)
    switcherBtn:SetText("Profile Switcher")
    switcherBtn:SetScript("OnClick", function()
        HR:OpenPanel("switcher", "editProfiles")
    end)

    f:SetScript("OnShow", function()
        HR:RefreshEditProfilesUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:RefreshEditProfilesUI()
    local f = self.editProfilesFrame
    if not f then return end

    local names = SortedKeys(HighRollerDB.profiles)
    local active = self:GetActiveProfileName()

    for _, row in ipairs(f.rows) do
        row:Hide()
    end

    local rowHeight = 26
    for i, name in ipairs(names) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, f.scrollContent)
            row:SetSize(320, rowHeight)

            row.delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.delBtn:SetSize(52, 20)
            row.delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.delBtn:SetText("Delete")

            row.editBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.editBtn:SetSize(44, 20)
            row.editBtn:SetPoint("RIGHT", row.delBtn, "LEFT", -4, 0)
            row.editBtn:SetText("Edit")

            row.copyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.copyBtn:SetSize(46, 20)
            row.copyBtn:SetPoint("RIGHT", row.editBtn, "LEFT", -4, 0)
            row.copyBtn:SetText("Copy")

            row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.label:SetPoint("RIGHT", row.copyBtn, "LEFT", -6, 0)
            row.label:SetJustifyH("LEFT")

            f.rows[i] = row
        end

        row:SetPoint("TOPLEFT", f.scrollContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
        if name == active then
            row.label:SetText("* " .. name)
            row.label:SetTextColor(1, 0.85, 0.2)
        else
            row.label:SetText(name)
            row.label:SetTextColor(1, 1, 1)
        end

        row.copyBtn:SetScript("OnClick", function()
            HR:CopyProfile(name, "editProfiles")
        end)

        row.editBtn:SetScript("OnClick", function()
            HR:OpenPolicyEditor(name, "editProfiles")
        end)

        row.delBtn:SetScript("OnClick", function()
            local popup = StaticPopup_Show("HIGHROLLER_CONFIRM_DELETE", name)
            if popup then
                popup.data = name
            end
        end)

        row:Show()
    end

    f.scrollContent:SetHeight(math.max(1, #names * rowHeight))
end

local OPT_ROLL = {
    { value = "DISENCHANT", text = "Disenchant" },
    { value = "GREED",      text = "Greed" },
    { value = "NEED",       text = "Need" },
    { value = "PASS",       text = "Pass" },
    { value = "MANUAL",     text = "Do not Automate" },
}

local OPT_NO_DE = {
    { value = "NEED",   text = "Need" },
    { value = "GREED",  text = "Greed" },
    { value = "PASS",   text = "Pass" },
    { value = "MANUAL", text = "Do not Automate" },
}

local OPT_FALLBACK = {
    { value = "GREED",  text = "Greed" },
    { value = "PASS",   text = "Pass" },
    { value = "NEED",   text = "Need" },
    { value = "MANUAL", text = "Do not Automate" },
}

local OPT_BOP_DE = {
    { value = "OK",           text = "Auto Click OK" },
    { value = "CANCEL",       text = "Auto Click Cancel" },
    { value = "CANCEL_GREED", text = "Cancel & Roll Greed" },
    { value = "CANCEL_PASS",  text = "Cancel & Pass" },
    { value = "MANUAL",       text = "Do not Automate" },
}

local OPT_BOP_LOOT = {
    { value = "OK",     text = "Auto Click OK" },
    { value = "CANCEL", text = "Auto Click Cancel" },
    { value = "MANUAL", text = "Do not Automate" },
}

local function FindOptionLabel(options, value)
    for _, opt in ipairs(options) do
        if opt.value == value then return opt.text end
    end
    return tostring(value)
end

function HR:CreatePolicyEditorFrame()
    local f = CreateManagedWindow("HighRollerPolicyEditorFrame", "policyEditor", 496, 552, "Policy Editor", true, false)
    self.policyEditorFrame = f

    -- Crisp white title & footer on dark backdrop
    f.titleText:SetTextColor(1, 1, 1)

    f.draft = DeepCopy(self.DEFAULT_TEMPLATE)
    f.editingOriginalName = nil
    f.dropdowns = {}

    local nameLbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -44)
    nameLbl:SetText("Profile Name:")
    nameLbl:SetTextColor(1, 1, 1)

    local nameBox = CreateFrame("EditBox", "HighRollerProfileNameEditBox", f, "InputBoxTemplate")
    nameBox:SetSize(270, 22)
    nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 10, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(32)
    nameBox:SetTextColor(1, 1, 1)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.nameBox = nameBox

    local function AddPolicyDropdown(globalName, labelText, fieldKey, options, x, y)
        local lbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", x + 16, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(1, 1, 1)

        local dd = CreateFrame("Frame", globalName, f, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - 14)
        UIDropDownMenu_SetWidth(dd, 188)

        local ddText = _G[globalName .. "Text"]
        if ddText then
            ddText:SetTextColor(1, 1, 1)
        end

        UIDropDownMenu_Initialize(dd, function(self, level)
            local current = f.draft[fieldKey]
            for _, opt in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.value = opt.value
                info.checked = (opt.value == current)
                info.func = function()
                    f.draft[fieldKey] = opt.value
                    UIDropDownMenu_SetSelectedValue(dd, opt.value)
                    UIDropDownMenu_SetText(dd, opt.text)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        dd.Refresh = function()
            local val = f.draft[fieldKey]
            UIDropDownMenu_SetSelectedValue(dd, val)
            UIDropDownMenu_SetText(dd, FindOptionLabel(options, val))
            if ddText then
                ddText:SetTextColor(1, 1, 1)
            end
        end

        table.insert(f.dropdowns, dd)
    end

    -- Pure white labels for high readability on black background (2 columns x 8 rows)
    local colL, colR = 8, 250

    AddPolicyDropdown("HighRollerPolGreen",     "Uncommon (Green) Loot",               "greenLoot",               OPT_ROLL,     colL, -74)
    AddPolicyDropdown("HighRollerPolBlueGen",   "Rare (Blue) BoE / General",           "blueGeneral",             OPT_ROLL,     colR, -74)

    AddPolicyDropdown("HighRollerPolEpicBoE",   "Epic BoE Items",                      "epicBoE",                 OPT_ROLL,     colL, -120)
    AddPolicyDropdown("HighRollerPolBlueBoP",   "Blue BoP Equip & Weapons",            "blueBoPGear",             OPT_ROLL,     colR, -120)

    AddPolicyDropdown("HighRollerPolEpicBoP",   "Epic BoP Items",                      "epicBoPGear",             OPT_ROLL,     colL, -166)
    AddPolicyDropdown("HighRollerPolFallback",  "No-Enchanter / Can't DE Fallback",    "noEnchanterFallback",     OPT_FALLBACK, colR, -166)

    AddPolicyDropdown("HighRollerPolOrbs",      "Orbs & High-Value Mats",              "orbs",                    OPT_NO_DE,    colL, -212)
    AddPolicyDropdown("HighRollerPolRecBoE",    "BoE Recipes",                         "recipeBoE",               OPT_NO_DE,    colR, -212)

    AddPolicyDropdown("HighRollerPolRecBoPUnl", "BoP Recipes (Known Prof, Unlearned)", "recipeBoPKnownUnlearned", OPT_NO_DE,    colL, -258)
    AddPolicyDropdown("HighRollerPolRecBoPOth", "BoP Recipes (Known / Unusable)",      "recipeBoPOther",          OPT_NO_DE,    colR, -258)

    AddPolicyDropdown("HighRollerPolMountUnl",  "Mounts (Don't Know)",                 "mountUnlearned",          OPT_NO_DE,    colL, -304)
    AddPolicyDropdown("HighRollerPolMountKwn",  "Mounts (Already Know)",               "mountKnown",              OPT_NO_DE,    colR, -304)

    AddPolicyDropdown("HighRollerPolPetUnl",    "Pets (Don't Know)",                   "petUnlearned",            OPT_NO_DE,    colL, -350)
    AddPolicyDropdown("HighRollerPolPetKwn",    "Pets (Already Know)",                 "petKnown",                OPT_NO_DE,    colR, -350)

    AddPolicyDropdown("HighRollerPolBopDE",     "BoP Disenchant Popup",                "bopDEConfirm",            OPT_BOP_DE,   colL, -396)
    AddPolicyDropdown("HighRollerPolBopLoot",   "BoP Need / Greed Popup",              "bopLootConfirm",          OPT_BOP_LOOT, colR, -396)

    local jcCheck = CreateFrame("CheckButton", "HighRollerPolPassJC", f, "InterfaceOptionsCheckButtonTemplate")
    jcCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -448)
    local jcText = _G["HighRollerPolPassJCText"]
    jcText:SetText("Pass on BoP Jewelcrafting Recipes (always pass BoP JC designs)")
    jcText:SetTextColor(1, 1, 1)
    jcCheck:SetScript("OnClick", function(self)
        f.draft.passJCRecipes = self:GetChecked() and true or false
    end)
    f.jcCheck = jcCheck

    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(130, 26)
    saveBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 96, 38)
    saveBtn:SetText("Save Profile")
    saveBtn:SetScript("OnClick", function()
        HR:SavePolicyEditor()
    end)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(110, 26)
    cancelBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -96, 38)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        HR:GoBackFrom("policyEditor")
    end)

    f:SetScript("OnShow", function()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:OpenPolicyEditor(existingProfileName, callerKey, highlightName)
    local f = self.policyEditorFrame
    if not f then return end

    if existingProfileName and HighRollerDB.profiles[existingProfileName] then
        f.editingOriginalName = existingProfileName
        f.draft = DeepCopy(HighRollerDB.profiles[existingProfileName])
        f.titleText:SetText("Edit Profile")
        f.nameBox:SetText(existingProfileName)
    else
        f.editingOriginalName = nil
        f.draft = DeepCopy(self.DEFAULT_TEMPLATE)
        f.titleText:SetText("Add Profile")
        f.nameBox:SetText("")
    end

    for _, dd in ipairs(f.dropdowns) do
        dd.Refresh()
    end
    f.jcCheck:SetChecked(f.draft.passJCRecipes and 1 or nil)

    self:OpenPanel("policyEditor", callerKey)
    f.nameBox:SetFocus()
    if highlightName then
        f.nameBox:HighlightText()
    end
end

function HR:SavePolicyEditor()
    local f = self.policyEditorFrame
    if not f then return end

    local newName = strtrim(f.nameBox:GetText() or "")
    if newName == "" then
        self:Print("Please enter a profile name before saving.")
        return
    end

    local orig = f.editingOriginalName
    if newName ~= orig and HighRollerDB.profiles[newName] then
        self:Print("A profile named \"" .. newName .. "\" already exists.")
        return
    end

    if orig and orig ~= newName then
        HighRollerDB.profiles[orig] = nil
        for charKey, activeName in pairs(HighRollerDB.activeProfileByChar) do
            if activeName == orig then
                HighRollerDB.activeProfileByChar[charKey] = newName
            end
        end
        if HighRollerDB.settings.autoProfileDungeon == orig then
            HighRollerDB.settings.autoProfileDungeon = newName
        end
        if HighRollerDB.settings.autoProfileRaid == orig then
            HighRollerDB.settings.autoProfileRaid = newName
        end
    end

    SanitizeProfileNonDEFields(f.draft)
    HighRollerDB.profiles[newName] = DeepCopy(f.draft)
    if not orig then
        self:Print("Saved new profile: |cffffd100" .. newName .. "|r")
    else
        self:Print("Updated profile: |cffffd100" .. newName .. "|r")
    end

    self:GoBackFrom("policyEditor")
    self:RefreshAllUI()
end

-- Custom Item Overrides / Exceptions Panel (Priority 0 in OnStartLootRoll)
function HR:CreateItemOverridesFrame()
    local f = CreateManagedWindow("HighRollerItemOverridesFrame", "itemOverrides", 448, 412, "Item Overrides", true, false)
    self.itemOverridesFrame = f
    f.titleText:SetTextColor(1, 1, 1)
    f.selectedAction = "NEED"

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
    hint:SetText("Enter an Item ID or Shift-click an item link (overrides all profiles):")
    hint:SetTextColor(1, 1, 1)

    local itemLbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    itemLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -64)
    itemLbl:SetText("Item ID / Link:")
    itemLbl:SetTextColor(1, 1, 1)

    local itemBox = CreateFrame("EditBox", "HighRollerOverrideItemBox", f, "InputBoxTemplate")
    itemBox:SetSize(296, 22)
    itemBox:SetPoint("LEFT", itemLbl, "RIGHT", 10, 0)
    itemBox:SetAutoFocus(false)
    itemBox:SetMaxLetters(256)
    itemBox:SetTextColor(1, 1, 1)
    itemBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    itemBox:SetScript("OnEnterPressed", function(self)
        if HR:SetItemOverride(self:GetText(), f.selectedAction) then
            self:SetText("")
            self:ClearFocus()
        end
    end)
    f.itemBox = itemBox

    -- Allow Shift-clicking items from bags/chat/loot/tooltips into the focused Item Override box
    if not HR.chatLinkHooked then
        HR.chatLinkHooked = true
        hooksecurefunc("ChatEdit_InsertLink", function(text)
            if text and HR.itemOverridesFrame and HR.itemOverridesFrame:IsShown()
                and HR.itemOverridesFrame.itemBox and HR.itemOverridesFrame.itemBox:HasFocus() then
                HR.itemOverridesFrame.itemBox:SetText(text)
                HR.itemOverridesFrame.itemBox:HighlightText()
            end
        end)
    end

    local actLbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    actLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -98)
    actLbl:SetText("Forced Action:")
    actLbl:SetTextColor(1, 1, 1)

    local actDD = CreateFrame("Frame", "HighRollerOverrideActionDD", f, "UIDropDownMenuTemplate")
    actDD:SetPoint("LEFT", actLbl, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(actDD, 160)
    local actDDText = _G["HighRollerOverrideActionDDText"]
    if actDDText then actDDText:SetTextColor(1, 1, 1) end

    UIDropDownMenu_Initialize(actDD, function(self, level)
        for _, opt in ipairs(OPT_ROLL) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.checked = (opt.value == f.selectedAction)
            info.func = function()
                f.selectedAction = opt.value
                UIDropDownMenu_SetSelectedValue(actDD, opt.value)
                UIDropDownMenu_SetText(actDD, opt.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    actDD.Refresh = function()
        UIDropDownMenu_SetSelectedValue(actDD, f.selectedAction)
        UIDropDownMenu_SetText(actDD, FindOptionLabel(OPT_ROLL, f.selectedAction))
        if actDDText then actDDText:SetTextColor(1, 1, 1) end
    end
    f.actDD = actDD

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(112, 24)
    addBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -92)
    addBtn:SetText("Add / Update")
    addBtn:SetScript("OnClick", function()
        if HR:SetItemOverride(f.itemBox:GetText(), f.selectedAction) then
            f.itemBox:SetText("")
            f.itemBox:ClearFocus()
        end
    end)

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -126)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 34)
    box:SetBackdrop(INNER_BOX_BACKDROP)
    box:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

    local scroll = CreateFrame("ScrollFrame", "HighRollerOverridesScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(382, 1)
    scroll:SetScrollChild(content)
    f.scrollContent = content
    f.rows = {}

    local emptyText = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", box, "CENTER", -8, 0)
    emptyText:SetText("No custom item overrides configured.")
    f.emptyText = emptyText

    f:SetScript("OnShow", function()
        HR:RefreshItemOverridesUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:RefreshItemOverridesUI()
    local f = self.itemOverridesFrame
    if not f then return end

    if f.actDD then
        f.actDD.Refresh()
    end

    for _, row in ipairs(f.rows) do
        row:Hide()
    end

    local ids = {}
    if HighRollerDB and type(HighRollerDB.itemOverrides) == "table" then
        for k in pairs(HighRollerDB.itemOverrides) do
            local numID = tonumber(k)
            if numID then
                table.insert(ids, numID)
            end
        end
    end
    table.sort(ids)

    if #ids == 0 then
        f.emptyText:Show()
        f.scrollContent:SetHeight(1)
        return
    end
    f.emptyText:Hide()

    local ACTION_HEX = {
        NEED       = "00FF66",
        GREED      = "FFD100",
        DISENCHANT = "CC66FF",
        PASS       = "FF5555",
        MANUAL     = "AAAAAA",
    }

    local rowHeight = 26
    for i, itemID in ipairs(ids) do
        local entry = HighRollerDB.itemOverrides[itemID] or HighRollerDB.itemOverrides[tostring(itemID)]
        local action = (type(entry) == "table" and entry.action) or (type(entry) == "string" and entry) or "MANUAL"
        local infoName, infoLink = GetItemInfo(itemID)
        local displayLink = infoLink or (type(entry) == "table" and entry.link) or nil
        local displayName = infoName or (type(entry) == "table" and entry.name) or ("Item #" .. tostring(itemID))

        if type(entry) == "table" and infoLink and not entry.link then
            entry.link = infoLink
            entry.name = infoName or entry.name
        end

        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, f.scrollContent)
            row:SetSize(380, rowHeight)

            row.remBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remBtn:SetSize(60, 20)
            row.remBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.remBtn:SetText("Remove")

            row.actText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.actText:SetPoint("RIGHT", row.remBtn, "LEFT", -6, 0)
            row.actText:SetWidth(98)
            row.actText:SetJustifyH("RIGHT")

            row.itemBtn = CreateFrame("Button", nil, row)
            row.itemBtn:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.itemBtn:SetPoint("RIGHT", row.actText, "LEFT", -6, 0)
            row.itemBtn:SetHeight(22)

            local hl = row.itemBtn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(1, 1, 1, 0.08)

            row.itemText = row.itemBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.itemText:SetAllPoints()
            row.itemText:SetJustifyH("LEFT")

            f.rows[i] = row
        end

        row:SetPoint("TOPLEFT", f.scrollContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
        if displayLink then
            row.itemText:SetText(string.format("%s |cff888888(%d)|r", displayLink, itemID))
        else
            row.itemText:SetText(string.format("|cffffffff%s|r |cff888888(%d)|r", displayName, itemID))
        end

        local hex = ACTION_HEX[action] or "FFFFFF"
        row.actText:SetText(string.format("|cff%s%s|r", hex, ACTION_LABELS[action] or tostring(action)))

        row.itemBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(displayLink or ("item:" .. tostring(itemID)))
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Priority 0 Override: " .. (ACTION_LABELS[action] or tostring(action)), 0.2, 1, 0.6)
            GameTooltip:AddLine("Click to edit in input box", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        row.itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.itemBtn:SetScript("OnClick", function()
            if IsShiftKeyDown() and displayLink then
                ChatEdit_InsertLink(displayLink)
                return
            end
            f.itemBox:SetText(displayLink or tostring(itemID))
            f.selectedAction = action
            f.actDD.Refresh()
            f.itemBox:SetFocus()
        end)

        row.remBtn:SetScript("OnClick", function()
            HR:RemoveItemOverride(itemID)
        end)

        row:Show()
    end

    f.scrollContent:SetHeight(math.max(1, #ids * rowHeight))
end

-- ============================================================================
-- 12. Boss Loot Queue, Loot Summary & Loot Report Export Panel
-- ============================================================================

function HR:CreateBossLootFrame()
    local f = CreateManagedWindow("HighRollerBossLootFrame", "bossLoot", 290, 265, "Boss Loot Queue", true, false)
    self.bossLootFrame = f

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -38)
    hint:SetText("Click MS, OS, or Bid to announce in /rw:")

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -56)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 34)
    box:SetBackdrop(INNER_BOX_BACKDROP)
    box:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

    local scroll = CreateFrame("ScrollFrame", "HighRollerBossLootScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(225, 1)
    scroll:SetScrollChild(content)
    f.scrollContent = content
    f.rows = {}

    f:SetScript("OnShow", function()
        HR:RefreshBossLootUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:RefreshBossLootUI()
    local f = self.bossLootFrame
    if not f then return end

    for _, r in ipairs(f.rows) do r:Hide() end

    local items = self.raidState.bossLoot
    local rowHeight = 26
    for i, item in ipairs(items) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, f.scrollContent)
            row:SetSize(224, rowHeight)

            row.bidBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.bidBtn:SetSize(30, 20)
            row.bidBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.bidBtn:SetText("Bid")

            row.osBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.osBtn:SetSize(28, 20)
            row.osBtn:SetPoint("RIGHT", row.bidBtn, "LEFT", -2, 0)
            row.osBtn:SetText("OS")

            row.msBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.msBtn:SetSize(28, 20)
            row.msBtn:SetPoint("RIGHT", row.osBtn, "LEFT", -2, 0)
            row.msBtn:SetText("MS")

            row.linkBtn = CreateFrame("Button", nil, row)
            row.linkBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.linkBtn:SetPoint("RIGHT", row.msBtn, "LEFT", -4, 0)
            row.linkBtn:SetHeight(22)

            row.text = row.linkBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.text:SetAllPoints()
            row.text:SetJustifyH("LEFT")

            f.rows[i] = row
        end

        row:SetPoint("TOPLEFT", f.scrollContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row.text:SetText(item.link)

        row.linkBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.link)
            GameTooltip:Show()
        end)
        row.linkBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.msBtn:SetScript("OnClick", function()
            HR:SendRaidMessage("Roll MS (1-100): " .. item.link, true)
        end)
        row.osBtn:SetScript("OnClick", function()
            HR:SendRaidMessage("Roll OS (1-99): " .. item.link, true)
        end)
        row.bidBtn:SetScript("OnClick", function()
            HR:SendRaidMessage("Bidding Open: " .. item.link, true)
        end)

        row:Show()
    end

    f.scrollContent:SetHeight(math.max(1, #items * rowHeight))
end

function HR:CreateLootReportFrame()
    local f = CreateManagedWindow("HighRollerReportFrame", "lootReport", 506, 380, "Loot Report", true, false)
    self.lootReportFrame = f

    -- Format switcher buttons inside report window
    local textTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    textTab:SetSize(78, 22)
    textTab:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    textTab:SetText("Plain Text")
    textTab:SetScript("OnClick", function()
        HighRollerDB.raidTracker.reportFormat = "TEXT"
        HR:RefreshLootReportUI()
    end)
    f.textTab = textTab

    local discordTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    discordTab:SetSize(72, 22)
    discordTab:SetPoint("LEFT", textTab, "RIGHT", 4, 0)
    discordTab:SetText("Discord")
    discordTab:SetScript("OnClick", function()
        HighRollerDB.raidTracker.reportFormat = "DISCORD"
        HR:RefreshLootReportUI()
    end)
    f.discordTab = discordTab

    local htmlTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    htmlTab:SetSize(64, 22)
    htmlTab:SetPoint("LEFT", discordTab, "RIGHT", 4, 0)
    htmlTab:SetText("HTML")
    htmlTab:SetScript("OnClick", function()
        HighRollerDB.raidTracker.reportFormat = "HTML"
        HR:RefreshLootReportUI()
    end)
    f.htmlTab = htmlTab

    local tsvTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tsvTab:SetSize(88, 22)
    tsvTab:SetPoint("LEFT", htmlTab, "RIGHT", 4, 0)
    tsvTab:SetText("Excel / TSV")
    tsvTab:SetScript("OnClick", function()
        HighRollerDB.raidTracker.reportFormat = "TSV"
        HR:RefreshLootReportUI()
    end)
    f.tsvTab = tsvTab

    local selectAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(80, 22)
    selectAllBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -40)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        if f.editBox then
            f.editBox:SetFocus()
            f.editBox:HighlightText()
        end
    end)

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -66)
    hint:SetText("Press Ctrl+C to copy. Text-only output (no WoW item links).")
    hint:SetTextColor(1, 1, 1)

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -84)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 34)
    box:SetBackdrop(INNER_BOX_BACKDROP)
    box:SetBackdropColor(0.03, 0.03, 0.03, 0.95)

    local scroll = CreateFrame("ScrollFrame", "HighRollerReportScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -28, 8)
    f.scroll = scroll

    local editBox = CreateFrame("EditBox", "HighRollerReportEditBox", scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextColor(1, 1, 1)
    editBox:SetWidth(436)
    editBox.cursorOffset = 0
    editBox.cursorHeight = 0

    local updatingReportText = false
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not updatingReportText and f.lastGeneratedText then
            updatingReportText = true
            self:SetText(f.lastGeneratedText)
            self:HighlightText()
            updatingReportText = false
        end
        scroll:UpdateScrollChildRect()
    end)
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        self.cursorOffset = y or 0
        self.cursorHeight = h or 0
        if ScrollingEdit_OnCursorChanged then
            ScrollingEdit_OnCursorChanged(self, x, y, w, h)
        end
    end)

    scroll:SetScrollChild(editBox)
    f.editBox = editBox

    -- Clicking empty area of the scroll box focuses & highlights the report
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    f:SetScript("OnShow", function()
        HR:RefreshLootReportUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:RefreshLootReportUI()
    local f = self.lootReportFrame
    if not f then return end

    local fmt = HighRollerDB.raidTracker.reportFormat or "TEXT"
    f.textTab:UnlockHighlight()
    f.discordTab:UnlockHighlight()
    f.htmlTab:UnlockHighlight()
    f.tsvTab:UnlockHighlight()

    if fmt == "TEXT" then
        f.textTab:LockHighlight()
        f.titleText:SetText("Loot Report (Plain Text)")
        f.lastGeneratedText = self:GenerateLootReportText()
    elseif fmt == "DISCORD" then
        f.discordTab:LockHighlight()
        f.titleText:SetText("Loot Report (Discord)")
        f.lastGeneratedText = self:GenerateLootReportDiscord()
    elseif fmt == "TSV" then
        f.tsvTab:LockHighlight()
        f.titleText:SetText("Loot Report (Excel / TSV)")
        f.lastGeneratedText = self:GenerateLootReportTSV()
    else
        f.htmlTab:LockHighlight()
        f.titleText:SetText("Loot Report (HTML)")
        f.lastGeneratedText = self:GenerateLootReportHTML()
    end

    f.editBox:SetText(f.lastGeneratedText)
    f.scroll:SetVerticalScroll(0)
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end

function HR:OpenLootReport(formatMode, callerKey)
    if not self:HasLootToReport() then
        self:Print("No loot to report yet.")
        return
    end
    if formatMode then
        HighRollerDB.raidTracker.reportFormat = formatMode
    end
    self:OpenPanel("lootReport", callerKey)
    self:RefreshLootReportUI()
end

function HR:CreateLootSummaryFrame()
    local f = CreateManagedWindow("HighRollerLootSummaryFrame", "lootSummary", 418, 365, "Loot Summary", true, false)
    self.lootSummaryFrame = f

    -- View tabs: Winners Summary & All Dropped Items
    local winnersTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    winnersTab:SetSize(112, 22)
    winnersTab:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    winnersTab:SetText("Winners (0)")
    winnersTab:SetScript("OnClick", function()
        HighRollerDB.raidTracker.lootSummaryView = "WINNERS"
        HR:RefreshLootSummaryUI()
    end)
    f.winnersTab = winnersTab

    local dropsTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    dropsTab:SetSize(116, 22)
    dropsTab:SetPoint("LEFT", winnersTab, "RIGHT", 4, 0)
    dropsTab:SetText("All Drops (0)")
    dropsTab:SetScript("OnClick", function()
        HighRollerDB.raidTracker.lootSummaryView = "DROPS"
        HR:RefreshLootSummaryUI()
    end)
    f.dropsTab = dropsTab

    local postBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    postBtn:SetSize(92, 22)
    postBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -40)
    postBtn:SetText("Post Chat")
    postBtn:SetScript("OnClick", function()
        HR:PostLootSummaryToChat()
    end)
    f.postBtn = postBtn

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -68)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 68)
    box:SetBackdrop(INNER_BOX_BACKDROP)
    box:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

    local scroll = CreateFrame("ScrollFrame", "HighRollerLootSummaryScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(352, 1)
    scroll:SetScrollChild(content)
    f.scrollContent = content
    f.rows = {}

    local emptyText = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", box, "CENTER", -8, 0)
    emptyText:SetText("No loot recorded yet in this group.")
    f.emptyText = emptyText

    -- Output Reporting Bar (greyed out automatically when no loot to report)
    local repLbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    repLbl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 42)
    repLbl:SetText("Report:")
    repLbl:SetTextColor(1, 1, 1)

    local textRepBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    textRepBtn:SetSize(78, 22)
    textRepBtn:SetPoint("LEFT", repLbl, "RIGHT", 6, 0)
    textRepBtn:SetText("Plain Text")
    textRepBtn:SetScript("OnClick", function()
        HR:OpenLootReport("TEXT", "lootSummary")
    end)
    f.textRepBtn = textRepBtn

    local discordRepBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    discordRepBtn:SetSize(72, 22)
    discordRepBtn:SetPoint("LEFT", textRepBtn, "RIGHT", 4, 0)
    discordRepBtn:SetText("Discord")
    discordRepBtn:SetScript("OnClick", function()
        HR:OpenLootReport("DISCORD", "lootSummary")
    end)
    f.discordRepBtn = discordRepBtn

    local htmlRepBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    htmlRepBtn:SetSize(64, 22)
    htmlRepBtn:SetPoint("LEFT", discordRepBtn, "RIGHT", 4, 0)
    htmlRepBtn:SetText("HTML")
    htmlRepBtn:SetScript("OnClick", function()
        HR:OpenLootReport("HTML", "lootSummary")
    end)
    f.htmlRepBtn = htmlRepBtn

    local tsvRepBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tsvRepBtn:SetSize(88, 22)
    tsvRepBtn:SetPoint("LEFT", htmlRepBtn, "RIGHT", 4, 0)
    tsvRepBtn:SetText("Excel / TSV")
    tsvRepBtn:SetScript("OnClick", function()
        HR:OpenLootReport("TSV", "lootSummary")
    end)
    f.tsvRepBtn = tsvRepBtn

    f:SetScript("OnShow", function()
        HR:RefreshLootSummaryUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:BuildWinnersSummaryList()
    -- Returns strictly won Epic BoP items, Tier Tokens, Mounts & Pets
    local all = self:BuildLootReportData()
    local winners = {}
    for _, item in ipairs(all) do
        if item.winner then
            table.insert(winners, item)
        end
    end
    return winners
end

function HR:BuildQualifiedDropsList()
    -- Returns complete boss loot table: won, queued, and unclaimed drops
    return self:BuildLootReportData()
end

-- Text-only chat summary (no item links)
function HR:PostLootSummaryToChat()
    local data = self:BuildLootReportData()
    if #data == 0 then
        self:Print("No loot to report.")
        return
    end
    self:SendRaidMessage("--- High Roller Loot Summary ---", false)
    for _, item in ipairs(data) do
        if item.winner then
            self:SendRaidMessage(string.format("%s -> %s (%s)", item.itemName, item.winner, item.detail), false)
        elseif item.queued then
            self:SendRaidMessage(string.format("%s -> Queued", item.itemName), false)
        else
            self:SendRaidMessage(string.format("%s -> Unclaimed", item.itemName), false)
        end
    end
    self:SendRaidMessage(string.format("High Roller by %s - %s", ADDON_AUTHOR, ADDON_URL), false)
end

function HR:RefreshLootSummaryUI()
    local f = self.lootSummaryFrame
    if not f then return end

    local view = HighRollerDB.raidTracker.lootSummaryView or "WINNERS"
    local winnersList = self:BuildWinnersSummaryList()
    local dropsList = self:BuildQualifiedDropsList()

    f.winnersTab:SetText(string.format("Winners (%d)", #winnersList))
    f.dropsTab:SetText(string.format("All Drops (%d)", #dropsList))

    if view == "WINNERS" then
        f.winnersTab:LockHighlight()
        f.dropsTab:UnlockHighlight()
    else
        f.winnersTab:UnlockHighlight()
        f.dropsTab:LockHighlight()
    end

    -- Grey out reporting buttons if there is no loot to report
    local hasLoot = self:HasLootToReport()
    if hasLoot then
        f.postBtn:Enable()
        f.textRepBtn:Enable()
        f.discordRepBtn:Enable()
        f.htmlRepBtn:Enable()
        f.tsvRepBtn:Enable()
    else
        f.postBtn:Disable()
        f.textRepBtn:Disable()
        f.discordRepBtn:Disable()
        f.htmlRepBtn:Disable()
        f.tsvRepBtn:Disable()
    end

    for _, r in ipairs(f.rows) do r:Hide() end

    local activeList = (view == "WINNERS") and winnersList or dropsList
    if #activeList == 0 then
        f.emptyText:SetText(view == "WINNERS" and "No winners recorded yet." or "No boss loot drops tracked yet.")
        f.emptyText:Show()
        f.scrollContent:SetHeight(1)
        return
    end
    f.emptyText:Hide()

    local rowHeight = 22
    for i, item in ipairs(activeList) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Button", nil, f.scrollContent)
            row:SetSize(350, rowHeight)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(1, 1, 1, 0.08)

            row.leftText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.leftText:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.leftText:SetWidth(186)
            row.leftText:SetJustifyH("LEFT")

            row.rightText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.rightText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.rightText:SetPoint("LEFT", row.leftText, "RIGHT", 4, 0)
            row.rightText:SetJustifyH("RIGHT")

            f.rows[i] = row
        end

        row:SetPoint("TOPLEFT", f.scrollContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row.leftText:SetText(item.itemLink)

        -- Retain class colors on both Winners and All Drops tabs
        if view == "WINNERS" then
            local hex = self:GetClassColorHex(item.winner, item.winnerClass)
            row.rightText:SetText(string.format("|cff%s%s|r |cffaaaaaa(%s)|r", hex, item.winner, item.detail))
        else
            if item.winner then
                local hex = self:GetClassColorHex(item.winner, item.winnerClass)
                local detail = item.winDetail and (" |cffaaaaaa(" .. item.winDetail .. ")|r") or ""
                row.rightText:SetText(string.format("|cff%s%s|r%s", hex, item.winner, detail))
            elseif item.queued then
                row.rightText:SetText("|cffffcc00Queued|r")
            else
                row.rightText:SetText("|cff888888Unclaimed|r")
            end
        end

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if item.itemLink then
                GameTooltip:SetHyperlink(item.itemLink)
            end
            if item.source and item.source ~= "" then
                GameTooltip:AddLine("Source: " .. item.source, 0.8, 0.8, 0.8)
            end
            if item.winner then
                local hex = HR:GetClassColorHex(item.winner, item.winnerClass)
                local det = item.winDetail or item.detail or "Won"
                GameTooltip:AddLine(string.format("Winner: |cff%s%s|r (%s)", hex, item.winner, det), 1, 1, 1)
            elseif item.queued then
                local holderTxt = item.queuedBy and (" (held by " .. item.queuedBy .. ")") or ""
                GameTooltip:AddLine("Status: |cffffcc00Queued|r" .. holderTxt, 1, 1, 1)
            else
                GameTooltip:AddLine("Status: |cff888888Unclaimed|r", 1, 1, 1)
            end
            if item.session then
                local sortedBids = HR:GetSortedBids(item.session)
                if #sortedBids > 0 then
                    GameTooltip:AddLine("Bids:", 1, 0.82, 0)
                    for _, b in ipairs(sortedBids) do
                        if not b.ignored then
                            local bHex = HR:GetClassColorHex(b.name, b.classFile)
                            local osTxt = b.isOS and " |cffff9900[OS]|r" or ""
                            GameTooltip:AddLine(string.format("  |cff%s%s|r: %d%s", bHex, b.name, b.amount, osTxt), 1, 1, 1)
                        end
                    end
                end
                local sortedRolls = HR:GetSortedRolls(item.session)
                if #sortedRolls > 0 then
                    GameTooltip:AddLine("Rolls:", 0.4, 0.8, 1)
                    for _, r in ipairs(sortedRolls) do
                        if not r.ignored then
                            local rHex = HR:GetClassColorHex(r.name, r.classFile)
                            local rTag = (r.category == "OS") and " |cffff9900(OS)|r" or ""
                            GameTooltip:AddLine(string.format("  |cff%s%s|r: %d%s", rHex, r.name, r.value, rTag), 1, 1, 1)
                        end
                    end
                end
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function()
            if IsShiftKeyDown() and item.itemLink then
                ChatEdit_InsertLink(item.itemLink)
            end
        end)

        row:Show()
    end

    f.scrollContent:SetHeight(math.max(1, #activeList * rowHeight))
end

-- ============================================================================
-- 13. Compact Raid Roll & Bid Tracker ("High Roller by Copper")
-- ============================================================================

local function CreateTrackerRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(206, 18)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(1, 1, 1, 0.10)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture(1, 0.82, 0, 0.18)
    row.bg:Hide()

    row.leftText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.leftText:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.leftText:SetJustifyH("LEFT")

    row.rightText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.rightText:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.rightText:SetJustifyH("RIGHT")

    return row
end

function HR:CreateRaidTrackerFrame()
    -- Compact RaidRoll-sized window; stays open until manually closed (allowEscClose = false)
    local trackerTitle = string.format("High Roller by %s", ADDON_AUTHOR)
    local f = CreateManagedWindow("HighRollerRaidTrackerFrame", "raidTracker", 268, 274, trackerTitle, false, true)
    self.raidTrackerFrame = f

    local itemBox = CreateFrame("Button", nil, f)
    itemBox:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -33)
    itemBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -33)
    itemBox:SetHeight(26)
    itemBox:SetBackdrop(INNER_BOX_BACKDROP)
    itemBox:SetBackdropColor(0.08, 0.08, 0.12, 0.9)

    local icon = itemBox:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", itemBox, "LEFT", 5, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.itemIcon = icon

    local itemText = itemBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    itemText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    itemText:SetPoint("RIGHT", itemBox, "RIGHT", -6, 0)
    itemText:SetJustifyH("LEFT")
    itemText:SetText("Waiting for /rw item link...")
    f.itemText = itemText

    itemBox:SetScript("OnEnter", function(self)
        local session = GetViewedSession()
        if session and session.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(session.itemLink)
            GameTooltip:Show()
        end
    end)
    itemBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    itemBox:SetScript("OnClick", function()
        local session = GetViewedSession()
        if session and session.itemLink and IsShiftKeyDown() then
            ChatEdit_InsertLink(session.itemLink)
        end
    end)

    -- View Switcher Tabs (Bids / Rolls) + History (< 0/0 >)
    local bidsViewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    bidsViewBtn:SetSize(74, 20)
    bidsViewBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -63)
    bidsViewBtn:SetText("Bids (0)")
    bidsViewBtn:SetScript("OnClick", function()
        HighRollerDB.raidTracker.activeView = "BIDS"
        HR:RefreshRaidTrackerUI()
    end)
    f.bidsViewBtn = bidsViewBtn

    local rollsViewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rollsViewBtn:SetSize(76, 20)
    rollsViewBtn:SetPoint("LEFT", bidsViewBtn, "RIGHT", 3, 0)
    rollsViewBtn:SetText("Rolls (0)")
    rollsViewBtn:SetScript("OnClick", function()
        HighRollerDB.raidTracker.activeView = "ROLLS"
        HR:RefreshRaidTrackerUI()
    end)
    f.rollsViewBtn = rollsViewBtn

    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(20, 20)
    nextBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -63)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function()
        if HR.raidState.viewIndex < #HR.raidState.sessions then
            HR.raidState.viewIndex = HR.raidState.viewIndex + 1
            HR:RefreshRaidTrackerUI()
        end
    end)
    f.nextBtn = nextBtn

    local histText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    histText:SetPoint("RIGHT", nextBtn, "LEFT", -3, 0)
    histText:SetWidth(28)
    histText:SetJustifyH("CENTER")
    histText:SetText("0/0")
    f.histText = histText

    local prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prevBtn:SetSize(20, 20)
    prevBtn:SetPoint("RIGHT", histText, "LEFT", -3, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function()
        if HR.raidState.viewIndex > 1 then
            HR.raidState.viewIndex = HR.raidState.viewIndex - 1
            HR:RefreshRaidTrackerUI()
        end
    end)
    f.prevBtn = prevBtn

    -- Compact Scrollable List (Shows EITHER Bids OR Rolls view)
    local listBox = CreateFrame("Frame", nil, f)
    listBox:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -87)
    listBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -87)
    listBox:SetHeight(114)
    listBox:SetBackdrop(INNER_BOX_BACKDROP)
    listBox:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    f.listBox = listBox

    local scroll = CreateFrame("ScrollFrame", "HighRollerTrackerListScroll", listBox, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listBox, "TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -25, 5)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(208, 1)
    scroll:SetScrollChild(content)
    f.listContent = content
    f.listRows = {}

    local emptyHint = listBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    emptyHint:SetPoint("CENTER", listBox, "CENTER", -8, 0)
    emptyHint:SetText("No entries yet.")
    f.emptyHint = emptyHint

    -- Compact Control Row 1: Countdown | Post Bids/Rolls | Tie-Break | Clear
    local cdBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cdBtn:SetSize(64, 20)
    cdBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -205)
    cdBtn:SetText("Countdown")
    cdBtn:SetScript("OnClick", function() HR:ToggleCountdown() end)
    f.cdBtn = cdBtn

    local postViewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    postViewBtn:SetSize(66, 20)
    postViewBtn:SetPoint("LEFT", cdBtn, "RIGHT", 2, 0)
    postViewBtn:SetText("Post Bids")
    postViewBtn:SetScript("OnClick", function() HR:PostTrackerViewToRaidChat() end)
    postViewBtn:SetScript("OnEnter", function(self)
        local view = (HighRollerDB and HighRollerDB.raidTracker and HighRollerDB.raidTracker.activeView) or "BIDS"
        local kind = (view == "BIDS") and "bids" or "rolls"
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Send to Raid Chat", 0.2, 1, 0.6)
        GameTooltip:AddLine("Post the current " .. kind .. " list to Raid chat.", 1, 1, 1)
        GameTooltip:Show()
    end)
    postViewBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.postViewBtn = postViewBtn

    local tieBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tieBtn:SetSize(60, 20)
    tieBtn:SetPoint("LEFT", postViewBtn, "RIGHT", 2, 0)
    tieBtn:SetText("Tie-Break")
    tieBtn:SetScript("OnClick", function() HR:AnnounceTieBreak() end)

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(48, 20)
    clearBtn:SetPoint("LEFT", tieBtn, "RIGHT", 2, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        if HR.raidState.isTestMode then
            HR:ClearRaidTrackerData(true, true)
            HR:LoadRaidLootState()
            HR:UpdateClassCache()
            HR:RefreshAllUI()
            HR:Print("Solo Test Mode cleared.")
        else
            HR:StopCountdown(true)
            wipe(HR.raidState.sessions)
            HR.raidState.viewIndex = 0
            HR.raidState.trackingActive = false
            HR:SaveRaidLootState()
            HR:RefreshAllUI()
        end
    end)

    -- Compact Control Row 2: Award #1 | To DE | Boss Loot | Loot
    local awardBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    awardBtn:SetSize(66, 20)
    awardBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -228)
    awardBtn:SetText("Award #1")
    awardBtn:SetScript("OnClick", function()
        local session = GetViewedSession()
        local winners, topVal, _, tag = HR:GetTopContenders(session)
        if #winners >= 1 then
            HR:AwardTrackedItemTo(winners[1], tostring(topVal) .. tag)
        else
            HR:Print("No eligible winner to award.")
        end
    end)

    local deBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    deBtn:SetSize(48, 20)
    deBtn:SetPoint("LEFT", awardBtn, "RIGHT", 2, 0)
    deBtn:SetText("To DE")
    deBtn:SetScript("OnClick", function()
        local target = HighRollerDB.settings.deTarget
        if target == "" then
            HR:Print("No DE assigned. Use: /hr assign de <player>")
        else
            HR:AwardTrackedItemTo(target, "Disenchant")
        end
    end)

    local bossLootBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    bossLootBtn:SetSize(68, 20)
    bossLootBtn:SetPoint("LEFT", deBtn, "RIGHT", 2, 0)
    bossLootBtn:SetText("Boss Loot")
    bossLootBtn:SetScript("OnClick", function()
        HR:OpenPanel("bossLoot", "raidTracker")
    end)

    local lootBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    lootBtn:SetSize(56, 20)
    lootBtn:SetPoint("LEFT", bossLootBtn, "RIGHT", 2, 0)
    lootBtn:SetText("Loot")
    lootBtn:SetScript("OnClick", function()
        HR:OpenPanel("lootSummary", "raidTracker")
    end)

    f:SetScript("OnShow", function()
        HR:RefreshRaidTrackerUI()
        HR:UpdateBackButtonState(f)
    end)
end

function HR:RefreshRaidTrackerUI()
    local f = self.raidTrackerFrame
    if not f then return end

    local activeView = HighRollerDB.raidTracker.activeView or "BIDS"

    if activeView == "BIDS" then
        f.bidsViewBtn:LockHighlight()
        f.rollsViewBtn:UnlockHighlight()
        if f.postViewBtn then f.postViewBtn:SetText("Post Bids") end
    else
        f.bidsViewBtn:UnlockHighlight()
        f.rollsViewBtn:LockHighlight()
        if f.postViewBtn then f.postViewBtn:SetText("Post Rolls") end
    end

    if self.raidState.countdownActive then
        f.cdBtn:SetText(string.format("Stop (%ds)", math.max(1, self.raidState.countdownLastSec)))
    else
        f.cdBtn:SetText("Countdown")
    end

    local total = #self.raidState.sessions
    local idx = self.raidState.viewIndex
    f.histText:SetText(string.format("%d/%d", idx, total))
    if idx > 1 then f.prevBtn:Enable() else f.prevBtn:Disable() end
    if idx < total then f.nextBtn:Enable() else f.nextBtn:Disable() end

    for _, r in ipairs(f.listRows) do r:Hide() end

    local session = GetViewedSession()
    if not session then
        f.itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.itemText:SetText("Waiting for /rw item link...")
        f.bidsViewBtn:SetText("Bids (0)")
        f.rollsViewBtn:SetText("Rolls (0)")
        f.emptyHint:SetText("Waiting for /rw item link...")
        f.emptyHint:Show()
        f.listContent:SetHeight(1)
        return
    end

    f.itemIcon:SetTexture(session.itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.itemText:SetText(session.itemLink)

    local sortedBids  = self:GetSortedBids(session)
    local sortedRolls = self:GetSortedRolls(session)
    f.bidsViewBtn:SetText(string.format("Bids (%d)", #sortedBids))
    f.rollsViewBtn:SetText(string.format("Rolls (%d)", #sortedRolls))

    local winners, _, winMode = self:GetTopContenders(session)
    local isTied = (#winners > 1)
    local winnerSet = {}
    for _, w in ipairs(winners) do winnerSet[w] = true end

    local entries = (activeView == "BIDS") and sortedBids or sortedRolls
    if #entries == 0 then
        f.emptyHint:SetText(activeView == "BIDS" and "No bids yet." or "No rolls yet.")
        f.emptyHint:Show()
        f.listContent:SetHeight(1)
        return
    end
    f.emptyHint:Hide()

    local winCounts = self:GetPlayerWinCounts()
    local rowHeight = 18
    for i, entry in ipairs(entries) do
        local row = f.listRows[i]
        if not row then
            row = CreateTrackerRow(f.listContent)
            f.listRows[i] = row
        end

        row:SetPoint("TOPLEFT", f.listContent, "TOPLEFT", 0, -((i - 1) * rowHeight))

        local markIdx = self.raidState.marks[entry.name] or 1
        local markStr = PLAYER_MARKS[markIdx]
        local markPrefix = (markStr ~= "") and ("|cffffd100" .. markStr .. "|r ") or ""
        local colorHex = self:GetClassColorHex(entry.name, entry.classFile)
        local wins = winCounts[entry.name] or 0
        local winBadge = (wins > 0) and string.format(" |cff00ff99[%d]|r", wins) or ""
        local winBadgeMuted = (wins > 0) and string.format(" |cff777777[%d]|r", wins) or ""

        if activeView == "BIDS" then
            if entry.ignored then
                row.leftText:SetText(string.format("|cff777777[X]|r |cff%s%s|r%s", colorHex, entry.name, winBadgeMuted))
                row.rightText:SetText("|cff777777" .. entry.amount .. (entry.isOS and " [OS]" or "") .. "|r")
                row.bg:Hide()
            else
                row.leftText:SetText(string.format("%s|cff%s%s|r%s", markPrefix, colorHex, entry.name, winBadge))
                local osTag = entry.isOS and " |cffff9900[OS]|r" or ""
                row.rightText:SetText(string.format("|cffffd100%d|r%s", entry.amount, osTag))
                if winMode == "BID" and winnerSet[entry.name] then
                    row.bg:SetTexture(isTied and 1 or 0.2, isTied and 0.45 or 0.9, 0.1, 0.22)
                    row.bg:Show()
                else
                    row.bg:Hide()
                end
            end
        else
            local rollTag
            if entry.category == "MS" then
                rollTag = "|cff66ccff(Roll)|r"
            elseif entry.category == "OS" then
                rollTag = "|cffff9900(OS)|r"
            else
                rollTag = string.format("|cffff4444(%d-%d)|r", entry.low, entry.high)
            end

            if entry.ignored then
                row.leftText:SetText(string.format("|cff777777[X]|r |cff%s%s|r%s", colorHex, entry.name, winBadgeMuted))
                row.rightText:SetText("|cff777777" .. entry.value .. "|r")
                row.bg:Hide()
            else
                row.leftText:SetText(string.format("%s|cff%s%s|r%s", markPrefix, colorHex, entry.name, winBadge))
                row.rightText:SetText(string.format("|cffffffff%d|r %s", entry.value, rollTag))
                if winMode == "ROLL" and winnerSet[entry.name] then
                    row.bg:SetTexture(isTied and 1 or 0.2, isTied and 0.45 or 0.9, 0.1, 0.22)
                    row.bg:Show()
                else
                    row.bg:Hide()
                end
            end
        end

        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                entry.ignored = not entry.ignored
            elseif button == "LeftButton" then
                local cur = HR.raidState.marks[entry.name] or 1
                HR.raidState.marks[entry.name] = (cur % #PLAYER_MARKS) + 1
            end
            HR:SaveRaidLootState()
            HR:RefreshRaidTrackerUI()
        end)

        row:Show()
    end

    f.listContent:SetHeight(math.max(1, #entries * rowHeight))
end

function HR:RefreshAllUI()
    if self.switcherFrame and self.switcherFrame:IsShown() then self:RefreshSwitcherUI() end
    if self.configFrame and self.configFrame:IsShown() then self:RefreshConfigUI() end
    if self.editProfilesFrame and self.editProfilesFrame:IsShown() then self:RefreshEditProfilesUI() end
    if self.itemOverridesFrame and self.itemOverridesFrame:IsShown() then self:RefreshItemOverridesUI() end
    if self.raidTrackerFrame and self.raidTrackerFrame:IsShown() then self:RefreshRaidTrackerUI() end
    if self.bossLootFrame and self.bossLootFrame:IsShown() then self:RefreshBossLootUI() end
    if self.lootSummaryFrame and self.lootSummaryFrame:IsShown() then self:RefreshLootSummaryUI() end
    if self.lootReportFrame and self.lootReportFrame:IsShown() then self:RefreshLootReportUI() end
end

-- ============================================================================
-- 14. Event Dispatcher & Slash Commands
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("START_LOOT_ROLL")
eventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
eventFrame:RegisterEvent("CONFIRM_DISENCHANT_ROLL")
eventFrame:RegisterEvent("CONFIRM_LOOT_ROLL")
eventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
eventFrame:RegisterEvent("CHAT_MSG_RAID")
eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("LOOT_OPENED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            HR:InitDB()
            HR:LoadRaidLootState()
            HR:CreateMinimapButton()
            HR:CreateSwitcherFrame()
            HR:CreateConfigFrame()
            HR:CreateEditProfilesFrame()
            HR:CreatePolicyEditorFrame()
            HR:CreateItemOverridesFrame()
            HR:CreateBossLootFrame()
            HR:CreateLootReportFrame()
            HR:CreateLootSummaryFrame()
            HR:CreateRaidTrackerFrame()
        end
    elseif event == "PLAYER_LOGIN" then
        HR:UpdateKnownProfessions()
        HR:UpdateClassCache()
        HR:CheckGroupTransition()
        HR:PrintLoadBannerAndHelp(true)
    elseif event == "PLAYER_LOGOUT" then
        HR:SaveRaidLootState()
    elseif event == "PLAYER_ENTERING_WORLD" then
        HR:UpdateKnownProfessions()
        HR:UpdateClassCache()
        HR:CheckGroupTransition()
        HR:CheckInstanceAutoProfile()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        HR:CheckInstanceAutoProfile()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        HR:CheckGroupTransition()
        HR:UpdateClassCache()
    elseif event == "SKILL_LINES_CHANGED" then
        HR:UpdateKnownProfessions()
    elseif event == "START_LOOT_ROLL" then
        local rollID = ...
        HR:OnStartLootRoll(rollID)
    elseif event == "CANCEL_LOOT_ROLL" then
        local rollID = ...
        HR:CancelPendingRoll(rollID)
    elseif event == "CONFIRM_DISENCHANT_ROLL" then
        local rollID, rollType = ...
        HR:OnConfirmDisenchantRoll(rollID, rollType)
    elseif event == "CONFIRM_LOOT_ROLL" then
        local rollID, rollType = ...
        HR:OnConfirmLootRoll(rollID, rollType)
    elseif event == "CHAT_MSG_RAID_WARNING" then
        local msg, sender = ...
        HR:OnRaidWarning(msg, sender)
    elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        local msg, sender = ...
        HR:ProcessPotentialBid(msg, sender)
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        HR:OnSystemMessage(msg)
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        HR:OnLootChatMessage(msg)
    elseif event == "LOOT_OPENED" then
        HR:CaptureBossLoot()
    end
end)

SLASH_HIGHROLLER1 = "/hr"
SLASH_HIGHROLLER2 = "/highroller"
SlashCmdList["HIGHROLLER"] = function(msg)
    local cmd, rest = strsplit(" ", strtrim(msg or ""), 2)
    cmd = strlower(cmd or "")

    if cmd == "" then
        if HR.switcherFrame:IsShown() then
            HR.switcherFrame:Hide()
        else
            HR:OpenPanel("switcher", nil)
        end
    elseif cmd == "config" then
        if HR.configFrame:IsShown() then
            HR.configFrame:Hide()
        else
            HR:OpenPanel("config", nil)
        end
    elseif cmd == "tracker" or cmd == "raid" then
        if HR.raidTrackerFrame:IsShown() then
            HR.raidTrackerFrame:Hide()
        else
            HR:OpenRaidTracker(nil)
        end
    elseif cmd == "loot" then
        if HR.lootSummaryFrame:IsShown() then
            HR.lootSummaryFrame:Hide()
        else
            HR:OpenPanel("lootSummary", nil)
        end
    elseif cmd == "overrides" or cmd == "override" or cmd == "exceptions" then
        if HR.itemOverridesFrame:IsShown() then
            HR.itemOverridesFrame:Hide()
        else
            HR:OpenPanel("itemOverrides", nil)
        end
    elseif cmd == "test" then
        HR:RunSoloTest()
    elseif cmd == "profile" and rest and rest ~= "" then
        HR:SetActiveProfile(rest)
    elseif cmd == "clear" then
        HR:ClearRaidTrackerData(true)
        HR:Print("Cleared saved raid loot table.")
    elseif cmd == "reset" then
        HR:ResetAllWindowPositions()
    elseif cmd == "pause" or cmd == "off" then
        HighRollerDB.settings.enabled = false
        HR:Print("Auto-rolling |cffff4444PAUSED|r.")
        HR:RefreshAllUI()
    elseif cmd == "resume" or cmd == "on" then
        HighRollerDB.settings.enabled = true
        HR:Print("Auto-rolling |cff00ff00ENABLED|r.")
        HR:RefreshAllUI()
    elseif cmd == "assign" and rest then
        local role, target = strsplit(" ", strtrim(rest), 2)
        role = strlower(role or "")
        target = strtrim(target or "")
        if role == "de" then
            HighRollerDB.settings.deTarget = target
            HR:Print("Assigned Disenchanter: |cffffd100" .. (target ~= "" and target or "None") .. "|r")
        else
            HR:Print("Usage: /hr assign de <player>")
        end
    elseif cmd == "status" then
        local state = HighRollerDB.settings.enabled and "|cff00ff00ENABLED|r" or "|cffff4444PAUSED|r"
        HR:Print("Status: " .. state .. " | Active Profile: |cffffd100" .. tostring(HR:GetActiveProfileName()) .. "|r")
        HR:Print(GetFooterText())
    else
        HR:PrintLoadBannerAndHelp(false)
    end
end
