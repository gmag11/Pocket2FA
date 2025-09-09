import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// Application short title shown in the app window and app switcher.
  ///
  /// In en, this message translates to:
  /// **'Pocket2FA'**
  String get appTitle;

  /// Title for the Home screen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// Title for the Settings screen and related labels.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Label for action that adds a new account entry.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// Generic add action label used on buttons.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Input field label for service name when creating a new account.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceLabel;

  /// Help text for the service input field.
  ///
  /// In en, this message translates to:
  /// **'Google, Twitter, Apple'**
  String get serviceHint;

  /// Input field label for account identifier when creating a new account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// Help text for the account input field.
  ///
  /// In en, this message translates to:
  /// **'John Doe'**
  String get accountHint;

  /// Input field label for OTP seed when creating a new account.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get seedLabel;

  /// Label prefix used when showing a server name in the app bar.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverLabel;

  /// Shown when a QR parsing operation fails.
  ///
  /// In en, this message translates to:
  /// **'Error parsing QR: {error}'**
  String errorParsingQr(Object error);

  /// Shown when no QR is found in a picked image.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in image'**
  String get noQrInImage;

  /// Shown when scanning an image fails.
  ///
  /// In en, this message translates to:
  /// **'Error scanning image: {error}'**
  String errorScanningImage(Object error);

  /// Title for the image QR picker screen.
  ///
  /// In en, this message translates to:
  /// **'Select QR Image'**
  String get selectQrImageTitle;

  /// Help text instructing the user to pick an image containing QR.
  ///
  /// In en, this message translates to:
  /// **'Select an image from gallery containing a QR code'**
  String get selectImageFromGallery;

  /// Button label for picking an image from gallery.
  ///
  /// In en, this message translates to:
  /// **'Select Image'**
  String get selectImageButton;

  /// Progress label shown while scanning an image.
  ///
  /// In en, this message translates to:
  /// **'Scanning QR from image...'**
  String get scanningFromImage;

  /// Generic back action label.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Title for the Create New Code screen.
  ///
  /// In en, this message translates to:
  /// **'Create new code'**
  String get createNewCodeTitle;

  /// Instruction to choose a creation method.
  ///
  /// In en, this message translates to:
  /// **'Choose how to create a new code:'**
  String get chooseHowToCreate;

  /// Label for the alternate creation methods section.
  ///
  /// In en, this message translates to:
  /// **'Alternate methods'**
  String get alternateMethods;

  /// Label for opening the advanced form to create a code.
  ///
  /// In en, this message translates to:
  /// **'Use the advanced form'**
  String get useAdvancedForm;

  /// Validation message shown when URL is empty in server dialog.
  ///
  /// In en, this message translates to:
  /// **'URL required'**
  String get urlRequired;

  /// Label for API key input.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKeyLabel;

  /// Label for name input in server dialog.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Label for URL input in server dialog.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get urlLabel;

  /// Generic save action label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label for Time-based OTP type option.
  ///
  /// In en, this message translates to:
  /// **'TOTP'**
  String get totpLabel;

  /// Label for HMAC-based OTP type option.
  ///
  /// In en, this message translates to:
  /// **'HOTP'**
  String get hotpLabel;

  /// Label for Steam OTP type option.
  ///
  /// In en, this message translates to:
  /// **'STEAM'**
  String get steamLabel;

  /// Label for group field in advanced form.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupLabel;

  /// Dropdown item indicating no group.
  ///
  /// In en, this message translates to:
  /// **'- No group -'**
  String get noGroupOption;

  /// Help text for the group input field.
  ///
  /// In en, this message translates to:
  /// **'The group to which the account is to be assigned'**
  String get groupHint;

  /// Heading for OTP type picker.
  ///
  /// In en, this message translates to:
  /// **'Choose the type of OTP to create'**
  String get chooseOtpType;

  /// Help text for the OTP type selection.
  ///
  /// In en, this message translates to:
  /// **'Time-based OTP or HMAC-based OTP or Steam OTP'**
  String get otpTypeHint;

  /// Label for the secret input field.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get secretLabel;

  /// Hint shown when secret field is locked in edit mode.
  ///
  /// In en, this message translates to:
  /// **'Secret is locked - tap the lock to edit'**
  String get secretLockedHint;

  /// Validation error when secret is empty.
  ///
  /// In en, this message translates to:
  /// **'Secret is required'**
  String get secretRequired;

  /// Validation error when secret isn't valid Base32.
  ///
  /// In en, this message translates to:
  /// **'Secret must be Base32 (uppercase letters A-Z and digits 2-7)'**
  String get secretBase32Error;

  /// Validation error when service field is empty.
  ///
  /// In en, this message translates to:
  /// **'Service is required'**
  String get serviceRequired;

  /// Validation error when account field is empty.
  ///
  /// In en, this message translates to:
  /// **'Account is required'**
  String get accountRequired;

  /// Help text for the secret input field.
  ///
  /// In en, this message translates to:
  /// **'The key used to generate the security codes'**
  String get secretHint;

  /// Label for the 'All' group with item count
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String groupAll(int count);

  /// Label for advanced options section.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsLabel;

  /// Help text for advanced options.
  ///
  /// In en, this message translates to:
  /// **'You can leave default values in next options if you don\'t know how to set them. They are the most commonly used values.'**
  String get optionsHint;

  /// Label for digits selector.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get digitsLabel;

  /// Help text for digits selector.
  ///
  /// In en, this message translates to:
  /// **'The number of digits of the generated security codes'**
  String get digitsHint;

  /// Label for algorithm selector.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get algorithmLabel;

  /// Help text for algorithm selector.
  ///
  /// In en, this message translates to:
  /// **'The algorithm used to secure your security codes'**
  String get algorithmHint;

  /// Label for period field.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get periodLabel;

  /// Hint showing the default period value.
  ///
  /// In en, this message translates to:
  /// **'Default is 30'**
  String get periodDefaultHint;

  /// Help text for period field.
  ///
  /// In en, this message translates to:
  /// **'The period of validity of the generated security codes in second'**
  String get periodHint;

  /// Label for counter field (HOTP).
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get counterLabel;

  /// Hint showing default counter value.
  ///
  /// In en, this message translates to:
  /// **'Default is 0'**
  String get counterDefaultHint;

  /// Help text for counter field.
  ///
  /// In en, this message translates to:
  /// **'The initial counter value'**
  String get counterHint;

  /// Label for edit action on advanced form.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get update;

  /// Label for create action on advanced form.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Generic remove/delete label used on buttons or menus.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Generic confirm action label used in dialogs.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Generic cancel action label used in dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Empty state message shown when no accounts are available.
  ///
  /// In en, this message translates to:
  /// **'No accounts found'**
  String get noAccounts;

  /// Label or title for QR code scanning UI.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQRCode;

  /// Label for copying content to clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Confirmation message shown after copying to clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// Snackbar message shown when an account was edited and saved successfully.
  ///
  /// In en, this message translates to:
  /// **'Account updated successfully'**
  String get accountUpdated;

  /// Error shown when a sync attempt fails due to network or server issues.
  ///
  /// In en, this message translates to:
  /// **'Cannot sync: offline or server unreachable'**
  String get cannotSync;

  /// Title text for the servers selector header in Home screen.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get serversTitle;

  /// Tooltip and semantics label for the sync button.
  ///
  /// In en, this message translates to:
  /// **'Synchronize'**
  String get synchronize;

  /// Text that shows the number of selected accounts in manage mode.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(Object count);

  /// Title for the confirmation dialog when deleting multiple accounts.
  ///
  /// In en, this message translates to:
  /// **'Delete Accounts'**
  String get deleteAccountsTitle;

  /// Confirmation prompt shown before deleting selected accounts.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected account(s)?'**
  String deleteAccountsConfirm(Object count);

  /// Label for the delete action in dialogs.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Shown when an operation requires a server but none is selected.
  ///
  /// In en, this message translates to:
  /// **'No server selected'**
  String get noServerSelected;

  /// Snackbar confirming accounts were deleted.
  ///
  /// In en, this message translates to:
  /// **'Accounts deleted'**
  String get accountsDeleted;

  /// Error shown when trying to access storage but none is configured.
  ///
  /// In en, this message translates to:
  /// **'Storage not available'**
  String get storageNotAvailable;

  /// Short label shown during a full-screen sync operation.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// Error shown when an external URL cannot be opened; exception appended.
  ///
  /// In en, this message translates to:
  /// **'Could not open URL'**
  String get couldNotOpenUrl;

  /// Label for finishing an edit or exiting manage mode.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Label for the button that adds a new account.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// Label to enter manage mode for selecting items.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// Short status label indicating server is reachable.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// Short status label indicating server is unreachable.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// Accessibility label when server is reachable.
  ///
  /// In en, this message translates to:
  /// **'Server reachable'**
  String get serverReachable;

  /// Accessibility label when server is unreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get serverUnreachable;

  /// Placeholder text shown when no server is configured.
  ///
  /// In en, this message translates to:
  /// **'no-server'**
  String get noServer;

  /// Placeholder used when server has no user email configured.
  ///
  /// In en, this message translates to:
  /// **'no email'**
  String get noEmail;

  /// Menu label for opening settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsLabel;

  /// Menu label for opening accounts list.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsLabel;

  /// Shown when attempting to copy but there is no code available.
  ///
  /// In en, this message translates to:
  /// **'No code to copy'**
  String get noCodeToCopy;

  /// Shown when copying to clipboard failed.
  ///
  /// In en, this message translates to:
  /// **'Error copying to clipboard'**
  String get errorCopyingToClipboard;

  /// Label for HOTP generation button.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// Label showing hotp counter value.
  ///
  /// In en, this message translates to:
  /// **'counter {count}'**
  String hotpCounter(Object count);

  /// Prefix used when showing QR scanner errors in a snackbar.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get qrScannerError;

  /// Instruction text shown over the camera preview for scanning.
  ///
  /// In en, this message translates to:
  /// **'Position the QR code in the frame'**
  String get positionQr;

  /// Dialog title when adding a new server connection.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServerTitle;

  /// Confirmation shown after saving a new server.
  ///
  /// In en, this message translates to:
  /// **'Server connection saved and validated'**
  String get serverSaved;

  /// Dialog title when editing an existing server.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get editServerTitle;

  /// Confirmation shown after editing a server.
  ///
  /// In en, this message translates to:
  /// **'Server updated and validated'**
  String get serverUpdated;

  /// Title for the accounts/settings screen.
  ///
  /// In en, this message translates to:
  /// **'Accounts / Servers'**
  String get accountsTitle;

  /// Heading shown when storage is locked and requires unlocking.
  ///
  /// In en, this message translates to:
  /// **'Local data is protected'**
  String get localDataProtected;

  /// Instruction to authenticate when storage is protected.
  ///
  /// In en, this message translates to:
  /// **'Authenticate with biometrics to unlock your local data.'**
  String get authenticateToUnlock;

  /// Shown when biometric auth fails.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get authenticationFailed;

  /// Label for button that attempts to unlock protected storage.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// Label for the code formatting section in settings.
  ///
  /// In en, this message translates to:
  /// **'Code formatting'**
  String get codeFormatting;

  /// Label describing a 3-digit grouping format.
  ///
  /// In en, this message translates to:
  /// **'by Trio'**
  String get byTrio;

  /// Label describing a 2-digit grouping format.
  ///
  /// In en, this message translates to:
  /// **'by Pair'**
  String get byPair;

  /// Snackbar shown when biometric is enabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric enabled'**
  String get biometricEnabled;

  /// Snackbar shown when biometric is disabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric disabled'**
  String get biometricDisabled;

  /// Generic failure message for operations in settings.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// Shown when biometric hardware or enrollment is not available on the device.
  ///
  /// In en, this message translates to:
  /// **'Biometrics not available on this device'**
  String get biometricsNotAvailable;

  /// Label for biometric protection setting.
  ///
  /// In en, this message translates to:
  /// **'Biometric protection'**
  String get biometricProtection;

  /// Label to hide OTP codes on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Hide OTPs on Home screen'**
  String get hideOtpsOnHome;

  /// Help text explaining long-press to reveal OTPs.
  ///
  /// In en, this message translates to:
  /// **'Long-press an OTP on the Home screen to reveal it for 10 seconds.'**
  String get longPressReveal;

  /// Shown when biometric unlock fails and user must retry.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed or was cancelled. Please retry to unlock your local data.'**
  String get biometricAuthFailed;

  /// Label for retrying biometric authentication.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Placeholder text for search fields.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Message shown when there are no servers in storage.
  ///
  /// In en, this message translates to:
  /// **'No servers configured. Configure a server in settings to get started.'**
  String get noServersConfigured;

  /// Shown when a search returns no results.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// Shown when an account cannot be rendered due to an error.
  ///
  /// In en, this message translates to:
  /// **'Error displaying account'**
  String get errorDisplayingAccount;

  /// Tooltip explaining that the account has not been uploaded to the server yet.
  ///
  /// In en, this message translates to:
  /// **'Not synchronized (pending upload)'**
  String get pendingUpload;

  /// Short line showing user email and server host.
  ///
  /// In en, this message translates to:
  /// **'{user} - {host}'**
  String userAtHost(Object user, Object host);

  /// Server display combining server name and host.
  ///
  /// In en, this message translates to:
  /// **'{name} ({host})'**
  String serverWithHost(Object name, Object host);

  /// Fallback label used when a value is not available.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Label for the About menu or dialog title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Label showing the repository URL.
  ///
  /// In en, this message translates to:
  /// **'Project repository: {url}'**
  String aboutRepo(Object url);

  /// Label showing the 2FAuth project URL.
  ///
  /// In en, this message translates to:
  /// **'2FAuth project: {url}'**
  String about2fauth(Object url);

  /// Label showing the current application version.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String aboutVersion(Object version);

  /// Label for closing the About dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aboutClose;

  /// Sync when opening the Home screen.
  ///
  /// In en, this message translates to:
  /// **'Sync when opening Home screen'**
  String get syncOnHomeOpen;

  /// Label for automatic synchronization setting.
  ///
  /// In en, this message translates to:
  /// **'Automatic synchronization'**
  String get autoSync;

  /// Label showing number of minutes for auto-sync interval.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String autoSyncIntervalMinutes(int minutes);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
