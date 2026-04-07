# Bengali Number Plate OCR - Quick Reference

## What Was Fixed
The OCR system now properly detects **Bangladeshi license plates** with Bengali numerals (০১২৩৪৫৬৭৮৯) and converts them to English (0123456789) for the backend.

## Changes Made
1. **`_convertBengaliToEnglish()`** - Converts Bengali numerals to English
2. **`_extractPlateText()`** - Smart extraction that filters city/metro text and extracts only the plate number
3. **Pattern matching** - Uses regex `\d{2,3}[-]\d{3,4}` to identify valid plate numbers

## License Plate Format
```
┌─────────────────────┐
│  ঢাকা মেট্রো-গ      │  ← City/Metro/Class (ignored)
│                     │
│     ৩১-৯৯৫৭         │  ← Plate Number (extracted & converted)
└─────────────────────┘
       ↓
    31-9957  (sent to backend)
```

## How to Test

### Method 1: Run Unit Tests
```bash
cd frontend
flutter test test/ocr_test.dart
```

### Method 2: Test on Real Device
1. Build and run the app:
   ```bash
   cd frontend
   flutter run
   ```

2. Login as **Operator**

3. Tap the **"Scan Plate"** button

4. Take a photo of a Bengali license plate

5. Verify the plate number is correctly extracted (e.g., "31-9957")

## Expected Behavior

### ✅ Should Work:
- Bengali plates: "৩১-৯৯৫৭" → "31-9957"
- Bengali plates: "১২-৮৬৮৯" → "12-8689"
- Mixed format: "ঢাকা মেট্রো-গ\n৩১-৯৯৫৭" → "31-9957"
- English plates: "31-9957" → "31-9957" (already works)

### ❌ Won't Extract (by design):
- City names only: "ঢাকা মেট্রো-গ" → ""
- Random text without number pattern

## Supported Plate Formats
- **XX-XXXX** (2 digits, hyphen, 4 digits) - e.g., "31-9957"
- **XX-XXX** (2 digits, hyphen, 3 digits) - e.g., "12-345"
- **XXX-XXXX** (3 digits, hyphen, 4 digits) - e.g., "123-4567"
- **XXX-XXX** (3 digits, hyphen, 3 digits) - e.g., "123-456"

## Troubleshooting

### Problem: OCR returns empty string
**Cause:** Image quality too low or plate not in frame
**Solution:**
- Ensure good lighting
- Hold camera steady
- Center the plate in the frame
- Clean the plate surface

### Problem: Wrong numbers detected
**Cause:** OCR misreading due to poor image quality
**Solution:**
- Improve lighting conditions
- Take photo from directly in front (not angled)
- Ensure plate is clean and not damaged

### Problem: City name showing in result
**Cause:** Pattern matching failed to isolate number
**Solution:** 
- Check if plate format matches XX-XXXX pattern
- Report the issue with the actual plate format

## Testing Checklist
- [ ] Unit tests pass (`flutter test test/ocr_test.dart`)
- [ ] App compiles (`flutter analyze lib/main.dart`)
- [ ] Scan button works in app
- [ ] Bengali numeral plates correctly converted
- [ ] English numeral plates still work
- [ ] City/metro text filtered out
- [ ] Result sent to backend successfully

## Files Changed
- `frontend/lib/main.dart` - Main OCR logic
- `frontend/test/ocr_test.dart` - Unit tests (new file)

## Status: ✅ Ready for Testing
All unit tests pass. Ready for real-world device testing with camera.
