import 'package:flutter_test/flutter_test.dart';
import 'package:hledger/services/upi_parser.dart';

void main() {
  group('amount extraction', () {
    test('ungrouped amounts are not truncated', () {
      // The previous pattern captured only the first three digits of an
      // ungrouped figure, so these all parsed an order of magnitude low.
      expect(UpiParser.parse('Rs 5000 debited from A/c XX1234')?.amount, 5000);
      expect(UpiParser.parse('Rs.1234.56 debited from A/c XX1234')?.amount,
          1234.56);
      expect(UpiParser.parse('INR 250000 debited')?.amount, 250000);
      expect(UpiParser.parse('₹99999 spent')?.amount, 99999);
    });

    test('Indian digit grouping is preserved', () {
      expect(UpiParser.parse('Rs.1,234.56 debited')?.amount, 1234.56);
      expect(UpiParser.parse('Rs.1,23,456.78 debited')?.amount, 123456.78);
      expect(UpiParser.parse('INR 1,200 credited')?.amount, 1200);
    });

    test('currency prefix variants', () {
      expect(UpiParser.parse('Rs500 debited')?.amount, 500);
      expect(UpiParser.parse('Rs. 500.00 debited')?.amount, 500);
      expect(UpiParser.parse('₹ 500 debited')?.amount, 500);
      expect(UpiParser.parse('Amount 750 debited')?.amount, 750);
      expect(UpiParser.parse('Amt: 640.25 debited')?.amount, 640.25);
    });

    test('balance figures are not mistaken for the transaction amount', () {
      final result = UpiParser.parse(
        'Rs.500.00 debited from A/c XX1234 on 12-Aug-26. Avl Bal Rs.12,500.00',
      );
      expect(result?.amount, 500);
    });

    test('a standalone balance alert is rejected', () {
      expect(
        UpiParser.parse('Your A/c XX1234 Avl Bal is Rs.12,500.00 as on 12-Aug-26'),
        isNull,
      );
      expect(
        UpiParser.parse('Available credit limit on your card is Rs.45,000'),
        isNull,
      );
    });

    test('a currency-like word does not seed a false amount', () {
      expect(UpiParser.parse('Delivery in 24 hrs. 500 items left'), isNull);
    });
  });

  group('direction', () {
    test('debit alerts', () {
      expect(UpiParser.parse('Rs.500 debited from A/c XX1234')?.direction,
          'debit');
      expect(UpiParser.parse('Rs.500 withdrawn at ATM')?.direction, 'debit');
      expect(UpiParser.parse('You spent Rs.500 on your card')?.direction,
          'debit');
    });

    test('credit alerts', () {
      expect(UpiParser.parse('Rs.500 credited to A/c XX1234')?.direction,
          'credit');
      expect(UpiParser.parse('Rs.500 deposited in A/c XX1234')?.direction,
          'credit');
      expect(UpiParser.parse('Refund of Rs.500 processed to A/c XX1234')
          ?.direction, 'credit');
    });

    test('salary credit is not misread as a debit by a later verb', () {
      // 'transferred' is a debit verb but appears after 'credited'; the marker
      // nearest the start of the message decides.
      final result = UpiParser.parse(
        'Rs.45,000.00 credited to A/c XX1234 on 01-Aug-26, transferred by '
        'ACME PVT LTD. Avl Bal Rs.52,300.00',
      );
      expect(result?.direction, 'credit');
      expect(result?.transactionType, 'income');
    });

    test('a credit-card debit is not misread as income', () {
      final result = UpiParser.parse(
        'Rs.2,500.00 debited towards your credit card bill payment',
      );
      expect(result?.direction, 'debit');
    });

    test('an amount with no direction is rejected, not assumed to be a debit',
        () {
      // Previously this returned a debit and fabricated an expense.
      expect(UpiParser.parse('Your transaction of Rs.5,000 is being processed'),
          isNull);
      expect(UpiParser.parse('Rs.1,000 cashback offer on your next order'),
          isNull);
    });
  });

  group('non-transactional messages are rejected', () {
    test('OTP messages', () {
      expect(
        UpiParser.parse('OTP for txn of Rs.5,000 at AMAZON is 123456. '
            'Do not share with anyone.'),
        isNull,
      );
      expect(
        UpiParser.parse('123456 is your one time password to authorise '
            'Rs.2,000 payment'),
        isNull,
      );
    });

    test('collect and payment requests', () {
      expect(
        UpiParser.parse('user@upi is requesting Rs.500. Approve in your UPI app'),
        isNull,
      );
      expect(
        UpiParser.parse('You have received a collect request of Rs.500'),
        isNull,
      );
    });

    test('failed and future-dated notices', () {
      expect(UpiParser.parse('Your payment of Rs.500 has failed'), isNull);
      expect(
        UpiParser.parse('Rs.1,999 will be debited on 25-Aug-26 towards '
            'your autopay mandate'),
        isNull,
      );
    });
  });

  group('sender handling', () {
    test('a numeric origin is discarded unparsed', () {
      expect(
        UpiParser.parse('I sent you Rs.500 yesterday', sender: '+919876543210'),
        isNull,
      );
      expect(
        UpiParser.parse('Rs.500 debited', sender: '9876543210'),
        isNull,
      );
    });

    test('a recognised header marks the result verified', () {
      final result = UpiParser.parse(
        'Rs.500.00 debited from A/c XX1234',
        sender: 'VM-HDFCBK',
      );
      expect(result?.senderVerified, isTrue);
      expect(result?.bankName, 'HDFC');
    });

    test('an unrecognised alphanumeric header still parses but unverified', () {
      final result = UpiParser.parse(
        'Rs.500.00 debited from A/c XX1234',
        sender: 'AX-NEWCOOP',
      );
      expect(result, isNotNull);
      expect(result!.senderVerified, isFalse);
    });

    test('sender identifies the bank even when the body does not', () {
      expect(
        UpiParser.parse('Rs.500 debited from A/c XX1234',
                sender: 'JD-ICICIB')
            ?.bankName,
        'ICICI',
      );
    });

    test('isTrustedSender classifies origins', () {
      expect(UpiParser.isTrustedSender('VM-HDFCBK'), isTrue);
      expect(UpiParser.isTrustedSender('AD-SBIINB'), isTrue);
      expect(UpiParser.isTrustedSender('+919876543210'), isFalse);
      expect(UpiParser.isTrustedSender('MOM'), isFalse);
      expect(UpiParser.isTrustedSender(null), isFalse);
    });
  });

  group('date and time', () {
    test('dd-MMM-yy is parsed', () {
      final result = UpiParser.parse('Rs.500 debited on 12-Aug-26');
      expect(result?.date?.year, 2026);
      expect(result?.date?.month, 8);
      expect(result?.date?.day, 12);
    });

    test('numeric dates are parsed', () {
      final result = UpiParser.parse('Rs.500 debited on 12/08/2026');
      expect(result?.date, DateTime(2026, 8, 12));
    });

    test('time of day is carried so entries are not all at midnight', () {
      final result =
          UpiParser.parse('Rs.500 debited on 12-Aug-26 at 14:35 hrs');
      expect(result?.date, DateTime(2026, 8, 12, 14, 35));
    });

    test('12-hour clock is normalised', () {
      expect(
        UpiParser.parse('Rs.500 debited on 12-Aug-26 02:35 PM')?.date,
        DateTime(2026, 8, 12, 14, 35),
      );
      expect(
        UpiParser.parse('Rs.500 debited on 12-Aug-26 12:05 AM')?.date,
        DateTime(2026, 8, 12, 0, 5),
      );
    });

    test('an impossible date does not roll forward into the next month', () {
      expect(UpiParser.parse('Rs.500 debited on 31/02/2026')?.date, isNull);
    });
  });

  group('reference number', () {
    test('UTR and UPI reference forms', () {
      expect(
        UpiParser.parse('Rs.500 debited. UPI Ref 123456789012')?.referenceNumber,
        '123456789012',
      );
      expect(
        UpiParser.parse('Rs.500 debited. UTR: HDFCN12345678')?.referenceNumber,
        'HDFCN12345678',
      );
      expect(
        UpiParser.parse('Rs.500 debited. Ref No. 987654321')?.referenceNumber,
        '987654321',
      );
    });

    test('a purely alphabetic capture is not accepted as a reference', () {
      expect(
        UpiParser.parse('Rs.500 debited. Reference unavailable')
            ?.referenceNumber,
        isNull,
      );
    });
  });

  group('counterparty and rail', () {
    test('merchant is extracted from a card alert', () {
      final result = UpiParser.parse(
        'Rs.1,299.00 spent on your HDFC Bank Debit Card XX1234 at '
        'AMAZON RETAIL on 12-Aug-26',
      );
      expect(result?.merchant, 'AMAZON RETAIL');
      expect(result?.suggestedCategory, 'Shopping');
      expect(result?.instrument, 'card');
    });

    test('VPA is extracted from a UPI alert', () {
      final result = UpiParser.parse(
        'Rs.250.00 debited from A/c XX1234 to VPA swiggy@ybl on 12-Aug-26. '
        'UPI Ref 445566778899',
      );
      expect(result?.vpa, 'swiggy@ybl');
      expect(result?.suggestedCategory, 'Food');
    });

    test('rails are identified', () {
      expect(UpiParser.parse('Rs.500 withdrawn at ATM XX1234')?.instrument,
          'atm');
      expect(UpiParser.parse('Rs.500 credited via NEFT')?.instrument, 'neft');
      expect(UpiParser.parse('Rs.500 debited via IMPS')?.instrument, 'imps');
      expect(UpiParser.parse('Rs.500 debited towards EMI')?.instrument, 'emi');
    });

    test('short category keys do not match inside unrelated words', () {
      // 'vi' maps to Bills and 'hp' to Transport; neither may fire on a
      // merchant that merely contains those letters.
      final result = UpiParser.parse(
        'Rs.500.00 debited from A/c XX1234 to VPA vivekkumar@okaxis',
      );
      expect(result?.suggestedCategory, 'Other');
    });

    test('displayLabel prefers the most specific counterparty', () {
      expect(
        UpiParser.parse('Rs.500 spent at STARBUCKS on 12-Aug-26')?.displayLabel,
        'STARBUCKS',
      );
      expect(
        UpiParser.parse('Rs.500 debited from A/c XX1234',
                sender: 'VM-HDFCBK')
            ?.displayLabel,
        'HDFC ••1234',
      );
    });
  });

  group('dedupeKey', () {
    test('the bank reference is used when present', () {
      final a = UpiParser.parse('Rs.200 debited. UPI Ref 123456789012');
      final b = UpiParser.parse(
        'Rs.200.00 debited from A/c XX9999. UPI Ref 123456789012',
      );
      expect(a?.dedupeKey, b?.dedupeKey);
    });

    test('two same-value debits on one day stay distinct', () {
      // The old key was amount + label + a date-only timestamp, so the second
      // of these was silently swallowed as a duplicate.
      final first = UpiParser.parse(
        'Rs.200.00 debited from A/c XX1234 to VPA shop1@ybl on 12-Aug-26. '
        'UPI Ref 111111111111',
      );
      final second = UpiParser.parse(
        'Rs.200.00 debited from A/c XX1234 to VPA shop2@ybl on 12-Aug-26. '
        'UPI Ref 222222222222',
      );
      expect(first?.dedupeKey, isNot(second?.dedupeKey));
    });
  });

  group('real-world message shapes', () {
    test('HDFC UPI debit', () {
      final result = UpiParser.parse(
        'Rs.450.00 debited from A/c XX4567 on 12-Aug-26 to VPA '
        'zomato@hdfcbank. UPI Ref 556677889900. Not you? Call 18002586161',
        sender: 'VM-HDFCBK',
      );
      expect(result, isNotNull);
      expect(result!.amount, 450);
      expect(result.direction, 'debit');
      expect(result.accountLast4, '4567');
      expect(result.vpa, 'zomato@hdfcbank');
      expect(result.suggestedCategory, 'Food');
      expect(result.referenceNumber, '556677889900');
      expect(result.bankName, 'HDFC');
      expect(result.senderVerified, isTrue);
    });

    test('SBI UPI credit', () {
      final result = UpiParser.parse(
        'Dear UPI user A/C X8901 credited by Rs.1500 on 12Aug26 by '
        'Ramesh Kumar (Ref no 445566778899)',
        sender: 'AD-SBIUPI',
      );
      expect(result, isNotNull);
      expect(result!.amount, 1500);
      expect(result.direction, 'credit');
      expect(result.transactionType, 'income');
      expect(result.accountLast4, '8901');
      expect(result.bankName, 'SBI');
    });

    test('ICICI card spend', () {
      final result = UpiParser.parse(
        'INR 2,349.00 spent using ICICI Bank Card XX7788 on 12-Aug-26 at '
        'MYNTRA. Avl Lmt: INR 47,651.00',
        sender: 'JD-ICICIB',
      );
      expect(result, isNotNull);
      expect(result!.amount, 2349);
      expect(result.direction, 'debit');
      expect(result.merchant, 'MYNTRA');
      expect(result.suggestedCategory, 'Shopping');
    });

    test('ATM withdrawal', () {
      final result = UpiParser.parse(
        'Rs 3000 withdrawn from A/c XX1234 at ATM on 12-Aug-26 14:22. '
        'Avl Bal Rs 8,450.00',
        sender: 'VM-HDFCBK',
      );
      expect(result, isNotNull);
      expect(result!.amount, 3000);
      expect(result.instrument, 'atm');
      expect(result.date, DateTime(2026, 8, 12, 14, 22));
    });

    test('autopay mandate debit', () {
      final result = UpiParser.parse(
        'Rs.199.00 debited from A/c XX1234 on 12-Aug-26 towards Netflix '
        'autopay mandate. UPI Ref 990011223344',
        sender: 'VM-HDFCBK',
      );
      expect(result, isNotNull);
      expect(result!.amount, 199);
      expect(result.direction, 'debit');
    });
  });

  group('promotional messages', () {
    test('a cashback offer is not income', () {
      // Reported from a real BHIM notification: this booked ₹20 of income.
      expect(
        UpiParser.parse(
          'Your next 5 UPI Lite payments come with cashback of Rs 20',
          sender: 'BHIM',
        ),
        isNull,
      );
    });

    test('a settled cashback still parses', () {
      // The offer above must be rejected without also losing the real thing.
      final result = UpiParser.parse(
        'Cashback of Rs.20 credited to your A/c XX1234 on 20-Aug-26. '
        'Ref 556677889900',
        sender: 'VM-HDFCBK',
      );
      expect(result, isNotNull);
      expect(result!.amount, 20);
      expect(result.direction, 'credit');
    });

    test('conditional and capped offers are rejected', () {
      const offers = [
        'Get cashback up to Rs 100 on your next payment',
        'Flat 20% off up to Rs 150 on UPI payments this week',
        'You are eligible for a personal loan of Rs 500000',
        'Refer and earn Rs 100 for every friend who joins',
        'Hurry! Grab Rs 50 cashback before the offer ends',
        'Congratulations! You will receive Rs 250 on your next 3 orders',
        'Pay with UPI on every transaction and earn Rs 10 back. T&C apply',
        'Shop now on No Cost EMI starting Rs 999 per month',
      ];
      for (final text in offers) {
        expect(UpiParser.parse(text, sender: 'VM-HDFCBK'), isNull,
            reason: 'should be rejected: $text');
      }
    });

    test('real alerts are not caught by the promotional filter', () {
      const alerts = [
        'Rs.450.00 debited from A/c XX1234 on 20-Aug-26 to zomato@ybl. '
            'UPI Ref 112233445566',
        'Rs 25,000.00 credited to A/c XX9876 on 01-Aug-26 by SALARY. '
            'Ref 998877665544',
        'Rs.1,299 spent on ICICI Card XX4321 at DECATHLON on 19-Aug-26',
        'Rs 3000 withdrawn from A/c XX1234 at ATM on 12-Aug-26 14:22',
      ];
      for (final text in alerts) {
        expect(UpiParser.parse(text, sender: 'VM-HDFCBK'), isNotNull,
            reason: 'should still parse: $text');
      }
    });
  });
}
