// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Pocket2FA';

  @override
  String get homeTitle => 'Accueil';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsGeneral => 'GÉNÉRAL';

  @override
  String get settingsSecurity => 'SÉCURITÉ';

  @override
  String get settingsSynchronization => 'SYNCHRONISATION';

  @override
  String get addAccount => 'Ajouter un compte';

  @override
  String get add => 'Ajouter';

  @override
  String get serviceLabel => 'Service';

  @override
  String get serviceHint => 'Google, Twitter, Apple';

  @override
  String get accountLabel => 'Compte';

  @override
  String get accountHint => 'Jean Dupont';

  @override
  String get seedLabel => 'Graine';

  @override
  String get serverLabel => 'Serveur';

  @override
  String errorParsingQr(Object error) {
    return 'Erreur lors de l\'analyse du QR : $error';
  }

  @override
  String get noQrInImage => 'Aucun code QR trouvé dans l\'image';

  @override
  String errorScanningImage(Object error) {
    return 'Erreur lors de l\'analyse de l\'image : $error';
  }

  @override
  String get selectQrImageTitle => 'Sélectionner une image QR';

  @override
  String get selectImageFromGallery =>
      'Sélectionnez une image de la galerie contenant un code QR';

  @override
  String get selectImageButton => 'Sélectionner une image';

  @override
  String get scanningFromImage => 'Analyse du QR à partir de l\'image...';

  @override
  String get back => 'Retour';

  @override
  String get createNewCodeTitle => 'Créer un nouveau code';

  @override
  String get chooseHowToCreate => 'Choisissez comment créer un nouveau code :';

  @override
  String get alternateMethods => 'Méthodes alternatives';

  @override
  String get useAdvancedForm => 'Utiliser le formulaire avancé';

  @override
  String get urlRequired => 'URL requise';

  @override
  String get apiKeyLabel => 'Clé d\'API';

  @override
  String get nameLabel => 'Nom';

  @override
  String get urlLabel => 'URL';

  @override
  String get save => 'Enregistrer';

  @override
  String get requires2fauth =>
      'Pocket2FA nécessite l\'accès à un serveur 2FAuth (auto-hébergé ou distant) pour synchroniser les comptes. Consultez le lien du projet 2FAuth ci-dessous pour les options de configuration et d\'hébergement.';

  @override
  String get totpLabel => 'TOTP';

  @override
  String get hotpLabel => 'HOTP';

  @override
  String get steamLabel => 'STEAM';

  @override
  String get groupLabel => 'Groupe';

  @override
  String get noGroupOption => '- Aucun groupe -';

  @override
  String get groupHint => 'Le groupe auquel le compte doit être attribué';

  @override
  String get chooseOtpType => 'Choisissez le type d\'OTP à créer';

  @override
  String get otpTypeHint =>
      'OTP basé sur le temps ou OTP basé sur HMAC ou OTP Steam';

  @override
  String get secretLabel => 'Secret';

  @override
  String get secretLockedHint =>
      'Le secret est verrouillé - appuyez sur le cadenas pour modifier';

  @override
  String get secretRequired => 'Le secret est requis';

  @override
  String get secretBase32Error =>
      'Le secret doit être en Base32 (lettres majuscules A-Z et chiffres 2-7)';

  @override
  String get serviceRequired => 'Le service est requis';

  @override
  String get accountRequired => 'Le compte est requis';

  @override
  String get secretHint => 'La clé utilisée pour générer les codes de sécurité';

  @override
  String groupAll(int count) {
    return 'Tous ($count)';
  }

  @override
  String get optionsLabel => 'Options';

  @override
  String get optionsHint =>
      'Vous pouvez laisser les valeurs par défaut dans les options suivantes si vous ne savez pas comment les définir. Ce sont les valeurs les plus couramment utilisées.';

  @override
  String get digitsLabel => 'Chiffres';

  @override
  String get digitsHint =>
      'Le nombre de chiffres des codes de sécurité générés';

  @override
  String get algorithmLabel => 'Algorithme';

  @override
  String get algorithmHint =>
      'L\'algorithme utilisé pour sécuriser vos codes de sécurité';

  @override
  String get periodLabel => 'Période';

  @override
  String get periodDefaultHint => 'Par défaut 30';

  @override
  String get periodHint =>
      'La période de validité des codes de sécurité générés en secondes';

  @override
  String get counterLabel => 'Compteur';

  @override
  String get counterDefaultHint => 'Par défaut 0';

  @override
  String get counterHint => 'La valeur initiale du compteur';

  @override
  String get update => 'Enregistrer';

  @override
  String get create => 'Créer';

  @override
  String get remove => 'Supprimer';

  @override
  String get confirm => 'Confirmer';

  @override
  String get cancel => 'Annuler';

  @override
  String get noAccounts => 'Aucun compte trouvé';

  @override
  String get scanQRCode => 'Scanner le code QR';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié dans le presse-papiers';

  @override
  String get nextCodeCopied => 'Prochain code copié dans le presse-papiers';

  @override
  String get accountUpdated => 'Compte mis à jour avec succès';

  @override
  String get cannotSync =>
      'Impossible de synchroniser : hors ligne ou serveur inaccessible';

  @override
  String get serversTitle => 'Serveurs';

  @override
  String get manageServers => 'Gérer les comptes serveur';

  @override
  String get synchronize => 'Synchroniser';

  @override
  String selectedCount(Object count) {
    return '$count sélectionné(s)';
  }

  @override
  String get deleteAccountsTitle => 'Supprimer les comptes';

  @override
  String deleteAccountsConfirm(Object count) {
    return 'Êtes-vous sûr de vouloir supprimer $count compte(s) sélectionné(s) ?';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get noServerSelected => 'Aucun serveur sélectionné';

  @override
  String get accountsDeleted => 'Comptes supprimés';

  @override
  String get storageNotAvailable => 'Stockage non disponible';

  @override
  String get syncing => 'Synchronisation en cours...';

  @override
  String get couldNotOpenUrl => 'Impossible d\'ouvrir l\'URL';

  @override
  String get done => 'Terminé';

  @override
  String get newLabel => 'Nouveau';

  @override
  String get manage => 'Gérer';

  @override
  String get online => 'En ligne';

  @override
  String get offline => 'Hors ligne';

  @override
  String get serverReachable => 'Serveur accessible';

  @override
  String get serverUnreachable => 'Serveur inaccessible';

  @override
  String get noServer => 'aucun serveur';

  @override
  String get noEmail => 'aucun e-mail';

  @override
  String get settingsLabel => 'Paramètres';

  @override
  String get accountsLabel => 'Comptes';

  @override
  String get noCodeToCopy => 'Aucun code à copier';

  @override
  String get errorCopyingToClipboard =>
      'Erreur lors de la copie dans le presse-papiers';

  @override
  String get generate => 'Générer';

  @override
  String hotpCounter(Object count) {
    return 'compteur $count';
  }

  @override
  String get qrScannerError => 'Erreur';

  @override
  String get positionQr => 'Positionnez le code QR dans le cadre';

  @override
  String get noCameraAvailable => 'Aucune caméra disponible';

  @override
  String get noCameraMessage =>
      'Cet appareil n\'a pas de caméra disponible. Utilisez l\'option de sélection d\'image ou le formulaire avancé.';

  @override
  String get addServerTitle => 'Ajouter un serveur';

  @override
  String get addServerButton => 'Ajouter un serveur';

  @override
  String get serverSaved => 'Connexion au serveur enregistrée et validée';

  @override
  String get editServerTitle => 'Modifier le serveur';

  @override
  String get serverUpdated => 'Serveur mis à jour et validé';

  @override
  String get deleteServerTitle => 'Supprimer le serveur';

  @override
  String deleteServerConfirm(Object serverName) {
    return 'Êtes-vous sûr de vouloir supprimer le serveur \'$serverName\' ?';
  }

  @override
  String get accountsTitle => 'Comptes / Serveurs';

  @override
  String get localDataProtected => 'Les données locales sont protégées';

  @override
  String get authenticateToUnlock =>
      'Authentifiez-vous avec la biométrie pour déverrouiller vos données locales.';

  @override
  String get authenticationFailed => 'Échec de l\'authentification';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get codeFormatting => 'Formatage du code';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get byTrio => 'par Trio';

  @override
  String get byPair => 'par Paire';

  @override
  String get biometricEnabled => 'Biométrie activée';

  @override
  String get biometricDisabled => 'Biométrie désactivée';

  @override
  String get operationFailed => 'Échec de l\'opération';

  @override
  String get biometricsNotAvailable =>
      'Biométrie non disponible sur cet appareil';

  @override
  String get biometricProtection => 'Protection biométrique';

  @override
  String get hideOtpsOnHome => 'Masquer les OTP sur l\'écran d\'accueil';

  @override
  String get longPressReveal =>
      'Appuyez longuement sur un OTP sur l\'écran d\'accueil pour le révéler pendant 10 secondes.';

  @override
  String get biometricAuthFailed =>
      'L\'authentification biométrique a échoué ou a été annulée. Veuillez réessayer pour déverrouiller vos données locales.';

  @override
  String get retry => 'Réessayer';

  @override
  String get search => 'Rechercher';

  @override
  String get noServersConfigured =>
      'Bienvenue dans Pocket2FA ! Commençons par ajouter un serveur.';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get errorDisplayingAccount => 'Erreur lors de l\'affichage du compte';

  @override
  String get pendingUpload => 'Non synchronisé (téléchargement en attente)';

  @override
  String userAtHost(Object user, Object host) {
    return '$user - $host';
  }

  @override
  String serverWithHost(Object name, Object host) {
    return '$name ($host)';
  }

  @override
  String get unknown => 'Inconnu';

  @override
  String get about => 'À propos';

  @override
  String aboutRepo(Object url) {
    return 'Dépôt du projet : $url';
  }

  @override
  String about2fauth(Object url) {
    return 'Projet 2FAuth : $url';
  }

  @override
  String aboutVersion(Object version) {
    return 'Version : $version';
  }

  @override
  String get aboutClose => 'Fermer';

  @override
  String get syncOnHomeOpen =>
      'Synchroniser lors de l\'ouverture de l\'application';

  @override
  String get autoSync => 'Synchronisation automatique';

  @override
  String autoSyncIntervalMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get syncEvery => 'Synchroniser toutes les';

  @override
  String get minutesLabel => 'minutes';
}
