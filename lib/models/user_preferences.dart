class UserPreferences {
  final bool showOtpAsDot;
  final bool showNextOtp;
  final bool revealDottedOtp;
  final bool closeOtpOnCopy;
  final bool copyOtpOnDisplay;
  final bool clearSearchOnCopy;
  final bool useBasicQrcodeReader;
  final String displayMode;
  final bool showAccountsIcons;
  final String iconCollection;
  final String iconVariant;
  final bool iconVariantStrictFetch;
  final int kickUserAfter;
  final int activeGroup;
  final bool rememberActiveGroup;
  final bool viewDefaultGroupOnCopy;
  final int defaultGroup;
  final String defaultCaptureMode;
  final bool useDirectCapture;
  final bool useWebauthnOnly;
  final bool getOfficialIcons;
  final String theme;
  final bool formatPassword;
  final int formatPasswordBy;
  final String lang;
  final bool getOtpOnRequest;
  final bool notifyOnNewAuthDevice;
  final bool notifyOnFailedLogin;
  final String timezone;
  final bool sortCaseSensitive;
  final int autoCloseTimeout;
  final bool autoSaveQrcodedAccount;
  final bool showEmailInFooter;

  UserPreferences({
    required this.showOtpAsDot,
    required this.showNextOtp,
    required this.revealDottedOtp,
    required this.closeOtpOnCopy,
    required this.copyOtpOnDisplay,
    required this.clearSearchOnCopy,
    required this.useBasicQrcodeReader,
    required this.displayMode,
    required this.showAccountsIcons,
    required this.iconCollection,
    required this.iconVariant,
    required this.iconVariantStrictFetch,
    required this.kickUserAfter,
    required this.activeGroup,
    required this.rememberActiveGroup,
    required this.viewDefaultGroupOnCopy,
    required this.defaultGroup,
    required this.defaultCaptureMode,
    required this.useDirectCapture,
    required this.useWebauthnOnly,
    required this.getOfficialIcons,
    required this.theme,
    required this.formatPassword,
    required this.formatPasswordBy,
    required this.lang,
    required this.getOtpOnRequest,
    required this.notifyOnNewAuthDevice,
    required this.notifyOnFailedLogin,
    required this.timezone,
    required this.sortCaseSensitive,
    required this.autoCloseTimeout,
    required this.autoSaveQrcodedAccount,
    required this.showEmailInFooter,
  });

  Map<String, dynamic> toMap() => {
        'showOtpAsDot': showOtpAsDot,
        'showNextOtp': showNextOtp,
        'revealDottedOTP': revealDottedOtp,
        'closeOtpOnCopy': closeOtpOnCopy,
        'copyOtpOnDisplay': copyOtpOnDisplay,
        'clearSearchOnCopy': clearSearchOnCopy,
        'useBasicQrcodeReader': useBasicQrcodeReader,
        'displayMode': displayMode,
        'showAccountsIcons': showAccountsIcons,
        'iconCollection': iconCollection,
        'iconVariant': iconVariant,
        'iconVariantStrictFetch': iconVariantStrictFetch,
        'kickUserAfter': kickUserAfter,
        'activeGroup': activeGroup,
        'rememberActiveGroup': rememberActiveGroup,
        'viewDefaultGroupOnCopy': viewDefaultGroupOnCopy,
        'defaultGroup': defaultGroup,
        'defaultCaptureMode': defaultCaptureMode,
        'useDirectCapture': useDirectCapture,
        'useWebauthnOnly': useWebauthnOnly,
        'getOfficialIcons': getOfficialIcons,
        'theme': theme,
        'formatPassword': formatPassword,
        'formatPasswordBy': formatPasswordBy,
        'lang': lang,
        'getOtpOnRequest': getOtpOnRequest,
        'notifyOnNewAuthDevice': notifyOnNewAuthDevice,
        'notifyOnFailedLogin': notifyOnFailedLogin,
        'timezone': timezone,
        'sortCaseSensitive': sortCaseSensitive,
        'autoCloseTimeout': autoCloseTimeout,
        'AutoSaveQrcodedAccount': autoSaveQrcodedAccount,
        'showEmailInFooter': showEmailInFooter,
      };

  factory UserPreferences.fromMap(Map<dynamic, dynamic> m) {
    bool b(dynamic v, [bool def = false]) => v is bool
        ? v
        : (v == null ? def : (v.toString().toLowerCase() == 'true'));
    int i(dynamic v, [int def = 0]) =>
        v is int ? v : (v == null ? def : int.tryParse(v.toString()) ?? def);
    String s(dynamic v, [String def = '']) =>
        v is String ? v : (v == null ? def : v.toString());

    return UserPreferences(
      showOtpAsDot: b(m['showOtpAsDot']),
      showNextOtp: b(m['showNextOtp']),
      revealDottedOtp: b(m['revealDottedOTP']),
      closeOtpOnCopy: b(m['closeOtpOnCopy']),
      copyOtpOnDisplay: b(m['copyOtpOnDisplay']),
      clearSearchOnCopy: b(m['clearSearchOnCopy']),
      useBasicQrcodeReader: b(m['useBasicQrcodeReader']),
      displayMode: s(m['displayMode'], 'list'),
      showAccountsIcons: b(m['showAccountsIcons'], true),
      iconCollection: s(m['iconCollection'], ''),
      iconVariant: s(m['iconVariant'], 'regular'),
      iconVariantStrictFetch: b(m['iconVariantStrictFetch']),
      kickUserAfter: i(m['kickUserAfter']),
      activeGroup: i(m['activeGroup']),
      rememberActiveGroup: b(m['rememberActiveGroup'], true),
      viewDefaultGroupOnCopy: b(m['viewDefaultGroupOnCopy']),
      defaultGroup: i(m['defaultGroup']),
      defaultCaptureMode: s(m['defaultCaptureMode'], 'livescan'),
      useDirectCapture: b(m['useDirectCapture'], true),
      useWebauthnOnly: b(m['useWebauthnOnly']),
      getOfficialIcons: b(m['getOfficialIcons'], true),
      theme: s(m['theme'], 'light'),
      formatPassword: b(m['formatPassword'], true),
      formatPasswordBy: i(m['formatPasswordBy'], 3),
      lang: s(m['lang'], 'browser'),
      getOtpOnRequest: b(m['getOtpOnRequest']),
      notifyOnNewAuthDevice: b(m['notifyOnNewAuthDevice'], true),
      notifyOnFailedLogin: b(m['notifyOnFailedLogin'], true),
      timezone: s(m['timezone'], 'UTC'),
      sortCaseSensitive: b(m['sortCaseSensitive']),
      autoCloseTimeout: i(m['autoCloseTimeout'], 0),
      autoSaveQrcodedAccount: b(m['AutoSaveQrcodedAccount']),
      showEmailInFooter: b(m['showEmailInFooter'], true),
    );
  }
}
