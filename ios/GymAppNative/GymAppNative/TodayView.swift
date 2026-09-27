import SwiftUI
import SwiftData
import GymAppNativeCore
import CoreMotion
import Combine

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
              .font(.gymH2.weight(.bold))
              .frame(width: 56, height: 56)
              .foregroundStyle(Color.gymAccentForeground)
              .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Circle())
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var metallicMotion = RecommendedCardMotion()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(session.weekday.capitalized)
          .font(.gymH3.weight(.bold))
          .foregroundStyle(Color.gymSecondaryText)
        Text(Self.dateLabel(session.date))
          .font(.gymH3.weight(.bold))
          .foregroundStyle(Color.gymSecondaryText)
        Spacer()
        HStack(spacing: 6) {
          if isRecommended {
            Image(systemName: "sparkle")
              .font(.gymSupport.weight(.bold))
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
        .font(.gymH1.weight(.bold))
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(session.focus)
        .font(.gymBody)
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
    .background {
      RoundedRectangle(cornerRadius: 22)
        .fill(Color.gymSurface)
      if isRecommended {
        RecommendedCardMetallicSurface(
          horizontalTilt: metallicMotion.horizontalTilt,
          verticalTilt: metallicMotion.verticalTilt
        )
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(
          isCompleted ? Color.gymCompleted : (isInProgress ? Color.gymTertiary : (isRecommended ? Color.gymAccent : Color.secondary.opacity(0.3))),
          lineWidth: isRecommended || isInProgress || isCompleted ? 2 : 1
        )
    }
    .clipShape(RoundedRectangle(cornerRadius: 22))
    .onAppear {
      metallicMotion.start(enabled: isRecommended && !reduceMotion)
    }
    .onChange(of: reduceMotion) { _, reducesMotion in
      metallicMotion.start(enabled: isRecommended && !reducesMotion)
    }
    .onDisappear {
      metallicMotion.stop()
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

private struct RecommendedCardMetallicSurface: View {
  let horizontalTilt: CGFloat
  let verticalTilt: CGFloat

  var body: some View {
    GeometryReader { proxy in
      let shineOffset = CGSize(
        width: horizontalTilt * proxy.size.width * 0.22,
        height: verticalTilt * proxy.size.height * 0.18
      )
      ZStack {
        LinearGradient(
          colors: [
            Color.gymAccent.opacity(0.14),
            Color.gymAccentSecondary.opacity(0.10),
            Color.gymAccent.opacity(0.05),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        // Deliberately oversize the highlight before moving it. A regular
        // gradient is clipped at its own bounds when device tilt changes.
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.30),
            .init(color: Color.gymAccent.opacity(0.05), location: 0.43),
            .init(color: Color.gymAccent.opacity(0.19), location: 0.50),
            .init(color: Color.gymAccent.opacity(0.05), location: 0.57),
            .init(color: .clear, location: 0.70),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .frame(width: proxy.size.width * 1.7, height: proxy.size.height * 1.7)
        .offset(shineOffset)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .clipped()
      .overlay {
        RoundedRectangle(cornerRadius: 22)
          .stroke(
            LinearGradient(
              colors: [Color.gymAccent.opacity(0.52), Color.gymAccent.opacity(0.76), Color.gymAccent.opacity(0.30)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      }
    }
    .allowsHitTesting(false)
  }
}

private final class RecommendedCardMotion: ObservableObject {
  @Published private(set) var horizontalTilt: CGFloat = 0
  @Published private(set) var verticalTilt: CGFloat = 0
  private let motionManager = CMMotionManager()

  func start(enabled: Bool) {
    stop()
    guard enabled, motionManager.isDeviceMotionAvailable else { return }

    motionManager.deviceMotionUpdateInterval = 1 / 30
    motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
      guard let attitude = motion?.attitude else { return }
      self?.horizontalTilt = CGFloat(max(-1, min(1, attitude.roll)))
      self?.verticalTilt = CGFloat(max(-1, min(1, attitude.pitch)))
    }
  }

  func stop() {
    motionManager.stopDeviceMotionUpdates()
    horizontalTilt = 0
    verticalTilt = 0
  }
}

private struct SessionStatusBadge: View {
  let label: String
  let symbol: String
  let color: Color

  var body: some View {
    Label(label, systemImage: symbol)
      .font(.gymSupport.weight(.bold))
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
        .font(.gymSupport.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)
      Text(value)
        .font(.gymH2.weight(.bold))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, minHeight: 54)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 14))
  }
}
