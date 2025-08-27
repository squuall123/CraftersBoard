-- CraftersBoard - Main Entry Point  
-- Version: 1.0.0
--
-- This is the main coordination file for the modular CraftersBoard addon.
-- All functionality has been moved to Core/ modules for better organization.
--
-- Module loading order (handled by .toc file):
-- 1. Core/Init.lua          - Namespace and utilities
-- 2. Core/Database.lua      - Saved variables management
-- 3. Core/Professions.lua   - Profession detection
-- 4. Core/ChatParser.lua    - Message analysis
-- 5. Core/Mute.lua          - Player/phrase muting
-- 6. Core/UI.lua            - Main window and interface
-- 7. Core/Settings.lua      - Options panel
-- 8. Core/Minimap.lua       - Minimap button
-- 9. Core/Events.lua        - Event handling
-- 10. Core/Commands.lua     - Slash commands
-- 11. CraftersBoard.lua     - This file (coordination)

print("CraftersBoard: Main file loading...")

local ADDON_NAME = ...

-- Verify that the addon namespace was properly initialized by Core/Init.lua
if not CraftersBoard then
    print("ERROR: CraftersBoard namespace not found! Ensure Core/Init.lua loads first.")
    error("CraftersBoard namespace not found! Ensure Core/Init.lua loads first.")
    return
end

print("CraftersBoard: Main file - namespace verified")

-- All functionality is now handled by the modular system:
-- - UI creation and management: Core/UI.lua
-- - Database and settings: Core/Database.lua  
-- - Chat parsing: Core/ChatParser.lua
-- - Event handling: Core/Events.lua
-- - Command processing: Core/Commands.lua
-- - Minimap button: Core/Minimap.lua
-- - Options panel: Core/Settings.lua
-- - Muting system: Core/Mute.lua
-- - Profession detection: Core/Professions.lua

-- The addon is now fully modular and ready to use!
print("|cff00ff88CraftersBoard|r Modular addon initialized successfully!")
print("|cff00ff88CraftersBoard|r Use |cffffff00/cb|r to open main window or |cffffff00/cb help|r for commands.")
