library;

import 'dart:io';

String _defaultScriptPath() {
  final sep = Platform.pathSeparator;
  return [
    Directory.current.path,
    'TranslationFiestaLocal',
    'local_service.py',
  ].join(sep);
}

Future<bool> tryStartLocalService({
  String? scriptPath,
  String? modelDir,
  String? serviceUrl,
  bool? autoStart,
}) async {
  final envAutoStart = Platform.environment['TF_LOCAL_AUTOSTART'];
  final shouldAutoStart = autoStart ??
      !(envAutoStart != null &&
          (envAutoStart == '0' || envAutoStart.toLowerCase() == 'false'));
  if (!shouldAutoStart) {
    return false;
  }

  final path =
      scriptPath ?? Platform.environment['TF_LOCAL_SCRIPT'] ?? _defaultScriptPath();
  final file = File(path);
  if (!await file.exists()) {
    return false;
  }

  final python = Platform.environment['PYTHON'] ?? 'python';
  try {
    final env = Map<String, String>.from(Platform.environment);
    if (modelDir != null && modelDir.trim().isNotEmpty) {
      env['TF_LOCAL_MODEL_DIR'] = modelDir.trim();
    }
    if (serviceUrl != null && serviceUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(serviceUrl.trim());
      if (uri != null) {
        if (uri.host.isNotEmpty) {
          env['TF_LOCAL_HOST'] = uri.host;
        }
        if (uri.port > 0) {
          env['TF_LOCAL_PORT'] = uri.port.toString();
        }
      }
    }
    env['TF_LOCAL_AUTOSTART'] = shouldAutoStart ? '1' : '0';
    await Process.start(
      python,
      [file.path, 'serve'],
      mode: ProcessStartMode.detached,
      workingDirectory: file.parent.path,
      environment: {...env, 'PYTHONUNBUFFERED': '1'},
    );
    return true;
  } catch (_) {
    return false;
  }
}
