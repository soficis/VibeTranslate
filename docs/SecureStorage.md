# Secure Storage

## Overview

The TranslationFiesta applications provide a secure way to store your Google Cloud API key, so you don't have to enter it every time you use the official API. This feature is available in the Python, Go, WinUI, and F# implementations.

## Core Features

- **Cross-Platform Support**: The secure storage system is designed to work across different operating systems, using platform-specific features where available.
- **Encrypted Storage**: Your API key is always encrypted at rest, so it is not stored in plain text.
- **Per-User Encryption**: On Windows, the API key is encrypted with user-specific data, so it can only be accessed by the same user on the same machine.
- **Fallback Storage**: If platform-specific secure storage is not available, the system will fall back to an encrypted file-based storage solution.

## How It Works

The Secure Storage system uses a variety of platform-specific and fallback mechanisms to store your API key securely.

### Windows
On Windows, the system uses the **Data Protection API (DPAPI)** to encrypt and decrypt the API key. This provides a high level of security, as the key is tied to the user's Windows account.

### macOS
On macOS, the system uses the built-in **Keychain** to store the API key.

### Linux
On Linux, the system uses the **Secret Service API**, which is a standard for storing secrets on modern Linux desktops.

### Fallback
If none of the platform-specific mechanisms are available, the system will fall back to storing the API key in an encrypted file in the user's home directory.

## Usage

To use the secure storage feature, simply enter your Google Cloud API key in the application's settings. The key will be automatically encrypted and stored securely. The next time you start the application, the key will be automatically loaded, so you don't have to enter it again.

## Implementation Details

### Python (`TranslationFiestaPy`)
- **`secure_storage.py`**: Contains the `SecureStorage` class, which implements the cross-platform secure storage logic. It uses the `keyring` library to interact with the platform-specific credential stores.

### Go (`TranslationFiestaGo`)
- **`internal/data/repositories/secure_storage_impl.go`**: Implements the secure storage logic in Go.

### WinUI (`TranslationFiesta.WinUI`)
- **`SecureStore.cs`**: Implements the secure storage logic in C#, using the `System.Security.Cryptography.ProtectedData` class to interact with DPAPI.

### F# (`TranslationFiestaFSharp`)
- **`SecureStore.fs`**: Implements the secure storage logic in F#.