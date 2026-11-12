# How to Create and View Posts

## IMPORTANT: Restart the App First!
The UserSlotRepository changes require a full app restart (not hot reload).

**Stop the app completely and restart it.**

## Step-by-Step Guide

### For Provider Posts (Offering Services)

1. Go to **Profile** tab
2. Switch to **Provider** tab
3. Click **Your Vehicles**
4. Click the **+ Add Vehicle** button
5. Fill in vehicle details (name, type, year, etc.)
6. Save the vehicle
7. Click on the vehicle you just created
8. Click the **+ FAB button** to create a post
9. Fill in the post details:
   - Service type (Passenger/Parcel/Lease)
   - Location (From → To or Base + Range)
   - Time (Start and End)
   - Price
   - Capacity
10. Click **Post**
11. Go to **Posts** tab (commons feed)
12. You should see your post with an **"Offering"** badge (blue)

### For User Posts (Looking for Services)

1. Go to **Profile** tab
2. Switch to **User** tab
3. Click **Needed Vehicles**
4. Click the **+ Add Vehicle** button
5. Fill in vehicle details (what you're looking for)
6. Save the vehicle
7. Click on the vehicle you just created
8. Click the **+ FAB button** to create a post
9. Fill in the post details (same as above)
10. Click **Post**
11. Go to **Posts** tab (commons feed)
12. You should see your post with a **"Looking"** badge (orange)

## Troubleshooting

### "No services available nearby"
This means:
- No posts have been created yet, OR
- The app needs to be restarted to load the new code

### Check Debug Console
Look for these messages:
```
✅ Loaded X provider slots from local storage
✅ Loaded X user slots from local storage
=== POSTS DEBUG ===
Provider slots: X
User slots: X
Total slot items: X
```

### Clear Data and Start Fresh
If you want to start over:
1. Stop the app
2. Clear app data (or uninstall/reinstall)
3. Restart the app
4. Register/login
5. Follow the steps above

## What's Fixed

1. **UserSlotRepository now persists data** - User posts are saved to local storage
2. **Both repositories listen to vehicle changes** - Slot entries rebuild when vehicles update
3. **Visual indicators** - "Looking" (orange) vs "Offering" (blue) badges
4. **Separate data** - User and Provider posts are completely separate
5. **Commons feed shows both** - All posts from both modes appear in the Posts tab

## Data Storage Keys

- Provider vehicles: `vehicles`
- Provider posts: `slots`
- User vehicles: `user_vehicles`
- User posts: `user_slots`

All stored in SharedPreferences (local storage).
