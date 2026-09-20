import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PeacockLockWidgetBundle: WidgetBundle {
  var body: some Widget {
    FillPinLiveActivityWidget()
  }
}

/// Fill PIN lock-screen + Dynamic Island. Sit / Coming / Can't are
/// interactive on iOS 17+ via FillPinLockScreenIntent. Banner tap uses
/// the existing chat deep link (hold t=0 / I'm in still open the app).
@available(iOS 16.2, *)
struct FillPinLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: FillPinAttributes.self) { context in
      FillPinLockScreenBanner(
        attributes: context.attributes,
        state: context.state
      )
    } dynamicIsland: { context in
      FillPinDynamicIsland(
        attributes: context.attributes,
        state: context.state
      ).island
    }
  }
}

@available(iOS 16.2, *)
struct FillPinLockScreenBanner: View {
  let attributes: FillPinAttributes
  let state: FillPinAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(state.title.isEmpty ? "Fill PIN" : state.title)
          .font(.headline)
        Spacer()
        if state.isComing && !state.holdLabel.isEmpty {
          Text(state.holdLabel)
            .font(.title3.monospacedDigit().weight(.semibold))
        }
      }
      Text(state.body.isEmpty ? state.seatLabel : state.body)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if state.isLive {
        FillPinActionRow(attributes: attributes, state: state)
      }
    }
    .padding(12)
    .widgetURL(state.openURL)
  }
}

@available(iOS 16.2, *)
struct FillPinActionRow: View {
  let attributes: FillPinAttributes
  let state: FillPinAttributes.ContentState

  var body: some View {
    if #available(iOS 17.0, *) {
      HStack(spacing: 8) {
        ForEach(Array(zip(state.actionIds, state.actions)), id: \.0) { id, label in
          Button(
            intent: FillPinLockScreenIntent(
              actionId: id,
              chatGroupId: attributes.chatGroupId,
              pinId: attributes.pinId,
              lobbyId: attributes.lobbyId
            )
          ) {
            Text(label)
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .tint(FillPinActionTint.color(for: id))
        }
      }
    } else {
      HStack(spacing: 8) {
        ForEach(state.actions, id: \.self) { label in
          Text(label)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
      }
    }
  }
}

enum FillPinActionTint {
  static func color(for actionId: String) -> Color {
    switch actionId {
    case "sit":
      return .green
    case "coming":
      return .orange
    case "cant":
      return .red
    default:
      return .accentColor
    }
  }
}

@available(iOS 16.2, *)
struct FillPinDynamicIsland {
  let attributes: FillPinAttributes
  let state: FillPinAttributes.ContentState

  var island: DynamicIsland {
    DynamicIsland {
      DynamicIslandExpandedRegion(.leading) {
        Text(state.seatLabel)
          .font(.headline)
      }
      DynamicIslandExpandedRegion(.trailing) {
        if state.isComing {
          Text(state.holdLabel.isEmpty ? "Coming" : state.holdLabel)
            .font(.headline.monospacedDigit())
        } else {
          Text(state.gameName.isEmpty ? "PIN" : state.gameName)
            .font(.subheadline)
        }
      }
      DynamicIslandExpandedRegion(.bottom) {
        if state.isLive {
          FillPinActionRow(attributes: attributes, state: state)
        }
      }
    } compactLeading: {
      Text(state.seatLabel)
    } compactTrailing: {
      Text(state.isComing ? (state.holdLabel.isEmpty ? "…" : state.holdLabel) : "PIN")
    } minimal: {
      Text("P")
    }
    .widgetURL(state.openURL)
  }
}
