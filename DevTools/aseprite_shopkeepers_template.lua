--------------------------------------------------------------
-- ShopKeepers Game — Aseprite Template Creator
-- Place in: File > Scripts > Open Scripts Folder
-- Run via:  File > Scripts > aseprite_shopkeepers_template
--------------------------------------------------------------

-- Asset type definitions: { label, width, height, description }
local ASSET_TYPES = {
    { label = "Facility / Building (128x128)",   w = 128, h = 128 },
    { label = "Hero Sprite Frame (32x32)",       w =  32, h =  32 },
    { label = "Monster Portrait (32x32)",        w =  32, h =  32 },
    { label = "Item / Ability Icon (32x32)",     w =  32, h =  32 },
    { label = "Hero Portrait (32x32)",           w =  32, h =  32 },
    { label = "Class Card (120x141)",            w = 120, h = 141 },
    { label = "Cutscene Background (960x540)",   w = 960, h = 540 },
    { label = "Custom Size...",                  w =   0, h =   0 },
}

-- Region definitions with theme + accent colors
local REGIONS = {
    { label = "None",                theme = nil,             accent = nil },
    { label = "R1 - Thornhaven",     theme = Color(74,122,90),  accent = Color(106,170,122) },
    { label = "R2 - Fungal Marshes", theme = Color(74,107,58),  accent = Color(139,195,74) },
    { label = "R3 - Sunken Shoals",  theme = Color(44,110,122), accent = Color(74,144,164) },
    { label = "R4 - Ashen Horizons", theme = Color(139,58,42),  accent = Color(212,98,42) },
    { label = "R5 - Starfall Expanse", theme = Color(74,58,139), accent = Color(156,106,191) },
    { label = "R6 - Necropolis",     theme = Color(58,58,74),   accent = Color(109,76,110) },
    { label = "R7 - Fractured Realm", theme = Color(26,26,46),  accent = Color(74,42,107) },
}

-- Build label lists for dropdowns
local asset_labels = {}
for i, a in ipairs(ASSET_TYPES) do
    asset_labels[i] = a.label
end

local region_labels = {}
for i, r in ipairs(REGIONS) do
    region_labels[i] = r.label
end

--------------------------------------------------------------
-- DIALOG
--------------------------------------------------------------
local dlg = Dialog("ShopKeepers Template")

dlg:combobox{
    id = "asset_type",
    label = "Asset Type:",
    options = asset_labels,
}

dlg:number{
    id = "custom_w",
    label = "Custom Width:",
    text = "64",
    decimals = 0,
    visible = false,
}

dlg:number{
    id = "custom_h",
    label = "Custom Height:",
    text = "64",
    decimals = 0,
    visible = false,
}

dlg:combobox{
    id = "region",
    label = "Region (optional):",
    options = region_labels,
}

dlg:check{
    id = "load_palette",
    label = "Load game palette:",
    selected = true,
}

dlg:separator{}

dlg:button{ id = "ok", text = "Create" }
dlg:button{ id = "cancel", text = "Cancel" }

dlg:show()

--------------------------------------------------------------
-- PROCESS
--------------------------------------------------------------
local data = dlg.data
if not data.ok then return end

-- Resolve dimensions
local chosen_idx = 1
for i, a in ipairs(ASSET_TYPES) do
    if a.label == data.asset_type then
        chosen_idx = i
        break
    end
end

local asset = ASSET_TYPES[chosen_idx]
local width = asset.w
local height = asset.h

-- Custom size override
if width == 0 then
    width = math.max(1, math.floor(data.custom_w))
    height = math.max(1, math.floor(data.custom_h))
end

-- Create new sprite
local spr = Sprite(width, height, ColorMode.RGB)
spr.filename = "shopkeepers_new"

