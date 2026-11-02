import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/app_localizations.dart';

/// Estado del permiso de cámara, sin tipos del plugin.
enum CameraAccess {
  granted,

  /// Todavía se puede pedir (nunca se pidió, o se negó una vez).
  denied,

  /// El sistema ya no muestra el diálogo: solo desde los ajustes de la app.
  permanentlyDenied,
}

abstract interface class ICameraPermission {
  Future<CameraAccess> status();
  Future<CameraAccess> request();

  /// Abre los ajustes de la app; false si no se pudo.
  Future<bool> openSettings();
}

/// Permiso del sistema con permission_handler (ya era dependencia). Se usa en
/// Android: el motor nativo abre Camera2 sin pedir el permiso. En iOS lo pide
/// el propio motor (EngineSession.swift, con NSCameraUsageDescription).
final class SystemCameraPermission implements ICameraPermission {
  const SystemCameraPermission();

  static CameraAccess _map(PermissionStatus status) => switch (status) {
        PermissionStatus.granted || PermissionStatus.limited => CameraAccess.granted,
        PermissionStatus.permanentlyDenied || PermissionStatus.restricted => CameraAccess.permanentlyDenied,
        PermissionStatus.denied || PermissionStatus.provisional => CameraAccess.denied,
      };

  @override
  Future<CameraAccess> status() async => _map(await Permission.camera.status);

  @override
  Future<CameraAccess> request() async => _map(await Permission.camera.request());

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// Lo que la persona ya contestó en esta ejecución de la app.
///
/// El diálogo del sistema pone la app en `inactive` y CameraScreen desmonta la
/// vista de la cámara; al volver se monta otra. Sin este registro, a quien
/// dijo que no se le volvería a mostrar la explicación en cada vuelta.
abstract final class CameraPermissionSession {
  static bool declined = false;

  @visibleForTesting
  static void reset() => declined = false;
}

/// Pide la cámara en contexto: si hace falta, primero explica para qué se usa
/// (y que las imágenes no se guardan ni se envían) y recién después muestra el
/// diálogo del sistema. No insiste: si la persona ya dijo que no en esta
/// ejecución, devuelve [CameraAccess.denied] sin preguntar, salvo que el pedido
/// venga de un toque suyo ([userInitiated], el botón "Permitir cámara").
Future<CameraAccess> ensureCameraAccess(
  BuildContext context,
  ICameraPermission permission, {
  bool userInitiated = false,
}) async {
  final current = await permission.status();
  if (current != CameraAccess.denied || !context.mounted) return current;
  if (!userInitiated) {
    if (CameraPermissionSession.declined) return CameraAccess.denied;
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.cameraRationaleTitle),
          content: Text(l10n.cameraRationaleBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cameraRationaleNotNow)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.cameraRationaleContinue)),
          ],
        ),
      );
      if (proceed != true) {
        CameraPermissionSession.declined = true;
        return CameraAccess.denied;
      }
      // La vista se fue con el diálogo abierto: no mostrar el del sistema sin pantalla.
      if (!context.mounted) return CameraAccess.denied;
    }
  }
  final result = await permission.request();
  if (result != CameraAccess.granted) CameraPermissionSession.declined = true;
  return result;
}

/// Lo que se ve sin permiso de cámara: por qué hace falta y cómo darlo.
class CameraDeniedView extends StatelessWidget {
  const CameraDeniedView({
    super.key,
    required this.access,
    required this.onRetry,
    required this.onOpenSettings,
    required this.fallbackText,
  });

  final CameraAccess access;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  /// Texto si no hay AppLocalizations (arnés sin traducciones).
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permanent = access == CameraAccess.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n == null ? fallbackText : '${l10n.cameraDeniedBody}\n\n${l10n.cameraRationaleBody}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
            if (l10n != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: permanent ? onOpenSettings : onRetry,
                child: Text(permanent ? l10n.cameraOpenSettings : l10n.cameraAllow),
              ),
              if (permanent) TextButton(onPressed: onRetry, child: Text(l10n.cameraAllow, style: const TextStyle(color: Colors.white))),
            ],
          ],
        ),
      ),
    );
  }
}
