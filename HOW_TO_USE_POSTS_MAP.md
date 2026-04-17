# Posts Map with Radius Circles

## ✅ What I Created

A new map screen that shows **all posts as markers with radius circles** around each one.

---

## 🎯 Features

- ✅ **Red markers** for each post/vehicle
- ✅ **Blue radius circles** showing coverage area
- ✅ **Tap marker** to see post details
- ✅ **Zoom in/out** buttons
- ✅ **Refresh** button to reload posts

---

## 🚀 How to Use

### Add to Your Navigation

```dart
// In your main.dart or wherever you have navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const PostsMapScreen(),
  ),
);
```

### Add as Tab or Menu Item

```dart
// Example: Add to bottom navigation
BottomNavigationBarItem(
  icon: Icon(Icons.map),
  label: 'Map',
),

// When tab is selected:
case 2: // Map tab
  return const PostsMapScreen();
```

---

## 🎨 What You'll See

```
┌─────────────────────────────────┐
│  Posts Map              🔄      │
├─────────────────────────────────┤
│                                 │
│        ╭─────────╮              │
│       ╱           ╲             │
│      │   🚗 Post   │            │
│       ╲           ╱             │
│        ╰─────────╯              │
│     ← 5km radius →              │
│                                 │
│              ╭─────────╮        │
│             ╱           ╲       │
│            │   🚗 Post   │      │
│             ╲           ╱       │
│              ╰─────────╯        │
│           ← 10km radius →       │
│                                 │
│                          [+]    │
│                          [-]    │
└─────────────────────────────────┘
```

---

## 🔧 Customization

### Change Marker Color

Edit `lib/screens/posts_map_screen.dart` line ~70:

```dart
color: Colors.green, // ✅ Change to green
color: Colors.orange, // ✅ Change to orange
color: Colors.purple, // ✅ Change to purple
```

### Change Circle Color

Edit line ~55:

```dart
color: Colors.red.withOpacity(0.2), // ✅ Red circle
borderColor: Colors.red,
```

### Change Marker Icon

Edit line ~80:

```dart
Icons.location_on, // ✅ Location pin
Icons.local_taxi, // ✅ Taxi icon
Icons.directions_bus, // ✅ Bus icon
```

---

## 📱 User Flow

1. **User opens map** → Sees all posts with radius circles
2. **User taps marker** → Bottom sheet shows post details
3. **User clicks "Book Now"** → Goes to booking screen

---

## 🎯 Example: Add to Main Screen

In your `lib/main.dart`, add a button to open the map:

```dart
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PostsMapScreen(),
      ),
    );
  },
  child: const Icon(Icons.map),
)
```

---

## ✅ That's It!

The map is ready to use. Just navigate to `PostsMapScreen()` and you'll see all posts with radius circles! 🎉
