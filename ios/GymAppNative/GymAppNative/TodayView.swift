import SwiftUI
import GymAppNativeCore

struct TodayView: View {
  let plan: TrainingPlan
  @State private var selectedSessionID: String

  init(plan: TrainingPlan) {
    self.plan = plan
    let recommended = plan.sessions.first { $0.date == Self.todayISODate } ?? plan.sessions.first
    _selectedSessionID = State(initialValue: recommended?.sessionID ?? "")
  }

  private var selectedSession: TrainingSession? {
    plan.sessions.first { $0.sessionID == selectedSessionID } ?? plan.sessions.first
  }

  private var weekSessions: [TrainingSession] {
    guard let selectedSession else { return [] }
    return plan.sessions.filter { $0.week == selectedSession.week }
  }

  var body: some View {
    NavigationStack {
      Group {
        if let selectedSession {
          VStack(spacing: 12) {
            Text("Semana \(selectedSession.week) · \(selectedSession.weekFocusLabel)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            TodaySessionCard(session: selectedSession)

            VStack(spacing: 8) {
              ForEach(weekSessions) { session in
                Button {
                  selectedSessionID = session.sessionID
                } label: {
                  WeekSessionRow(session: session, isSelected: session.sessionID == selectedSessionID)
                }
                .buttonStyle(.plain)
              }
            }

            Spacer(minLength: 0)

            NavigationLink {
              SessionPreviewView(session: selectedSession)
            } label: {
              Label("Siguiente", systemImage: "chevron.right")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
          }
          .padding(.horizontal, 16)
          .padding(.top, 12)
          .padding(.bottom, 12)
        } else {
          ContentUnavailableView(
            "No hay entrenamientos",
            systemImage: "calendar.badge.exclamationmark"
          )
        }
      }
    }
  }

  private static var todayISODate: String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }
}

private struct TodaySessionCard: View {
  let session: TrainingSession

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Hoy toca")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(session.label)
        .font(.system(size: 32, weight: .bold))
        .lineLimit(2)
        .frame(height: 92, alignment: .topLeading)
        .padding(.top, 12)

      Text(session.focus)
        .font(.body)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .frame(height: 48, alignment: .topLeading)
        .padding(.top, 8)

      HStack(spacing: 8) {
        TodayMetric(label: "Fecha", value: Self.dateLabel(session.date))
        TodayMetric(label: "Estimado", value: "\(session.estimatedMinutes)m")
        TodayMetric(label: "Bloques", value: "\(session.exercises.count)")
      }
      .padding(.top, 12)
    }
    .padding(16)
    .frame(height: 280)
    .background(.background, in: RoundedRectangle(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20)
        .stroke(.separator, lineWidth: 1)
    }
  }

  private static func dateLabel(_ isoDate: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"

    guard let date = parser.date(from: isoDate) else { return isoDate }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = "EEE, d MMM"
    return formatter.string(from: date).lowercased()
  }
}

private struct TodayMetric: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 7) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Text(value)
        .font(.title3.weight(.bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, minHeight: 72)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
  }
}

private struct WeekSessionRow: View {
  let session: TrainingSession
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(session.weekday)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)

      Text(session.label)
        .font(.title3.weight(.bold))
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 11)
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    .foregroundStyle(isSelected ? .white : .primary)
    .background(
      isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary),
      in: RoundedRectangle(cornerRadius: 18)
    )
    .overlay {
      if !isSelected {
        RoundedRectangle(cornerRadius: 18)
          .stroke(.separator, lineWidth: 1)
      }
    }
  }
}
