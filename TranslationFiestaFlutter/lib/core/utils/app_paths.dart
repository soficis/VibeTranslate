library;

import 'dart:io';
import 'package:path/path.dart' as path;

/// Portable runtime paths for TranslationFiesta Flutter.
class AppPaths {
  AppPaths._();

  static final AppPaths instance = AppPaths._();

  late final Directory dataDirectory = _resolveDataDirectory();

  Directory get logsDirectory => _ensureSubdirectory('logs');
  Directory get exportsDirectory => _ensureSubdirectory('exports');
  File get settingsFile => File(path.join(dataDirectory.path, 'settings.json'));
  File get logFile =>
      File(path.join(logsDirectory.path, 'TranslationFiestaFlutter.log'));

  Directory _resolveDataDirectory() {
    final override = Platform.environment['TF_APP_HOME']?.trim();
    final resolvedPath = (override != null && override.isNotEmpty)
        ? override
        : path.join(_resolveExecutableDirectory(), 'data');

    final directory = Directory(resolvedPath);
    directory.createSync(recursive: true);
    return directory;
  }

  String _resolveExecutableDirectory() {
    final executablePath = Platform.resolvedExecutable;
    return File(executablePath).parent.path;
  }

  Directory _ensureSubdirectory(String name) {
    final dir = Directory(path.join(dataDirectory.path, name));
    dir.createSync(recursive: true);
    return dir;
  }
}
