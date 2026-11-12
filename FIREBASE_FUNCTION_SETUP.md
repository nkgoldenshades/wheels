# 🔥 Firebase Cloud Function Setup

## Why This is Needed

Firebase JWTs don't include a `role` claim by default. Supabase needs this claim to assign the correct Postgres role for RLS policies.

**Without this:**
- Supabase assigns `anon` role
- RLS policies fail even if UID matches
- Queries return empty or throw permission errors

**With this:**
- Firebase user gets `role: 'authenticated'` custom claim
- Supabase recognizes the role
- RLS policies work correctly

## Setup Steps

### Option A: Deploy Cloud Function (Recommended)

#### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

#### 2. Login to Firebase
```bash
firebase login
```

#### 3. Initialize Functions (if not already done)
```bash
firebase init functions
```

Select:
- Use existing project: `quickohunt-app`
- Language: JavaScript
- ESLint: No (or Yes, your choice)
- Install dependencies: Yes

#### 4. Copy Function Code
Copy the contents of `firebase_functions/index.js` to `functions/index.js`
Copy the contents of `firebase_functions/package.json` to `functions/package.json`

#### 5. Deploy
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

#### 6. Verify Deployment
1. Go to Firebase Console → Functions
2. You should see: `addRoleClaim` function
3. Status should be "Active"

#### 7. Test with New Signup
1. Sign up a new user in your app
2. Check Firebase Console → Authentication → Users
3. Click on the user → "Custom claims" tab
4. Should see: `{"role":"authenticated"}`

---

### Option B: Manual Setup (For Existing Users)

If you already have test users and don't want to deploy a function yet:

#### 1. Install Firebase Admin SDK
```bash
npm install -g firebase-admin
```

#### 2. Create a Script
Create `set_role.js`:

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function setRoleForUser(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, {
      role: 'authenticated'
    });
    console.log(`✅ Set role for user: ${uid}`);
  } catch (error) {
    console.error(`❌ Error:`, error);
  }
}

// Replace with your Firebase UID
const uid = 'YOUR_FIREBASE_UID_HERE';
setRoleForUser(uid).then(() => process.exit());
```

#### 3. Get Service Account Key
1. Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save as `serviceAccountKey.json` in same folder as script

#### 4. Run Script
```bash
node set_role.js
```

#### 5. Verify
Check Firebase Console → Authentication → Users → Custom claims

---

## Verification

### Test 1: Check Custom Claim in Firebase
1. Firebase Console → Authentication → Users
2. Click on a user
3. Go to "Custom claims" tab
4. Should see: `{"role":"authenticated"}`

### Test 2: Check JWT in Supabase
After logging in, run in Supabase SQL Editor:

```sql
SELECT auth.jwt() ->> 'role';
```

**Expected:** Returns `"authenticated"`

### Test 3: Check Postgres Role
```sql
SELECT auth.role();
```

**Expected:** Returns `"authenticated"`

### Test 4: Verify RLS Works
```sql
-- Should succeed (you're inserting your own data)
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES (auth.uid()::text, 'Test Car', 'Car', ARRAY['passenger']);
```

**Expected:** Insert succeeds, no RLS error

---

## Troubleshooting

### Issue: Function Not Triggering

**Symptoms:**
- New users don't get custom claim
- Function shows 0 invocations in Firebase Console

**Fix:**
1. Check function is deployed: `firebase functions:list`
2. Check function logs: `firebase functions:log`
3. Redeploy: `firebase deploy --only functions`

### Issue: "Permission Denied" When Deploying

**Symptoms:**
- Deploy fails with permission error

**Fix:**
1. Check you're logged in: `firebase login`
2. Check project: `firebase use quickohunt-app`
3. Check IAM permissions in Firebase Console

### Issue: Custom Claim Not Appearing

**Symptoms:**
- Function runs successfully
- But custom claim not visible in Firebase Console

**Fix:**
1. Wait 1-2 minutes (propagation delay)
2. Refresh Firebase Console
3. Check function logs for errors
4. Try manual script (Option B)

### Issue: RLS Still Failing After Setting Claim

**Symptoms:**
- Custom claim exists
- But RLS policies still fail

**Fix:**
1. User must log out and log back in (to get new JWT with claim)
2. Or force token refresh:
   ```dart
   await FirebaseAuth.instance.currentUser?.getIdToken(true);
   ```
3. Check `SELECT auth.role();` returns `"authenticated"`

---

## Production Considerations

### Security
- ✅ Cloud Function runs with admin privileges (secure)
- ✅ Only Firebase Auth triggers can call it
- ✅ No client-side code can modify claims

### Performance
- Function runs once per user (on creation)
- Minimal cost (Firebase free tier: 125K invocations/month)
- No impact on app performance

### Monitoring
- Check Firebase Console → Functions → Logs
- Set up alerts for function failures
- Monitor invocation count

---

## Alternative: Supabase Native Auth

If you want to avoid this complexity, consider switching to Supabase native auth:

**Pros:**
- No custom claims needed
- `auth.uid()` is UUID (native)
- Simpler setup

**Cons:**
- Limited free tier (50K MAU)
- No Firebase features (FCM, etc.)
- Need to migrate existing users

**To switch:**
1. Change schema: `id UUID` instead of `id TEXT`
2. Remove Firebase Auth code
3. Use Supabase auth methods
4. Update RLS policies: `auth.uid() = id` (no ::text cast)

---

## Files Reference

| File | Purpose |
|------|---------|
| `firebase_functions/index.js` | Cloud Function code |
| `firebase_functions/package.json` | Dependencies |
| `FIREBASE_FUNCTION_SETUP.md` | This guide |

---

## Quick Commands

```bash
# Deploy function
firebase deploy --only functions

# View logs
firebase functions:log

# Test locally
firebase emulators:start --only functions

# List deployed functions
firebase functions:list

# Delete function
firebase functions:delete addRoleClaim
```

---

## Time Estimate

- Option A (Cloud Function): 10 minutes
- Option B (Manual script): 5 minutes per user

---

## Next Steps

After setting up custom claims:
1. Test new signup → Verify claim appears
2. Test RLS policies → Should work now
3. Continue with app development
4. Monitor function logs for any issues

**Remember:** Existing users need to log out and log back in to get the new JWT with the custom claim.
