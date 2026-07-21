# Searcher Filter Guide - Clear Insights

## 📋 Overview
This guide clarifies what you'll see when using different filters in QuickoHunt search. There are **two main post types** with different filtering behaviors.

---

## 🛣️ Fixed Route Posts (From → To)

**What is it?**
- A fixed route from a specific starting point to a specific destination
- Provider/user travels along a set path

**When you filter with:**
- **From Location**: Shows posts that start FROM that exact location
- **To Location**: Shows posts that go TO that exact location
- **Both**: Shows posts matching BOTH from and to locations

**Example:**
- You search: From "Chennai" → To "Bangalore"
- You see: Only posts that go from Chennai to Bangalore
- You DON'T see: Posts from Chennai to Hyderabad, or from Madurai to Bangalore

**Visual Badge:** 🛣️ **Fixed Route** (blue badge on slot card)

---

## 📍 Base Location Posts (Base + Radius)

**What is it?**
- Provider has a home/base location
- They provide service within a radius around that base
- They can travel within that radius

**When you filter with:**
- **Base Location**: Shows posts whose base location has YOUR searched location within its service radius
- Think of it as: "Show me posts where my location falls inside their circle"

**How radius filtering works:**
1. You enter your location (e.g., "Indiranagar")
2. System checks distance from Indiranagar to each post's base location
3. If Indiranagar is within the post's radius → Post is shown
4. If Indiranagar is outside the post's radius → Post is hidden

**Example:**
- Post has: Base location "Chennai" with 50 km radius
- You search for: "Velachery" (15 km from Chennai)
- Result: ✅ Post is shown (Velachery is within 50 km)

- Post has: Base location "Chennai" with 50 km radius
- You search for: "Bangalore" (250 km from Chennai)
- Result: ❌ Post is hidden (Bangalore is outside 50 km)

**Visual Badge:** 📍 **Base Location • 50 km** (green badge on slot card)

---

## 🔍 Key Differences At A Glance

| Feature | Fixed Route | Base Location |
|---------|------------|---|
| **Route Type** | Exact path from A → B | Flexible within radius |
| **Filter From** | Exact start point | Provider's home base |
| **Filter To** | Exact end point | N/A (use radius instead) |
| **Radius** | None | Specified (e.g., 50 km) |
| **Search Behavior** | Match exact locations | Match if you're within radius |
| **Badge** | 🛣️ Fixed Route | 📍 Base Location |

---

## 💡 Tips for Better Search Results

### Searching for Fixed Route (From → To)
✅ Be specific with from and to locations
✅ Use exact city names or place names
✅ Both filters together give more precise results
❌ Avoid being too vague (e.g., "North Chennai" without district)

### Searching for Base Location
✅ Enter YOUR location (where you need service)
✅ System automatically checks provider's radius
✅ Bigger radius = more flexible service area
❌ Don't need to guess the provider's base - just enter yours

### Mixed Results
⚠️ When you search WITHOUT a route type filter:
- You get BOTH Fixed Route AND Base Location posts
- They have different badges so you can identify them
- Base Location posts show their service radius

---

## 🎯 Common Scenarios

### Scenario 1: "I need daily commute from home to office"
→ Use **Fixed Route** filter
→ Set From = "Your Home"
→ Set To = "Your Office"
→ You'll see exact routes matching your commute

### Scenario 2: "I need a delivery person available in my area"
→ Use **Base Location** filter  
→ Set Base Location = "Your City/Area"
→ You'll see providers based there who can deliver within their radius

### Scenario 3: "Show me everything available in my area"
→ Don't filter by route type
→ You'll see BOTH:
  - Fixed routes passing through your area
  - Base location posts centered in your area
→ Look at badges to understand each post type

---

## 📱 On the Slot Card

Each post clearly shows:

1. **Post Type Badge** (top-right, colored)
   - 🛣️ **Fixed Route** (Blue) = From → To exact path
   - 📍 **Base Location • 50 km** (Green) = Base + radius

2. **Location Display**
   - Fixed Route: Shows "From: Chennai → To: Bangalore" with arrows
   - Base Location: Shows "Based in Chennai • 50 km range"

3. **Distance Info**
   - "Vehicle ~25 km away" = Distance from your location to the vehicle

---

## ❓ FAQ

**Q: Do Base Location posts always show within radius?**
A: Yes, if your search location is within their radius, the post appears. The radius is clearly shown.

**Q: Can I filter by radius myself?**
A: No - the app automatically filters by the provider's pre-set radius. You just enter your location.

**Q: What if I search for Fixed Route but get Base Location posts too?**
A: If you DON'T explicitly select a route type, you get mixed results. Select route type to see only that type.

**Q: Why do some posts not appear after I search?**
A: Check:
1. Your search location might be outside their service radius (Base Location)
2. Your from/to don't match exactly (Fixed Route) - try without filters for more results
3. Post might have expired (check end time)

**Q: Can a post be both types?**
A: No - each post is EITHER Fixed Route OR Base Location, not both.

---

## 🎓 Understanding Your Search Experience

When you enter a location in the **Base Location filter**, the app:

```
Your Search Input
    ↓
"Indiranagar, Bangalore"
    ↓
Converts to coordinates
    ↓
(13.35°N, 77.62°E)
    ↓
Checks distance to EVERY post's base location
    ↓
Compare distance vs post's radius
    ↓
Show only posts where:
Distance ≤ Post Radius
```

This is why you see posts within radius - the system is literally checking if your location falls inside their service circle.

---

## 📊 Visual Reference

### Fixed Route Example
```
Start: Chennai ————→ End: Bangalore
       🔵                    🔵
       Connected by exact route
```

### Base Location Example  
```
                You are here
                     ⭐
                    /  \
                   /    \
                  /  30km\
                 / radius \
             🏠 Provider's Base Location
             
If you're within the circle → You see the post
If you're outside → Post is hidden
```

---

## 🚀 Next Steps

1. **Try filtering by route type** - Notice how results change
2. **Look at post badges** - Quickly identify post types
3. **Read the location info** - Fixed Route shows path, Base Location shows radius
4. **Experiment with locations** - See how base location radius filtering works

---

*Updated: Based on filtering logic analysis and user feedback on clarity*
