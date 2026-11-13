// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart'
    show Code, Format, ReaderWidget;

/// Why the camera cannot be used.
enum CameraProblem {
  /// The user refused camera access (or turned it off in settings).
  noPermission,

  /// Anything else: no camera, or it would not start.
  unavailable,
}

/// The one place the app touches the camera. The scan screen asks it for a
/// view and hears back one barcode or one problem, so widget tests replace it
/// and never open a camera. Reads EAN-13, EAN-8, UPC-A and UPC-E only. It takes
/// no photo, records no sound and picks nothing from the gallery.
abstract class BarcodeCamera {
  const BarcodeCamera();

  /// The camera view. The phone asks for camera permission the first time this
  /// is built. [onCode] gets the digits of a barcode that was read and
  /// whether it was a UPC-E code (which the app expands to UPC-A), and may be
  /// called again for the same barcode; [onProblem] says the camera cannot be
  /// used.
  Widget view({
    required void Function(String code, bool upcE) onCode,
    required void Function(CameraProblem problem) onProblem,
  });
}

/// The real camera, with flutter_zxing (zxing-cpp runs on the phone).
class ZxingCamera extends BarcodeCamera {
  const ZxingCamera();

  @override
  Widget view({
    required void Function(String code, bool upcE) onCode,
    required void Function(CameraProblem problem) onProblem,
  }) {
    return ReaderWidget(
      codeFormat: Format.ean13 | Format.ean8 | Format.upca | Format.upce,
      // Nothing but the preview and the frame: no flashlight, no camera
      // switch and no gallery.
      showFlashlight: false,
      showToggleCamera: false,
      showGallery: false,
      onScan: (Code code) {
        final text = code.text;
        if (code.isValid && text != null && text.isNotEmpty) {
          onCode(text, code.format == Format.upce);
        }
      },
      onControllerCreated: (controller, error) {
        if (error == null) return;
        // The camera plugin reports a refusal as a CameraException with the
        // code CameraAccessDenied, CameraAccessDeniedWithoutPrompt or
        // CameraAccessRestricted. Its type is not exported by flutter_zxing,
        // and adding the camera package just to name it is not worth it.
        onProblem(
          error.toString().contains('CameraAccess')
              ? CameraProblem.noPermission
              : CameraProblem.unavailable,
        );
      },
    );
  }
}
