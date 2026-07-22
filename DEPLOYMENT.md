# QuickOHunt Deployment Guide

## Firebase Hosting Deployment

### Prerequisites
1. Flutter web build completed (`build/web/` folder exists)
2. Firebase CLI installed: `npm install -g firebase-tools`
3. Firebase project created

### Setup Steps

#### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

#### 2. Login to Firebase
```bash
firebase login
```

#### 3. Configure Project
Update `.firebaserc` with your Firebase project ID:
```json
{
  "projects": {
    "default": "your-firebase-project-id"
  }
}
```

#### 4. Build Flutter Web
```bash
cd E:\quickohunt
flutter build web --release
```

This creates `build/web/` directory with optimized production build.

#### 5. Deploy to Firebase Hosting
```bash
firebase deploy
```

### Deployment Output
After deployment completes, you'll get:
- **Hosting URL**: `https://your-project.web.app`
- **Console URL**: Firebase console link

### Post-Deployment
1. Visit your hosting URL to verify deployment
2. Check Firebase Console for hosting analytics
3. Set up custom domain if needed (Firebase Console > Hosting > Domain)

### Rollback (if needed)
```bash
firebase hosting:channel:list     # View all versions
firebase hosting:clone SOURCE:VERSION CHANNEL:TARGET
```

### Environment Variables
Supabase keys are already configured in:
- `web/index.html` (via Flutter environment)
- Supabase project settings

No additional configuration needed for production.

### Performance Tips
1. **Caching**: Static assets cached for 1 year (see firebase.json)
2. **CDN**: Firebase CDN automatically distributes globally
3. **Compression**: Enable gzip compression in Firebase Console

### Troubleshooting

**Build fails:**
```bash
flutter clean
flutter pub get
flutter build web --release
```

**Deploy fails:**
```bash
firebase init          # Reinitialize
firebase deploy        # Try again
```

**Slow loading:**
- Check Firebase Console > Performance
- Enable Cloud CDN in Firebase Console

### Monitoring
- Firebase Console > Hosting > Analytics
- Monitor traffic, bandwidth, errors
- Set up alerts for deployment issues

---

**Next: Set up custom domain in Firebase Console**
