# iPhone weight widget

The iPhone home-screen widget shows the last weight, when it was logged, the trend and "Tap to log". The whole widget is one tap target that opens Daybook on the weight sheet. It never writes anything.

## Files

| File | What it is |
|---|---|
| `ios/WeightWidget/WeightWidget.swift` | The widget (WidgetKit and SwiftUI). Kind `WeightWidget`, small and medium sizes |
| `ios/WeightWidget/Info.plist` | The extension's Info.plist. Its version is the app's (`FLUTTER_BUILD_NAME`, `FLUTTER_BUILD_NUMBER`) |
| `ios/WeightWidget/WeightWidget.entitlements` | App Group `group.io.github.bartbasi.daybook` |
| `ios/Runner/Runner.entitlements` | The same App Group for the app |
| `ios/Runner.xcodeproj/project.pbxproj` | Has the `WeightWidget` app extension target, made by the script below |
| `tools/ios/add_widget_target.rb` | Adds the target to the Xcode project |
| `.github/workflows/ios-widget-target.yml` | Runs the script on a Mac in CI, builds, uploads the changed project |

## How the data gets there

1. On every weight save, edit, delete, Undo, units change, at start and when the app comes back, `lib/platform/weight_widget.dart` writes five ready-made texts (`weight_title`, `weight_value`, `weight_when`, `weight_trend`, `weight_tap`). On iOS it first calls home_widget's `setAppGroupId`, so the plugin stores them in `UserDefaults(suiteName: "group.io.github.bartbasi.daybook")`.
2. It then calls `updateWidget` with the iOS name `WeightWidget`, which asks WidgetKit to reload that widget kind.
3. The widget reads the five texts from the same App Group and shows them. If nothing is stored yet (the app has never run), it shows only its name.
4. While the app is open, the texts are also rewritten at local midnight, so "Today" in the widget moves to the new day without the app being closed and reopened.

## How a tap reaches the weight sheet

1. The widget's `widgetURL` is `daybook://weight?homeWidget`. home_widget on iOS passes a link to Dart only when it has a `homeWidget` query item.
2. iOS opens Daybook with that link. From a cold start the plugin keeps it as the initial link; while the app runs it sends it on its `home_widget/updates` channel.
3. `HomeShell` in `lib/app.dart` reads the initial link at start and listens for later ones. `isWeightLink` checks only the scheme and host, so the query item does not matter, and Home opens the weight sheet.

No URL scheme entry is expected to be needed in `ios/Runner/Info.plist`: a widget's link should open its own app, and home_widget's own example app works that way. That rests on the example app, not on a test here, so it is to be confirmed on the iPhone. If a tap does not open Daybook, add a `CFBundleURLTypes` entry for the `daybook` scheme to `ios/Runner/Info.plist`.

The second thing to watch on the iPhone: if a real widget tap produces a route error in the app, set `FlutterDeepLinkingEnabled` to `false` in `ios/Runner/Info.plist`.

## How the target was added (no Mac needed)

The Xcode project cannot be edited by hand safely, so a Ruby script does it with the `xcodeproj` gem on GitHub's macOS runner:

- adds the `WeightWidget` app extension target (bundle id `io.github.bartbasi.daybook.WeightWidget`) with its source, Info.plist and entitlements;
- gives it Debug, Release and Profile configurations on the same Flutter xcconfig files as the Runner, so its version always equals the app's; the deployment target and Swift version are the Runner's;
- sets `CODE_SIGN_ENTITLEMENTS` on the Runner, makes the Runner depend on the extension, and adds an "Embed Foundation Extensions" phase that copies `WeightWidget.appex` into `Runner.app/PlugIns`.

That phase must come before Flutter's "Thin Binary" script phase. After it, Xcode reports a dependency cycle. The script puts it there.

The script stops without changing anything if the target already exists. If it finds parts of the target without the target itself (a half-finished earlier run), it stops and asks for the project file to be restored from git.

## To regenerate the target

1. Restore `ios/Runner.xcodeproj/project.pbxproj` to a version without the target, for example the one before the commit that added it.
2. Commit and push that to a branch, then start the "iOS widget target" workflow on that branch from the Actions tab (or `gh workflow run ios-widget-target.yml --ref <branch>`).
3. When it passes, download the `ios-widget-target` artifact. It holds every file under `ios/` that the script or the build changed, at its path, plus the build log.
4. Copy those files into the repository, commit, and push. The normal CI iOS build then checks that `Runner.app/PlugIns/WeightWidget.appex` exists.

Changing only the Swift code, the Info.plist or the entitlements does not need the script: those files are already in the project.

## Signing (by hand, once, in the Apple Developer portal)

The CI build is unsigned, and an unsigned build ignores entitlements. Before the first signed build:

1. Under Identifiers, create the App Group `group.io.github.bartbasi.daybook`.
2. On the App ID `io.github.bartbasi.daybook`, turn on App Groups and pick that group.
3. Create the App ID `io.github.bartbasi.daybook.WeightWidget`, turn on App Groups and pick the same group.
4. Make a provisioning profile for each of the two App IDs (development for installing on the iPhone, App Store for TestFlight). The app's profile and the widget's profile both have to include the App Group.

5. In Xcode, under Signing and Capabilities, set the team on both targets, Runner and WeightWidget. Automatic signing fails for an extension with no team, and the project rightly sets none.

A signed export in CI later needs a provisioning profile for both bundle ids, `io.github.bartbasi.daybook` and `io.github.bartbasi.daybook.WeightWidget`.

If the widget shows only its name after a weigh-in on a signed build, the App Group is missing from one of the two profiles.

## What CI proves and what only an iPhone can

CI proves the project builds with the extension inside `Runner.app/PlugIns` and with the app's version; the iOS simulator test checks the extension is in the app, that the texts go into the App Group's storage and come back, and that the weight link opens the weight sheet.

Only a signed build on an iPhone shows that the widget can read the App Group, how it looks in light and dark and with large text, that a tap opens the app on the weight sheet, and how long that takes from cold.
