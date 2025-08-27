# Testing the CraftedItem_ID Fix

The fix has been implemented with a delayed loading system that should resolve the "CraftedItem_ID" display issue in your profession viewer.

## What Was Fixed

1. **Root Cause**: GetItemInfo() returns nil when items aren't cached in WoW client yet
2. **Previous Behavior**: Fallback to "CraftedItem_XXX" pattern immediately
3. **New Behavior**: Retry system attempts GetItemInfo() every 2 seconds up to 10 times
4. **Auto-Refresh**: Profession viewer automatically updates when item names load

## How to Test

### Method 1: In-Game Testing
1. `/reload` to restart the addon with the new code
2. Open the profession viewer (`/cb` command)
3. Look for any recipes showing as "CraftedItem_XXX"
4. Wait 1-2 minutes - these should automatically change to real item names
5. You should see the profession viewer refresh automatically

### Method 2: Debug Testing  
1. Copy the test file content: `test_item_name_fix.lua`
2. In WoW chat, type: `/script` then paste the test code
3. This will show you:
   - How many recipes have real names vs CraftedItem_X names
   - Percentage breakdown
   - Sample recipes that are still being resolved
   - Progress over time

### Method 3: Monitor Progress
1. Run the test script
2. Wait 30 seconds 
3. Run it again
4. You should see the number of "CraftedItem_X" names decrease over time

## Expected Results

- **Immediate**: Some recipes may still show "CraftedItem_XXX" initially
- **After 30 seconds**: Most common items should resolve to real names
- **After 2 minutes**: Nearly all items should have real names
- **Profession Viewer**: Should automatically refresh when names load

## If Issues Persist

If you still see "CraftedItem_XXX" names after 5 minutes:

1. Check `/console` for any error messages
2. Try the diagnostic: `/script print("Retry system active:", CraftersBoard.VanillaAccurateData and CraftersBoard.VanillaAccurateData.retryTimer ~= nil)`
3. Manual refresh: `/cb` to close/reopen profession viewer

## What to Report Back

Please let me know:
1. **Immediate**: Do you still see "CraftedItem_XXX" names right after `/reload`?
2. **After 2 minutes**: How many recipes still show "CraftedItem_XXX"?
3. **Profession Viewer**: Does it refresh automatically when names load?
4. **Overall**: What percentage of recipes now show real item names?

The fix should significantly reduce or eliminate the "CraftedItem_ID" issue you reported!
