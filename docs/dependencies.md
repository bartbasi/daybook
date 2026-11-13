# Dependencies

Every package Daybook uses, with its license. Daybook is GPL-3.0 with additional terms (see NOTICE). MIT, BSD and Apache 2.0 are all compatible with GPL-3.0.

Licenses were read from each package's LICENSE file in the pub cache on 2026-11-08. Update this file whenever `pubspec.yaml` changes.

## Shipped in the app

Direct dependencies:

| Package | Version | License | Why |
|---|---|---|---|
| flutter (SDK) | 3.47.7 | BSD-3-Clause | App framework |
| drift | 2.35.3 | MIT | Local database, migrations |
| drift_flutter | 0.3.1 | MIT | Opens the drift database on the device |
| sqlite3 | 3.9.1 | MIT | SQLite bindings; also reads the bundled USDA database |
| path_provider | 2.1.6 | BSD-3-Clause | Finds the app's private folder |
| path | 1.9.1 | BSD-3-Clause | File path joins |
| http | 1.6.0 | BSD-3-Clause | Open Food Facts barcode lookup (the only network call) |
| archive | 4.6.0 | MIT | Zip file for export and import |
| home_widget | 0.10.0 | BSD-3-Clause | Passes the last weight to the home-screen widget and reports a tap on it |
| flutter_zxing | 3.1.1 | MIT | Reads barcodes from the camera, on the phone (the zxing-cpp code is compiled into the app) |

SQLite itself is public domain.

Pulled in by the packages above:

| Package | License |
|---|---|
| args, async, characters, code_assets, collection, convert, crypto, ffi, file, glob, hooks, http_parser, jni, jni_flutter, jni_util, logging, meta, native_toolchain_c, objective_c, package_config, path_provider_android, path_provider_foundation, path_provider_linux, path_provider_platform_interface, path_provider_windows, platform, plugin_platform_interface, pub_semver, record_use, source_span, stack_trace, stream_channel, string_scanner, term_glyph, typed_data, vector_math, web, xdg_directories | BSD-3-Clause |
| camera 0.12.2, camera_android_camerax 0.7.6+1, camera_avfoundation 0.11.1, camera_platform_interface 2.15.0, camera_web 0.3.6, cross_file 0.3.5+5, file_selector_linux 0.9.4+1, file_selector_macos 0.9.5+2, file_selector_platform_interface 2.7.0, file_selector_windows 0.9.3+6, flutter_plugin_android_lifecycle 2.0.35, flutter_web_plugins (Flutter SDK), image_picker_for_web 3.1.1, image_picker_linux 0.2.2, image_picker_macos 0.2.2+1, image_picker_platform_interface 2.11.2, image_picker_windows 0.2.2 | BSD-3-Clause |
| image_picker 1.2.4, image_picker_android 0.8.13+25, image_picker_ios 0.8.13+15 | BSD-3-Clause and Apache-2.0 (both texts are in their LICENSE files) |
| image 4.12.0 | MIT |
| posix, sqlcipher_flutter_libs, sqlite3_flutter_libs, yaml | MIT |
| material_color_utilities | Apache-2.0 |
| sky_engine (Flutter engine) | BSD-3-Clause for Flutter, plus the permissive licenses of its bundled parts |

