# 🚀 Quick Deploy Guide - VaultWheels

## ⚡ Super Quick Deploy (3 Commands)

```bash
cd e:\quickohunt
flutter build web --release
firebase deploy --only hosting
```

**Or even simpler - just double-click:**
```
deploy_vaultwheels.bat
```

---

## 🎯 What You Want to Do

### **Option 1: Just Deploy (No Git)**
```bash
# Double-click this file:
deploy_vaultwheels.bat

# Or manually:
flutter build web --release
firebase deploy --only hosting
```

### **Option 2: Commit to Git + Deploy**
```bash
# Double-click this file:
git_commit_and_deploy.bat

# Or manually:
git add .
git commit -m "Your message"
git push origin main
flutter build web --release
firebase deploy --only hosting
```

---

## 🌐 Setting Up vaultwheels.vervestrideai.com

### **After Deploying:**

1. **Open Firebase Console:**
   ```
   https://console.firebase.google.com/project/quickohunt-app/hosting
   ```

2. **Click "Add custom domain"**

3. **Enter:**
   ```
   vaultwheels.vervestrideai.com
   ```

4. **Firebase shows DNS records like:**
   ```
   Type: A
   Name: vaultwheels
   Value: 151.101.1.195

   Type: A  
   Name: vaultwheels
   Value: 151.101.65.195
   ```

5. **Add these to your vervestrideai.com DNS settings**

6. **Where?** 
   - Cloudflare? → DNS tab
   - GoDaddy? → DNS Management
   - Namecheap? → Advanced DNS
   - Google Domains? → DNS settings

7. **Wait 15-30 minutes** for DNS to propagate

8. **Done!** Visit: `https://vaultwheels.vervestrideai.com`

---

## 📋 Quick Checklist

**Before Deploy:**
- [ ] ✅ Legal documents ready
- [ ] ✅ Register screen shows Terms acceptance
- [ ] ✅ Test payment keys configured
- [ ] Run: `flutter doctor` (check no issues)

**Deploy:**
- [ ] Run: `deploy_vaultwheels.bat` (or manual commands)
- [ ] Verify: Visit `https://quickohunt-app.web.app`

**Custom Domain:**
- [ ] Firebase Console → Add custom domain
- [ ] Add DNS records to vervestrideai.com
- [ ] Wait for DNS propagation
- [ ] Verify: Visit `https://vaultwheels.vervestrideai.com`

---

## 🆘 Common Issues

### **"flutter: command not found"**
```bash
# Add Flutter to PATH or use full path:
C:\flutter\bin\flutter build web --release
```

### **"firebase: command not found"**
```bash
# Install Firebase CLI:
npm install -g firebase-tools

# Login:
firebase login
```

### **Build Takes Too Long**
```bash
# Use these flags for faster builds:
flutter build web --release --no-tree-shake-icons
```

### **Deploy Fails**
```bash
# Check you're logged in:
firebase login

# Check project is set:
firebase use quickohunt-app

# Try again:
firebase deploy --only hosting
```

---

## 💡 Pro Tips

### **1. Test Before Deploy**
```bash
# Build and test locally first:
flutter build web --release
cd build\web
python -m http.server 8000

# Visit: http://localhost:8000
```

### **2. Deploy Only Changed Files**
Firebase is smart - only uploads changed files. Second deploys are FAST!

### **3. Preview Before Production**
```bash
# Deploy to preview channel first:
firebase hosting:channel:deploy preview

# If good, deploy to main:
firebase deploy --only hosting
```

### **4. Check Deploy Status**
```bash
firebase hosting:sites:list
```

---

## 📊 After Deploy - What to Check

1. **Main site loads:** `https://quickohunt-app.web.app` ✅
2. **Terms page:** `https://quickohunt-app.web.app/terms.html` ✅
3. **Privacy page:** `https://quickohunt-app.web.app/privacy.html` ✅
4. **Registration works:** Click Terms links ✅
5. **Mobile responsive:** Test on phone ✅

---

## 🎯 Your URLs

### **Default Firebase (After Deploy):**
```
https://quickohunt-app.web.app
https://quickohunt-app.firebaseapp.com
```

### **Custom Domain (After DNS Setup):**
```
https://vaultwheels.vervestrideai.com
```

**All show the same app!** 🎉

---

## 📞 Need Help?

**Firebase Console:**
https://console.firebase.google.com/project/quickohunt-app

**Check DNS Propagation:**
https://dnschecker.org/#A/vaultwheels.vervestrideai.com

**Firebase Hosting Docs:**
https://firebase.google.com/docs/hosting

---

## ✅ That's It!

**Simple Version:**
1. Double-click `deploy_vaultwheels.bat`
2. Add custom domain in Firebase Console
3. Update DNS at your domain provider
4. Wait 15-30 minutes
5. Visit your new site! 🚀

**Questions?** Just ask! 💪
