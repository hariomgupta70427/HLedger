import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_capture.dart';
import 'notification_service.dart';
import 'upi_parser.dart';

/// SharedPreferences key under which the background isolate stashes SMS it
/// captured while the app was closed, for the foreground isolate to reconcile
/// into the review queue on next open.
const String _kPendingRawKey = 'hledger_pending_sms_raw';

/// SharedPreferences key remembering that the user opted in to auto-detect and
/// granted SMS access. Lets [SmsTransactionService.initialize] resume listening
/// on startup WITHOUT prompting.
const String _kEnabledKey = 'hledger_sms_autodetect_enabled';

/// As [_kEnabledKey], for the payment-app notification source.
const String _kNotificationEnabledKey = 'hledger_notif_autodetect_enabled';

/// Upper bound on stashed captures, in case the app stays closed for weeks.
const int _kMaxStashed = 50;

/// One captured SMS, as stashed by the background isolate.
///
/// The originating address travels with the body because the parser needs it:
/// it is what rejects person-to-person messages and what identifies the bank,
/// and by the time the foreground isolate drains the stash the message itself
/// is long gone.
class _Capture {
  const _Capture(this.body, this.sender);

  final String body;
  final String? sender;

  String encode() => json.encode(<String, String?>{'b': body, 's': sender});

  /// Entries written before captures carried a sender are bare message bodies,
  /// so a decode failure is an older stash rather than corruption.
  static _Capture decode(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return _Capture(decoded['b'] as String? ?? '', decoded['s'] as String?);
      }
    } on FormatException {
      // Legacy plain-body entry.
    }
    return _Capture(raw, null);
  }
}

/// Top-level background SMS handler.
///
/// Runs in a SEPARATE isolate spawned by the OS when an SMS arrives while the
/// app is backgrounded or killed. It has no access to app state, the provider,
/// or Firestore — so it does the two things it safely can:
///   1. Fire a heads-up local notification ("transaction detected").
///   2. Stash the message so the foreground isolate can enqueue it (with the
///      real user id) the next time the app opens.
///
/// Must be a top-level function annotated with `@pragma('vm:entry-point')` so
/// the AOT compiler keeps it and the background isolate can find it.
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  final body = message.body ?? '';
  final sender = message.address;
  final parsed = UpiParser.parse(body, sender: sender);
  if (parsed == null) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_kPendingRawKey) ?? <String>[];
    pending.add(_Capture(body, sender).encode());
    if (pending.length > _kMaxStashed) {
      pending.removeRange(0, pending.length - _kMaxStashed);
    }
    await prefs.setStringList(_kPendingRawKey, pending);
  } catch (e) {
    debugPrint('❌ SMS background stash failed: $e');
  }

  // flutter_local_notifications supports being driven from a background
  // isolate; NotificationService re-initializes itself here (fresh isolate
  // memory) before showing.
  try {
    await NotificationService().showTransactionDetected(parsed);
  } catch (e) {
    debugPrint('❌ SMS background notify failed: $e');
  }
}

/// Auto-detection of bank and UPI transactions, from two independent sources.
///
/// **Bank SMS** — every bank still texts. The OS spawns an isolate for it, so it
/// survives the app being killed.
///
/// **Payment-app notifications** — a UPI payment made inside GPay or PhonePe
/// often produces no SMS at all, so without this source those transactions are
/// invisible. Capture lives in native code ([NotificationCapture]) and writes to
/// disk, so this source also survives the app being killed; Dart only reads the
/// queue.
///
/// Both feed one [onTransactionDetected] stream, deduplicated on the bank's own
/// reference number, so a payment announced twice is reported once. Each source
/// is a separate, deliberate opt-in; neither is ever requested at startup.
class SmsTransactionService {
  SmsTransactionService._();

  static final SmsTransactionService _instance = SmsTransactionService._();
  static SmsTransactionService get instance => _instance;

  final Telephony _telephony = Telephony.instance;

  /// Real-time stream of parsed incoming transactions. [AppProvider] subscribes
  /// to this; captures that must not be lost are handed over through the drain
  /// handlers instead, because a stream cannot report whether anyone stored the
  /// event.
  final _controller = StreamController<UpiParseResult>.broadcast();
  Stream<UpiParseResult> get onTransactionDetected => _controller.stream;

  /// Dedupe keys already handed downstream this session, oldest first.
  final LinkedHashSet<String> _delivered = LinkedHashSet<String>();
  static const int _deliveredCap = 240;

  StreamSubscription<void>? _captureSub;

  /// Where accepted detections go. Held so the live notification path and the
  /// two drains all file through exactly the same handler.
  Future<bool> Function(UpiParseResult)? _enqueue;

  bool _initialized = false;
  bool _hasSmsPermission = false;
  bool _hasNotificationAccess = false;
  bool _smsListening = false;
  bool _draining = false;
  bool _drainingCaptures = false;

  /// Whether SMS access has been granted.
  bool get hasPermission => _hasSmsPermission;

