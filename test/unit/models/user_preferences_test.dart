import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/user_preferences.dart';

/// Builds preferences whose defaults match [UserPreferences.fromMap] so each
/// case can override only the fields it exercises.
UserPreferences preferencesWith({
  bool showOtpAsDot = false,
  bool showNextOtp = false,
  bool revealDottedOtp = false,
  bool closeOtpOnCopy = false,
  bool copyOtpOnDisplay = false,
  bool clearSearchOnCopy = false,
  bool useBasicQrcodeReader = false,
  String displayMode = 'list',
  bool showAccountsIcons = true,
  String iconCollection = '',
  String iconVariant = 'regular',
  bool iconVariantStrictFetch = false,
  int kickUserAfter = 0,
  int activeGroup = 0,
  bool rememberActiveGroup = true,
  bool viewDefaultGroupOnCopy = false,
  int defaultGroup = 0,
  String defaultCaptureMode = 'livescan',
  bool useDirectCapture = true,
  bool useWebauthnOnly = false,
  bool getOfficialIcons = true,
  String theme = 'light',
  bool formatPassword = true,
  int formatPasswordBy = 3,
  String lang = 'browser',
  bool getOtpOnRequest = false,
  bool notifyOnNewAuthDevice = true,
  bool notifyOnFailedLogin = true,
  String timezone = 'UTC',
  bool sortCaseSensitive = false,
  int autoCloseTimeout = 0,
  bool autoSaveQrcodedAccount = false,
  bool showEmailInFooter = true,
}) {
  return UserPreferences(
    showOtpAsDot: showOtpAsDot,
    showNextOtp: showNextOtp,
    revealDottedOtp: revealDottedOtp,
    closeOtpOnCopy: closeOtpOnCopy,
    copyOtpOnDisplay: copyOtpOnDisplay,
    clearSearchOnCopy: clearSearchOnCopy,
    useBasicQrcodeReader: useBasicQrcodeReader,
    displayMode: displayMode,
    showAccountsIcons: showAccountsIcons,
    iconCollection: iconCollection,
    iconVariant: iconVariant,
    iconVariantStrictFetch: iconVariantStrictFetch,
    kickUserAfter: kickUserAfter,
    activeGroup: activeGroup,
    rememberActiveGroup: rememberActiveGroup,
    viewDefaultGroupOnCopy: viewDefaultGroupOnCopy,
    defaultGroup: defaultGroup,
    defaultCaptureMode: defaultCaptureMode,
    useDirectCapture: useDirectCapture,
    useWebauthnOnly: useWebauthnOnly,
    getOfficialIcons: getOfficialIcons,
    theme: theme,
    formatPassword: formatPassword,
    formatPasswordBy: formatPasswordBy,
    lang: lang,
    getOtpOnRequest: getOtpOnRequest,
    notifyOnNewAuthDevice: notifyOnNewAuthDevice,
    notifyOnFailedLogin: notifyOnFailedLogin,
    timezone: timezone,
    sortCaseSensitive: sortCaseSensitive,
    autoCloseTimeout: autoCloseTimeout,
    autoSaveQrcodedAccount: autoSaveQrcodedAccount,
    showEmailInFooter: showEmailInFooter,
  );
}

void main() {
  group('UserPreferences', () {
    test('round-trips all 33 fields', () {
      final preferences = preferencesWith(
        showOtpAsDot: true,
        showNextOtp: true,
        revealDottedOtp: true,
        closeOtpOnCopy: true,
        copyOtpOnDisplay: true,
        clearSearchOnCopy: true,
        useBasicQrcodeReader: true,
        displayMode: 'grid',
        showAccountsIcons: false,
        iconCollection: 'custom',
        iconVariant: 'solid',
        iconVariantStrictFetch: true,
        kickUserAfter: 15,
        activeGroup: 7,
        rememberActiveGroup: false,
        viewDefaultGroupOnCopy: true,
        defaultGroup: 3,
        defaultCaptureMode: 'upload',
        useDirectCapture: false,
        useWebauthnOnly: true,
        getOfficialIcons: false,
        theme: 'dark',
        formatPassword: false,
        formatPasswordBy: 5,
        lang: 'es',
        getOtpOnRequest: true,
        notifyOnNewAuthDevice: false,
        notifyOnFailedLogin: false,
        timezone: 'Europe/Madrid',
        sortCaseSensitive: true,
        autoCloseTimeout: 30,
        autoSaveQrcodedAccount: true,
        showEmailInFooter: false,
      );

      final restored = UserPreferences.fromMap(preferences.toMap());

      expect(restored.toMap(), preferences.toMap());
    });

    test('applies the documented defaults for an empty payload', () {
      final restored = UserPreferences.fromMap({});

      expect(restored.toMap(), preferencesWith().toMap());
    });

    test('coerces booleans, numbers and strings from legacy payloads', () {
      final restored = UserPreferences.fromMap({
        'showOtpAsDot': 'true',
        'showNextOtp': 'TRUE',
        'revealDottedOTP': 'True',
        'clearSearchOnCopy': 1,
        'kickUserAfter': '15',
        'activeGroup': '7',
        'formatPasswordBy': '5',
        'autoCloseTimeout': '30',
        'displayMode': 42,
        'iconCollection': null,
        'theme': null,
        'timezone': 'Europe/Madrid',
      });

      expect(restored.showOtpAsDot, isTrue);
      expect(restored.showNextOtp, isTrue);
      expect(restored.revealDottedOtp, isTrue);
      expect(restored.clearSearchOnCopy, isFalse);
      expect(restored.kickUserAfter, 15);
      expect(restored.activeGroup, 7);
      expect(restored.formatPasswordBy, 5);
      expect(restored.autoCloseTimeout, 30);
      expect(restored.displayMode, '42');
      expect(restored.iconCollection, '');
      expect(restored.theme, 'light');
      expect(restored.timezone, 'Europe/Madrid');
    });

    test('keeps the capitalized and mixed-case persisted keys', () {
      final preferences = preferencesWith(
        revealDottedOtp: true,
        autoSaveQrcodedAccount: true,
      );

      expect(preferences.toMap()['revealDottedOTP'], isTrue);
      expect(preferences.toMap()['AutoSaveQrcodedAccount'], isTrue);

      expect(
        UserPreferences.fromMap({'revealDottedOTP': true}).revealDottedOtp,
        isTrue,
      );
      expect(
        UserPreferences.fromMap({'AutoSaveQrcodedAccount': true})
            .autoSaveQrcodedAccount,
        isTrue,
      );
    });

    test('ignores differently capitalized variants of the legacy keys', () {
      final restored = UserPreferences.fromMap({
        'revealDottedOtp': true,
        'autoSaveQrcodedAccount': true,
      });

      expect(restored.revealDottedOtp, isFalse);
      expect(restored.autoSaveQrcodedAccount, isFalse);
    });
  });
}
