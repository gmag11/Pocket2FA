import 'package:flutter_zxing/flutter_zxing.dart';

/// Thrown when an image cannot be read or decoded by the barcode plugin.
///
/// A thrown exception means the file itself is unusable (missing, not an
/// image, corrupt, too large for the decoder...). It is kept distinct from a
/// successful decode that simply contains no barcode, which returns `null`.
class QrImageUnreadableException implements Exception {
  final String message;

  const QrImageUnreadableException(this.message);

  @override
  String toString() => message;
}

/// Single entry point for decoding a QR code from an image file.
///
/// Gallery selection, Android share intake and desktop drop intake all use this
/// service so the decoder options (and therefore detection reliability) cannot
/// drift between them.
class QrImageScanner {
  const QrImageScanner();

  static const int maxSize = 4000;

  /// Decodes [path] at its stored resolution (bounded by [maxSize]).
  ///
  /// Returns the decoded text when a valid barcode is found, or `null` when
  /// the image could be read but contains no barcode. Throws
  /// [QrImageUnreadableException] when the plugin reports that the file could
  /// not be read or decoded.
  Future<String?> decodeFile(String path) async {
    final Code result = await zx.readBarcodeImagePathString(
      path,
      DecodeParams(
        tryHarder: true,
        tryInverted: true,
        tryRotate: true,
        tryDownscale: true,
        maxSize: maxSize, // safety bound; common screenshots are untouched
      ),
    );

    final error = result.error;
    if (error != null && error.isNotEmpty) {
      throw QrImageUnreadableException(error);
    }

    final text = result.text;
    if (result.isValid && text != null && text.isNotEmpty) {
      return text;
    }
    return null;
  }
}