-- Try to load the game palette
if data.load_palette then
    -- Look for the palette in common locations
    local palette_paths = {}

    -- Path relative to this script's location (DevTools/)
    local script_path = app.fs.filePath
    if script_path and script_path ~= "" then
        table.insert(palette_paths, app.fs.joinPath(app.fs.filePath, "shopkeepers_palette.gpl"))
    end

    -- Common project paths (Windows)
    local user_profile = os.getenv("USERPROFILE") or ""
    if user_profile ~= "" then
        table.insert(palette_paths, user_profile .. "\\OneDrive\\ShopKeepers Game\\DevTools\\shopkeepers_palette.gpl")
    end

    -- Aseprite extensions/palettes folder
    local config_path = app.fs.userConfigPath
    if config_path then
        table.insert(palette_paths, app.fs.joinPath(config_path, "palettes", "shopkeepers_palette.gpl"))
    end

    local loaded = false
    for _, path in ipairs(palette_paths) do
        local f = io.open(path, "r")
        if f then
            f:close()
            -- Parse the .gpl file manually and build palette
            local colors = {}
            local gpl = io.open(path, "r")
            if gpl then
                for line in gpl:lines() do
                    -- Skip header lines and comments
                    if not line:match("^GIMP") and
                       not line:match("^Name:") and
                       not line:match("^Columns:") and
                       not line:match("^#") and
                       line:match("%d") then
                        local r, g, b = line:match("^%s*(%d+)%s+(%d+)%s+(%d+)")
                        if r then
                            table.insert(colors, Color(tonumber(r), tonumber(g), tonumber(b), 255))
                        end
                    end
                end
                gpl:close()
            end

            if #colors > 0 then
                local pal = spr.palettes[1]
                pal:resize(#colors)
                for i, c in ipairs(colors) do
                    pal:setColor(i - 1, c)
                end
                loaded = true
                break
            end
        end
    end

    if not loaded then
        app.alert{
            title = "Palette Not Found",
            text = {
                "Could not find shopkeepers_palette.gpl",
                "",
                "Copy it to one of these locations:",
                "1. Aseprite palettes folder (Edit > Preferences > Folders)",
                "2. " .. (user_profile ~= "" and (user_profile .. "\\OneDrive\\ShopKeepers Game\\DevTools\\") or "your project's DevTools/ folder"),
            },
            buttons = { "OK" }
        }
    end
end

-- Apply region colors as foreground/background if selected
local region_idx = 1
for i, r in ipairs(REGIONS) do
    if r.label == data.region then
        region_idx = i
        break
    end
end

local region = REGIONS[region_idx]
if region.theme then
    app.fgColor = region.theme
    app.bgColor = region.accent
end

-- Add guide lines for certain asset types to help with composition
if asset.w == 128 and asset.h == 128 then
    -- Facility: center guides for door/sign placement
    -- (Aseprite doesn't support guides via Lua, but we can name the layer)
    spr.layers[1].name = "Building"
elseif asset.w == 32 and asset.h == 32 then
    spr.layers[1].name = "Sprite"
elseif asset.w == 120 and asset.h == 141 then
    spr.layers[1].name = "Card Art"
elseif asset.w == 960 and asset.h == 540 then
    spr.layers[1].name = "Background"
else
    spr.layers[1].name = "Layer"
end

-- Add animation frames for hero sprites
if chosen_idx == 2 then -- Hero Sprite Frame
    local anim_dlg = Dialog("Hero Sprite Setup")
    anim_dlg:check{
        id = "add_frames",
        label = "Add animation frames?",
        selected = true,
    }
    anim_dlg:label{ text = "Creates tagged frames: idle(4), attack(5)," }
    anim_dlg:label{ text = "cast(5), hit(3), death(5), walk(6)" }
    anim_dlg:separator{}
    anim_dlg:button{ id = "ok", text = "Yes" }
    anim_dlg:button{ id = "no", text = "No, just 1 frame" }
    anim_dlg:show()

    if anim_dlg.data.ok then
        local anims = {
            { name = "idle",   frames = 4 },
            { name = "attack", frames = 5 },
            { name = "cast",   frames = 5 },
            { name = "hit",    frames = 3 },
            { name = "death",  frames = 5 },
            { name = "walk",   frames = 6 },
        }

        -- Total frames needed (minus the 1 we already have)
        local total = 0
        for _, a in ipairs(anims) do
            total = total + a.frames
        end

        -- Add remaining frames
        for i = 2, total do
            spr:newEmptyFrame()
        end

        -- Create tags
        local frame_idx = 1
        for _, a in ipairs(anims) do
            local tag = spr:newTag(frame_idx, frame_idx + a.frames - 1)
            tag.name = a.name
            frame_idx = frame_idx + a.frames
        end

        spr.layers[1].name = "Character"
    end
end

-- Zoom to fit for small sprites
if width <= 64 and height <= 64 then
    -- Set view zoom for small sprites (helps see pixels)
    app.command.FitScreen()
end

app.refresh()
app.alert{
    title = "Template Created",
    text = {
        "Asset: " .. asset.label,
        "Size: " .. width .. "x" .. height .. " px",
        region.theme and ("Region: " .. region.label .. " (colors set as FG/BG)") or "",
        "",
        "Happy pixel art!",
    },
    buttons = { "OK" }
}
