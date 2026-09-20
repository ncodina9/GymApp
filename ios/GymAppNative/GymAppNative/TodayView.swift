import SwiftUI
import SwiftData
import GymAppNativeCore

struct TodayView: View {
  let plan: TrainingPlan
  @Query private var activeWorkoutRecords: [ActiveWorkoutRecord]
  @State private var path: [String] = []

  init(plan: TrainingPlan) {
    self.plan = plan
  }

  private var recommendedSession: TrainingSession? {
    plan.sessions.first { $0.date == Self.todayISODate } ?? plan.sessions.first
  }

  private var weekSessions: [TrainingSession] {
    guard let recommendedSession else { return [] }
    return plan.sessions.filter { $0.week == recommendedSession.week }
  }

  private var activeWorkout: ActiveWorkoutSnapshot? {
    ActiveWorkoutStore.load(from: activeWorkoutRecords)
  }

  var body: some View {
    NavigationStack(path: $path) {
      if let recommendedSession {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            Text("Semana \(recommendedSession.week) · \(recommendedSession.weekFocusLabel)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(weekSessions) { session in
              NavigationLink(value: session.sessionID) {
                WeekSessionCard(
                  session: session,
                  isRecommended: session.sessionID == recommendedSession.sessionID,
                  isInProgress: activeWorkout?.execution.session.sessionID == session.sessionID
                )
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(for: String.self) { sessionID in
          if let session = plan.sessions.first(where: { $0.sessionID == sessionID }) {
            SessionPreviewView(
              session: session,
              activeWorkout: activeWorkout,
              onReturnHome: { path.removeAll() }
            )
          }
        }
      } else {
        ContentUnavailableView(
          "No hay entrenamientos",
          systemImage: "calendar.badge.exclamationmark"
        )
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

private struct WeekSessionCard: View {
  let session: TrainingSession
  let isRecommended: Bool
  let isInProgress: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(session.weekday.capitalized)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.secondary)
        Text(Self.dateLabel(session.date))
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        if isInProgress {
          Text("En curso")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12), in: Capsule())
        } else if isRecommended {
          Image(systemName: "sparkle")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.accentColor)
        }
      }

      Text(session.label)
        .font(.title2.weight(.bold))
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(session.focus)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 8) {
        SessionMetric(label: "Estimado", value: "\(session.estimatedMinutes)m")
        SessionMetric(label: "Bloques", value: "\(session.exercises.count)")
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(.primary)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(
          isInProgress ? Color.orange : (isRecommended ? Color.accentColor : Color.secondary.opacity(0.3)),
          lineWidth: isRecommended || isInProgress ? 2 : 1
        )
    }
  }

  private static func dateLabel(_ isoDate: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: isoDate) else { return isoDate }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = "d MMM"
    return formatter.string(from: date).lowercased()
  }
}

private struct SessionMetric: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 6) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3.weight(.bold))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, minHeight: 54)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }
}
