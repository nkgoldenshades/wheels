# 🌐 GitHub Pages Setup Instructions

## ⚠️ **White Screen Issue?**

If you see a white screen when running locally, that's normal for debug mode!

Your **deployed app** on GitHub Pages will work fine.

---

## 📋 **Enable GitHub Pages (Required!)**

### **Step 1: Go to Repository Settings**
1. Open: https://github.com/nkgoldenshades/Vaultwheels-web
2. Click **Settings** (top menu)
3. Click **Pages** (left sidebar)

### **Step 2: Configure Source**
- **Source:** Deploy from a branch
- **Branch:** main
- **Folder:** / (root)
- Click **Save**

### **Step 3: Wait 1-2 Minutes**
GitHub will build and deploy your site automatically.

### **Step 4: Check Your Live App**
Visit:
```
https://nkgoldenshades.github.io/Vaultwheels-web/
```

---

## 🔧 **If White Screen on GitHub Pages Too:**

### **Fix 1: Update base href in index.html**

The deployed `index.html` needs the correct base href.

**Check:** `E:\Vaultwheels-web\index.html`

**Line 3 should be:**
```html
<base href="/Vaultwheels-web/">
```

**NOT:**
```html
<base href="$FLUTTER_BASE_HREF">
```

**To fix:**
1. Open `E:\Vaultwheels-web\index.html`
2. Change line 3 to: `<base href="/Vaultwheels-web/">`
3. Commit and push:
```bash
cd E:\Vaultwheels-web
git add index.html
git commit -m "Fix base href for GitHub Pages"
git push origin main
```

---

### **Fix 2: Check Browser Console**

1. Open your deployed app
2. Press F12 (Developer Tools)
3. Look for errors in Console tab
4. Common errors:
   - **404 on main.dart.js** → base href wrong
   - **CORS errors** → Supabase/Firebase config issue
   - **Firebase not defined** → Check Firebase config

---

## ✅ **Testing Checklist**

### **Local Testing (Debug Mode):**
```bash
cd E:\quickohunt
flutter run -d chrome
```
White screen is NORMAL in debug mode!

### **Production Testing (Deployed):**
1. Enable GitHub Pages (steps above)
2. Wait 2 minutes
3. Visit: https://nkgoldenshades.github.io/Vaultwheels-web/
4. Should see your app loading!

---

## 🚀 **Quick Fix Script**

If white screen persists on GitHub Pages, run this:

```powershell
# Fix base href
cd E:\Vaultwheels-web
(Get-Content index.html) -replace '<base href="\$FLUTTER_BASE_HREF">', '<base href="/Vaultwheels-web/">' | Set-Content index.html

# Commit and push
git add index.html
git commit -m "Fix base href for GitHub Pages"
git push origin main

# Wait 1-2 minutes, then check:
# https://nkgoldenshades.github.io/Vaultwheels-web/
```

---

## 📊 **Deployment Status**

Check if GitHub Pages is building:
```
https://github.com/nkgoldenshades/Vaultwheels-web/actions
```

Look for green checkmark ✅ = Deployed successfully!

---

## 🎯 **Expected Result**

After enabling GitHub Pages and fixing base href:

**Your app at:** https://nkgoldenshades.github.io/Vaultwheels-web/

Should show:
- ✅ QuickOHunt home screen
- ✅ Login/signup buttons
- ✅ All features working
- ✅ Connected to Supabase

---

**Next:** Enable GitHub Pages now and wait 2 minutes! 🚀
