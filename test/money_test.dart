import 'package:flutter_test/flutter_test.dart';
import 'package:hledger/core/format/money.dart';

void main() {
  group('rupees', () {
    test('groups in lakh and crore, not thousands', () {
      expect(Money.rupees(1250000), '₹12,50,000');
      expect(Money.rupees(100000), '₹1,00,000');
      expect(Money.rupees(10000000), '₹1,00,00,000');
      expect(Money.rupees(4500), '₹4,500');
      expect(Money.rupees(999), '₹999');
    });

    test('puts the sign before the symbol', () {
      expect(Money.rupees(-4500), '-₹4,500');
      expect(Money.rupees(-1250000), '-₹12,50,000');
    });

    test('rounds to whole rupees', () {
      expect(Money.rupees(1234.56), '₹1,235');
      expect(Money.rupees(1234.4), '₹1,234');
    });

    test('never renders a signed zero', () {
      expect(Money.rupees(0), '₹0');
      expect(Money.rupees(-0.2), '₹0');
      expect(Money.rupees(-0.0), '₹0');
    });
  });

  group('signed', () {
    test('marks the direction of the movement', () {
      expect(Money.signed(4500), '+₹4,500');
      expect(Money.signed(-4500), '-₹4,500');
    });

    test('leaves zero unmarked', () {
      expect(Money.signed(0), '₹0');
    });
  });

  group('compact', () {
    test('scales in Indian units', () {
      expect(Money.compact(10000), '₹10K');
      expect(Money.compact(45000), '₹45K');
      expect(Money.compact(150000), '₹1.5L');
      expect(Money.compact(1000000), '₹10L');
      expect(Money.compact(10000000), '₹1Cr');
      expect(Money.compact(15000000), '₹1.5Cr');
    });

    test('stays exact below the thousand threshold', () {
      expect(Money.compact(9999), '₹9,999');
      expect(Money.compact(0), '₹0');
      expect(Money.compact(450), '₹450');
    });

    test('carries the sign', () {
      expect(Money.compact(-45000), '-₹45K');
      expect(Money.compact(-150000), '-₹1.5L');
    });
  });
}
