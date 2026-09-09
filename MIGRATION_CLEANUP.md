# Migration & Cleanup Guide

## 🧹 Cleanup - Remove Old Files

The following old files have been replaced by the new refactored code and can be safely deleted:

```
lib/home.dart              # Replaced by navigation system in main.dart
lib/assignment_layout.dart # Replaced by assignment_detail_screen.dart
lib/dates_status.dart      # Replaced by models.dart and widgets
```

### To Delete These Files:
1. Open VS Code's Explorer
2. Right-click on each file
3. Select "Delete"
4. Confirm deletion

OR use terminal:
```bash
cd assignment_tracker
rm lib/home.dart
rm lib/assignment_layout.dart
rm lib/dates_status.dart
```

## 📊 Data Migration

### Old Format vs New Format

**Old Data Structure:**
- Assignments stored in separate widgets state
- No persistence
- Courses hardcoded in assignment_layout.dart
- No calendar integration

**New Data Structure:**
- Assignments stored in SharedPreferences as JSON
- Structured Course model with colors
- Separate active and history lists
- Calendar event IDs tracked

### Automatic Migration
The new app uses SharedPreferences, so:
1. First run creates empty storage
2. No data migration needed from old format
3. Users start fresh or manually recreate assignments

### Manual Migration (If needed)

If you want to keep old assignments, you would need to:
1. Export old assignments data
2. Create a migration script
3. Import into new format

Since old version didn't have persistence, this is not applicable unless you manually added data.

## 🔄 Fresh Start Setup

1. **Delete old files**
   ```bash
   rm lib/home.dart lib/assignment_layout.dart lib/dates_status.dart
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

4. **First time setup:**
   - App creates default courses automatically
   - Add your first assignment
   - Calendar integration initializes

## 📱 Platform-Specific Setup

### Android Setup

1. **Edit `android/app/build.gradle`:**
   ```gradle
   android {
       compileSdkVersion 34  // Or latest
       
       defaultConfig {
           targetSdkVersion 34  // Or latest
           minSdkVersion 21
       }
   }
   ```

2. **Edit `android/app/src/main/AndroidManifest.xml`:**
   ```xml
   <uses-permission android:name="android.permission.READ_CALENDAR" />
   <uses-permission android:name="android.permission.WRITE_CALENDAR" />
   <uses-permission android:name="android.permission.INTERNET" />
   ```

3. **Grant permissions at runtime:**
   The app handles this automatically via permission_handler

### iOS Setup

1. **Edit `ios/Runner/Info.plist`:**
   ```xml
   <key>NSCalendarsUsageDescription</key>
   <string>Assignment Tracker needs access to your calendar to sync assignment due dates. Your calendar will not be modified without your permission.</string>
   ```

2. **Enable Calendar in Xcode:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner > Signing & Capabilities
   - Click "+ Capability"
   - Add "Calendar" capability

### Windows/Linux/macOS
- Calendar integration requires platform-specific implementation
- For now, app runs but calendar features won't work
- Consider adding platform-specific calendar libraries in future

## 🗂️ Project Structure After Cleanup

```
assignment_tracker/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── models.dart
│   ├── screens/
│   │   ├── assignments_screen.dart
│   │   ├── assignment_detail_screen.dart
│   │   ├── history_screen.dart
│   │   └── settings_screen.dart
│   ├── services/
│   │   ├── calendar_service.dart
│   │   └── storage_service.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── widgets/
│       └── assignment_card.dart
├── android/
├── ios/
├── test/
├── pubspec.yaml
├── analysis_options.yaml
├── REFACTORING_GUIDE.md
└── README.md
```

## ✅ Verification Checklist

After cleanup and setup:

- [ ] No compile errors (`flutter analyze`)
- [ ] App starts without crashes (`flutter run`)
- [ ] All 3 navigation tabs work
- [ ] Can create new assignment
- [ ] Can edit assignment
- [ ] Can delete assignment
- [ ] Can change theme
- [ ] Can add course
- [ ] Can set calendar email
- [ ] Calendar events appear on device calendar
- [ ] Done assignments move to History
- [ ] Can restore from History

## 🚀 Building for Release

### Android
```bash
flutter build apk --release
# or for app bundle:
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web (if enabled)
```bash
flutter build web --release
```

## 🔍 Troubleshooting

### App Won't Start
```bash
flutter clean
flutter pub get
flutter run
```

### Calendar Events Not Syncing
- Check calendar permissions granted on device
- Verify email is configured in Settings
- Check Android/iOS permissions in manifest/plist

### Build Errors
```bash
flutter doctor  # Check environment
flutter pub get  # Refresh dependencies
flutter clean   # Clean build
```

### Old Data Not Showing
- Old format used in-memory storage only
- New app uses SharedPreferences
- No automatic migration (clean start)
- Re-add assignments manually if needed

## 📚 References

- [Flutter DevTools](https://docs.flutter.dev/tools/devtools)
- [Material 3 Design](https://m3.material.io/)
- [device_calendar Package](https://pub.dev/packages/device_calendar)
- [SharedPreferences Package](https://pub.dev/packages/shared_preferences)

---

**Next Steps:** Review REFACTORING_GUIDE.md for feature documentation
