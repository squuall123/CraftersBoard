-- CraftersBoard - Main Entry Point

local ADDON_NAME = ...

if not CraftersBoard then
    error("CraftersBoard namespace not found! Ensure Core/Init.lua loads first.")
    return
end

print("|cff00ff88CraftersBoard|r Modular addon initialized successfully!")
print("|cff00ff88CraftersBoard|r Use |cffffff00/cb|r to open main window or |cffffff00/cb help|r for commands.")
