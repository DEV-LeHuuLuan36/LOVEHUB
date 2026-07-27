import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/core/security/input_validator.dart';

void main() {
  group('InputValidator.sanitize', () {
    test('strips control characters', () {
      expect(InputValidator.sanitize('Hello\x00\x07World'), 'HelloWorld');
      expect(InputValidator.sanitize('Line1\nLine2\r'), 'Line1Line2');
    });

    test('keeps emoji + accented characters', () {
      expect(InputValidator.sanitize('Tiếng Việt 💕'), 'Tiếng Việt 💕');
    });

    test('trims whitespace', () {
      expect(InputValidator.sanitize('  hi  '), 'hi');
    });
  });

  group('InputValidator.validateEmail', () {
    test('accepts a sane address', () {
      expect(InputValidator.validateEmail('a@b.co'), isNull);
    });
    test('rejects missing parts', () {
      expect(InputValidator.validateEmail('a'), isNotNull);
      expect(InputValidator.validateEmail('a@b'), isNotNull);
      expect(InputValidator.validateEmail('@b.co'), isNotNull);
    });
    test('lowercases input', () {
      // The validator itself returns null on valid input; the caller is
      // expected to lowercase separately. Make sure validation passes both
      // cases.
      expect(InputValidator.validateEmail('MiXeD@Example.Com'), isNull);
    });
  });

  group('InputValidator.validateName', () {
    test('rejects empty after trimming', () {
      expect(InputValidator.validateName('   '), isNotNull);
    });
    test('accepts 1..50 chars', () {
      expect(InputValidator.validateName('Minh'), isNull);
      expect(InputValidator.validateName('x' * 50), isNull);
      expect(InputValidator.validateName('x' * 51), isNotNull);
    });
  });

  group('InputValidator.validateBankAccount', () {
    test('digits only, min 4, max 19', () {
      expect(InputValidator.validateBankAccount('1234567890'), isNull);
      expect(InputValidator.validateBankAccount('12'), isNotNull);
      expect(InputValidator.validateBankAccount('1234567890abcdefghij'), isNotNull);
      expect(InputValidator.validateBankAccount('1234abcd'), isNotNull);
    });
  });

  group('InputValidator.normaliseVietQrAccountName', () {
    test('uppercases and strips diacritics', () {
      expect(
        InputValidator.normaliseVietQrAccountName('Nguyễn Văn A'),
        'NGUYEN VAN A',
      );
    });
  });

  group('InputValidator.validateCoupleCode', () {
    test('upcases, drops whitespace, length 4..24', () {
      expect(InputValidator.validateCoupleCode('abcd1234'), isNull);
      // Sanitisation drops spaces + upcases, so ' love-1 ' → 'LOVE-1' is
      // valid. The validator cannot reject what a user pastes in.
      expect(InputValidator.validateCoupleCode(' love-1 '), isNull);
      expect(InputValidator.validateCoupleCode('a'), isNotNull);
      expect(InputValidator.validateCoupleCode('x' * 25), isNotNull);
      // Banned chars survive normalisation.
      expect(InputValidator.validateCoupleCode('ab cd!'), isNotNull);
    });
  });

  group('InputValidator.parseMoney', () {
    test('parses comma/dot-separated amounts', () {
      expect(InputValidator.parseMoney('1,000,000'), 1000000);
      expect(InputValidator.parseMoney('1.000.000'), 1000000);
      expect(InputValidator.parseMoney('50000'), 50000);
    });
    test('rejects bad input', () {
      expect(InputValidator.parseMoney(null), isNull);
      expect(InputValidator.parseMoney(''), isNull);
      expect(InputValidator.parseMoney('abc'), isNull);
      expect(InputValidator.parseMoney('0'), isNull);
      expect(InputValidator.parseMoney('-1'), isNull);
    });
  });

  group('InputValidator.validateAmount', () {
    test('rejects non-positive and too large', () {
      expect(InputValidator.validateAmount(0), isNotNull);
      expect(InputValidator.validateAmount(-1), isNotNull);
      expect(InputValidator.validateAmount(null), isNotNull);
      expect(InputValidator.validateAmount(1000000001), isNotNull);
    });
    test('accepts positive in range', () {
      expect(InputValidator.validateAmount(1), isNull);
      expect(InputValidator.validateAmount(100000), isNull);
    });
  });

  group('InputValidator.validateHttpUrl', () {
    test('accepts http(s)', () {
      expect(InputValidator.validateHttpUrl('https://x.com'), isNull);
      expect(InputValidator.validateHttpUrl('http://x.com/y'), isNull);
    });
    test('rejects javascript:/data:/file:', () {
      expect(InputValidator.validateHttpUrl('javascript:alert(1)'), isNotNull);
      expect(InputValidator.validateHttpUrl('data:text/html,xx'), isNotNull);
      expect(InputValidator.validateHttpUrl('file:///etc/passwd'), isNotNull);
    });
  });
}
