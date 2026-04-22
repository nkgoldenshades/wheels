# Quick Web Commands Reference

## 🚀 Run Development Server

### Windows (PowerShell/CMD)
```bash
run_web.bat
```

Or manually:
```bash
flutter run -d chrome --web-renderer html
```

### Linux/Mac (Bash)
```bash
./run_web.sh
```

Or manually:
```bash
flutter run -d chrome --web-renderer html
```

## 🏗️ Build for Production

```bash
flutter build web --web-renderer html --release
```

Output will be in: `build/web/`

## 🧹 Clean Build (If Issues)

```bash
flutter clean
flutter pub get
flutter run -d chrome --web-renderer html
```

## 🔍 Check for Issues

```bash
flutter analyze
```

## 📦 Update Dependencies

```bash
flutter pub upgrade
```

## 🌐 Test in Different Browsers

### Chrome
```bash
flutter run -d chrome --web-renderer html
```

### Edge
```bash
flutter run -d edge --web-renderer html
```

### Firefox (if configured)
```bash
flutter run -d firefox --web-renderer html
```

## 🐛 Debug Mode vs Release Mode

### Debug (with hot reload)
```bash
flutter run -d chrome --web-renderer html
```

### Profile (performance testing)
```bash
flutter run -d chrome --web-renderer html --profile
```

### Release (optimized)
```bash
flutter run -d chrome --web-renderer html --release
```

## 💡 Tips

1. **Clear browser cache** if you see old errors:
   - Chrome: `Ctrl+Shift+Delete` (Windows) or `Cmd+Shift+Delete` (Mac)
   - Or use Incognito mode: `Ctrl+Shift+N`

2. **Hot reload** during development:
   - Press `r` in terminal for hot reload
   - Press `R` for hot restart
   - Press `q` to quit

3. **View console logs**:
   - Open browser DevTools: `F12` or `Ctrl+Shift+I`
   - Check Console tab for errors/logs

4. **Port already in use?**
   ```bash
   flutter run -d chrome --web-renderer html --web-port=8081
   ```

## 🎯 Common Issues

### Issue: "Waiting for connection from debug service"
**Solution**: Close all Chrome instances and try again

### Issue: Font warnings in console
**Solution**: Safe to ignore - app uses system fonts

### Issue: CanvasKit errors
**Solution**: Already fixed with HTML renderer configuration

### Issue: Hot reload not working
**Solution**: Press `R` (capital R) for full restart
