import SwiftUI
import SwiftData
import GymAppNativeCore

@main
struct GymAppNativeApp: App {
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("premiumColorScheme") private var premiumSchemeRaw = ""
  @AppStorage("keepScreenAwake") private var keepScreenAwake = false

  private var appearance: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
  }

  var body: some Scene {
    WindowGroup {
      ZStack {
        SafeAreaCanvas(color: .gymCanvas)
          .id(premiumSchemeRaw)
        ContentView()
        WatchWorkoutSyncHost()
      }
        .preferredColorScheme(appearance.colorScheme)
        .background(Color.gymCanvas, ignoresSafeAreaEdges: .all)
        .toolbarBackground(.hidden, for: .statusBar)
        .toolbarColorScheme(appearance.colorScheme, for: .statusBar)
        // Native alerts and file pickers inherit this tint. It intentionally
        // differs from the selected visual accent to preserve contrast on all
        // of iOS's system surfaces.
        .tint(.gymSystemAction)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
        .onChange(of: keepScreenAwake) { _, enabled in
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
    }
    .modelContainer(for: [ActiveWorkoutRecord.self, CompletedWorkoutRecord.self])
    .onChange(of: appearanceRaw) { _, _ in WatchWorkoutConnectivity.shared.activate() }
    .onChange(of: premiumSchemeRaw) { _, _ in WatchWorkoutConnectivity.shared.activate() }
  }

}

private struct WatchWorkoutSyncHost: View {
  @Query private var activeWorkoutRecords: [ActiveWorkoutRecord]
  @Query private var completedWorkoutRecords: [CompletedWorkoutRecord]
  @AppStorage("appearanceTheme") private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage("themeAccent") private var accentRaw = ThemeAccent.blue.rawValue
  @AppStorage("premiumColorScheme") private var premiumSchemeRaw = ""
  @State private var plan: TrainingPlan?
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext

  private var updateToken: [Date] {
    activeWorkoutRecords.map(\.updatedAt)
  }

  var body: some View {
    Color.clear
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onAppear {
        loadPlan()
        synchronize()
        retryPendingHealthWorkouts()
      }
      .onChange(of: updateToken) { _, _ in synchronize() }
      .onChange(of: completedWorkoutRecords.map(\.completedAt)) { _, _ in synchronize() }
      .onChange(of: appearanceRaw) { _, _ in synchronize() }
      .onChange(of: colorScheme) { _, _ in synchronize() }
      .onChange(of: accentRaw) { _, _ in synchronize() }
      .onChange(of: premiumSchemeRaw) { _, _ in synchronize() }
      .onChange(of: plan?.planID) { _, _ in synchronize() }
      .onReceive(NotificationCenter.default.publisher(for: .watchWorkoutCommandReceived)) { notification in
        guard let envelope = notification.object as? WatchWorkoutCommandEnvelope else { return }
        if let handler = WatchWorkoutCommandRouter.shared.handler {
          handler(envelope.command)
        } else {
          applyDetachedWatchCommand(envelope.command)
        }
      }
  }

  private func synchronize() {
    let activeWorkout = ActiveWorkoutStore.load(from: activeWorkoutRecords)
    let sessions = todaySessions(
      from: plan,
      activeWorkout: activeWorkout,
      completedSessionIDs: Set(completedWorkoutRecords.map(\.sessionID))
    )
    WatchWorkoutConnectivity.shared.publishCatalog(
      sessions: sessions,
      completedSessionIDs: Set(completedWorkoutRecords.map(\.sessionID)),
      theme: WatchWorkoutTheme(
        appearance: resolvedWatchAppearance,
        accent: accentRaw,
        premiumScheme: premiumSchemeRaw.isEmpty ? nil : premiumSchemeRaw
      )
    )
    if let snapshot = activeWorkout {
      WatchWorkoutConnectivity.shared.publish(snapshot)
    } else {
      WatchWorkoutConnectivity.shared.clear()
    }
  }

  private func retryPendingHealthWorkouts() {
    Task {
      await HealthWorkoutStore.syncPendingIfEnabled(
        records: completedWorkoutRecords,
        in: modelContext
      )
    }
  }

  private var resolvedWatchAppearance: String {
    guard appearanceRaw == AppAppearance.system.rawValue else { return appearanceRaw }
    return colorScheme == .dark ? AppAppearance.dark.rawValue : AppAppearance.light.rawValue
  }

