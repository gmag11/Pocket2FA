# 2FAuth Flutter Client

A mobile client application for managing two-factor authentication (2FA) codes, designed to work with the [2FAuth web application](https://github.com/Bubka/2FAuth). This Flutter-based client provides a native mobile experience while securely synchronizing with your self-hosted 2FAuth instance.

## Purpose

This project complements the official 2FAuth web application by offering:

- Native mobile experience for accessing your 2FA codes on the go
- Secure local generation of TOTP/HOTP codes
- Synchronization with your self-hosted 2FAuth server
- Offline access to your authentication codes

**Important**: This client requires a running instance of 2FAuth. It does not replace the web application but extends its functionality to mobile devices.

## Features

- **Secure Code Generation**: All codes are generated locally on your device
- **Server Synchronization**: Sync your accounts and icons from your 2FAuth instance
- **Offline Access**: Access your codes even without internet connection
- **Encrypted Storage**: Your secrets are stored securely using platform encryption
- **Multi-Platform Support**: Runs on Android, iOS, and Windows
- **Real-time Updates**: Codes refresh automatically every 30 seconds
- **Copy to Clipboard**: One-tap copying of generated codes
- **Group Organization**: Browse accounts organized by groups
- **Icon Support**: Display service icons for easy identification

## Requirements

### For End Users

- A running instance of [2FAuth](https://github.com/Bubka/2FAuth) (version compatible with API specifications included in this project)
- Mobile device (Android/iOS) or Windows PC
- Internet connection for initial synchronization

### For Developers

- Flutter SDK (version 3.35.1 or compatible)
- Android Studio or VS Code with Flutter extension
- Platform-specific development tools:
  - Android: Android SDK and emulator/device
  - iOS: Xcode and macOS (for iOS development)
  - Windows: Visual Studio with C++ development tools

## Installation

1. **Clone the repository**:

   ```bash
   git clone [repository-url]
   cd 2fauth-client
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

3. **Run the application**:

   ```bash
   flutter run
   ```

## Usage

1. **Setup**: Open the app and navigate to Settings → Servers
2. **Add Server**: Configure connection to your 2FAuth instance (URL and API key)
3. **Synchronize**: Pull your accounts and icons from the server
4. **Access Codes**: View and copy your 2FA codes from the main accounts list
5. **Offline Use**: Codes continue to work without internet connection after initial sync

## Privacy & Security

- All secret keys remain encrypted on your device
- Code generation happens locally - secrets never leave your device
- Server synchronization uses secure HTTPS connections
- API keys and sensitive data are stored using platform secure storage

## License

This project is licensed under the AGPL-3.0 License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests to help improve this client application.

## Support

For support and questions:

- Review existing issues before creating new ones
- Ensure your 2FAuth server instance is properly configured and accessible

## Related Projects

- [2FAuth Web Application](https://github.com/Bubka/2FAuth) - The official web application that this client connects to
- [API Specifications](https://github.com/Bubka/2FAuth-API) - API documentation for developers

---

**Note**: This client requires an existing 2FAuth server instance. It is not a standalone 2FA solution but rather a mobile companion to the web application.
