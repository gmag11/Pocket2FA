import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket2fa/services/settings_storage.dart';

/// A [Box] backed by a plain map, so unit tests never initialise Hive.
class FakeHiveBox extends Mock implements Box<dynamic> {}

/// A [SettingsStorage] that answers from memory instead of the platform.
///
/// It overrides only the members unit tests read: the box accessor, the lock
/// state, PIN metadata, and biometric support. Everything else keeps the real
/// implementation and would reach a plugin, so tests must not call it.
class FakeSettingsStorage extends SettingsStorage {
  FakeSettingsStorage({
    Map<dynamic, dynamic>? initialValues,
    this.unlocked = true,
    bool pinEnabled = false,
    int? pinDigits,
    this.biometricsSupported = false,
  })  : _values = {...?initialValues},
        _hasPin = pinEnabled,
        _pinLength = pinDigits {
    when(() => _box.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) {
      final key = invocation.positionalArguments.first;
      return _values.containsKey(key)
          ? _values[key]
          : invocation.namedArguments[#defaultValue];
    });
    when(() => _box.put(any(), any())).thenAnswer((invocation) async {
      _values[invocation.positionalArguments[0]] =
          invocation.positionalArguments[1];
    });
    when(() => _box.delete(any())).thenAnswer((invocation) async {
      _values.remove(invocation.positionalArguments.first);
    });
    when(() => _box.containsKey(any())).thenAnswer(
      (invocation) =>
          _values.containsKey(invocation.positionalArguments.first),
    );
  }

  final FakeHiveBox _box = FakeHiveBox();
  final Map<dynamic, dynamic> _values;

  final bool unlocked;
  final bool _hasPin;
  final int? _pinLength;
  final bool biometricsSupported;

  Map<dynamic, dynamic> get values => Map.unmodifiable(_values);

  @override
  Box<dynamic> get box {
    if (!unlocked) {
      throw StateError(
        'Local storage is locked; call attemptUnlock() to authenticate before accessing the box.',
      );
    }
    return _box;
  }

  @override
  bool get isUnlocked => unlocked;

  @override
  Future<bool> hasPin() async => _hasPin;

  @override
  int? get pinLength => _pinLength;

  @override
  Future<bool> supportsBiometrics() async => biometricsSupported;
}
