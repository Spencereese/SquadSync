import ActivityKit
import SwiftUI
import WidgetKit

/// Home Screen / lock screen widget and the caller Live Activity.
/// Not compiled into Runner. Add this file to a Widget Extension target
/// named SquadWidget. See the README for the signing steps.
///
/// Keys match the Dart snapshot. The activity map is stored by the
/// live_activities plugin as "<activity id>_<key>" in the App Group.

private let squadAppGroupId = "group.com.spencereese.squadsync"

private struct SquadHomeEntry: TimelineEntry {
  let date: Date
  let whoSummary: String
  let whoNames: String
  let spotLine: String
  let honesty: String
}

private struct SquadHomeProvider: TimelineProvider {
  func placeholder(in context: Context) -> SquadHomeEntry {
    entry(at: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (SquadHomeEntry) -> Void) {
    completion(entry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SquadHomeEntry>) -> Void) {
    let now = Date()
    let next = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
    completion(Timeline(entries: [entry(at: now)], policy: .after(next)))
  }

  private func entry(at date: Date) -> SquadHomeEntry {
    let store = UserDefaults(suiteName: squadAppGroupId)
    return SquadHomeEntry(
      date: date,
      whoSummary: store?.string(forKey: "who_summary") ?? "Open SquadSync",
      whoNames: store?.string(forKey: "who_names") ?? "",
      spotLine: store?.string(forKey: "spot_line") ?? "No spot called.",
      honesty: store?.string(forKey: "honesty")
        ?? "Updates while SquadSync is open. It does not stay live in the background until push exists."
    )
  }
}

private struct SquadHomeView: View {
  let entry: SquadHomeEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(entry.whoSummary)
        .font(.headline)
        .lineLimit(2)
      if !entry.whoNames.isEmpty {
        Text(entry.whoNames)
          .font(.subheadline)
          .lineLimit(2)
      }
      Text(entry.spotLine)
        .font(.footnote)
        .lineLimit(3)
      Text(entry.honesty)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(3)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(12)
  }
}

struct SquadHomeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SquadHomeWidget", provider: SquadHomeProvider()) { entry in
      SquadHomeView(entry: entry)
    }
    .configurationDisplayName("Who's on")
    .description("Who is available, and the open spot. Updates while SquadSync is open.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  public struct ContentState: Codable, Hashable {}
  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

@available(iOS 16.1, *)
struct SquadSpotActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      SquadActivityLockScreen(context: context)
    } dynamicIsland: { context in
      let game = activityText(context, "game", fallback: "Spot")
      let counts = activityCounts(context)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(game).font(.headline).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(counts).font(.headline)
        }
        DynamicIslandExpandedRegion(.bottom) {
          activityCountdown(context)
        }
      } compactLeading: {
        Text(game).lineLimit(1)
      } compactTrailing: {
        activityCountdown(context)
      } minimal: {
        activityCountdown(context)
      }
    }
  }
}

@available(iOS 16.1, *)
private struct SquadActivityLockScreen: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(activityText(context, "game", fallback: "Spot"))
        .font(.headline)
      activityCountdown(context)
      Text(activityCounts(context))
        .font(.subheadline)
      Text("On this phone only. Other members are not shown this yet.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
  }
}

@available(iOS 16.1, *)
private func activityText(
  _ context: ActivityViewContext<LiveActivitiesAppAttributes>,
  _ key: String,
  fallback: String
) -> String {
  let store = UserDefaults(suiteName: squadAppGroupId)
  return store?.string(forKey: context.attributes.prefixedKey(key)) ?? fallback
}

@available(iOS 16.1, *)
private func activityCounts(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
  let store = UserDefaults(suiteName: squadAppGroupId)
  let inCount = Int(store?.string(forKey: context.attributes.prefixedKey("inCount")) ?? "") ?? 0
  let outCount = Int(store?.string(forKey: context.attributes.prefixedKey("outCount")) ?? "") ?? 0
  return "\(inCount) in · \(outCount) out"
}

@available(iOS 16.1, *)
private func activityCountdown(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
  let store = UserDefaults(suiteName: squadAppGroupId)
  let raw = store?.string(forKey: context.attributes.prefixedKey("joinUntilMillis")) ?? ""
  let millis = Double(raw) ?? 0
  let end = Date(timeIntervalSince1970: millis / 1000)
  let start = min(Date(), end)
  return Text(timerInterval: start...end, countsDown: true)
    .monospacedDigit()
    .font(.title3)
}

@main
struct SquadWidgets: WidgetBundle {
  var body: some Widget {
    SquadHomeWidget()
    if #available(iOS 16.1, *) {
      SquadSpotActivity()
    }
  }
}
