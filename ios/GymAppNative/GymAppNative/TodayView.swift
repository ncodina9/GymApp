import SwiftUI
import GymAppNativeCore

struct TodayView: View {
  let plan: TrainingPlan

  private var session: TrainingSession? {
    plan.sessions.first { $0.date == Self.todayISODate } ?? plan.sessions.first
  }

  var body: some View {
    NavigationStack {
      Group {
        if let session {
          VStack(alignment: .leading, spacing: 20) {
            Text("Semana \(session.week) · \(session.weekFocusLabel)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)

            Text(session.label)
              .font(.largeTitle.weight(.bold))

            Text(session.focus)
              .font(.title3)
              .foregroundStyle(.secondary)

            HStack(spacing: 12) {
              Metric(label: "Ejercicios", value: "\(session.exercises.count)")
              Metric(label: "Estimado", value: "\(session.estimatedMinutes)m")
              Metric(
                label: "Bloques",
                value: "\(Set(session.exercises.map(\.block)).count)"
              )
            }

            Spacer()
          }
          .padding(24)
          .navigationTitle("Hoy")
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

private struct Metric: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 6) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title2.weight(.bold))
    }
    .frame(maxWidth: .infinity, minHeight: 84)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
  }
}