  /// Whether notification access has been granted and the listener is running.
  bool get hasNotificationAccess => _hasNotificationAccess;

  /// Whether either detection source is live.
  bool get isDetecting => _hasSmsPermission || _hasNotificationAccess;

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Startup init. NEVER prompts.
  ///
  /// Resumes whichever sources the user previously opted into and still has
  /// permission for. Returns whether the SMS source is listening.
  Future<bool> initialize() async {
    if (_initialized) return _hasSmsPermission;
    _initialized = true;

    await _resumeSms();
    await _resumeNotifications();

    debugPrint('📱 Auto-detect initialized. '
        'SMS: $_hasSmsPermission, notifications: $_hasNotificationAccess');
    return _hasSmsPermission;
  }

  // ── SMS source ──

  Future<void> _resumeSms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final optedIn = prefs.getBool(_kEnabledKey) ?? false;

      // Silent status check — does NOT show a system dialog.
      final granted = await Permission.sms.status;
      _hasSmsPermission = optedIn && granted.isGranted;

      if (_hasSmsPermission) {
        _startSmsListening();
      } else if (optedIn && !granted.isGranted) {
        // Opted in before but revoked SMS access in system settings. Clear the
        // flag so the UI reflects the off state.
        await prefs.setBool(_kEnabledKey, false);
      }
    } catch (e) {
      debugPrint('❌ SMS resume failed: $e');
      _hasSmsPermission = false;
    }
  }

  /// Deliberate opt-in: show the one-tap system SMS permission dialog.
  ///
  /// Callers must show the prominent disclosure first — see
  /// `ProminentDisclosure.show`. Returns whether access was granted.
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.sms.request();
      _hasSmsPermission = status.isGranted;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, _hasSmsPermission);

      if (_hasSmsPermission) _startSmsListening();

      debugPrint('📱 SMS permission result: $_hasSmsPermission');
      return _hasSmsPermission;
    } catch (e) {
      debugPrint('❌ SMS permission request failed: $e');
      return false;
    }
  }

  void _startSmsListening() {
    if (_smsListening) return;
    _smsListening = true;
    try {
      _telephony.listenIncomingSms(
        onNewMessage: _onForegroundSms,
        onBackgroundMessage: smsBackgroundHandler,
        listenInBackground: true,
      );
      debugPrint('🔔 SMS listener started');
    } catch (e) {
      _smsListening = false;
      debugPrint('❌ SMS listen failed: $e');
    }
  }

  /// Foreground handler: parse with the originating address, then emit.
  ///
  /// The address is not optional detail. Without it the parser cannot tell a
  /// bank header from a personal number, so private conversations would be
  /// scanned for figures, and the bank behind the message would be unknown.
  void _onForegroundSms(SmsMessage message) {
    final parsed = UpiParser.parse(message.body ?? '', sender: message.address);
    if (parsed == null) return;
    _emit(parsed, 'SMS');
  }

  // ── Payment-app notification source ──

  Future<void> _resumeNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final optedIn = prefs.getBool(_kNotificationEnabledKey) ?? false;
      if (!optedIn) return;

      final granted = await NotificationCapture.isPermissionGranted();
      _hasNotificationAccess = granted;
      if (!granted) {
        await prefs.setBool(_kNotificationEnabledKey, false);
      }
    } catch (e) {
      debugPrint('❌ Notification access resume failed: $e');
      _hasNotificationAccess = false;
    }
  }

  /// Whether notification access is currently granted, without prompting.
  Future<bool> checkNotificationAccess() async {
    _hasNotificationAccess = await NotificationCapture.isPermissionGranted();
    return _hasNotificationAccess;
  }

  /// Deliberate opt-in for the notification source.
  ///
  /// Android grants this only on a settings screen, so there is nothing to await
  /// — the caller re-checks when the user comes back. Returns the state as known
  /// right now, which will normally still be false.
  Future<bool> requestNotificationAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Record the intent before leaving, so a grant is honoured on return even
      // if this process is recycled while the settings screen is open.
      await prefs.setBool(_kNotificationEnabledKey, true);

      await NotificationCapture.openPermissionSettings();
      return checkNotificationAccess();
    } catch (e) {
      debugPrint('❌ Notification access request failed: $e');
      return false;
    }
  }

  /// Sources the native layer passed over, and why. Diagnostics only.
  Future<Map<String, String>> skippedSources() =>
      NotificationCapture.skippedSources();

  // ── Fan-in ──

  /// Publish a detection unless this transaction has already been reported.
  void _emit(UpiParseResult parsed, String origin) {
    final key = parsed.dedupeKey;
    if (_delivered.contains(key)) {
      debugPrint('↩︎ Duplicate detection ignored from $origin: $key');
      return;
    }
    _remember(key);

    debugPrint('🔔 Detected via $origin: $parsed');
    _controller.add(parsed);
    NotificationService().showTransactionDetected(parsed);
  }

  void _remember(String key) {
    _delivered.add(key);
    while (_delivered.length > _deliveredCap) {
      _delivered.remove(_delivered.first);
    }
  }

  /// Hand every SMS the background isolate captured to [enqueue], keeping the
  /// ones it could not take.
  ///
  /// The stash is the only record of a transaction detected while the app was
  /// closed. Clearing it before the caller has actually stored the capture — as
  /// this used to — loses the transaction outright whenever the enqueue is
  /// refused, and it is refused for every capture that arrives before sign-in
  /// completes. Those are held and picked up on the next drain.
  ///
  /// No notification is shown here: the background isolate already alerted the
  /// user when it made the capture.
  Future<void> drainPendingCaptures(
    Future<bool> Function(UpiParseResult parsed) enqueue,
  ) async {
    // Called both on startup and again when a user binds, so two drains can
    // overlap; without this they would read the same stash and enqueue it twice.
    if (_draining) return;
    _draining = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stashed = prefs.getStringList(_kPendingRawKey) ?? <String>[];
      if (stashed.isEmpty) return;

      final held = <String>[];
      var drained = 0;

      for (final raw in stashed) {
        final capture = _Capture.decode(raw);
        final parsed = UpiParser.parse(capture.body, sender: capture.sender);
        // The parser is deterministic, so an entry it refuses now will be
        // refused on every future drain — holding it would leak forever.
        if (parsed == null) continue;

        // Already delivered live this session, so it is accounted for.
        if (_delivered.contains(parsed.dedupeKey)) continue;

        if (await _tryEnqueue(parsed, enqueue)) {
          _remember(parsed.dedupeKey);
          drained++;
        } else {
          held.add(raw);
        }
      }

      if (held.isEmpty) {
        await prefs.remove(_kPendingRawKey);
      } else {
        await prefs.setStringList(_kPendingRawKey, held);
      }
      debugPrint('📥 Drained $drained capture(s); ${held.length} held back');
    } catch (e) {
      debugPrint('❌ SMS drain failed: $e');
    } finally {
      _draining = false;
    }
  }

  /// Start routing detections to [enqueue] and flush everything already
  /// captured by either source.
  ///
  /// Safe to call again — on sign-in, for instance — which is what lets a capture
  /// that arrived before there was a user finally be filed.
  Future<void> startCapture(
    Future<bool> Function(UpiParseResult parsed) enqueue,
  ) async {
    _enqueue = enqueue;

    _captureSub ??= NotificationCapture.onCaptured.listen(
      (_) => drainNotificationCaptures(),
      onError: (Object e) => debugPrint('❌ Capture signal error: $e'),
    );

    await drainPendingCaptures(enqueue);
    await drainNotificationCaptures();
  }

  /// Read the native notification queue, file what parses, and acknowledge only
  /// what was actually stored.
  ///
  /// This is the single path for notification captures, whether the alert
  /// arrived seconds ago with the UI open or last week with the app killed. The
  /// native service writes to disk either way, so there is no second code path
  /// that could behave differently.
  Future<void> drainNotificationCaptures() async {
    final enqueue = _enqueue;
    if (enqueue == null) return;
    if (_drainingCaptures) return;
    _drainingCaptures = true;

    try {
      final captured = await NotificationCapture.drain();
      if (captured.isEmpty) return;

      final settled = <String>[];
      var filed = 0;

      for (final alert in captured) {
        final parsed = UpiParser.parse(alert.text);
        if (parsed == null) {
          // Nothing to book. The parser is deterministic, so it will refuse this
          // again — dropping it is what stops the queue filling with noise.
          settled.add(alert.key);
          continue;
        }

        // A notification rarely states a date, and the post time is exact. It
        // also lets the synthetic dedupe key line up with the bank's own SMS for
        // the same payment, which collapses the pair into one entry.
        final dated =
            parsed.date == null ? parsed.copyWith(date: alert.postedAt) : parsed;
        // The posting package is the vouched-for origin here — there is no SMS
        // header — and it was allowlisted natively before capture.
        final result = dated.copyWith(senderVerified: true);

        if (_delivered.contains(result.dedupeKey)) {
          settled.add(alert.key);
          continue;
        }

        if (await _tryEnqueue(result, enqueue)) {
          _remember(result.dedupeKey);
          settled.add(alert.key);
          filed++;
          NotificationService().showTransactionDetected(result);
        }
      }

      await NotificationCapture.acknowledge(settled);
      debugPrint('📥 Notification queue: ${captured.length} read, $filed filed, '
          '${captured.length - settled.length} held');
    } catch (e) {
      debugPrint('❌ Notification drain failed: $e');
    } finally {
      _drainingCaptures = false;
    }
  }

  Future<bool> _tryEnqueue(
    UpiParseResult parsed,
    Future<bool> Function(UpiParseResult) enqueue,
  ) async {
    try {
      return await enqueue(parsed);
    } catch (e) {
      debugPrint('❌ Capture enqueue failed: $e');
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    _captureSub?.cancel();
    _captureSub = null;
    _controller.close();
  }
}
