// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pocket2FA';

  @override
  String get homeTitle => 'Home';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'GENERAL';

  @override
  String get settingsSecurity => 'SECURITY';

  @override
  String get settingsSynchronization => 'SYNCHRONIZATION';

  @override
  String get addAccount => 'Add account';

  @override
  String get add => 'Add';

  @override
  String get serviceLabel => 'Service';

  @override
  String get serviceHint => 'Google, Twitter, Apple';

  @override
  String get accountLabel => 'Account';

  @override
  String get accountHint => 'John Doe';

  @override
  String get seedLabel => 'Seed';

  @override
  String get serverLabel => 'Server';

  @override
  String errorParsingQr(Object error) {
    return 'Error parsing QR: $error';
  }

  @override
  String get noQrInImage => 'No QR code found in image';

  @override
  String errorScanningImage(Object error) {
    return 'Error scanning image: $error';
  }

  @override
  String get selectQrImageTitle => 'Select QR Image';

  @override
  String get selectImageFromGallery =>
      'Select an image from gallery containing a QR code';

  @override
  String get selectImageButton => 'Select Image';

  @override
  String get scanningFromImage => 'Scanning QR from image...';

  @override
  String get back => 'Back';

  @override
  String get createNewCodeTitle => 'Create new code';

  @override
  String get chooseHowToCreate => 'Choose how to create a new code:';

  @override
  String get alternateMethods => 'Alternate methods';

  @override
  String get useAdvancedForm => 'Use the advanced form';

  @override
  String get urlRequired => 'URL required';

  @override
  String get apiKeyLabel => 'API key';

  @override
  String get nameLabel => 'Name';

  @override
  String get urlLabel => 'URL';

  @override
  String get save => 'Save';

  @override
  String get requires2fauth =>
      'Pocket2FA requires access to a 2FAuth server (self-hosted or remote) to sync accounts. See the 2FAuth project link below for setup and hosting options.';

  @override
  String get totpLabel => 'TOTP';

  @override
  String get hotpLabel => 'HOTP';

  @override
  String get steamLabel => 'STEAM';

  @override
  String get groupLabel => 'Group';

  @override
  String get noGroupOption => '- No group -';

  @override
  String get groupHint => 'The group to which the account is to be assigned';

  @override
  String get chooseOtpType => 'Choose the type of OTP to create';

  @override
  String get otpTypeHint => 'Time-based OTP or HMAC-based OTP or Steam OTP';

  @override
  String get secretLabel => 'Secret';

  @override
  String get secretLockedHint => 'Secret is locked - tap the lock to edit';

  @override
  String get secretRequired => 'Secret is required';

  @override
  String get secretBase32Error =>
      'Secret must be Base32 (uppercase letters A-Z and digits 2-7)';

  @override
  String get serviceRequired => 'Service is required';

  @override
  String get accountRequired => 'Account is required';

  @override
  String get secretHint => 'The key used to generate the security codes';

  @override
  String groupAll(int count) {
    return 'All ($count)';
  }

  @override
  String get optionsLabel => 'Options';

  @override
  String get optionsHint =>
      'You can leave default values in next options if you don\'t know how to set them. They are the most commonly used values.';

  @override
  String get digitsLabel => 'Digits';

  @override
  String get digitsHint =>
      'The number of digits of the generated security codes';

  @override
  String get algorithmLabel => 'Algorithm';

  @override
  String get algorithmHint =>
      'The algorithm used to secure your security codes';

  @override
  String get periodLabel => 'Period';

  @override
  String get periodDefaultHint => 'Default is 30';

  @override
  String get periodHint =>
      'The period of validity of the generated security codes in second';

  @override
  String get counterLabel => 'Counter';

  @override
  String get counterDefaultHint => 'Default is 0';

  @override
  String get counterHint => 'The initial counter value';

  @override
  String get update => 'Save';

  @override
  String get create => 'Create';

  @override
  String get remove => 'Remove';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get noAccounts => 'No accounts found';

  @override
  String get scanQRCode => 'Scan QR code';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get nextCodeCopied => 'Next code copied to clipboard';

  @override
  String get accountUpdated => 'Account updated successfully';

  @override
  String get cannotSync => 'Cannot sync: offline or server unreachable';

  @override
  String get serversTitle => 'Servers';

  @override
  String get manageServers => 'Manage server accounts';

  @override
  String get synchronize => 'Synchronize';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get deleteAccountsTitle => 'Delete Accounts';

  @override
  String deleteAccountsConfirm(Object count) {
    return 'Are you sure you want to delete $count selected account(s)?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get noServerSelected => 'No server selected';

  @override
  String get accountsDeleted => 'Accounts deleted';

  @override
  String get storageNotAvailable => 'Storage not available';

  @override
  String get syncing => 'Syncing...';

  @override
  String get couldNotOpenUrl => 'Could not open URL';

  @override
  String get done => 'Done';

  @override
  String get newLabel => 'New';

  @override
  String get manage => 'Manage';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get serverReachable => 'Server reachable';

  @override
  String get serverUnreachable => 'Server unreachable';

  @override
  String get noServer => 'no-server';

  @override
  String get noEmail => 'no email';

  @override
  String get settingsLabel => 'Settings';

  @override
  String get accountsLabel => 'Accounts';

  @override
  String get noCodeToCopy => 'No code to copy';

  @override
  String get errorCopyingToClipboard => 'Error copying to clipboard';

  @override
  String get generate => 'Generate';

  @override
  String hotpCounter(Object count) {
    return 'counter $count';
  }

  @override
  String get qrScannerError => 'Error';

  @override
  String get positionQr => 'Position the QR code in the frame';

  @override
  String get noCameraAvailable => 'No camera available';

  @override
  String get noCameraMessage =>
      'This device doesn\'t have a camera available. Use the select image option or the advanced form.';

  @override
  String get addServerTitle => 'Add server';

  @override
  String get addServerButton => 'Add Server';

  @override
  String get serverSaved => 'Server connection saved and validated';

  @override
  String get editServerTitle => 'Edit server';

  @override
  String get serverUpdated => 'Server updated and validated';

  @override
  String get deleteServerTitle => 'Delete server';

  @override
  String deleteServerConfirm(Object serverName) {
    return 'Are you sure you want to delete the server \'$serverName\'?';
  }

  @override
  String get accountsTitle => 'Accounts / Servers';

  @override
  String get localDataProtected => 'Local data is protected';

  @override
  String get authenticateToUnlock =>
      'Authenticate with biometrics to unlock your local data.';

  @override
  String get authenticationFailed => 'Authentication failed';

  @override
  String get unlock => 'Unlock';

  @override
  String get codeFormatting => 'Code formatting';

  @override
  String get byTrio => 'by Trio';

  @override
  String get byPair => 'by Pair';

  @override
  String get biometricEnabled => 'Biometric enabled';

  @override
  String get biometricDisabled => 'Biometric disabled';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get biometricsNotAvailable =>
      'Biometrics not available on this device';

  @override
  String get biometricProtection => 'Biometric protection';

  @override
  String get hideOtpsOnHome => 'Hide OTPs on Home screen';

  @override
  String get longPressReveal =>
      'Long-press an OTP on the Home screen to reveal it for 10 seconds.';

  @override
  String get biometricAuthFailed =>
      'Biometric authentication failed or was cancelled. Please retry to unlock your local data.';

  @override
  String get retry => 'Retry';

  @override
  String get search => 'Search';

  @override
  String get noServersConfigured =>
      'Welcome to Pocket2FA! Let\'s get started by adding a server.';

  @override
  String get noResults => 'No results';

  @override
  String get errorDisplayingAccount => 'Error displaying account';

  @override
  String get pendingUpload => 'Not synchronized (pending upload)';

  @override
  String userAtHost(Object user, Object host) {
    return '$user - $host';
  }

  @override
  String serverWithHost(Object name, Object host) {
    return '$name ($host)';
  }

  @override
  String get unknown => 'Unknown';

  @override
  String get about => 'About';

  @override
  String aboutRepo(Object url) {
    return 'Project repository: $url';
  }

  @override
  String about2fauth(Object url) {
    return '2FAuth project: $url';
  }

  @override
  String aboutVersion(Object version) {
    return 'Version: $version';
  }

  @override
  String get aboutClose => 'Close';

  @override
  String get syncOnHomeOpen => 'Sync when opening application';

  @override
  String get autoSync => 'Automatic synchronization';

  @override
  String autoSyncIntervalMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get syncEvery => 'Sync every';

  @override
  String get minutesLabel => 'minutes';
}
