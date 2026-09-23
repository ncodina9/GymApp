import SwiftUI
import SwiftData
import GymAppNativeCore

struct TodayView: View {
  let plan: TrainingPlan
  @Query private var activeWorkoutRecords: [ActiveWorkoutRecord]
  @Query private var completedWorkoutRecords: [CompletedWorkoutRecord]
  @AppStorage("themeAccent") private var themeAccentRaw = ThemeAccent.blue.rawValue
  @AppStorage("premiumColorScheme") private var premiumSchemeRaw = ""
  @State private var path: [String] = []

  init(plan: TrainingPlan) {
    self.plan = plan
  }

  private var recommendedSession: TrainingSession? {
    if let activeWorkout {
      return activeWorkout.execution.session
    }

    let pendingSessions = plan.sessions
      .filter { !completedSessionIDs.contains($0.sessionID) }
      .sorted { $0.date < $1.date }
    guard !pendingSessions.isEmpty else {
      return plan.sessions.max { $0.date < $1.date }
    }

    let today = Calendar.current.startOfDay(for: .now)
    return pendingSessions.first(where: { session in
      Self.recommendationDate(session) >= today
    }) ?? pendingSessions.first
  }

  private static func recommendationDate(_ session: TrainingSession) -> Date {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    return parser.date(from: session.date) ?? .distantPast
  }

  private var weekSessions: [TrainingSession] {
    guard let recommendedSession else { return [] }
    return plan.sessions.filter { $0.week == recommendedSession.week }
  }

  private var activeWorkout: ActiveWorkoutSnapshot? {
    ActiveWorkoutStore.load(from: activeWorkoutRecords)
  }

  private var completedSessionIDs: Set<String> {
    Set(completedWorkoutRecords.map(\.sessionID))
  }

  var body: some View {
    NavigationStack(path: $path) {
      if let recommendedSession {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(weekSessions) { session in
              NavigationLink(value: session.sessionID) {
                WeekSessionCard(
                  session: session,
                  isRecommended: session.sessionID == recommendedSession.sessionID,
                  isInProgress: activeWorkout?.execution.session.sessionID == session.sessionID,
                  isCompleted: completedSessionIDs.contains(session.sessionID)
                )
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .id("today-theme-\(themeAccentRaw)-\(premiumSchemeRaw)")
        .background(GymCanvas())
        .safeAreaInset(edge: .top, spacing: 0) {
          AccentHeaderCard(
            title: "Semana \(recommendedSession.week)",
            detail: recommendedSession.weekFocusLabel
          )
        }
        .overlay(alignment: .bottomTrailing) {
          NavigationLink {
            SettingsView(plan: plan)
          } label: {
            Image(systemName: "gearshape.fill")
              .font(.headline.weight(.bold))
              .frame(width: 56, height: 56)
              .foregroundStyle(.primary)
              .glassEffect(.regular.interactive(), in: Circle())
          }
          .accessibilityLabel("Opciones")
          .buttonStyle(.plain)
          .padding(.trailing, 20)
          .padding(.bottom, 16)
        }
        .navigationDestination(for: String.self) { sessionID in
          if let session = plan.sessions.first(where: { $0.sessionID == sessionID }) {
            SessionPreviewView(
              session: session,
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
    .background(InteractivePopGestureRestorer())
  }

}

struct WeekSessionCard: View {
  let session: TrainingSession
  let isRecommended: Bool
  let isInProgress: Bool
  let isCompleted: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(session.weekday.capitalized)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(Color.gymSecondaryText)
        Text(Self.dateLabel(session.date))
          .font(.subheadline.weight(.bold))
          .foregroundStyle(Color.gymSecondaryText)
        Spacer()
        HStack(spacing: 6) {
          if isRecommended {
            Image(systemName: "sparkle")
              .font(.caption2.weight(.bold))
              .foregroundStyle(Color.gymAccent)
              .accessibilityLabel("Entrenamiento recomendado")
          }
          if isCompleted {
            SessionStatusBadge(label: "Completado", symbol: "checkmark", color: Color.gymCompleted)
          } else if isInProgress {
            SessionStatusBadge(label: "En curso", symbol: "figure.run", color: Color.gymTertiary)
          }
        }
      }

      Text(session.label)
        .font(.title2.weight(.bold))
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(session.focus)
        .font(.subheadline)
        .foregroundStyle(Color.gymSecondaryText)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 8) {
        SessionMetric(label: "Estimado", value: "\(SessionDurationEstimator.estimate(for: session).totalMinutes)m")
        SessionMetric(label: "Bloques", value: "\(session.exercises.count)")
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(.primary)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(
          isCompleted ? Color.gymCompleted : (isInProgress ? Color.gymTertiary : (isRecommended ? Color.gymAccent : Color.secondary.opacity(0.3))),
          lineWidth: isRecommended || isInProgress || isCompleted ? 2 : 1
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

  private static func sessionDate(_ session: TrainingSession) -> Date {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    return parser.date(from: session.date) ?? .distantPast
  }
}

private struct SessionStatusBadge: View {
  let label: String
  let symbol: String
  let color: Color

  var body: some View {
    Label(label, systemImage: symbol)
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color, in: Capsule())
  }
}

private struct SessionMetric: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 6) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)
      Text(value)
        .font(.title3.weight(.bold))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, minHeight: 54)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 14))
  }
}
