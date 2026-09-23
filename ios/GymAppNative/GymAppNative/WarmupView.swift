import SwiftUI
import SwiftData
import GymAppNativeCore

struct WarmupView: View {
  let session: TrainingSession
  let configuredSeconds: Int
  let snapshot: ActiveWorkoutSnapshot?

  @State private var execution: WorkoutExecutionState
  @State private var startedAt: Date
  @State private var endsAt: Date?
  @State private var remaining: Int
  @State private var hasCompleted = false
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  init(
    session: TrainingSession,
    configuredSeconds: Int,
    snapshot: ActiveWorkoutSnapshot? = nil
  ) {
    self.session = session
    self.configuredSeconds = configuredSeconds
    self.snapshot = snapshot
    _execution = State(initialValue: snapshot?.execution ?? WorkoutExecutionState(session: session))
    _startedAt = State(initialValue: snapshot?.startedAt ?? .now)
    _endsAt = State(initialValue: snapshot?.warmupEndsAt)
    _remaining = State(initialValue: snapshot?.warmupRemaining ?? configuredSeconds)
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let secondsLeft = remainingSeconds(at: context.date)
      let progress = CGFloat(secondsLeft) / CGFloat(max(configuredSeconds, 1))

      VStack(spacing: 18) {
        Text("Calentamiento")
          .font(.system(size: 31, weight: .bold))
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("Prepara el cuerpo antes de la primera serie.")
          .font(.subheadline)
          .foregroundStyle(Color.gymSecondaryText)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: 0)

        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 30)
            .fill(Color.gymAccentSecondary)

          GeometryReader { proxy in
            Rectangle()
              .fill(Color.gymAccent)
              .frame(width: proxy.size.width * progress)
          }

          VStack(spacing: 6) {
            Text("Tiempo restante")
              .font(.headline.weight(.bold))
            Text(clock(secondsLeft))
              .font(.system(size: 64, weight: .bold))
              .monospacedDigit()
              .contentTransition(.numericText())
          }
          .foregroundStyle(Color.gymAccentForeground)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .animation(.linear(duration: 0.85), value: secondsLeft)

        Spacer(minLength: 0)

        Button("Continuar", action: completeWarmup)
          .font(.headline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 64)
          .foregroundStyle(Color.gymAccentForeground)
          .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
          .buttonStyle(.plain)
      }
      .padding(16)
      .onChange(of: secondsLeft) { _, newValue in
        if newValue == 0, endsAt != nil {
          completeWarmup()
        }
      }
    }
    .background(GymCanvas())
    .toolbar(.hidden, for: .navigationBar)
    .onAppear(perform: startOrRestore)
    .onDisappear {
      if !hasCompleted {
        persist(status: .running)
      }
    }
  }

  private func startOrRestore() {
    if endsAt == nil {
      let duration = max(remaining, configuredSeconds)
      remaining = duration
      endsAt = .now.addingTimeInterval(TimeInterval(duration))
    }
    persist(status: .running)
  }

  private func remainingSeconds(at date: Date) -> Int {
    guard let endsAt else { return remaining }
    return max(0, Int(endsAt.timeIntervalSince(date).rounded(.up)))
  }

  private func completeWarmup() {
    guard !hasCompleted else { return }
    hasCompleted = true
    endsAt = nil
    remaining = 0
    persist(status: .completed)
    dismiss()
  }

  private func persist(status: WorkoutWarmupStatus) {
    ActiveWorkoutStore.save(
      ActiveWorkoutSnapshot(
        execution: execution,
        phase: .workingSet,
        feedback: ActiveWorkoutFeedbackDraft(
          rir: 2,
          painKnee: 0,
          painWrist: 0,
          painShoulder: 0,
          painLowerBack: 0,
          note: "OK"
        ),
        restEndsAt: nil,
        restTotalSeconds: 0,
        setTimerEndsAt: nil,
        setTimerRemaining: 0,
        reviewExerciseIndexes: [],
        reviewRestSeconds: 0,
        exerciseDecisions: [:],
        warmupStatus: status,
        warmupEndsAt: status == .running ? endsAt : nil,
        warmupRemaining: status == .running ? remainingSeconds(at: .now) : 0,
        startedAt: startedAt
      ),
      in: modelContext
    )
  }

  private func clock(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
  }
}
