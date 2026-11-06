import AppIntents
import SwiftUI
import WidgetKit

let widgetGroupId = "group.com.financetrack.financeTrack"
let widgetKind = "FinanceWidget"

struct FinanceEntry: TimelineEntry {
  let date: Date
  let title: String
  let balance: String
  let spent: String
  let hidden: Bool
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> FinanceEntry {
    load(preview: true)
  }

  func getSnapshot(in context: Context, completion: @escaping (FinanceEntry) -> Void) {
    completion(load(preview: context.isPreview))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FinanceEntry>) -> Void) {
    completion(Timeline(entries: [load(preview: false)], policy: .atEnd))
  }

  private func load(preview: Bool) -> FinanceEntry {
    let data = UserDefaults(suiteName: widgetGroupId)
    let title = data?.string(forKey: "widget_title") ?? ""
    let balance = data?.string(forKey: "widget_balance") ?? ""
    let spent = data?.string(forKey: "widget_spent") ?? ""
    return FinanceEntry(
      date: Date(),
      title: title.isEmpty ? "All accounts" : title,
      balance: balance.isEmpty ? (preview ? "₹1,240" : "₹—") : balance,
      spent: spent.isEmpty ? "Open the app once to show your balance" : spent,
      hidden: data?.bool(forKey: "widget_eye_hidden") ?? false
    )
  }
}

struct ToggleBalanceIntent: AppIntent {
  static var title: LocalizedStringResource = "Show or hide the balance"
  static var isDiscoverable: Bool = false

  func perform() async throws -> some IntentResult {
    let data = UserDefaults(suiteName: widgetGroupId)
    let hidden = data?.bool(forKey: "widget_eye_hidden") ?? false
    data?.set(!hidden, forKey: "widget_eye_hidden")
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    return .result()
  }
}

struct FinanceWidgetView: View {
  var entry: FinanceEntry

  private var ink: Color { Color(red: 0.09, green: 0.19, blue: 0.05) }
  private var leaf: Color { Color(red: 0.18, green: 0.33, blue: 0.06) }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .center) {
          Text(entry.title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(leaf)
          Spacer(minLength: 8)
          Button(intent: ToggleBalanceIntent()) {
            Image(systemName: entry.hidden ? "eye.slash" : "eye")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(ink)
              .frame(width: 28, height: 28)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(entry.hidden ? "Show balance" : "Hide balance")
        }
        Text(entry.hidden ? "₹ ••••" : entry.balance)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(ink)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(entry.hidden ? "Spent •••• this month" : entry.spent)
          .font(.system(size: 12))
          .foregroundStyle(leaf)
          .lineLimit(1)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(red: 0.78, green: 0.96, blue: 0.48))
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

      HStack(spacing: 10) {
        Link(destination: URL(string: "financetrack://type?voice=1&homeWidget")!) {
          Label("Speak", systemImage: "mic.fill")
            .font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        Link(destination: URL(string: "financetrack://type?homeWidget")!) {
          Label("Type", systemImage: "keyboard")
            .font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      }
    }
    .containerBackground(Color(red: 0.11, green: 0.11, blue: 0.12), for: .widget)
  }
}

@main
struct FinanceWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: widgetKind, provider: Provider()) { entry in
      FinanceWidgetView(entry: entry)
    }
    .configurationDisplayName("zyvault")
    .description("Your balance, plus quick voice or typed logging.")
    .supportedFamilies([.systemMedium])
  }
}
