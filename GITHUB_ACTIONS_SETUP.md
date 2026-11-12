# GitHub Actions - Automatic Deployment to Firebase

## ✅ What's Set Up

Automatic workflow: **GitHub → Build → Firebase Hosting (vaultwheels.web.app)**

When you push to `main` branch, GitHub Actions will:
1. Build Flutter Web
2. Deploy to vaultwheels.web.app automatically

---

## 🔧 Setup Required (ONE TIME)

### Step 1: Create Firebase Service Account

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **quickohunt-app**
3. Go to **Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Save the JSON file (keep it secret!)

### Step 2: Add GitHub Secret

1. Go to your GitHub repo: https://github.com/nkgoldenshades/mytransport
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `FIREBASE_SERVICE_ACCOUNT_QUICKOHUNT_APP`
5. Value: Copy entire JSON content from the Firebase service account file
6. Click **Add secret**

### Step 3: Test

1. Make a small change to your code (or just push)
2. Go to GitHub → **Actions** tab
3. Watch the workflow run
4. Check vaultwheels.web.app after deployment

---

## 🚀 How It Works

**Every time you push to main:**

```
You push to GitHub
    ↓
GitHub Actions triggers
    ↓
Flutter builds web
    ↓
Firebase deploys to vaultwheels.web.app
    ↓
Live site updates automatically
```

---

## 📋 Workflow File

Location: `.github/workflows/deploy-vaultwheels.yml`

**Triggers on:**
- Push to `main` branch
- Pull requests to `main` branch

**Actions:**
- Builds Flutter Web (release mode)
- Deploys to Firebase Hosting
- Targets: vaultwheels site in quickohunt-app project

---

## ✨ Benefits

✅ **Automatic**: No manual deployment needed  
✅ **Fast**: Deploys in ~5 minutes  
✅ **Safe**: Only deploys from main branch  
✅ **Visible**: See status in GitHub Actions tab  

---

## 🔍 Monitor Deployment

After pushing:
1. Go to: https://github.com/nkgoldenshades/mytransport/actions
2. Click the latest workflow run
3. Watch the logs
4. Check vaultwheels.web.app when complete

---

## ❌ Troubleshooting

**If deployment fails:**

1. Check GitHub Actions logs for errors
2. Verify Firebase service account JSON is correctly added
3. Ensure `.github/workflows/deploy-vaultwheels.yml` exists
4. Check Firebase project has vaultwheels hosting site

---

## 📝 Manual Override

If you need to deploy manually without GitHub:
```bash
flutter build web --release
firebase deploy --only hosting:vaultwheels
```

---

**Status: Ready to configure**

Next: Add Firebase service account to GitHub Secrets, then test!
