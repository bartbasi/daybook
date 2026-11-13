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

SQLite itself is public domain.

Pulled in by the packages above:

| Package | License |
|---|---|
| args, async, characters, code_assets, collection, convert, crypto, ffi, file, glob, hooks, http_parser, jni, jni_flutter, jni_util, logging, meta, native_toolchain_c, objective_c, package_config, path_provider_android, path_provider_foundation, path_provider_linux, path_provider_platform_interface, path_provider_windows, platform, plugin_platform_interface, pub_semver, record_use, source_span, stack_trace, stream_channel, string_scanner, term_glyph, typed_data, vector_math, web, xdg_directories | BSD-3-Clause |
| posix, sqlcipher_flutter_libs, sqlite3_flutter_libs, yaml | MIT |
| material_color_utilities | Apache-2.0 |
| sky_engine (Flutter engine) | BSD-3-Clause for Flutter, plus the permissive licenses of its bundled parts |

home_widget adds no other Dart package (it uses path_provider and path_provider_foundation, listed above). Its Android side uses androidx.glance:glance-appwidget 1.2.0, androidx.core, androidx.work and kotlinx-coroutines-android, all Apache-2.0. Its LICENSE in the pub cache is BSD-3-Clause (Anton Borries), and its own Android manifest declares no permissions. androidx.work (a dependency of home_widget) adds four to the merged manifest: WAKE_LOCK, ACCESS_NETWORK_STATE, RECEIVE_BOOT_COMPLETED and FOREGROUND_SERVICE. The app manifest removes all four with `tools:node="remove"`, because WorkManager is only used by home_widget's background callbacks, which Daybook does not use.

Flutter's `LicenseRegistry` collects all of these notices, so the License screen in About can show them.

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

## Data

Data is not code and keeps its own license. See [data-sources.md](data-sources.md).
