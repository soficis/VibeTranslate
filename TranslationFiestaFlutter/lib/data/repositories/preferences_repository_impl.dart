library;

import 'dart:convert';
import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/app_paths.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/translation_repository.dart';

/// Implementation of PreferencesRepository interface
/// Single Responsibility: Handle application preferences with portable file persistence.
class PreferencesRepositoryImpl implements PreferencesRepository {
  final Logger logger = Logger.instance;
  Map<String, dynamic>? _cachedPreferences;

  @override
  Future<Result<bool>> getBoolPreference(
    String key, {
    bool defaultValue = false,
  }) async {
    try {
      final prefs = await _loadPreferences();
      final value = prefs[key];
      if (value is bool) {
        logger.debug('Retrieved bool preference: $key = $value');
        return Right(value);
      }

      logger.debug(
        'Bool preference missing, using default: $key = $defaultValue',
      );
      return Right(defaultValue);
    } catch (e) {
      final errorMessage = 'Failed to get bool preference $key: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<void>> setBoolPreference(String key, bool value) async {
    try {
      final prefs = await _loadPreferences();
      prefs[key] = value;
      await _savePreferences(prefs);
      logger.debug('Set bool preference: $key = $value');
      return const Right(null);
    } catch (e) {
      final errorMessage = 'Failed to set bool preference $key: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<String?>> getStringPreference(String key) async {
    try {
      final prefs = await _loadPreferences();
      final value = prefs[key];
      if (value == null) {
        logger.debug('String preference missing: $key');
        return const Right(null);
      }

      if (value is String) {
        logger.debug('Retrieved string preference: $key');
        return Right(value);
      }

      final converted = value.toString();
      logger.warning('String preference had non-string type, coercing: $key');
      return Right(converted);
    } catch (e) {
      final errorMessage = 'Failed to get string preference $key: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<void>> setStringPreference(String key, String value) async {
    try {
      final prefs = await _loadPreferences();
      prefs[key] = value;
      await _savePreferences(prefs);
      logger.debug('Set string preference: $key');
      return const Right(null);
    } catch (e) {
      final errorMessage = 'Failed to set string preference $key: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<void>> removePreference(String key) async {
    try {
      final prefs = await _loadPreferences();
      prefs.remove(key);
      await _savePreferences(prefs);
      logger.debug('Removed preference: $key');
      return const Right(null);
    } catch (e) {
      final errorMessage = 'Failed to remove preference $key: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<void>> clearAllPreferences() async {
    try {
      final cleared = <String, dynamic>{};
      await _savePreferences(cleared);
      logger.info('Cleared all preferences');
      return const Right(null);
    } catch (e) {
      final errorMessage = 'Failed to clear all preferences: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  Future<Map<String, dynamic>> _loadPreferences() async {
    if (_cachedPreferences != null) {
      return _cachedPreferences!;
    }

    final file = AppPaths.instance.settingsFile;
    if (!await file.exists()) {
      _cachedPreferences = <String, dynamic>{};
      return _cachedPreferences!;
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      _cachedPreferences = <String, dynamic>{};
      return _cachedPreferences!;
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Preferences file must be a JSON object');
    }

    _cachedPreferences = Map<String, dynamic>.from(decoded);
    return _cachedPreferences!;
  }

  Future<void> _savePreferences(Map<String, dynamic> prefs) async {
    final file = AppPaths.instance.settingsFile;
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(prefs),
      mode: FileMode.write,
      flush: true,
    );
    _cachedPreferences = prefs;
  }

  /// Convenience methods for theme preferences
  Future<Result<bool>> getThemePreference() async {
    return getBoolPreference(
      AppConstants.themePreferenceKey,
      defaultValue: false,
    );
  }

  Future<Result<void>> setThemePreference(bool isDark) async {
    return setBoolPreference(AppConstants.themePreferenceKey, isDark);
  }

  Future<Result<String?>> getProviderIdPreference() async {
    return getStringPreference(AppConstants.providerIdPreferenceKey);
  }

  Future<Result<void>> setProviderIdPreference(String providerId) async {
    return setStringPreference(
      AppConstants.providerIdPreferenceKey,
      providerId,
    );
  }
}

/// Factory for creating PreferencesRepository instances
class PreferencesRepositoryFactory {
  static PreferencesRepository create() {
    return PreferencesRepositoryImpl();
  }
}
