import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bengali Number Plate OCR Tests', () {
    
    /// Convert Bengali numerals to English numerals
    String convertBengaliToEnglish(String text) {
      const bengaliToEnglish = {
        '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4',
        '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9',
      };
      
      String result = text;
      bengaliToEnglish.forEach((bengali, english) {
        result = result.replaceAll(bengali, english);
      });
      return result;
    }

    /// Extract license plate number from OCR text
    String extractPlateText(String rawText) {
      // Convert Bengali numerals to English
      final converted = convertBengaliToEnglish(rawText);
      
      // Split into lines to process separately
      final lines = converted.split('\n');
      
      // Look for line matching plate number pattern: 2-3 digits, hyphen, 3-4 digits
      final platePattern = RegExp(r'\b(\d{2,3}[-]\d{3,4})\b');
      
      for (final line in lines) {
        final match = platePattern.firstMatch(line);
        if (match != null) {
          return match.group(1)!.trim().toUpperCase();
        }
      }
      
      // Fallback: if no pattern match, try to find any line with digits and hyphen
      for (final line in lines) {
        if (line.contains('-') && RegExp(r'\d').hasMatch(line)) {
          final digitsAndHyphen = line.replaceAll(RegExp(r'[^\d-]'), '');
          if (digitsAndHyphen.isNotEmpty && digitsAndHyphen.contains('-')) {
            return digitsAndHyphen.trim().toUpperCase();
          }
        }
      }
      
      // Last resort: return cleaned text
      return converted.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
    }

    test('Convert Bengali numerals to English', () {
      expect(convertBengaliToEnglish('৩১-৯৯৫৭'), equals('31-9957'));
      expect(convertBengaliToEnglish('১২-৮৬৮৯'), equals('12-8689'));
      expect(convertBengaliToEnglish('০০-০০০০'), equals('00-0000'));
    });

    test('Extract plate from full OCR text with Bengali numerals', () {
      // Test case from image: "ঢাকা মেট্রো-গ" on top, "৩১-৯৯৫৭" on bottom
      const ocrText = 'ঢাকা মেট্রো-গ\n৩১-৯৯৫৭';
      expect(extractPlateText(ocrText), equals('31-9957'));
    });

    test('Extract plate with different city names', () {
      const ocrText1 = 'চট্ট মেট্রো-গ\n১১-৭২৮৮';
      expect(extractPlateText(ocrText1), equals('11-7288'));
      
      const ocrText2 = 'ঢাকা মেট্রো-খ\n১২-৮৬৮৯';
      expect(extractPlateText(ocrText2), equals('12-8689'));
    });

    test('Extract plate with 3-digit prefix', () {
      const ocrText = 'ঢাকা মেট্রো-গ\n১২৩-৪৫৬৭';
      expect(extractPlateText(ocrText), equals('123-4567'));
    });

    test('Extract plate with 3-digit suffix', () {
      const ocrText = 'ঢাকা মেট্রো-গ\n১২-৩৪৫';
      expect(extractPlateText(ocrText), equals('12-345'));
    });

    test('Handle single line OCR result', () {
      const ocrText = '৩১-৯৯৫৭';
      expect(extractPlateText(ocrText), equals('31-9957'));
    });

    test('Handle noisy OCR with extra spaces', () {
      const ocrText = 'ঢাকা   মেট্রো-গ\n  ৩১-৯৯৫৭  ';
      expect(extractPlateText(ocrText), equals('31-9957'));
    });

    test('Ignore non-numeric lines and extract only the number', () {
      const ocrText = 'ঢাকা মেট্রো-গ\nClass Number\n৩১-৯৯৫৭\nExtra Text';
      expect(extractPlateText(ocrText), equals('31-9957'));
    });
  });
}
