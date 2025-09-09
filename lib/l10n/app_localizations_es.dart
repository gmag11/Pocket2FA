// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Pocket2FA';

  @override
  String get homeTitle => 'Inicio';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get addAccount => 'Añadir cuenta';

  @override
  String get add => 'Añadir';

  @override
  String get serviceLabel => 'Servicio';

  @override
  String get serviceHint => 'Google, Twitter, Apple';

  @override
  String get accountLabel => 'Cuenta';

  @override
  String get accountHint => 'Juan Pérez';

  @override
  String get seedLabel => 'Semilla';

  @override
  String get serverLabel => 'Servidor';

  @override
  String errorParsingQr(Object error) {
    return 'Error al analizar QR: $error';
  }

  @override
  String get noQrInImage => 'No se encontró un código QR en la imagen';

  @override
  String errorScanningImage(Object error) {
    return 'Error al escanear la imagen: $error';
  }

  @override
  String get selectQrImageTitle => 'Seleccionar imagen QR';

  @override
  String get selectImageFromGallery =>
      'Selecciona una imagen de la galería que contenga un código QR';

  @override
  String get selectImageButton => 'Seleccionar imagen';

  @override
  String get scanningFromImage => 'Escaneando QR desde imagen...';

  @override
  String get back => 'Atrás';

  @override
  String get createNewCodeTitle => 'Crear nuevo código';

  @override
  String get chooseHowToCreate => 'Elige cómo crear un nuevo código:';

  @override
  String get alternateMethods => 'Métodos alternativos';

  @override
  String get useAdvancedForm => 'Usar el formulario avanzado';

  @override
  String get urlRequired => 'URL requerida';

  @override
  String get apiKeyLabel => 'Clave API';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get urlLabel => 'URL';

  @override
  String get save => 'Guardar';

  @override
  String get totpLabel => 'TOTP';

  @override
  String get hotpLabel => 'HOTP';

  @override
  String get steamLabel => 'STEAM';

  @override
  String get groupLabel => 'Grupo';

  @override
  String get noGroupOption => '- Sin grupo -';

  @override
  String get groupHint => 'El grupo al que se asignará la cuenta';

  @override
  String get chooseOtpType => 'Elige el tipo de OTP a crear';

  @override
  String get otpTypeHint => 'OTP basada en tiempo, HOTP (contador) o Steam OTP';

  @override
  String get secretLabel => 'Secreto';

  @override
  String get secretLockedHint =>
      'El secreto está bloqueado - toca el candado para editar';

  @override
  String get secretRequired => 'El secreto es obligatorio';

  @override
  String get secretBase32Error =>
      'El secreto debe ser Base32 (letras A-Z en mayúsculas y dígitos 2-7)';

  @override
  String get serviceRequired => 'El servicio es obligatorio';

  @override
  String get accountRequired => 'La cuenta es obligatoria';

  @override
  String get secretHint =>
      'La clave usada para generar los códigos de seguridad';

  @override
  String groupAll(int count) {
    return 'Todos ($count)';
  }

  @override
  String get optionsLabel => 'Opciones';

  @override
  String get optionsHint =>
      'Puedes dejar lso valores predeterminados en estas opciones si no sabes cómo configurarlas. Son los valores más utilizados.';

  @override
  String get digitsLabel => 'Dígitos';

  @override
  String get digitsHint =>
      'Número de dígitos de los códigos de seguridad generados';

  @override
  String get algorithmLabel => 'Algoritmo';

  @override
  String get algorithmHint =>
      'Algoritmo usado para proteger los códigos de seguridad';

  @override
  String get periodLabel => 'Periodo';

  @override
  String get periodDefaultHint => 'Por defecto es 30';

  @override
  String get periodHint =>
      'Periodo de validez de los códigos de seguridad en segundos';

  @override
  String get counterLabel => 'Contador';

  @override
  String get counterDefaultHint => 'Por defecto es 0';

  @override
  String get counterHint => 'Valor inicial del contador';

  @override
  String get update => 'Editar';

  @override
  String get create => 'Crear';

  @override
  String get remove => 'Eliminar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get noAccounts => 'No se encontraron cuentas';

  @override
  String get scanQRCode => 'Escanear código QR';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado al portapapeles';

  @override
  String get accountUpdated => 'Cuenta actualizada correctamente';

  @override
  String get cannotSync =>
      'No se puede sincronizar: sin conexión o servidor inalcanzable';

  @override
  String get serversTitle => 'Servidores';

  @override
  String get synchronize => 'Sincronizar';

  @override
  String selectedCount(Object count) {
    return '$count seleccionados';
  }

  @override
  String get deleteAccountsTitle => 'Eliminar cuentas';

  @override
  String deleteAccountsConfirm(Object count) {
    return '¿Seguro que quieres eliminar $count cuenta(s) seleccionada(s)?';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String get noServerSelected => 'No hay servidor seleccionado';

  @override
  String get accountsDeleted => 'Cuentas eliminadas';

  @override
  String get storageNotAvailable => 'Almacenamiento no disponible';

  @override
  String get syncing => 'Sincronizando...';

  @override
  String get couldNotOpenUrl => 'No se pudo abrir la URL';

  @override
  String get done => 'Listo';

  @override
  String get newLabel => 'Nuevo';

  @override
  String get manage => 'Editar';

  @override
  String get online => 'En línea';

  @override
  String get offline => 'Sin conexión';

  @override
  String get serverReachable => 'Servidor accesible';

  @override
  String get serverUnreachable => 'Servidor inaccesible';

  @override
  String get noServer => 'sin servidor';

  @override
  String get noEmail => 'sin correo';

  @override
  String get settingsLabel => 'Ajustes';

  @override
  String get accountsLabel => 'Cuentas';

  @override
  String get noCodeToCopy => 'No hay código para copiar';

  @override
  String get errorCopyingToClipboard => 'Error al copiar al portapapeles';

  @override
  String get generate => 'Generar';

  @override
  String hotpCounter(Object count) {
    return 'contador $count';
  }

  @override
  String get qrScannerError => 'Error';

  @override
  String get positionQr => 'Posiciona el código QR en el marco';

  @override
  String get addServerTitle => 'Añadir servidor';

  @override
  String get serverSaved => 'Conexión con el servidor guardada y validada';

  @override
  String get editServerTitle => 'Editar servidor';

  @override
  String get serverUpdated => 'Servidor actualizado y validado';

  @override
  String get accountsTitle => 'Cuentas / Servidores';

  @override
  String get localDataProtected => 'Los datos locales están protegidos';

  @override
  String get authenticateToUnlock =>
      'Autentícate con biometría para desbloquear tus datos locales.';

  @override
  String get authenticationFailed => 'Autenticación fallida';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get codeFormatting => 'Formato de código';

  @override
  String get byTrio => 'por tríos';

  @override
  String get byPair => 'por pares';

  @override
  String get biometricEnabled => 'Biometría activada';

  @override
  String get biometricDisabled => 'Biometría desactivada';

  @override
  String get operationFailed => 'La operación falló';

  @override
  String get biometricsNotAvailable =>
      'Biometría no disponible en este dispositivo';

  @override
  String get biometricProtection => 'Protección biométrica';

  @override
  String get hideOtpsOnHome => 'Ocultar OTPs en la pantalla de inicio';

  @override
  String get longPressReveal =>
      'Mantén pulsado un OTP en la pantalla de inicio para mostrarlo durante 10 segundos.';

  @override
  String get biometricAuthFailed =>
      'La autenticación biométrica falló o se canceló. Por favor reintenta para desbloquear tus datos locales.';

  @override
  String get retry => 'Reintentar';

  @override
  String get search => 'Buscar';

  @override
  String get noServersConfigured =>
      'No hay servidores configurados. Configura un servidor en ajustes para empezar.';

  @override
  String get noResults => 'Sin resultados';

  @override
  String get errorDisplayingAccount => 'Error al mostrar la cuenta';

  @override
  String get pendingUpload => 'No sincronizado (pendiente de subida)';

  @override
  String userAtHost(Object user, Object host) {
    return '$user - $host';
  }

  @override
  String serverWithHost(Object name, Object host) {
    return '$name ($host)';
  }

  @override
  String get unknown => 'Desconocido';

  @override
  String get about => 'Acerca de';

  @override
  String aboutRepo(Object url) {
    return 'Repositorio del proyecto: $url';
  }

  @override
  String about2fauth(Object url) {
    return 'Proyecto 2FAuth: $url';
  }

  @override
  String aboutVersion(Object version) {
    return 'Versión: $version';
  }

  @override
  String get aboutClose => 'Cerrar';
}
