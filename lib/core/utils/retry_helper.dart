/// Generic retry utility for wrapping async calls with automatic retry on failure.
class RetryHelper {
  /// Runs [fn], retrying up to [maxAttempts] times with [delay] between attempts.
  /// On the last attempt, the error is rethrown.
  static Future<T> run<T>(
    Future<T> Function() fn, {
    int maxAttempts = 2,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        return await fn();
      } catch (e) {
        if (i == maxAttempts - 1) rethrow;
        await Future.delayed(delay);
      }
    }
    // This should never be reached, but Dart requires a return.
    throw Exception('Max retries reached');
  }
}
