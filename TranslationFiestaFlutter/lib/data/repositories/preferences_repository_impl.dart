library;

import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/translation_repository.dart';

/// Implementation of PreferencesRepository interface
/// Single Responsibility: Handle application preferences with persistence
class PreferencesRepositoryImpl implements PreferencesRepository {
  final Logger logger = Logger.instance;
  SharedPreferences? _prefs;

  @override
  Future<Result<bool>> getBoolPreference(String key,
      {bool defaultValue = false,}) async {
    try {
      final prefs = await _getPrefs();
      final value = prefs.getBool(key) ?? defaultValue;
      logger.debug('Retrieved bool preference: $key = $value');
      return Right(value);
    } catch (e) {
      final errorMessage = 'Failed to get bool preference $key: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<void>> setBoolPreference(String key, bool value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(key, value);
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
      final prefs = await _getPrefs();
      final value = prefs.getString(key);
      logger.debug('Retrieved string preference: $key = ${value ?? "null"}');
      return Right(value);
    } catch (e) {
      final errorMessage = 'Failed to get string preference $key: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<void>> setStringPreference(String key, String value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(key, value);
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
      final prefs = await _getPrefs();
      await prefs.remove(key);
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
      final prefs = await _getPrefs();
      await prefs.clear();
      logger.info('Cleared all preferences');
      return const Right(null);
    } catch (e) {
      final errorMessage = 'Failed to clear all preferences: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  /// Get SharedPreferences instance with lazy initialization
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Convenience methods for theme preferences
  Future<Result<bool>> getThemePreference() async {
    return getBoolPreference(AppConstants.themePreferenceKey,
        defaultValue: false,);
  }

  Future<Result<void>> setThemePreference(bool isDark) async {
    return setBoolPreference(AppConstants.themePreferenceKey, isDark);
  }

  Future<Result<String?>> getProviderIdPreference() async {
    return getStringPreference(AppConstants.providerIdPreferenceKey);
  }

  Future<Result<void>> setProviderIdPreference(String providerId) async {
    return setStringPreference(AppConstants.providerIdPreferenceKey, providerId);
  }

  Future<Result<String?>> getLocalServiceUrlPreference() async {
    return getStringPreference(AppConstants.localServiceUrlPreferenceKey);
  }

  Future<Result<void>> setLocalServiceUrlPreference(String url) async {
    return setStringPreference(AppConstants.localServiceUrlPreferenceKey, url);
  }

  Future<Result<String?>> getLocalModelDirPreference() async {
    return getStringPreference(AppConstants.localModelDirPreferenceKey);
  }

  Future<Result<void>> setLocalModelDirPreference(String path) async {
    return setStringPreference(AppConstants.localModelDirPreferenceKey, path);
  }

  Future<Result<bool>> getLocalAutoStartPreference() async {
    return getBoolPreference(AppConstants.localAutoStartPreferenceKey, defaultValue: true);
  }

  Future<Result<void>> setLocalAutoStartPreference(bool enabled) async {
    return setBoolPreference(AppConstants.localAutoStartPreferenceKey, enabled);
  }
}

/// Factory for creating PreferencesRepository instances
class PreferencesRepositoryFactory {
  static PreferencesRepository create() {
    return PreferencesRepositoryImpl();
  }
}
