import 'package:clock/clock.dart';

/// A UTC instant from a Unix timestamp in seconds.
DateTime utcFromUnixSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

/// Runs [body] with the global clock fixed at [instant].
///
/// Use this instead of calling `withClock` directly so every test that needs
/// deterministic time follows the same convention.
T withFixedTime<T>(DateTime instant, T Function() body) =>
    withClock(Clock.fixed(instant), body);

/// Async variant of [withFixedTime].
///
/// The clock override is zone-scoped, so it remains active across awaits
/// inside [body].
Future<T> withFixedTimeAsync<T>(
  DateTime instant,
  Future<T> Function() body,
) =>
    withClock(Clock.fixed(instant), body);
