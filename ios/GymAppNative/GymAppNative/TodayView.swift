import SwiftUI
import SwiftData
import GymAppNativeCore

struct TodayView: View {
  let plan: TrainingPlan
  @Query private var activeWorkoutRecords: [ActiveWorkoutRecord]

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
    NavigationStack {
      if let recommendedSession {
        ScrollView {
          VStack(spacing: 12) {
            Text("Semana \(recommendedSession.week) · \(recommendedSession.weekFocusLabel)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink {
              SessionPreviewView(session: recommendedSession, activeWorkout: activeWorkout)
            } label: {
              TodaySessionCard(session: recommendedSession)
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
              ForEach(weekSessions) { session in
                NavigationLink {
                  SessionPreviewView(session: session, activeWorkout: activeWorkout)
                } label: {
                  WeekSessionRow(
                    session: session,
                    isRecommended: session.sessionID == recommendedSession.sessionID,
                    isInProgress: activeWorkout?.execution.session.sessionID == session.sessionID
                  )
                }
                .buttonStyle(.plain)
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
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

      TodayMetric(label: "Fecha", value: Self.dateLabel(session.date))

      HStack(spacing: 8) {
        TodayMetric(label: "Estimado", value: "\(session.estimatedMinutes)m")
        TodayMetric(label: "Bloques", value: "\(session.exercises.count)")
      }
      .padding(.top, 8)
    }
    .padding(16)
    .frame(height: 340)
    .background(.background, in: RoundedRectangle(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20)
        .stroke(Color.accentColor, lineWidth: 2)
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
    .frame(maxWidth: .infinity, minHeight: 58)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
  }
}

private struct WeekSessionRow: View {
  let session: TrainingSession
  let isRecommended: Bool
  let isInProgress: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(session.weekday)
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
        .font(.title3.weight(.bold))
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 11)
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    .foregroundStyle(.primary)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(isInProgress ? Color.orange : (isRecommended ? Color.accentColor : Color.secondary.opacity(0.3)), lineWidth: isRecommended || isInProgress ? 2 : 1)
    }
  }
}
