// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/nutrients.dart';
import '../../data/off_client.dart';
import '../../platform/barcode.dart';
import '../../strings.dart';

// The barcode scan screen (food-entry.html frame 9) and the lookup that follows
// a scan. The camera comes through [BarcodeCamera], so a widget test never
// opens one. Nothing here is written to a log, and no barcode or product name
// is put in an error.

/// What a scan came to. A cancelled scan is a null result instead.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// The product is saved on the phone; [foodId] is its food row (a barcode that
/// is the user's own food gives that food's id). [serving] is false only for a
/// cached product that has no serving size, so its line is 100 g and Assumed.
class ScanFound extends ScanOutcome {
  const ScanFound(this.foodId, {required this.serving});
  final int foodId;
  final bool serving;
}

/// Nothing was found or saved; [message] says why, in plain words. When
/// [barcode] is set, Open Food Facts has no product for it.
class ScanMessage extends ScanOutcome {
  const ScanMessage(this.message, {this.barcode});
  final String message;
  final String? barcode;
}

/// Finds the food for [code], which is already in its [barcodeForm]. A stored
/// food with that barcode that is not archived (the user's own, or a product
/// cached by an earlier scan) is used with no request at all. Otherwise one
/// request goes to Open Food Facts and the product is saved on the phone. A
/// product with no name or no energy cannot be used and counts as not found,
/// and nothing is saved for it.
Future<ScanOutcome> lookUpBarcode(
  AppDatabase db,
  OffClient? off,
  String code,
) async {
  try {
    final stored = await findFoodByBarcode(db, code);
    if (stored != null) {
      return ScanFound(stored.id, serving: stored.serving);
    }
  } catch (_) {
    // The search failed; the request below is still worth a try.
  }
  final OffProduct? product;
  try {
    if (off == null) return const ScanMessage(S.scanNoConnection);
    product = await off.lookup(code);
  } on ArgumentError {
    return ScanMessage(S.scanNotFound(code), barcode: code);
  } on OffException {
    return const ScanMessage(S.scanNoConnection);
  } catch (_) {
    return const ScanMessage(S.scanNoConnection);
  }
  if (product == null ||
      product.name == product.barcode ||
      !product.nutrients.containsKey(Nutrients.energy)) {
    return ScanMessage(S.scanNotFound(code), barcode: code);
  }
  try {
    return ScanFound(
      await saveOffProduct(db, product),
      serving: product.servingQuantity != null,
    );
  } catch (_) {
    return const ScanMessage(S.scanSaveFailed);
  }
}

/// Opens the scan screen and, once it has a barcode, looks it up. Null when the
/// user closed the screen. The camera permission is asked when the screen
/// opens, never before.
Future<ScanOutcome?> scanBarcode(BuildContext context) {
  final scope = AppScope.of(context);
  return Navigator.of(context).push<ScanOutcome>(
    MaterialPageRoute(
      builder: (_) => BarcodeScanScreen(
        camera: scope.camera,
        lookup: (code) => lookUpBarcode(scope.db, scope.off, code),
      ),
    ),
  );
}

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({
    super.key,
    required this.camera,
    required this.lookup,
  });

  final BarcodeCamera camera;

  /// Looks a barcode up and saves it. The screen shows that it is working and
  /// closes with the answer.
  final Future<ScanOutcome> Function(String code) lookup;

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _number = TextEditingController();
  var _typing = false;
  var _looking = false;
  CameraProblem? _problem;
  String? _numberError;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  /// One lookup at a time: a second code, from the camera or typed, while one
  /// is running does nothing.
  Future<void> _submit(String code, bool upcE) async {
    if (_looking) return;
    setState(() => _looking = true);
    final ScanOutcome outcome;
    try {
      outcome = await widget.lookup(barcodeForm(code, upcE: upcE));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(const ScanMessage(S.scanNoConnection));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  void _onProblem(CameraProblem problem) {
    if (!mounted || _looking) return;
    setState(() => _problem = problem);
  }

  void _lookUpTyped() {
    final code = _number.text.trim();
    final shape = RegExp(r'^(\d{8}|\d{12,14})$').hasMatch(code);
    // An 8 digit number that is not a valid EAN-8 may be a UPC-E.
    final upcE = shape && isUpcE(code);
    if (!shape || !(barcodeCheckOk(code) || upcE)) {
      setState(
        () => _numberError = shape ? S.scanNumberCheck : S.scanNumberBad,
      );
      return;
    }
    setState(() => _numberError = null);
    _submit(code, upcE);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Nothing can be closed while the lookup runs; it ends within seconds.
      canPop: !_looking,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: S.foodClose,
            icon: const Icon(Icons.close),
            onPressed: _looking ? null : () => Navigator.of(context).pop(),
          ),
          title: Semantics(header: true, child: const Text(S.scanTitle)),
        ),
        body: SafeArea(
          child: ContentWidth(
            child: _looking ? _lookingBody() : _body(context),
          ),
        ),
      ),
    );
  }

  Widget _lookingBody() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        liveRegion: true,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(S.scanLooking, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    return LayoutBuilder(
      builder: (context, room) {
        // The words and the buttons never take more than half the height and
        // scroll inside themselves, so the text can be large.
        return Column(
          children: [
            Expanded(child: _main(context)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: room.maxHeight * 0.5),
              child: SingleChildScrollView(child: _bottom(context)),
            ),
          ],
        );
      },
    );
  }

  /// The camera, or the field for typing the number, or what went wrong.
  Widget _main(BuildContext context) {
    if (_typing) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _number,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _lookUpTyped(),
          onChanged: (_) {
            if (_numberError != null) setState(() => _numberError = null);
          },
          decoration: InputDecoration(
            labelText: S.scanNumberLabel,
            errorText: _numberError,
            errorMaxLines: 5,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }
    final problem = _problem;
    if (problem != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: true,
            child: Text(
              problem == CameraProblem.noPermission
                  ? S.scanNoPermission
                  : S.scanCameraFailed,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: S.scanHelp,
      child: widget.camera.view(onCode: _submit, onProblem: _onProblem),
    );
  }

  Widget _bottom(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_typing && _problem == null) ...[
            Text(S.scanHelp, textAlign: TextAlign.center),
            const SizedBox(height: 4),
          ],
          Text(S.scanPrivacy, textAlign: TextAlign.center, style: small),
          const SizedBox(height: 12),
          if (_typing)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _lookUpTyped,
              child: const Text(S.scanLookUp),
            ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => setState(() {
              _typing = !_typing;
              _numberError = null;
            }),
            child: Text(
              _typing ? S.scanUseCamera : S.scanTypeNumber,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