home_widget adds no other Dart package (it uses path_provider and path_provider_foundation, listed above). Its Android side uses androidx.glance:glance-appwidget 1.2.0, androidx.core, androidx.work and kotlinx-coroutines-android, all Apache-2.0. androidx.datastore comes in through Glance (home_widget's Kotlin code imports it), also Apache-2.0. androidx.room comes in through WorkManager, also Apache-2.0. Its LICENSE in the pub cache is BSD-3-Clause (Anton Borries), and its own Android manifest declares no permissions. androidx.work (a dependency of home_widget) adds four to the merged manifest: WAKE_LOCK, ACCESS_NETWORK_STATE, RECEIVE_BOOT_COMPLETED and FOREGROUND_SERVICE. The app manifest removes all four with `tools:node="remove"`, because WorkManager is only used by home_widget's background callbacks, which Daybook does not use.

flutter_zxing decodes on the phone: zxing-cpp is compiled into the app (Android through CMake and the NDK, iOS from the sources in the package). In the 3.1.1 archive the zxing-cpp files carry Apache-2.0 notices, the bundled libzueci is BSD-3-Clause, and the bundled zint barcode library has its own BSD-style license (its LICENSE file, which asks that the names of its authors are kept). It uses no Google Play services, no ML Kit and no network call in the way Daybook uses it. Its network functions, `readBarcodeImageUrl`, `readBarcodesImageUrl`, `zxingReadBarcodeImageUrl` and `zxingReadBarcodesImageUrl`, are never called, and `test/guards_test.dart` fails if any name with `ImageUrl` in it appears in `lib/`. The camera plugin's Android side uses AndroidX CameraX (Apache-2.0). `camera`, `image` and `image_picker` come in only because flutter_zxing needs them; Daybook uses none of them directly. It never records sound, takes no photo and picks nothing from the gallery. The camera plugin adds `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` (with `maxSdkVersion` 28) to the merged Android manifest. No package declares `READ_EXTERNAL_STORAGE`: the manifest merger adds it as an implied permission because camera_android_camerax declares `WRITE_EXTERNAL_STORAGE`. The app manifest removes all three with `tools:node="remove"`. Only `CAMERA` stays. image_picker also adds a service that asks Google Play services to install a photo picker; the app manifest removes it, because Daybook never picks photos. The camera is asked for when the scan screen first opens.

home_widget's iOS side imports only Apple frameworks (AppIntents, Intents, UIKit, WidgetKit) and Flutter. The iPhone widget itself (`ios/WeightWidget/`) uses only WidgetKit and SwiftUI, which are part of iOS.

Flutter's `LicenseRegistry` collects the notices of the Dart packages and the Flutter engine only. It does not see native code that is compiled into the app.

**Note for task 8.x (About screen):** the license list in About must be given the notices of zxing-cpp (Apache-2.0), zint (BSD-style, its authors named in its LICENSE) and CameraX (Apache-2.0) by hand, because they are not in `LicenseRegistry`. libzueci (BSD-3-Clause) goes in with zxing-cpp.

## Build and test only (not shipped)

| Package or tool | License | Why |
|---|---|---|
| drift_dev | MIT | Generates database code and schema snapshots |
| build_runner | BSD-3-Clause | Runs code generation |
| flutter_test (SDK) | BSD-3-Clause | Tests |
| integration_test (SDK) | BSD-3-Clause | Part of the Flutter SDK. Runs the app on the Android emulator and iOS simulator in CI |
| flutter_lints | BSD-3-Clause | Lint rules |
| Python 3 standard library | PSF-2.0 | `tools/build_food_db.py` builds the USDA asset |
| actions/checkout, actions/setup-java, actions/upload-artifact | MIT | GitHub Actions CI |
| subosito/flutter-action | MIT | Installs Flutter in CI |
| flutter_driver (SDK), fuchsia_remote_debug_protocol (SDK), process, sync_http (pulled in by integration_test) | BSD-3-Clause | Dev only |
| webdriver (pulled in by integration_test) | Apache-2.0 | Dev only |
| reactivecircus/android-emulator-runner | Apache-2.0 | Android emulator for the integration test job in CI |
| xcodeproj (Ruby gem, comes with CocoaPods on GitHub's macOS runners) and Ruby | MIT (xcodeproj); Ruby license or BSD-2-Clause (Ruby) | `tools/ios/add_widget_target.rb` adds the iPhone widget target to the Xcode project. Run by hand in CI only |

## Data

Data is not code and keeps its own license. See [data-sources.md](data-sources.md).
