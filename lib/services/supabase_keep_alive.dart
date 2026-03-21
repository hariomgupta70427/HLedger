import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseKeepAlive {
  static Timer? _timer;

  /// Start pinging Supabase every 4 minutes to prevent free-tier pause.
  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 4),
      (_) async {
        try {
          await Supabase.instance.client
              .from('transactions')
              .select('id')
              .limit(1);
        } catch (_) {
          // Silently ignore — just keeping connection alive
        }
      },
    );
  }

  static void stop() => _timer?.cancel();
}
