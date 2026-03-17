# Profile Posts Pages Added

## What Was Added

Added "My Posts" option to both User and Provider tabs in the Profile page.

### User Tab
- **My Posts** - Shows all posts from UserSlotRepository (posts you're looking for)
  - Badge: "Looking" (orange)
  - Empty state with button to create posts
  - Navigates to `UserPostsListPage`

### Provider Tab
- **My Posts** - Shows all posts from SlotRepository (services you're offering)
  - Badge: "Offering" (blue)
  - Empty state with button to create posts
  - Navigates to `ProviderPostsListPage`

## Navigation Flow

### User Mode
1. Profile → User tab → My Posts
2. Shows all posts from UserSlotRepository
3. Each post displays with "Looking" badge
4. Click post to view details

### Provider Mode
1. Profile → Provider tab → My Posts
2. Shows all posts from SlotRepository
3. Each post displays with "Offering" badge
4. Click post to view details

## Features

- **Separate Lists**: User and Provider posts are completely separate
- **Visual Indicators**: Each post shows the appropriate badge
- **Empty States**: Helpful messages when no posts exist
- **Quick Actions**: Buttons to create posts directly from empty state
- **Real-time Updates**: Lists update automatically when posts are added/removed

## Files Modified

- `lib/main.dart`:
  - Added `UserPostsListPage` class
  - Added `ProviderPostsListPage` class
  - Updated ProfilePage to include "My Posts" options

## How to Use

1. **Restart the app** (full restart, not hot reload)
2. Go to **Profile** tab
3. Switch between **User** and **Provider** tabs
4. Click **My Posts** to see your posts
5. If empty, click the button to create posts

## Data Sources

- **User Posts**: `UserSlotRepository.instance.slotsListenable`
- **Provider Posts**: `SlotRepository.instance.slotsListenable`

Both repositories now persist data to local storage, so posts will survive app restarts.
