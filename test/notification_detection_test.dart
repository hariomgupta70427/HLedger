import 'package:flutter_test/flutter_test.dart';
import 'package:hledger/services/transaction_classifier.dart';
import 'package:hledger/services/upi_parser.dart';

/// Detection cases taken from the shapes real payment apps actually post, kept
/// separate from the SMS suite because notification text has no sender header
/// and is usually a title glued to a one-line body.
void main() {
  group('UPI debit', () {
    test('GPay outgoing payment', () {
      final r = UpiParser.parse('₹450 paid to Zomato You paid ₹450 to Zomato');
      expect(r, isNotNull);
      expect(r!.amount, 450);
      expect(r.direction, 'debit');
      expect(r.transactionType, 'expense');
    });

    test('PhonePe outgoing payment with reference', () {
      final r = UpiParser.parse(
        'Payment successful ₹1,250 debited to BLINKIT. UPI Ref 445566778899',
      );
      expect(r, isNotNull);
      expect(r!.amount, 1250);
      expect(r.direction, 'debit');
      expect(r.dedupeKey, 'ref:445566778899');
    });
  });

  group('UPI credit / received', () {
    test('received from a person', () {
      final r = UpiParser.parse('₹500 received You received ₹500 from Hariom');
      expect(r, isNotNull);
      expect(r!.amount, 500);
      expect(r.direction, 'credit');
      expect(r.transactionType, 'income');
    });

    // The reported miss: Amazon Pay words an incoming payment as a balance
    // top-up, with no settlement participle anywhere in the text.
    test('Amazon Pay wallet top-up is income, not a miss', () {
      final r = UpiParser.parse(
        'Money added ₹500 added to your Amazon Pay balance',
      );
      expect(r, isNotNull, reason: 'wallet top-up must be detected');
      expect(r!.amount, 500);
      expect(r.direction, 'credit');
    });

    test('transferred into the account is income', () {
      final r = UpiParser.parse('₹2,000 transferred to your account by RAHUL');
      expect(r, isNotNull);
      expect(r!.amount, 2000);
      expect(r.direction, 'credit');
    });

    test('a balance line after the amount is not the amount', () {
      final r = UpiParser.parse(
        '₹500 received from Hariom. Available balance is ₹12,340',
      );
      expect(r, isNotNull);
      expect(r!.amount, 500, reason: 'must not pick up the balance figure');
    });
  });

  group('cashback', () {
    test('a settled cashback is income', () {
      final r = UpiParser.parse(
        'Cashback credited ₹20 cashback credited to your Paytm wallet',
      );
      expect(r, isNotNull);
      expect(r!.amount, 20);
      expect(r.direction, 'credit');
    });
  });

  group('promotional offers', () {
    test('the BHIM cashback offer is rejected', () {
      expect(
        UpiParser.parse(
          'Your next 5 UPI Lite payments come with cashback of Rs 20',
        ),
        isNull,
      );
    });

    test('an Amazon Pay style offer is rejected', () {
      expect(
        UpiParser.parse('Get up to ₹100 cashback on your next recharge'),
        isNull,
      );
    });
  });

  group('card payments', () {
    test('a card spend is a debit', () {
      final r = UpiParser.parse(
        'Transaction alert ₹1,299 spent on your HDFC Bank Credit Card XX4321 '
        'at DECATHLON',
      );
      expect(r, isNotNull);
      expect(r!.amount, 1299);
      expect(r.direction, 'debit');
      expect(r.instrument, 'card');
      expect(r.accountLast4, '4321');
    });

    test('a RuPay credit card paid over UPI is a debit', () {
      final r = UpiParser.parse(
        'UPI payment ₹780 debited from your RuPay Credit Card XX9012 to '
        'RELIANCE FRESH. UPI Ref 121314151617',
      );
      expect(r, isNotNull);
      expect(r!.amount, 780);
      expect(r.direction, 'debit');
      expect(r.dedupeKey, 'ref:121314151617');
    });
  });

  group('duplicate handling', () {
    test('the same alert twice collapses to one identity', () {
      const text = '₹450 paid to Zomato. UPI Ref 998877665544';
      final first = UpiParser.parse(text);
      final second = UpiParser.parse(text);

      expect(first!.dedupeKey, second!.dedupeKey);
      expect(
        TransactionClassifier.toPendingTransaction(first, userId: 'u1')
            .detectionKey,
        TransactionClassifier.toPendingTransaction(second, userId: 'u1')
            .detectionKey,
      );
    });

    test('two genuine payments of the same amount stay distinct', () {
      // Different references: two real ₹200 payments, not one duplicate.
      final a = UpiParser.parse('₹200 paid to BLINKIT. UPI Ref 111111111111');
      final b = UpiParser.parse('₹200 paid to BLINKIT. UPI Ref 222222222222');

      expect(a!.dedupeKey, isNot(b!.dedupeKey));
    });

    test('same amount and no reference still separates by counterparty', () {
      final a = UpiParser.parse('₹200 paid to BLINKIT on 20-08-26');
      final b = UpiParser.parse('₹200 paid to ZEPTO on 20-08-26');

      expect(a!.dedupeKey, isNot(b!.dedupeKey));
    });
  });

  group('unsupported sources', () {
    test('a chat message that mentions money is not a transaction', () {
      // Even if such text reached the parser, there is no settled direction.
      expect(UpiParser.parse('Bro I need 500 rupees for the trip'), isNull);
    });

    test('a shopping order update is not a transaction', () {
      expect(
        UpiParser.parse('Your order of ₹1,299 will be delivered tomorrow'),
        isNull,
      );
    });

    test('an OTP is never a transaction', () {
      expect(
        UpiParser.parse('123456 is your OTP to pay Rs 500. Do not share it.'),
        isNull,
      );
    });

    test('a standalone balance alert is not a transaction', () {
      expect(
        UpiParser.parse('Your available balance is ₹12,340 as on 20-08-26'),
        isNull,
      );
    });
  });
}
