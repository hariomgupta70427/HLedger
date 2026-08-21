import 'package:flutter_test/flutter_test.dart';
import 'package:hledger/models/transaction.dart';
import 'package:hledger/services/transaction_classifier.dart';
import 'package:hledger/services/upi_parser.dart';

UpiParseResult _parse(String sms, {String? sender}) {
  final result = UpiParser.parse(sms, sender: sender);
  expect(result, isNotNull, reason: 'fixture should parse: $sms');
  return result!;
}

void main() {
  group('category scoping', () {
    test('a balance line is not filed as a Bills expense', () {
      // 'rent' sits inside "Current balance". Matching against the whole
      // message body used to turn every balance line into a Bills entry.
      final parsed = _parse(
        'Rs.200 debited from A/c XX1234 on 20-08-26. Current balance Rs.900.',
        sender: 'VM-HDFCBK',
      );

      expect(TransactionClassifier.classify(parsed).category, 'Other');
    });

    test('a counterparty keyword is honoured', () {
      final parsed = _parse(
        'Rs.450 debited from A/c XX1234 on 20-08-26. '
        'Avl bal Rs.5000. Info: SWIGGY',
        sender: 'VM-HDFCBK',
      );

      final result = TransactionClassifier.classify(parsed);
      expect(result.category, 'Food');
      expect(TransactionClassifier.isHighConfidence(result.confidence), isTrue);
    });

    test('a short keyword does not match inside an unrelated word', () {
      // 'ola' would substring-match 'Chocolate Room'.
      final parsed = _parse(
        'Rs.300 debited from A/c XX1234 at Chocolate Room on 20-08-26.',
        sender: 'VM-HDFCBK',
      );

      expect(TransactionClassifier.classify(parsed).category,
          isNot('Transport'));
    });

    test('unlabelled income is treated as a transfer in', () {
      final parsed = _parse(
        'Rs.25000 credited to A/c XX1234 on 20-08-26.',
        sender: 'VM-HDFCBK',
      );

      final result = TransactionClassifier.classify(parsed);
      expect(result.category, 'Work');
      expect(TransactionClassifier.isHighConfidence(result.confidence), isFalse);
    });
  });

  group('sender trust', () {
    const swiggySms = 'Rs.450 debited from A/c XX1234 on 20-08-26. '
        'Avl bal Rs.5000. Info: SWIGGY. HDFC Bank';

    test('a recognised sender keeps the entry one tap from the ledger', () {
      final result = TransactionClassifier.classify(
        _parse(swiggySms, sender: 'VM-HDFCBK'),
      );

      expect(TransactionClassifier.isHighConfidence(result.confidence), isTrue);
    });

    test('an unvouched-for origin is held back for review', () {
      final verified = TransactionClassifier.classify(
        _parse(swiggySms, sender: 'VM-HDFCBK'),
      );
      final unverified = TransactionClassifier.classify(_parse(swiggySms));

      expect(unverified.category, verified.category);
      expect(unverified.confidence, lessThan(verified.confidence));
      expect(
        TransactionClassifier.isHighConfidence(unverified.confidence),
        isFalse,
      );
    });
  });

  group('toPendingTransaction', () {
    test('carries the dedupe key so a second sighting is recognised', () {
      final parsed = _parse(
        'Rs.450 debited from A/c XX1234 on 20-08-26. '
        'UPI Ref 123456789012. Info: SWIGGY',
        sender: 'VM-HDFCBK',
      );

      final pending =
          TransactionClassifier.toPendingTransaction(parsed, userId: 'u1');

      expect(parsed.dedupeKey, 'ref:123456789012');
      expect(pending.detectionKey, parsed.dedupeKey);
    });

    test('two same-value debits on one day stay distinct', () {
      final first = _parse(
        'Rs.200 debited from A/c XX1234 on 20-08-26 at 10:15 AM. Info: BLINKIT',
        sender: 'VM-HDFCBK',
      );
      final second = _parse(
        'Rs.200 debited from A/c XX1234 on 20-08-26 at 6:40 PM. Info: ZEPTO',
        sender: 'VM-HDFCBK',
      );

      expect(
        TransactionClassifier.toPendingTransaction(first, userId: 'u1')
            .detectionKey,
        isNot(TransactionClassifier.toPendingTransaction(second, userId: 'u1')
            .detectionKey),
      );
    });

    test('labels the entry with the most specific counterparty', () {
      final parsed = _parse(
        'Rs.450 debited from A/c XX1234 on 20-08-26. Info: SWIGGY',
        sender: 'VM-HDFCBK',
      );

      final pending =
          TransactionClassifier.toPendingTransaction(parsed, userId: 'u1');

      expect(pending.description, parsed.displayLabel);
      expect(pending.person, parsed.displayLabel);
      expect(pending.displayLabel, 'SWIGGY');
    });

    test('arrives pending, auto-detected, and typed by direction', () {
      final debit = TransactionClassifier.toPendingTransaction(
        _parse('Rs.450 debited from A/c XX1234 on 20-08-26.',
            sender: 'VM-HDFCBK'),
        userId: 'u1',
      );
      final credit = TransactionClassifier.toPendingTransaction(
        _parse('Rs.450 credited to A/c XX1234 on 20-08-26.',
            sender: 'VM-HDFCBK'),
        userId: 'u1',
      );

      expect(debit.status, TransactionStatus.pending);
      expect(debit.source, TransactionSource.autoDetected);
      expect(debit.userId, 'u1');
      expect(debit.type, 'expense');
      expect(credit.type, 'income');
    });
  });

  group('round-tripping the review queue', () {
    test('the dedupe key survives being stored on device', () {
      final pending = TransactionClassifier.toPendingTransaction(
        _parse(
          'Rs.450 debited from A/c XX1234 on 20-08-26. UPI Ref 123456789012.',
          sender: 'VM-HDFCBK',
        ),
        userId: 'u1',
      );

      final restored = Transaction.fromJson(pending.toLocalJson());

      expect(restored.detectionKey, pending.detectionKey);
      expect(restored.status, TransactionStatus.pending);
      expect(restored.source, TransactionSource.autoDetected);
    });

    test('a confirmed entry keeps the key it was detected with', () {
      final pending = TransactionClassifier.toPendingTransaction(
        _parse(
          'Rs.450 debited from A/c XX1234 on 20-08-26. UPI Ref 123456789012.',
          sender: 'VM-HDFCBK',
        ),
        userId: 'u1',
      );

      final confirmed = pending.copyWith(status: TransactionStatus.confirmed);

      expect(confirmed.detectionKey, pending.detectionKey);
      expect(confirmed.toFirestore()['detection_key'], pending.detectionKey);
    });

    test('a manual entry stores no detection key', () {
      final manual = Transaction(
        id: 'x',
        userId: 'u1',
        amount: 120,
        type: 'expense',
        category: 'Food',
        timestamp: DateTime(2026, 8, 20),
      );

      expect(manual.detectionKey, isNull);
      expect(manual.toFirestore().containsKey('detection_key'), isFalse);
    });
  });
}
