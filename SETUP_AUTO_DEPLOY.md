# Setup Automatic GitHub → Firebase Deployment

## 🎯 Goal
Every time you push to GitHub, automatically build and deploy to **vaultwheels.web.app**

---

## ✅ What's Done (Already Set Up)

- ✅ GitHub Actions workflow created
- ✅ Workflow file pushed to GitHub
- ✅ Ready to configure

**Workflow file:** `.github/workflows/deploy-vaultwheels.yml`

---

## 🔧 NEXT STEP: Add Firebase Secret to GitHub

### Step 1: Get Firebase Service Account JSON

1. Open [Firebase Console](https://console.firebase.google.com/project/quickohunt-app/settings/serviceaccounts/adminsdk)
2. Click **Generate New Private Key**
3. Save the JSON file
4. Open it and copy **ALL** the content

### Step 2: Add to GitHub Secrets

1. Go to: https://github.com/nkgoldenshades/mytransport/settings/secrets/actions
2. Click **New repository secret**
3. **Name:** `FIREBASE_SERVICE_ACCOUNT_QUICKOHUNT_APP`
4. **Value:** Paste the entire JSON content
5. Click **Add secret**

---

## 🚀 Test It

After adding the secret:

1. Make a small change to any file
2. Commit: `git add . && git commit -m "test"`
3. Push: `git push origin main`
4. Go to: https://github.com/nkgoldenshades/mytransport/actions
5. Watch the workflow run
6. Check https://vaultwheels.web.app (updated!)

---

## 🔄 Workflow Flow

```
You push code to GitHub
        ↓
GitHub Actions triggered
        ↓
Flutter builds web (takes ~5 min)
        ↓
Firebase deploys to vaultwheels.web.app
        ↓
Site LIVE ✅
```

---

## 📊 Monitor Deployments

Check status: https://github.com/nkgoldenshades/mytransport/actions

You'll see:
- ✅ Green = Deployed successfully
- ❌ Red = Build or deploy failed
- ⏳ Yellow = In progress

---

## ✨ Benefits

After setup:
- No more manual `flutter build web`
- No more `firebase deploy`
- Just `git push` and it's live!

---

**That's it! Just add the Firebase secret and you're done.** 🎉