  private func loadPlan() {
    guard let url = Bundle.main.url(forResource: "trainingPlan", withExtension: "json") else { return }
    plan = try? TrainingPlanLoader.decode(data: Data(contentsOf: url))
  }

  private func todaySessions(
    from plan: TrainingPlan?,
    activeWorkout: ActiveWorkoutSnapshot?,
    completedSessionIDs: Set<String>
  ) -> [TrainingSession] {
    guard let plan else { return [] }
    let recommended: TrainingSession?
    if let activeWorkout {
      recommended = activeWorkout.execution.session
    } else {
      let pending = plan.sessions
        .filter { !completedSessionIDs.contains($0.sessionID) }
        .sorted { $0.date < $1.date }
      let today = Calendar.current.startOfDay(for: .now)
      recommended = pending.first(where: { sessionDate($0) >= today }) ?? pending.first
    }
    guard let recommended else { return [] }
    return plan.sessions.filter { $0.week == recommended.week }
  }

  private func sessionDate(_ session: TrainingSession) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: session.date) ?? .distantPast
  }

  private func applyDetachedWatchCommand(_ command: WatchWorkoutCommand) {
    let active = ActiveWorkoutStore.load(from: activeWorkoutRecords)

    switch command {
    case let .startWorkout(sessionID):
      guard active == nil, let session = plan?.sessions.first(where: { $0.sessionID == sessionID }) else { return }
      save(ActiveWorkoutSnapshot(
        execution: WorkoutExecutionState(session: session),
        phase: .workingSet,
        feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "Registrada desde Apple Watch"),
        restEndsAt: nil, restTotalSeconds: 0, setTimerEndsAt: nil, setTimerRemaining: 0,
        reviewExerciseIndexes: [], reviewRestSeconds: 0, exerciseDecisions: [:], startedAt: .now
      ))
    case let .startWarmup(sessionID):
      guard active == nil, let session = plan?.sessions.first(where: { $0.sessionID == sessionID }) else { return }
      let seconds = max(3, UserDefaults.standard.integer(forKey: "warmupMinutes")) * 60
      save(ActiveWorkoutSnapshot(
        execution: WorkoutExecutionState(session: session),
        phase: .workingSet,
        feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "Calentamiento desde Apple Watch"),
        restEndsAt: nil, restTotalSeconds: 0, setTimerEndsAt: nil, setTimerRemaining: 0,
        reviewExerciseIndexes: [], reviewRestSeconds: 0, exerciseDecisions: [:],
        warmupStatus: .running, warmupEndsAt: .now.addingTimeInterval(TimeInterval(seconds)), warmupRemaining: seconds, startedAt: .now
      ))
    case let .prioritizeExercise(sessionID, exerciseIndex):
      if var active {
        guard active.execution.session.sessionID == sessionID,
              active.execution.selectNextBlock(exerciseIndex: exerciseIndex)
        else { return }
        active.phase = .workingSet
        active.restEndsAt = nil
        active.restTotalSeconds = 0
        save(active)
        return
      }
      guard active == nil, let session = plan?.sessions.first(where: { $0.sessionID == sessionID }) else { return }
      var execution = WorkoutExecutionState(session: session)
      guard execution.selectNextBlock(exerciseIndex: exerciseIndex) else { return }
      save(ActiveWorkoutSnapshot(
        execution: execution, phase: .workingSet,
        feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "Registrada desde Apple Watch"),
        restEndsAt: nil, restTotalSeconds: 0, setTimerEndsAt: nil, setTimerRemaining: 0,
        reviewExerciseIndexes: [], reviewRestSeconds: 0, exerciseDecisions: [:], startedAt: .now
      ))
    case let .replaceActiveWorkout(sessionID, startsWithWarmup, exerciseIndex):
      guard let session = plan?.sessions.first(where: { $0.sessionID == sessionID }) else { return }
      var execution = WorkoutExecutionState(session: session)
      if let exerciseIndex, !startsWithWarmup,
         !execution.selectNextBlock(exerciseIndex: exerciseIndex) {
        return
      }
      let warmupSeconds = max(3, UserDefaults.standard.integer(forKey: "warmupMinutes")) * 60
      save(ActiveWorkoutSnapshot(
        execution: execution,
        phase: .workingSet,
        feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "OK"),
        restEndsAt: nil, restTotalSeconds: 0, setTimerEndsAt: nil, setTimerRemaining: 0,
        reviewExerciseIndexes: [], reviewRestSeconds: 0, exerciseDecisions: [:],
        warmupStatus: startsWithWarmup ? .running : .completed,
        warmupEndsAt: startsWithWarmup ? .now.addingTimeInterval(TimeInterval(warmupSeconds)) : nil,
        warmupRemaining: startsWithWarmup ? warmupSeconds : 0,
        startedAt: .now
      ))
    case .requestState:
      synchronize()
    default:
      guard var snapshot = active else { return }
      apply(command, to: &snapshot)
    }
  }

  private func apply(_ command: WatchWorkoutCommand, to snapshot: inout ActiveWorkoutSnapshot) {
    switch command {
    case .continueAfterTimer where snapshot.warmupStatus == .running:
      snapshot.warmupStatus = .completed
      snapshot.warmupEndsAt = nil
      snapshot.warmupRemaining = 0
      save(snapshot)
    case .continueAfterTimer where snapshot.phase == .rest:
      snapshot.phase = .workingSet
      snapshot.restEndsAt = nil
      snapshot.restTotalSeconds = 0
      save(snapshot)
    case let .submitExerciseReview(decisions) where snapshot.phase == .exerciseReview:
      snapshot.exerciseDecisions.merge(decisions) { _, incoming in incoming }
      continueAfterExerciseReview(snapshot: &snapshot)
    case .addRest15 where snapshot.phase == .rest:
      adjustRest(15, snapshot: &snapshot)
      save(snapshot)
    case .subtractRest15 where snapshot.phase == .rest:
      adjustRest(-15, snapshot: &snapshot)
      save(snapshot)
    case .startTimedSet:
      guard snapshot.phase == .workingSet, let current = snapshot.execution.current,
            snapshot.execution.trainingSet(for: current)?.type == .timed,
            snapshot.setTimerEndsAt == nil,
            let duration = snapshot.execution.targets(for: current)?.durationSeconds else { return }
      let remaining = snapshot.setTimerRemaining > 0 ? snapshot.setTimerRemaining : duration
      snapshot.setTimerRemaining = remaining
      snapshot.setTimerEndsAt = .now.addingTimeInterval(TimeInterval(remaining))
      save(snapshot)
    case .pauseTimedSet:
      guard snapshot.phase == .workingSet, let endsAt = snapshot.setTimerEndsAt else { return }
      snapshot.setTimerRemaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
      snapshot.setTimerEndsAt = nil
      save(snapshot)
    case .resetTimedSet:
      guard snapshot.phase == .workingSet, let current = snapshot.execution.current,
            let duration = snapshot.execution.targets(for: current)?.durationSeconds else { return }
      snapshot.setTimerEndsAt = nil
      snapshot.setTimerRemaining = duration
      save(snapshot)
    case let .updateWorkingSet(reps, weightKg):
      guard snapshot.phase == .workingSet, let current = snapshot.execution.current,
            snapshot.execution.trainingSet(for: current)?.type == .working else { return }
      snapshot.execution.updateWorkingTargets(for: current, reps: reps, weightKg: weightKg)
      save(snapshot)
    case let .selectEquipment(equipment):
      guard snapshot.phase == .workingSet,
            let current = snapshot.execution.current,
            snapshot.execution.canSelectEquipment(equipment, for: current),
            snapshot.execution.selectEquipment(equipment, for: current)
      else { return }
      save(snapshot)
    case .registerSet:
      beginFeedback(snapshot: &snapshot)
    case let .submitSetFeedback(feedback):
      guard snapshot.phase == .feedback else { return }
      snapshot.feedback = ActiveWorkoutFeedbackDraft(
        rir: feedback.rir ?? 2,
        painKnee: feedback.painKnee,
        painWrist: feedback.painWrist,
        painShoulder: feedback.painShoulder,
        painLowerBack: feedback.painLowerBack,
        note: feedback.note
      )
      register(snapshot: &snapshot, skipped: false, feedback: feedback)
    case .skipSet:
      register(snapshot: &snapshot, skipped: true)
    default:
      break
    }
  }

  private func adjustRest(_ seconds: Int, snapshot: inout ActiveWorkoutSnapshot) {
    let remaining = max(0, Int((snapshot.restEndsAt ?? .now).timeIntervalSinceNow.rounded(.up)))
    let adjusted = max(0, remaining + seconds)
    snapshot.restEndsAt = .now.addingTimeInterval(TimeInterval(adjusted))
    snapshot.restTotalSeconds = max(snapshot.restTotalSeconds, adjusted)
  }

  private func beginFeedback(snapshot: inout ActiveWorkoutSnapshot) {
    guard snapshot.phase == .workingSet,
          let current = snapshot.execution.current
    else { return }
    let isTimed = snapshot.execution.trainingSet(for: current)?.type == .timed
    if isTimed, snapshot.setTimerEndsAt.map({ $0 > .now }) != false { return }
    snapshot.phase = .feedback
    save(snapshot)
  }

  private func register(
    snapshot: inout ActiveWorkoutSnapshot,
    skipped: Bool,
    feedback: WorkoutSetFeedback = .ok
  ) {
    guard (skipped ? snapshot.phase == .workingSet : snapshot.phase == .feedback),
          let current = snapshot.execution.current
    else { return }
    let isTimed = snapshot.execution.trainingSet(for: current)?.type == .timed
    if isTimed, snapshot.setTimerEndsAt.map({ $0 > .now }) != false { return }
    let advance = skipped
      ? snapshot.execution.skipCurrent()
      : snapshot.execution.recordCurrent(feedback: WorkoutSetFeedback(
          rir: isTimed ? nil : feedback.rir,
          painKnee: feedback.painKnee,
          painWrist: feedback.painWrist,
          painShoulder: feedback.painShoulder,
          painLowerBack: feedback.painLowerBack,
          note: feedback.note
        ))
    guard let advance else { return }
    snapshot.setTimerEndsAt = nil
    snapshot.setTimerRemaining = 0
    snapshot.feedback = ActiveWorkoutFeedbackDraft(
      rir: 2,
      painKnee: 0,
      painWrist: 0,
      painShoulder: 0,
      painLowerBack: 0,
      note: "OK"
    )
    if !advance.reviewExerciseIndexes.isEmpty {
      snapshot.phase = .exerciseReview
      snapshot.reviewExerciseIndexes = advance.reviewExerciseIndexes
      snapshot.reviewRestSeconds = advance.restSeconds ?? 0
      save(snapshot)
      return
    }
    guard advance.next != nil else {
      finish(snapshot)
      return
    }
    if let restSeconds = advance.restSeconds, restSeconds > 0 {
      snapshot.phase = .rest
      snapshot.restTotalSeconds = restSeconds
      snapshot.restEndsAt = .now.addingTimeInterval(TimeInterval(restSeconds))
    } else {
      snapshot.phase = .workingSet
    }
    save(snapshot)
  }

  private func continueAfterExerciseReview(snapshot: inout ActiveWorkoutSnapshot) {
    snapshot.reviewExerciseIndexes = []
    guard snapshot.execution.current != nil else {
      finish(snapshot)
      return
    }
    if snapshot.reviewRestSeconds > 0 {
      snapshot.phase = .rest
      snapshot.restTotalSeconds = snapshot.reviewRestSeconds
      snapshot.restEndsAt = .now.addingTimeInterval(TimeInterval(snapshot.reviewRestSeconds))
      snapshot.reviewRestSeconds = 0
    } else {
      snapshot.phase = .workingSet
    }
    save(snapshot)
  }

  private func save(_ snapshot: ActiveWorkoutSnapshot) {
    ActiveWorkoutStore.save(snapshot, in: modelContext)
    WatchWorkoutConnectivity.shared.publish(snapshot)
  }

  private func finish(_ snapshot: ActiveWorkoutSnapshot) {
    let completedAt = Date.now
    let record = ActiveWorkoutStore.markCompleted(
      sessionID: snapshot.execution.session.sessionID,
      startedAt: snapshot.startedAt,
      completedAt: completedAt,
      execution: snapshot.execution,
      decisions: snapshot.exerciseDecisions,
      in: modelContext
    )
    ActiveWorkoutStore.clear(in: modelContext)
    WatchWorkoutConnectivity.shared.clear()
    if let record {
      Task { await HealthWorkoutStore.syncIfEnabled(record: record, execution: snapshot.execution, in: modelContext) }
    }
  }
}

private struct SafeAreaCanvas: View {
  let color: Color

  var body: some View {
    GeometryReader { proxy in
      color
        .frame(
          width: proxy.size.width,
          height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        )
        .offset(y: -proxy.safeAreaInsets.top)
    }
    .ignoresSafeArea()
  }
}
