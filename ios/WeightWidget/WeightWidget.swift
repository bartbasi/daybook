// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import SwiftUI
import UIKit
import WidgetKit

// The iPhone home-screen weight widget. It only shows the texts the app wrote
// into the shared App Group (see lib/platform/weight_widget.dart). It never
// writes anything, reads no database, makes no network call and logs nothing.
// The whole widget is one tap target that opens the app on the weight sheet.

/// Shared with the app. Must match both .entitlements files and
/// iosAppGroup in lib/platform/weight_widget.dart.
private let appGroup = "group.io.github.bartbasi.daybook"

/// The app's weight link. home_widget passes a link to Dart only when it has
/// a "homeWidget" query item.
private let weightLink = URL(string: "daybook://weight?homeWidget")!

// The only words that live here: the widget's name and description in the
// widget gallery (lib/strings.dart lists this file). Everything the widget
// shows comes from the app.
private let galleryName = "Daybook weight"
private let galleryDescription = "Your last weight and trend. Tap to log a new one."

struct WeightEntry: TimelineEntry {
  let date: Date
  let title: String
  let weight: String
  let when: String
  let trend: String
  let tap: String

  /// Before the app has ever run nothing is stored, so only the name shows.
  static func neutral() -> WeightEntry {
    WeightEntry(date: Date(), title: galleryName, weight: "", when: "", trend: "", tap: "")
  }

  /// What the app last wrote. An empty text means "show nothing here".
  static func stored() -> WeightEntry {
    let data = UserDefaults(suiteName: appGroup)
    func text(_ key: String) -> String { data?.string(forKey: key) ?? "" }
    let weight = text("weight_value")
    if weight.isEmpty { return neutral() }
    return WeightEntry(
      date: Date(),
      title: text("weight_title"),
      weight: weight,
      when: text("weight_when"),
      trend: text("weight_trend"),
      tap: text("weight_tap"))
  }
}

struct WeightProvider: TimelineProvider {
  func placeholder(in context: Context) -> WeightEntry {
    WeightEntry.neutral()
  }

  func getSnapshot(in context: Context, completion: @escaping (WeightEntry) -> Void) {
    completion(WeightEntry.stored())
  }

  // One entry. The app asks for a new timeline after every change.
  func getTimeline(in context: Context, completion: @escaping (Timeline<WeightEntry>) -> Void) {
    completion(Timeline(entries: [WeightEntry.stored()], policy: .never))
  }
}

struct WeightWidgetView: View {
  let entry: WeightEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      line(entry.title, font: Font.subheadline.weight(.semibold), secondary: true)
      line(entry.weight, font: family == .systemSmall ? Font.title2.bold() : Font.largeTitle.bold())
        .layoutPriority(2)
      line(entry.when, font: Font.footnote, secondary: true)
      line(entry.trend, font: Font.footnote, secondary: true)
      Spacer(minLength: 0)
      line(entry.tap, font: Font.footnote.weight(.semibold))
        .layoutPriority(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(spoken))
    .widgetURL(weightLink)
    .weightWidgetBackground()
  }

  /// One spoken description for the whole tap target.
  private var spoken: String {
    [entry.title, entry.weight, entry.when, entry.trend, entry.tap]
      .filter { !$0.isEmpty }
      .joined(separator: ". ")
  }

  @ViewBuilder
  private func line(_ text: String, font: Font, secondary: Bool = false) -> some View {
    if !text.isEmpty {
      Text(text)
        .font(font)
        .foregroundStyle(
          secondary ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
  }
}

extension View {
  /// iOS 17 and later draw the background and margins from
  /// containerBackground; earlier versions need them in the view.
  @ViewBuilder
  fileprivate func weightWidgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) {
        Color(UIColor.systemBackground)
      }
    } else {
      padding().background(Color(UIColor.systemBackground))
    }
  }
}

@main
struct WeightWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WeightWidget", provider: WeightProvider()) { entry in
      WeightWidgetView(entry: entry)
    }
    .configurationDisplayName(galleryName)
    .description(galleryDescription)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
