import SwiftUI
import SwiftData
import GymAppNativeCore

struct TodayView: View {
  let plan: TrainingPlan
  @Query private var activeWorkoutRecords: [ActiveWorkoutRecord]
  @Query private var completedWorkoutRecords: [CompletedWorkoutRecord]
  @State private var path: [String] = []

  init(plan: TrainingPlan) {
    self.plan = plan
  }

  private var recommendedSession: TrainingSession? {
    let sessionsByWeek = Dictionary(grouping: plan.sessions, by: \.week)
      .values
      .map { $0.sorted { $0.date < $1.date } }
      .sorted { $0[0].week < $1[0].week }

    if let nextWeek = sessionsByWeek.first(where: { week in
      week.contains { !completedSessionIDs.contains($0.sessionID) }
    }) {
      return nextWeek.first
    }

    return plan.sessions.max { $0.date < $1.date }
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
            Text("Semana \(recommendedSession.week) · \(recommendedSession.weekFocusLabel)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

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
        .background(GymCanvas())
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
          .foregroundStyle(.secondary)
        Text(Self.dateLabel(session.date))
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.secondary)
        Spacer()
        if isCompleted {
          Text("Completado")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.gymSuccess)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gymSuccess.opacity(0.14), in: Capsule())
        } else if isInProgress {
          Text("En curso")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.gymWarning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gymWarning.opacity(0.14), in: Capsule())
        } else if isRecommended {
          Image(systemName: "sparkle")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.gymAccent)
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
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(
          isCompleted ? Color.gymSuccess : (isInProgress ? Color.gymWarning : (isRecommended ? Color.gymAccent : Color.secondary.opacity(0.3))),
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
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 14))
  }
}
