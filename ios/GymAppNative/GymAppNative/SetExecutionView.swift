import SwiftUI
import SwiftData
import AudioToolbox
import UserNotifications
import UIKit
import GymAppNativeCore

struct SetExecutionView: View {
  @State private var session: TrainingSession
  let onFinishToToday: () -> Void
  @State private var execution: WorkoutExecutionState
  @State private var phase: ExecutionPhase = .workingSet
  @State private var feedbackRir = 2
  @State private var feedbackPainKnee = 0
  @State private var feedbackPainWrist = 0
  @State private var feedbackPainShoulder = 0
  @State private var feedbackPainLowerBack = 0
  @State private var feedbackNote = "OK"
  @State private var restEndsAt: Date?
  @State private var restTotalSeconds = 0
  @State private var setTimerEndsAt: Date?
  @State private var setTimerRemaining = 0
  @State private var reviewExerciseIndexes: [Int] = []
  @State private var reviewRestSeconds = 0
  @State private var exerciseDecisions: [String: String] = [:]
  @State private var warmupStatus: WorkoutWarmupStatus = .completed
  @State private var warmupEndsAt: Date?
  @State private var warmupRemaining = 0
  @State private var transitionOrigin: ExecutionPhase = .workingSet
  @State private var transitionDirection: FlowDirection = .forward
  @State private var startedAt: Date
  @State private var finishedAt: Date?
  @State private var isExerciseHistoryPresented = false
  @State private var isCoachGuidancePresented = false
  @State private var isSessionActionMenuPresented = false
  @State private var showsWorkoutProgress = false
  @State private var showsFinishConfirmation = false
  @State private var wasReplacedFromWatch = false
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  init(session: TrainingSession, onFinishToToday: @escaping () -> Void = {}) {
    _session = State(initialValue: session)
    self.onFinishToToday = onFinishToToday
    _execution = State(initialValue: WorkoutExecutionState(session: session))
    _startedAt = State(initialValue: .now)
  }

  init(snapshot: ActiveWorkoutSnapshot, onFinishToToday: @escaping () -> Void = {}) {
    _session = State(initialValue: snapshot.execution.session)
    self.onFinishToToday = onFinishToToday
    _execution = State(initialValue: snapshot.execution)
    _phase = State(initialValue: ExecutionPhase(snapshot.phase))
    _feedbackRir = State(initialValue: snapshot.feedback.rir)
    _feedbackPainKnee = State(initialValue: snapshot.feedback.painKnee)
    _feedbackPainWrist = State(initialValue: snapshot.feedback.painWrist)
    _feedbackPainShoulder = State(initialValue: snapshot.feedback.painShoulder)
    _feedbackPainLowerBack = State(initialValue: snapshot.feedback.painLowerBack)
    _feedbackNote = State(initialValue: snapshot.feedback.note)
    _restEndsAt = State(initialValue: snapshot.restEndsAt)
    _restTotalSeconds = State(initialValue: snapshot.restTotalSeconds)
    _setTimerEndsAt = State(initialValue: snapshot.setTimerEndsAt)
    _setTimerRemaining = State(initialValue: snapshot.setTimerRemaining)
    _reviewExerciseIndexes = State(initialValue: snapshot.reviewExerciseIndexes)
    _reviewRestSeconds = State(initialValue: snapshot.reviewRestSeconds)
    _exerciseDecisions = State(initialValue: snapshot.exerciseDecisions)
    _warmupStatus = State(initialValue: snapshot.warmupStatus)
    _warmupEndsAt = State(initialValue: snapshot.warmupEndsAt)
    _warmupRemaining = State(initialValue: snapshot.warmupRemaining)
    _startedAt = State(initialValue: snapshot.startedAt)
  }

  var body: some View {
    ZStack {
      Group {
        switch phase {
        case .workingSet:
          if let locator = execution.current {
            WorkingSetView(
              execution: $execution,
              locator: locator,
              onContinue: { move(to: .feedback, direction: .forward) },
              onSkip: skipCurrentSet,
              timerEndsAt: $setTimerEndsAt,
              timerRemaining: $setTimerRemaining,
              onExecutionChanged: persistActiveWorkout,
              onSessionActionsRequested: { showSessionActionMenu() },
              isCoachGuidancePresented: $isCoachGuidancePresented
            )
          } else {
            FinishedWorkoutView(
              execution: execution,
              startedAt: startedAt,
              finishedAt: finishedAt ?? .now,
              exerciseDecisions: exerciseDecisions,
              onFinish: onFinishToToday
            )
          }
        case .feedback:
          if let locator = execution.current {
            FeedbackView(
              execution: execution,
              locator: locator,
              rir: $feedbackRir,
              painKnee: $feedbackPainKnee,
              painWrist: $feedbackPainWrist,
              painShoulder: $feedbackPainShoulder,
              painLowerBack: $feedbackPainLowerBack,
              note: $feedbackNote,
              onBack: { move(to: .workingSet, direction: .backward) },
              onRegister: registerCurrentSet,
              onSessionActionsRequested: { showSessionActionMenu() }
            )
          }
        case .rest:
          if let restEndsAt, let next = execution.current {
            RestView(
              execution: $execution,
              next: next,
              endsAt: restEndsAt,
              totalSeconds: restTotalSeconds,
              onAdjust: adjustRest,
              onContinue: continueFromRest,
              onSelectBlock: selectNextBlock,
              onExecutionChanged: persistActiveWorkout
            )
          }
        case .exerciseReview:
          ExerciseReviewView(
            exercises: reviewExerciseIndexes.compactMap { execution.session.exercises.indices.contains($0) ? execution.session.exercises[$0] : nil },
            decisions: $exerciseDecisions,
            isFinalReview: execution.current == nil,
            onContinue: continueAfterExerciseReview
          )
        case .finished:
          FinishedWorkoutView(
            execution: execution,
            startedAt: startedAt,
            finishedAt: finishedAt ?? .now,
            exerciseDecisions: exerciseDecisions,
            onFinish: onFinishToToday
          )
        }
      }
      .id(TransitionKey(origin: transitionOrigin, destination: phase))
      .transition(transition)
      .zIndex(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(GymCanvas())
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !isExerciseHistoryPresented && !isCoachGuidancePresented {
        WorkoutProgressBar(
          completed: execution.completedSetCount,
          total: execution.totalSetCount
        )
      }
    }
    .overlay {
      if isSessionActionMenuPresented {
        SessionActionFan(
          completed: execution.records.count,
          total: execution.totalSetCount,
          onDismiss: { hideSessionActionMenu() },
          onHome: returnToToday,
          onProgress: {
            hideSessionActionMenu()
            showsWorkoutProgress = true
          },
          onFinish: {
            hideSessionActionMenu()
            showsFinishConfirmation = true
          }
        )
        .transition(.opacity)
        .zIndex(50)
      }
    }
    .navigationDestination(isPresented: $showsWorkoutProgress) {
      ActiveWorkoutProgressView(
        execution: execution,
        onBack: { showsWorkoutProgress = false },
        onHome: returnToToday,
        onFinish: {
          showsFinishConfirmation = true
        }
      )
    }
    .alert("Finalizar entrenamiento", isPresented: $showsFinishConfirmation) {
      Button("Cancelar", role: .cancel) {}
      Button("Finalizar", role: .destructive, action: finishRemainingWorkout)
    } message: {
      Text("Se marcarán como omitidas \(pendingSetCount) series pendientes. Las series ya registradas se conservarán.")
    }
    .onPreferenceChange(ExerciseHistoryPresentationPreferenceKey.self) {
      isExerciseHistoryPresented = $0
    }
    .onAppear {
      WatchWorkoutConnectivity.shared.activate()
      WatchWorkoutCommandRouter.shared.handler = handleWatchCommand
      persistActiveWorkout()
      syncTimerNotifications()
    }
    .onDisappear {
      WatchWorkoutCommandRouter.shared.handler = nil
      if phase != .finished, !wasReplacedFromWatch {
        persistActiveWorkout()
      }
    }
    .onChange(of: feedbackRir) { _, _ in persistActiveWorkout() }
    .onChange(of: feedbackPainKnee) { _, _ in persistActiveWorkout() }
    .onChange(of: feedbackPainWrist) { _, _ in persistActiveWorkout() }
    .onChange(of: feedbackPainShoulder) { _, _ in persistActiveWorkout() }
    .onChange(of: feedbackPainLowerBack) { _, _ in persistActiveWorkout() }
    .onChange(of: feedbackNote) { _, _ in persistActiveWorkout() }
    .onChange(of: setTimerEndsAt) { _, _ in persistActiveWorkout() }
    .onChange(of: restEndsAt) { _, _ in syncTimerNotifications() }
    .onChange(of: setTimerEndsAt) { _, _ in syncTimerNotifications() }
    .onChange(of: setTimerRemaining) { _, _ in persistActiveWorkout() }
    .onChange(of: exerciseDecisions) { _, _ in persistActiveWorkout() }
  }

  private func handleWatchCommand(_ command: WatchWorkoutCommand) {
      switch command {
      case .requestState:
        break
      case .startWorkout, .startWarmup:
        // These commands are resolved by the app-level Watch sync host before
        // an execution view exists.
        break
      case let .prioritizeExercise(sessionID, exerciseIndex):
        guard session.sessionID == sessionID,
              execution.selectNextBlock(exerciseIndex: exerciseIndex)
        else { return }
        restEndsAt = nil
        restTotalSeconds = 0
        move(to: .workingSet, direction: .forward)
      case let .replaceActiveWorkout(sessionID, startsWithWarmup, exerciseIndex):
        replaceWorkoutFromWatch(
          sessionID: sessionID,
          startsWithWarmup: startsWithWarmup,
          exerciseIndex: exerciseIndex
        )
      case .addRest15:
        guard phase == .rest else { return }
        adjustRest(by: 15)
      case .subtractRest15:
        guard phase == .rest else { return }
        adjustRest(by: -15)
      case .continueAfterTimer:
        guard phase == .rest else { return }
        continueFromRest()
      case .registerSet:
        beginFeedbackFromWatch()
      case let .submitSetFeedback(feedback):
        guard phase == .feedback else { return }
        feedbackRir = feedback.rir ?? 2
        feedbackPainKnee = feedback.painKnee
        feedbackPainWrist = feedback.painWrist
        feedbackPainShoulder = feedback.painShoulder
        feedbackPainLowerBack = feedback.painLowerBack
        feedbackNote = feedback.note
        registerCurrentSet()
      case let .submitExerciseReview(decisions):
        guard phase == .exerciseReview else { return }
        exerciseDecisions.merge(decisions) { _, incoming in incoming }
        continueAfterExerciseReview()
      case .skipSet:
        guard phase == .workingSet else { return }
        skipCurrentSet()
      case .startTimedSet:
        startTimedSetFromWatch()
      case .pauseTimedSet:
        pauseTimedSetFromWatch()
      case .resetTimedSet:
        resetTimedSetFromWatch()
      case let .updateWorkingSet(reps, weightKg):
        guard phase == .workingSet,
              let locator = execution.current,
              execution.trainingSet(for: locator)?.type == .working
        else { return }
        execution.updateWorkingTargets(for: locator, reps: reps, weightKg: weightKg)
        persistActiveWorkout()
      case let .selectEquipment(equipment):
        guard phase == .workingSet,
              let locator = execution.current,
              execution.canSelectEquipment(equipment, for: locator),
              execution.selectEquipment(equipment, for: locator)
        else { return }
        persistActiveWorkout()
      }
  }

  private func move(to newPhase: ExecutionPhase, direction: FlowDirection) {
    withAnimation(.smooth(duration: 0.3)) {
      transitionOrigin = phase
      transitionDirection = direction
      phase = newPhase
    }
    persistActiveWorkout()
  }

  private func persistActiveWorkout() {
    guard phase != .finished else { return }
    let snapshot = ActiveWorkoutSnapshot(
        execution: execution,
        phase: ActiveWorkoutPhase(phase),
        feedback: ActiveWorkoutFeedbackDraft(
          rir: feedbackRir,
          painKnee: feedbackPainKnee,
          painWrist: feedbackPainWrist,
          painShoulder: feedbackPainShoulder,
          painLowerBack: feedbackPainLowerBack,
          note: feedbackNote
        ),
        restEndsAt: restEndsAt,
        restTotalSeconds: restTotalSeconds,
        setTimerEndsAt: setTimerEndsAt,
        setTimerRemaining: setTimerRemaining,
        reviewExerciseIndexes: reviewExerciseIndexes,
        reviewRestSeconds: reviewRestSeconds,
        exerciseDecisions: exerciseDecisions,
        warmupStatus: warmupStatus,
        warmupEndsAt: warmupEndsAt,
        warmupRemaining: warmupRemaining,
        startedAt: startedAt
      )
    ActiveWorkoutStore.save(snapshot, in: modelContext)
    WatchWorkoutConnectivity.shared.publish(snapshot)
  }

  private func finishWorkout() {
    WorkoutTimerNotification.cancelAll()
    let completionDate = Date.now
    finishedAt = completionDate
    withAnimation(.smooth(duration: 0.3)) {
      phase = .finished
    }
    let completedRecord = ActiveWorkoutStore.markCompleted(
      sessionID: session.sessionID,
      startedAt: startedAt,
      completedAt: completionDate,
      execution: execution,
      decisions: exerciseDecisions,
      in: modelContext
    )
    ActiveWorkoutStore.clear(in: modelContext)
    WatchWorkoutConnectivity.shared.clear()
    if let completedRecord {
      Task {
        await HealthWorkoutStore.syncIfEnabled(
          record: completedRecord,
          execution: execution,
          in: modelContext
        )
      }
    }
  }

  private var pendingSetCount: Int {
    max(0, execution.totalSetCount - execution.records.count)
  }

  private func finishRemainingWorkout() {
    _ = execution.skipRemaining()
    restEndsAt = nil
    restTotalSeconds = 0
    setTimerEndsAt = nil
    setTimerRemaining = 0
    finishWorkout()
  }

  private func returnToToday() {
    persistActiveWorkout()
    onFinishToToday()
  }

  private func showSessionActionMenu() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
      isSessionActionMenuPresented = true
    }
  }

  private func hideSessionActionMenu() {
    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
      isSessionActionMenuPresented = false
    }
  }

  private func adjustRest(by seconds: Int) {
    let remaining = max(0, Int((restEndsAt ?? .now).timeIntervalSinceNow.rounded(.up)))
    let adjusted = max(0, remaining + seconds)
    restEndsAt = .now.addingTimeInterval(TimeInterval(adjusted))
    restTotalSeconds = max(restTotalSeconds, adjusted)
    persistActiveWorkout()
  }

  private func continueFromRest() {
    restEndsAt = nil
    restTotalSeconds = 0
    move(to: .workingSet, direction: .forward)
  }

  private func selectNextBlock(_ exerciseIndex: Int) {
    guard execution.selectNextBlock(exerciseIndex: exerciseIndex) else { return }
    persistActiveWorkout()
  }

  private func syncTimerNotifications() {
    WorkoutTimerNotification.schedule(
      identifier: .rest,
      endsAt: restEndsAt,
      title: "Descanso terminado",
      body: "Ya puedes empezar la siguiente serie."
    )
    WorkoutTimerNotification.schedule(
      identifier: .timedSet,
      endsAt: setTimerEndsAt,
      title: "Tiempo completado",
      body: "La serie temporizada ha finalizado."
    )
  }

  private func continueAfterExerciseReview() {
    reviewExerciseIndexes = []
    guard execution.current != nil else {
      finishWorkout()
      return
    }
    if reviewRestSeconds > 0 {
      restEndsAt = Date().addingTimeInterval(TimeInterval(reviewRestSeconds))
      restTotalSeconds = reviewRestSeconds
      reviewRestSeconds = 0
      move(to: .rest, direction: .forward)
    } else {
      move(to: .workingSet, direction: .forward)
    }
  }

  private func skipCurrentSet() {
    guard let advance = execution.skipCurrent() else {
      finishWorkout()
      return
    }

    if !advance.reviewExerciseIndexes.isEmpty {
      advanceAfterRecord(advance)
      return
    }
    guard advance.next != nil else {
      finishWorkout()
      return
    }

    advanceAfterRecord(advance)
  }

  private func advanceAfterRecord(_ advance: WorkoutAdvance) {
    if !advance.reviewExerciseIndexes.isEmpty {
      reviewExerciseIndexes = advance.reviewExerciseIndexes
      reviewRestSeconds = advance.restSeconds ?? 0
      move(to: .exerciseReview, direction: .forward)
    } else if let restSeconds = advance.restSeconds, restSeconds > 0 {
      restEndsAt = Date().addingTimeInterval(TimeInterval(restSeconds))
      restTotalSeconds = restSeconds
      move(to: .rest, direction: .forward)
    } else {
      move(to: .workingSet, direction: .forward)
    }
  }

  private func registerCurrentSet() {
    guard let current = execution.current else {
      finishWorkout()
      return
    }
    let isTimed = execution.trainingSet(for: current)?.type == .timed
    let setFeedback = WorkoutSetFeedback(
      rir: isTimed ? nil : feedbackRir,
      painKnee: feedbackPainKnee,
      painWrist: feedbackPainWrist,
      painShoulder: feedbackPainShoulder,
      painLowerBack: feedbackPainLowerBack,
      note: feedbackNote
    )
    guard let advance = execution.recordCurrent(feedback: setFeedback) else {
      finishWorkout()
      return
    }

    feedbackRir = 2
    feedbackPainKnee = 0
    feedbackPainWrist = 0
    feedbackPainShoulder = 0
    feedbackPainLowerBack = 0
    feedbackNote = "OK"
    setTimerEndsAt = nil
    setTimerRemaining = 0
    if !advance.reviewExerciseIndexes.isEmpty {
      advanceAfterRecord(advance)
      return
    }
    guard advance.next != nil else {
      finishWorkout()
      return
    }

    advanceAfterRecord(advance)
  }

  private func beginFeedbackFromWatch() {
    guard phase == .workingSet,
          let current = execution.current
    else { return }

    let isTimed = execution.trainingSet(for: current)?.type == .timed
    if isTimed, setTimerEndsAt.map({ $0 > .now }) != false { return }

    move(to: .feedback, direction: .forward)
  }

  private func replaceWorkoutFromWatch(
    sessionID: String,
    startsWithWarmup: Bool,
    exerciseIndex: Int?
  ) {
    guard let url = Bundle.main.url(forResource: "trainingPlan", withExtension: "json"),
          let plan = try? TrainingPlanLoader.decode(data: Data(contentsOf: url)),
          let replacement = plan.sessions.first(where: { $0.sessionID == sessionID })
    else { return }

    var replacementExecution = WorkoutExecutionState(session: replacement)
    if let exerciseIndex, !startsWithWarmup,
       !replacementExecution.selectNextBlock(exerciseIndex: exerciseIndex) {
      return
    }

    execution = replacementExecution
    session = replacement
    feedbackRir = 2
    feedbackPainKnee = 0
    feedbackPainWrist = 0
    feedbackPainShoulder = 0
    feedbackPainLowerBack = 0
    feedbackNote = "OK"
    restEndsAt = nil
    restTotalSeconds = 0
    setTimerEndsAt = nil
    setTimerRemaining = 0
    reviewExerciseIndexes = []
    reviewRestSeconds = 0
    exerciseDecisions = [:]
    warmupStatus = startsWithWarmup ? .running : .completed
    let warmupSeconds = max(3, UserDefaults.standard.integer(forKey: "warmupMinutes")) * 60
    warmupEndsAt = startsWithWarmup ? .now.addingTimeInterval(TimeInterval(warmupSeconds)) : nil
    warmupRemaining = startsWithWarmup ? warmupSeconds : 0
    startedAt = .now
    finishedAt = nil
    move(to: .workingSet, direction: .forward)

    if startsWithWarmup {
      wasReplacedFromWatch = true
      onFinishToToday()
    }
  }

  private func startTimedSetFromWatch() {
    guard phase == .workingSet,
          let current = execution.current,
          execution.trainingSet(for: current)?.type == .timed,
          setTimerEndsAt == nil,
          let duration = execution.targets(for: current)?.durationSeconds
    else { return }
    let remaining = setTimerRemaining > 0 ? setTimerRemaining : duration
    setTimerRemaining = remaining
    setTimerEndsAt = .now.addingTimeInterval(TimeInterval(remaining))
    persistActiveWorkout()
  }

  private func pauseTimedSetFromWatch() {
    guard phase == .workingSet, let setTimerEndsAt else { return }
    setTimerRemaining = max(0, Int(setTimerEndsAt.timeIntervalSinceNow.rounded(.up)))
    self.setTimerEndsAt = nil
    persistActiveWorkout()
  }

  private func resetTimedSetFromWatch() {
    guard phase == .workingSet,
          let current = execution.current,
          execution.trainingSet(for: current)?.type == .timed,
          let duration = execution.targets(for: current)?.durationSeconds
    else { return }
    setTimerEndsAt = nil
    setTimerRemaining = duration
    persistActiveWorkout()
  }
}

private enum ExecutionPhase: Hashable {
  case workingSet
  case feedback
  case rest
  case exerciseReview
  case finished
}

private extension ExecutionPhase {
  init(_ persistedPhase: ActiveWorkoutPhase) {
    switch persistedPhase {
    case .workingSet: self = .workingSet
    case .feedback: self = .feedback
    case .rest: self = .rest
    case .exerciseReview: self = .exerciseReview
    }
  }
}

private extension ActiveWorkoutPhase {
  init(_ executionPhase: ExecutionPhase) {
    switch executionPhase {
    case .workingSet: self = .workingSet
    case .feedback: self = .feedback
    case .rest: self = .rest
    case .exerciseReview: self = .exerciseReview
    case .finished: self = .workingSet
    }
  }
}

private enum FlowDirection {
  case forward
  case backward
}

private struct TransitionKey: Hashable {
  let origin: ExecutionPhase
  let destination: ExecutionPhase
}

private struct WorkoutProgressBar: View {
  let completed: Int
  let total: Int

  private var progress: CGFloat {
    CGFloat(completed) / CGFloat(max(total, 1))
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle().fill(Color.gymCanvas)
        Rectangle()
          .fill(Color.gymProgressFill)
          .frame(width: geometry.size.width * progress)
          .animation(.easeInOut(duration: 0.35), value: progress)
      }
    }
    .frame(height: 7)
    .accessibilityLabel("Progreso del entrenamiento: \(completed) de \(total) series")
  }
}

private extension SetExecutionView {
  var transition: AnyTransition {
    let insertionEdge: Edge = transitionDirection == .forward ? .trailing : .leading
    return .asymmetric(
      insertion: .move(edge: insertionEdge).combined(with: .opacity),
      removal: .opacity
    )
  }
}

private struct WorkingSetView: View {
  @Binding var execution: WorkoutExecutionState
  let locator: WorkoutSetLocator
  let onContinue: () -> Void
  let onSkip: () -> Void
  @Binding var timerEndsAt: Date?
  @Binding var timerRemaining: Int
  let onExecutionChanged: () -> Void
  let onSessionActionsRequested: () -> Void
  @State private var editField: SetEditField?
  @State private var timedSetFinished = false
  @State private var isHistoryExpanded = false
  @State private var historyRevealDistance: CGFloat?
  @Environment(\.dismiss) private var dismiss
  @Binding var isCoachGuidancePresented: Bool

  private var exercise: TrainingExercise? { execution.exercise(for: locator) }
  private var trainingSet: TrainingSet? { execution.trainingSet(for: locator) }
  private var activeEquipment: Equipment { execution.equipment(for: locator) ?? .barbell }
  private var activeTargets: WorkoutSetTargets? { execution.targets(for: locator) }

  var body: some View {
    Group {
      if let exercise, let trainingSet {
        VStack(alignment: .leading, spacing: 12) {
          ExerciseExecutionHeader(
            eyebrow: supersetLabel(for: exercise),
            exercise: exercise,
            setIndex: trainingSet.setIndex - 1,
            isHistoryExpanded: isHistoryExpanded,
            onHistoryRequested: showHistory,
            onHistoryDismissed: dismissHistory,
            onHistoryDragChanged: beginHistoryDrag,
            onHistoryDragEnded: completeHistoryDrag
          )
          .padding(.horizontal, -16)
          .padding(.top, -16)

          if trainingSet.type == .timed {
            TimedSetTarget(
              seconds: activeTargets?.durationSeconds ?? 0,
              endsAt: $timerEndsAt,
              pausedRemaining: $timerRemaining,
              onAdjustDuration: adjustTimedDuration,
              onFinishedTap: onContinue,
              onFinishedChanged: { timedSetFinished = $0 }
            )
          } else {
            VStack(spacing: 10) {
              SetTargetCard(
                label: "Reps",
                value: activeTargets?.reps.map(String.init) ?? "-",
                action: { editField = .reps }
              )
              MaterialSelector(
                selection: Binding(
                  get: { activeEquipment },
                  set: { selectedEquipment in
                    _ = execution.selectEquipment(selectedEquipment, for: locator)
                    onExecutionChanged()
                  }
                ),
                options: equipmentOptions(for: exercise),
                unavailableOptions: unavailableEquipment(for: exercise)
              )
              SetTargetCard(
                label: "Peso",
                value: (activeTargets?.weightKg ?? trainingSet.targetWeightKg)
                  .formatted(.number.precision(.fractionLength(0...2))),
                unit: weightUnit(for: activeEquipment),
                numericValue: activeTargets?.weightKg ?? trainingSet.targetWeightKg,
                plateLayout: EquipmentLoadRules.plateLayout(
                  totalWeightKg: activeTargets?.weightKg ?? trainingSet.targetWeightKg,
                  equipment: activeEquipment
                ),
                action: { editField = .weight }
              )
            }
            .frame(maxHeight: .infinity)
          }

          ExerciseCoachCueCard(
            exercise: exercise,
            onLongPress: {
              withAnimation(.smooth(duration: 0.2)) { isCoachGuidancePresented = true }
            }
          )

          BottomActions(
            primaryTitle: "Continuar",
            primaryAction: onContinue,
            skipAction: onSkip,
            primaryDisabled: trainingSet.type == .timed && !timedSetFinished,
            onBack: { dismiss() },
            onSessionActionsRequested: onSessionActionsRequested
          )
        }
        .padding(16)
        .overlay(alignment: .top) {
          if isHistoryExpanded {
            ExerciseHistoryOverlay(
              exercise: exercise,
              eyebrow: supersetLabel(for: exercise),
              setIndex: trainingSet.setIndex - 1,
              revealDistance: historyRevealDistance,
              onRevealChanged: beginHistoryDrag,
              onRevealEnded: completeHistoryDrag,
              onDismiss: dismissHistory
            )
            .zIndex(20)
          }
        }
        .overlay {
          if isCoachGuidancePresented {
            ExerciseCoachGuidanceOverlay(
              exercise: exercise,
              onDismiss: {
                withAnimation(.smooth(duration: 0.18)) { isCoachGuidancePresented = false }
              }
            )
            .zIndex(30)
          }
        }
      } else {
        ContentUnavailableView("Serie no disponible", systemImage: "exclamationmark.triangle")
      }
    }
    .sheet(item: $editField) { field in
      if let targets = activeTargets {
        SetTargetEditor(
          field: field,
          initialValue: field == .reps ? Double(targets.reps ?? 0) : targets.weightKg,
          equipment: activeEquipment,
          onConfirm: { value in
            switch field {
            case .reps:
              execution.updateWorkingTargets(
                for: locator,
                reps: max(1, Int(value)),
                weightKg: targets.weightKg
              )
            case .weight:
              execution.updateWorkingTargets(
                for: locator,
                reps: targets.reps,
                weightKg: value
              )
            }
            onExecutionChanged()
          }
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
      }
    }
    .preference(
      key: ExerciseHistoryPresentationPreferenceKey.self,
      value: isHistoryExpanded
    )
  }

  private func weightUnit(for equipment: Equipment) -> String {
    switch equipment {
    case .external:
      return "kg de lastre"
    case .dumbbell:
      return "kg por mancuerna"
    default:
      return "kg"
    }
  }

  private func equipmentOptions(for exercise: TrainingExercise) -> [Equipment] {
    exercise.selectableEquipmentOptions
  }

  private func unavailableEquipment(for exercise: TrainingExercise) -> Set<Equipment> {
    Set(
      equipmentOptions(for: exercise).filter {
        !execution.canSelectEquipment($0, for: locator)
      }
    )
  }

  private func supersetPosition(for exercise: TrainingExercise) -> Int? {
    guard let supersetID = exercise.supersetID else { return nil }
    let members = execution.session.exercises.filter { $0.supersetID == supersetID }
    return (members.firstIndex { $0.exerciseID == exercise.exerciseID } ?? 0) + 1
  }

  private func supersetSize(for exercise: TrainingExercise) -> Int? {
    guard let supersetID = exercise.supersetID else { return nil }
    return execution.session.exercises.filter { $0.supersetID == supersetID }.count
  }

  private func supersetLabel(for exercise: TrainingExercise) -> String? {
    guard let position = supersetPosition(for: exercise), let size = supersetSize(for: exercise) else {
      return nil
    }
    return "Superserie \(position)/\(size)"
  }

  private func showHistory() {
    historyRevealDistance = 0
    isHistoryExpanded = true
    Task { @MainActor in
      withAnimation(.smooth(duration: 0.32)) { historyRevealDistance = nil }
    }
  }

  private func beginHistoryDrag(_ distance: CGFloat) {
    guard distance > 0 else { return }
    historyRevealDistance = distance
    isHistoryExpanded = true
  }

  private func completeHistoryDrag(_ distance: CGFloat) {
    guard distance >= 42 else {
      dismissHistory()
      return
    }
    withAnimation(.smooth(duration: 0.3)) { historyRevealDistance = nil }
  }

  private func dismissHistory() {
    withAnimation(.smooth(duration: 0.24), completionCriteria: .logicallyComplete) {
      historyRevealDistance = 0
    } completion: {
      isHistoryExpanded = false
      historyRevealDistance = nil
    }
  }

  private func adjustTimedDuration(by seconds: Int) {
    guard let targets = activeTargets else { return }
    let duration = max(15, (targets.durationSeconds ?? 60) + seconds)
    execution.updateTimedDuration(for: locator, durationSeconds: duration)
    if let timerEndsAt {
      let remaining = max(0, Int(timerEndsAt.timeIntervalSinceNow.rounded(.up)))
      let adjustedRemaining = max(0, remaining + seconds)
      self.timerEndsAt = .now.addingTimeInterval(TimeInterval(adjustedRemaining))
      timerRemaining = adjustedRemaining
    } else {
      timerRemaining = duration
    }
    onExecutionChanged()
  }
}

private enum SetEditField: String, Identifiable {
  case reps
  case weight

  var id: String { rawValue }
  var title: String { self == .reps ? "Reps" : "Peso" }
}

private struct ExerciseCoachCueCard: View {
  let exercise: TrainingExercise
  let onLongPress: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "figure.strengthtraining.traditional")
        .font(.headline.weight(.semibold))
        .foregroundStyle(Color.gymAccent)
        .frame(width: 24)

      Text(ExerciseCoachGuidance(exercise: exercise).summary)
        .font(.subheadline)
        .foregroundStyle(Color.gymSecondaryText)
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
    .contentShape(RoundedRectangle(cornerRadius: 18))
    .onLongPressGesture(minimumDuration: 0.35, perform: onLongPress)
    .accessibilityLabel("Indicaciones para \(exercise.displayName)")
    .accessibilityHint("Mantén pulsado para ver las indicaciones completas")
  }

}

private struct ExerciseCoachGuidanceOverlay: View {
  let exercise: TrainingExercise
  let onDismiss: () -> Void

  private var guidance: ExerciseCoachGuidance { ExerciseCoachGuidance(exercise: exercise) }

  var body: some View {
    ZStack {
      Rectangle()
        .fill(.ultraThinMaterial)
        .ignoresSafeArea()
        .onTapGesture(perform: onDismiss)

      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
          Text(exercise.displayName)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
          Button(action: onDismiss) {
            Image(systemName: "xmark")
              .font(.subheadline.weight(.bold))
              .frame(width: 32, height: 32)
              .background(Color.gymSurface, in: Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Cerrar indicaciones")
        }
        Text(guidance.fullGuidance)
          .font(.subheadline)
          .foregroundStyle(Color.gymSecondaryText)
        Text("Objetivo")
          .font(.caption.weight(.bold))
          .foregroundStyle(Color.gymAccent)
        Text(guidance.trainingGoal)
          .font(.headline.weight(.semibold))
      }
      .padding(20)
      .frame(maxWidth: 360, alignment: .leading)
      .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 24))
      .overlay {
        RoundedRectangle(cornerRadius: 24)
          .stroke(Color.gymAccent.opacity(0.38), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
      .padding(24)
    }
    .transition(.opacity.combined(with: .scale(scale: 0.96)))
    .accessibilityAddTraits(.isModal)
  }
}

private struct ExerciseCoachGuidance {
  let exercise: TrainingExercise

  var summary: String { "\(technicalGuidance) Objetivo: \(trainingGoal)" }

  var fullGuidance: String {
    let variation = variationName.map { "Variación: \($0). " } ?? ""
    return "\(technicalGuidance) \(variation)"
  }

  var trainingGoal: String {
    let muscles = exercise.primaryMuscles.prefix(2).map(Self.muscleLabel).joined(separator: " y ")
    let goal: String = switch exercise.trainingBlock {
    case "fuerza":
      "desarrollar fuerza con técnica estable\(muscles.isEmpty ? "" : " en \(muscles)")"
    case "tecnica":
      "consolidar el patrón y el control del movimiento"
    case "volumen":
      "acumular trabajo de calidad\(muscles.isEmpty ? "" : " en \(muscles)")"
    default:
      "estimular \(muscles.isEmpty ? "la musculatura objetivo" : muscles) con control"
    }
    return goal.prefix(1).uppercased() + goal.dropFirst()
  }

  private var variationName: String? {
    guard exercise.name.localizedCaseInsensitiveCompare(exercise.displayName) != .orderedSame,
          !isMaterialOnlyVariant
    else { return nil }
    return exercise.name
  }

  private var isMaterialOnlyVariant: Bool {
    let normalizedName = exercise.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let materialTerms = [
      "barra", "multipower", "mancuernas", "mancuerna", "polea", "cable", "discos", "lastre",
    ]
    guard materialTerms.contains(where: { normalizedName.contains($0) }) else { return false }

    let normalizedDisplayName = exercise.displayName
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      .replacingOccurrences(of: " de ", with: " ")
    let simplifiedName = materialTerms.reduce(normalizedName) { value, term in
      value.replacingOccurrences(of: term, with: "")
    }
    .replacingOccurrences(of: "con", with: "")
    .replacingOccurrences(of: "en", with: "")
    .replacingOccurrences(of: " ", with: "")
    let simplifiedDisplayName = normalizedDisplayName.replacingOccurrences(of: " ", with: "")
    return simplifiedName == simplifiedDisplayName
  }

  private var technicalGuidance: String {
    let sentences = exercise.notes
      .split(separator: ".")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("reps") }
    return (sentences.isEmpty ? [exercise.notes] : sentences).joined(separator: ". ")
  }

  private nonisolated static func muscleLabel(_ rawValue: String) -> String {
    switch rawValue {
    case "triceps": "tríceps"
    case "gluteo": "glúteo"
    case "biceps": "bíceps"
    default: rawValue
    }
  }
}

private struct FeedbackView: View {
  let execution: WorkoutExecutionState
  let locator: WorkoutSetLocator
  @Binding var rir: Int
  @Binding var painKnee: Int
  @Binding var painWrist: Int
  @Binding var painShoulder: Int
  @Binding var painLowerBack: Int
  @Binding var note: String
  let onBack: () -> Void
  let onRegister: () -> Void
  let onSessionActionsRequested: () -> Void
  @State private var isHistoryExpanded = false
  @State private var historyRevealDistance: CGFloat?

  private var exercise: TrainingExercise? { execution.exercise(for: locator) }
  private var trainingSet: TrainingSet? { execution.trainingSet(for: locator) }
  private var targets: WorkoutSetTargets? { execution.targets(for: locator) }
  private var equipment: Equipment { execution.equipment(for: locator) ?? exercise?.equipment ?? .barbell }
  private var isTimed: Bool { trainingSet?.type == .timed }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ExerciseExecutionHeader(
        eyebrow: "Evaluar serie",
        exercise: exercise,
        setIndex: locator.setIndex - 1,
        isHistoryExpanded: isHistoryExpanded,
        onHistoryRequested: showHistory,
        onHistoryDismissed: dismissHistory,
        onHistoryDragChanged: beginHistoryDrag,
        onHistoryDragEnded: completeHistoryDrag
      )
      .padding(.horizontal, -16)
      .padding(.top, -16)

      if isTimed {
        FeedbackMetric(label: "Tiempo", value: feedbackTimeLabel(targets?.durationSeconds ?? 0))
          .zIndex(isHistoryExpanded ? -1 : 0)
      } else {
        HStack(spacing: 8) {
          FeedbackMetric(label: "Reps", value: targets?.reps.map(String.init) ?? "-")
          FeedbackMetric(
            label: "Peso",
            value: "\(targets?.weightKg.formatted(.number.precision(.fractionLength(0...2))) ?? "-") kg",
            footer: equipment.executionLabel
          )
        }
        .zIndex(isHistoryExpanded ? -1 : 0)
      }

      VStack(spacing: 10) {
        if !isTimed {
          FeedbackStepper(label: "RIR", value: $rir, range: 0 ... 5)
        }
        PainFeedbackBlock(
          painKnee: $painKnee,
          painWrist: $painWrist,
          painShoulder: $painShoulder,
          painLowerBack: $painLowerBack
        )
        NotePicker(note: $note)
      }
      .padding(10)
      .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
      .zIndex(isHistoryExpanded ? -1 : 0)

      Spacer(minLength: 0)

      HStack(spacing: 12) {
        SessionNavigationButton(
          onBack: onBack,
          onSessionActionsRequested: onSessionActionsRequested
        )

        Button("Registrar serie", action: onRegister)
          .font(.headline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 64)
          .foregroundStyle(Color.gymControlSelectionForeground)
          .background(Color.gymControlSelectionFill, in: Capsule())
          .overlay { Capsule().stroke(Color.gymAccent, lineWidth: 1) }
          .buttonStyle(.plain)
      }
      .zIndex(isHistoryExpanded ? -1 : 0)
    }
    .padding(16)
    .overlay(alignment: .top) {
      if isHistoryExpanded, let exercise {
        ExerciseHistoryOverlay(
          exercise: exercise,
          eyebrow: "Evaluar serie",
          setIndex: locator.setIndex - 1,
          revealDistance: historyRevealDistance,
          onRevealChanged: beginHistoryDrag,
          onRevealEnded: completeHistoryDrag,
          onDismiss: dismissHistory
        )
        .zIndex(20)
      }
    }
    .preference(
      key: ExerciseHistoryPresentationPreferenceKey.self,
      value: isHistoryExpanded
    )
  }

  private func showHistory() {
    historyRevealDistance = 0
    isHistoryExpanded = true
    Task { @MainActor in
      withAnimation(.smooth(duration: 0.32)) { historyRevealDistance = nil }
    }
  }

  private func beginHistoryDrag(_ distance: CGFloat) {
    guard distance > 0 else { return }
    historyRevealDistance = distance
    isHistoryExpanded = true
  }

  private func completeHistoryDrag(_ distance: CGFloat) {
    guard distance >= 42 else {
      dismissHistory()
      return
    }
    withAnimation(.smooth(duration: 0.3)) { historyRevealDistance = nil }
  }

  private func dismissHistory() {
    withAnimation(.smooth(duration: 0.24), completionCriteria: .logicallyComplete) {
      historyRevealDistance = 0
    } completion: {
      isHistoryExpanded = false
      historyRevealDistance = nil
    }
  }
}

private struct SetProgressIndicators: View {
  let setCount: Int
  let currentSetIndex: Int
  var onAccent = false
  @State private var currentSetPulse = false

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0 ..< max(setCount, 1), id: \.self) { index in
        let isCompleted = index < currentSetIndex
        let isCurrent = index == currentSetIndex
        Capsule()
          .fill(
            indicatorFill(isCompleted: isCompleted, isCurrent: isCurrent)
              .opacity(isCurrent && !currentSetPulse ? 0.38 : 1)
          )
          .overlay {
            Capsule().strokeBorder(
              indicatorBorder(isCompleted: isCompleted, isCurrent: isCurrent),
              lineWidth: 1.5
            )
          }
          .frame(maxWidth: .infinity)
          .frame(height: 9)
      }
    }
    .onAppear { startCurrentSetPulse() }
    .onChange(of: currentSetIndex) { _, _ in startCurrentSetPulse() }
  }

  private func startCurrentSetPulse() {
    currentSetPulse = false
    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
      currentSetPulse = true
    }
  }

  private func indicatorFill(isCompleted: Bool, isCurrent: Bool) -> Color {
    guard onAccent else {
      return isCompleted ? Color.gymAccent : (isCurrent ? Color.gymAccent.opacity(0.46) : .clear)
    }
    return isCompleted ? Color.gymAccentForeground : (isCurrent ? Color.gymAccentForeground.opacity(0.42) : .clear)
  }

  private func indicatorBorder(isCompleted: Bool, isCurrent: Bool) -> Color {
    if onAccent {
      return isCompleted || isCurrent ? Color.gymAccentForeground : Color.gymAccentForeground.opacity(0.44)
    }
    return isCompleted || isCurrent ? Color.gymAccent : .secondary.opacity(0.35)
  }
}

private struct ExerciseExecutionHeader: View {
  let eyebrow: String?
  let exercise: TrainingExercise?
  let setIndex: Int
  let isHistoryExpanded: Bool
  let onHistoryRequested: () -> Void
  let onHistoryDismissed: () -> Void
  let onHistoryDragChanged: (CGFloat) -> Void
  let onHistoryDragEnded: (CGFloat) -> Void

  var body: some View {
    VStack(spacing: 12) {
      if let eyebrow {
        Text(eyebrow)
          .font(.subheadline.weight(.semibold))
          .opacity(0.84)
      }

      Text(exercise?.displayName ?? "Ejercicio")
        .font(.system(size: 31, weight: .bold))
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.74)
        .frame(maxWidth: .infinity, minHeight: 42)

      SetProgressIndicators(
        setCount: exercise?.sets.count ?? 0,
        currentSetIndex: setIndex,
        onAccent: true
      )

      if exercise != nil {
        HistoryDisclosureHandle(expansion: isHistoryExpanded ? 1 : 0)
          .stroke(
            Color.gymAccentForeground.opacity(0.42),
            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 54, height: 8)
          .contentShape(Rectangle().inset(by: -16))
          .highPriorityGesture(
            TapGesture().onEnded {
              if isHistoryExpanded {
                onHistoryDismissed()
              } else {
                onHistoryRequested()
              }
            }
          )
          .animation(.smooth(duration: 0.2), value: isHistoryExpanded)
      }

    }
    .foregroundStyle(Color.gymAccentForeground)
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 22)
    .frame(maxWidth: .infinity)
    .fixedSize(horizontal: false, vertical: true)
    .background(alignment: .top) {
      Color.gymAccent
        .frame(height: 112)
        .offset(y: -112)
    }
    .background {
      UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 52,
        bottomTrailingRadius: 52,
        topTrailingRadius: 0,
        style: .continuous
      )
      .fill(Color.gymAccent)
    }
    .gesture(
      DragGesture(minimumDistance: 18)
        .onChanged { value in
          if value.translation.height > 0 {
            onHistoryDragChanged(value.translation.height)
          }
        }
        .onEnded { value in
          guard exercise != nil else { return }
          if value.translation.height > 42 {
            onHistoryDragEnded(value.translation.height)
          } else if value.translation.height < -30, isHistoryExpanded {
            onHistoryDismissed()
          } else {
            onHistoryDragEnded(value.translation.height)
          }
        }
    )
  }
}

private struct HistoryDisclosureHandle: Shape {
  var expansion: CGFloat

  var animatableData: CGFloat {
    get { expansion }
    set { expansion = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let bend = min(max(expansion, 0), 1)
    let rise = min(2.5, rect.height * 0.32) * bend
    let inset = 2.5

    var path = Path()
    path.move(to: CGPoint(x: rect.minX + inset, y: rect.midY + rise))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - rise))
    path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY + rise))
    return path
  }
}

private struct ExerciseHistoryOverlay: View {
  private static let headerOverlap: CGFloat = 70

  let exercise: TrainingExercise
  let eyebrow: String?
  let setIndex: Int
  let revealDistance: CGFloat?
  let onRevealChanged: (CGFloat) -> Void
  let onRevealEnded: (CGFloat) -> Void
  let onDismiss: () -> Void
  @Query private var completedWorkoutRecords: [CompletedWorkoutRecord]

  var body: some View {
    GeometryReader { geometry in
      let availableHeight = geometry.size.height

      VStack(spacing: 0) {
        ExerciseExecutionHeader(
          eyebrow: eyebrow,
          exercise: exercise,
          setIndex: setIndex,
          isHistoryExpanded: true,
          onHistoryRequested: {},
          onHistoryDismissed: onDismiss,
          onHistoryDragChanged: onRevealChanged,
          onHistoryDragEnded: onRevealEnded
        )
        .zIndex(2)

        GeometryReader { historyGeometry in
          let maximumHistoryHeight = historyGeometry.size.height
          let visibleHistoryHeight = revealDistance.map {
            min(maximumHistoryHeight, max(0, $0))
          } ?? maximumHistoryHeight

          ExerciseHistoryPanel(exercise: exercise, completedWorkoutRecords: completedWorkoutRecords)
            .frame(
              width: historyGeometry.size.width,
              height: visibleHistoryHeight + Self.headerOverlap,
              alignment: .top
            )
            .offset(y: -Self.headerOverlap)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .zIndex(1)
          }
      }
      .frame(width: geometry.size.width, height: availableHeight, alignment: .top)
    }
  }
}

private struct ExerciseHistoryPanel: View {
  let exercise: TrainingExercise
  let completedWorkoutRecords: [CompletedWorkoutRecord]

  var body: some View {
    ZStack(alignment: .top) {
      Color.gymAccent

      ScrollView {
        ExerciseHistoryContent(
          exercise: exercise,
          completedWorkouts: completedWorkoutRecords,
          showsTitle: false
        )
          .padding(.horizontal, 20)
          .padding(.top, 98)
          .padding(.bottom, 28)
      }
      .foregroundStyle(.primary)
      .background(Color.gymCanvas)
      .mask(BottomContainerRelativeMask())
      .padding(.horizontal, 8)
      .padding(.bottom, 8)
    }
    .mask(BottomContainerRelativeMask())
  }
}

private struct ExerciseHistoryPresentationPreferenceKey: PreferenceKey {
  static var defaultValue = false

  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

private struct BottomContainerRelativeMask: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        ContainerRelativeShape()
          .fill(.black)

        Rectangle()
          .fill(.black)
          .frame(height: geometry.size.height / 2)
      }
    }
  }
}

private struct FeedbackChip: View {
  let text: String
  var accent = false

  var body: some View {
    Text(text)
      .font(.caption2.weight(.bold))
      .lineLimit(1)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(accent ? Color.gymControlSelectionForeground : Color.gymSecondaryText)
      .background(accent ? Color.gymControlSelectionFill : Color.secondary.opacity(0.12), in: Capsule())
  }
}

private struct FeedbackMetric: View {
  let label: String
  let value: String
  var footer: String? = nil

  var body: some View {
    VStack(spacing: 5) {
      Text(label).font(.subheadline.weight(.bold)).foregroundStyle(Color.gymSecondaryText)
      Text(value).font(.system(size: 31, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
      Text(footer ?? "Material")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)
        .lineLimit(1)
        .opacity(footer == nil ? 0 : 1)
    }
    .frame(maxWidth: .infinity, minHeight: 94)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 1) }
  }
}

private struct FeedbackStepper: View {
  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    HStack(spacing: 14) {
      Text(label).font(.headline.weight(.bold)).foregroundStyle(Color.gymSecondaryText)
      Spacer()
      adjustmentButton(symbol: "minus", accessibilityLabel: "Bajar RIR") {
        value = max(range.lowerBound, value - 1)
      }
      Text("\(value)")
        .font(.title2.weight(.bold))
        .monospacedDigit()
        .frame(width: 36)
      adjustmentButton(symbol: "plus", accessibilityLabel: "Subir RIR") {
        value = min(range.upperBound, value + 1)
      }
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 76)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 14))
    .overlay { RoundedRectangle(cornerRadius: 14).stroke(.separator, lineWidth: 1) }
  }

  private func adjustmentButton(
    symbol: String,
    accessibilityLabel: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.title3.weight(.bold))
        .frame(width: 76, height: 64)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .foregroundStyle(.primary)
    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.secondary.opacity(0.42), lineWidth: 1)
    }
    .contentShape(RoundedRectangle(cornerRadius: 14))
    .accessibilityLabel(accessibilityLabel)
    .buttonStyle(.plain)
  }
}

private struct PainFeedbackBlock: View {
  @Binding var painKnee: Int
  @Binding var painWrist: Int
  @Binding var painShoulder: Int
  @Binding var painLowerBack: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Molestias")
        .font(.subheadline.weight(.bold))
        .foregroundStyle(Color.gymSecondaryText)

      ScrollView(.vertical) {
        VStack(spacing: 8) {
          PainLevelControl(label: "Rodilla", value: $painKnee)
          PainLevelControl(label: "Muñeca", value: $painWrist)
          PainLevelControl(label: "Hombro", value: $painShoulder)
          PainLevelControl(label: "Lumbar", value: $painLowerBack)
        }
      }
      .scrollIndicators(.visible)
      .frame(maxHeight: 160)
    }
    .padding(12)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 14))
    .overlay { RoundedRectangle(cornerRadius: 14).stroke(.separator, lineWidth: 1) }
  }
}

private struct PainLevelControl: View {
  let label: String
  @Binding var value: Int

  var body: some View {
    HStack(spacing: 6) {
      Text(label).font(.subheadline.weight(.bold)).foregroundStyle(Color.gymSecondaryText)
      Spacer()
      ForEach(0 ... 3, id: \.self) { level in
        Button("\(level)") { value = level }
          .font(.subheadline.weight(.bold))
          .frame(width: 48, height: 48)
          .foregroundStyle(value == level ? Color.gymControlSelectionForeground : .primary)
          .background(value == level ? Color.gymControlSelectionFill : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
          .overlay {
            RoundedRectangle(cornerRadius: 10)
              .stroke(value == level ? Color.gymAccent : Color.secondary.opacity(0.38), lineWidth: 1)
          }
          .buttonStyle(.plain)
      }
    }
  }
}

private struct NotePicker: View {
  @Binding var note: String
  private let options = ["OK", "Pesado", "Técnica", "Molestia"]

  var body: some View {
    HStack(spacing: 6) {
      ForEach(options, id: \.self) { option in
        Button(option) { note = option }
          .font(.caption.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 48)
          .foregroundStyle(note == option ? Color.gymControlSelectionForeground : .primary)
          .background(note == option ? Color.gymControlSelectionFill : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .stroke(note == option ? Color.gymAccent : Color.secondary.opacity(0.38), lineWidth: 1)
          }
          .buttonStyle(.plain)
      }
    }
  }
}

private func feedbackTimeLabel(_ seconds: Int) -> String {
  "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}

private struct ExerciseReviewView: View {
  let exercises: [TrainingExercise]
  @Binding var decisions: [String: String]
  let isFinalReview: Bool
  let onContinue: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      ExerciseReviewHeader(exercises: exercises)
        .padding(.horizontal, -16)
        .padding(.top, -16)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(exercises) { exercise in
            ExerciseDecisionSection(
              exercise: exercise,
              showsExerciseName: exercises.count > 1,
              selection: Binding(
                get: { decisions[exercise.exerciseID] ?? ExerciseDecisionSection.defaultDecision(for: exercise) },
                set: { decisions[exercise.exerciseID] = $0 }
              )
            )
          }
        }
      }
      .scrollIndicators(.hidden)

      Button(isFinalReview ? "Finalizar" : "Continuar", action: onContinue)
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(Color.gymAccentForeground)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
        .buttonStyle(.plain)
    }
    .padding(16)
  }
}

private struct ExerciseReviewHeader: View {
  let exercises: [TrainingExercise]

  var body: some View {
    VStack(spacing: 8) {
      Text(exercises.count > 1 ? "Evaluar superserie" : "Evaluar ejercicio")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)

      Text(exercises.map(\.displayName).joined(separator: " + "))
        .font(.system(size: 31, weight: .bold))
        .lineLimit(2)
        .minimumScaleFactor(0.78)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
    .foregroundStyle(Color.gymAccentForeground)
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 22)
    .frame(maxWidth: .infinity, minHeight: 106)
    .background(alignment: .top) {
      Color.gymAccent
        .frame(height: 112)
        .offset(y: -112)
    }
    .background {
      UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 52,
        bottomTrailingRadius: 52,
        topTrailingRadius: 0,
        style: .continuous
      )
      .fill(Color.gymAccent)
    }
  }
}

private struct ExerciseDecisionSection: View {
  let exercise: TrainingExercise
  let showsExerciseName: Bool
  @Binding var selection: String

  private var isTimed: Bool { exercise.sets.first?.type == .timed }

  static func defaultDecision(for exercise: TrainingExercise) -> String {
    exercise.sets.first?.type == .timed ? "Mantener tiempo" : "Mantener"
  }
  private var options: [String] {
    if isTimed {
      return ["Mantener tiempo", "Subir tiempo", "Bajar tiempo", "Mejorar posición", "Marcar molestia"]
    }
    let canChangeWeight = exercise.equipment != .bodyweight && exercise.equipment != .cable
    return canChangeWeight
      ? ["Mantener", "Subir peso", "Bajar peso", "Subir reps", "Bajar reps", "Marcar molestia"]
      : ["Mantener", "Subir reps", "Bajar reps", "Marcar molestia"]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if showsExerciseName {
        Text(exercise.displayName)
          .font(.title3.weight(.bold))
          .lineLimit(2)
      }
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        ForEach(options, id: \.self) { option in
          decisionButton(option)
        }
      }
    }
  }

  private func decisionButton(_ option: String) -> some View {
    Button { selection = option } label: {
      HStack(spacing: 6) {
        Text(decisionSymbol(for: option))
          .font(.headline.weight(.bold))
        Text(option)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .font(.subheadline.weight(.bold))
      .frame(maxWidth: .infinity, minHeight: 58)
      .foregroundStyle(selection == option ? selectedForeground(option) : decisionColor(option))
      .background(
        selection == option ? selectedFill(option) : decisionColor(option).opacity(0.14),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(selectedBorder(option).opacity(selection == option ? 1 : 0.72), lineWidth: 2)
      }
    }
    .accessibilityLabel(option)
    .buttonStyle(.plain)
  }

  private func decisionSymbol(for option: String) -> String {
    let lower = option.lowercased()
    if lower.contains("subir") || lower.contains("mejorar") { return "↗" }
    if lower.contains("bajar") { return "↘" }
    if lower.contains("molestia") { return "×" }
    return "="
  }

  private func decisionColor(_ option: String) -> Color {
    let lower = option.lowercased()
    if lower.contains("bajar") || lower.contains("molestia") { return Color.gymDanger }
    if lower.contains("subir") { return Color.gymSuccess }
    return Color.gymAccent
  }

  private func selectedFill(_ option: String) -> Color {
    usesThemeAccent(option) ? Color.gymControlSelectionFill : decisionColor(option)
  }

  private func selectedForeground(_ option: String) -> Color {
    usesThemeAccent(option) ? Color.gymControlSelectionForeground : .white
  }

  private func selectedBorder(_ option: String) -> Color {
    usesThemeAccent(option) ? Color.gymAccent : decisionColor(option)
  }

  private func usesThemeAccent(_ option: String) -> Bool {
    let lower = option.lowercased()
    return !lower.contains("subir") && !lower.contains("bajar") && !lower.contains("molestia")
  }
}

private struct RestView: View {
  @Binding var execution: WorkoutExecutionState
  let next: WorkoutSetLocator
  let endsAt: Date
  let totalSeconds: Int
  let onAdjust: (Int) -> Void
  let onContinue: () -> Void
  let onSelectBlock: (Int) -> Void
  let onExecutionChanged: () -> Void
  @State private var hasAnnouncedCompletion = false
  @State private var completionWaveID = 0

  private var hasNextSuperset: Bool {
    execution.exercise(for: next)?.supersetID != nil
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
      VStack(spacing: 8) {
        RestExecutionHeader(
          remaining: remaining,
          totalSeconds: totalSeconds,
          completionWaveID: completionWaveID,
          onContinue: onContinue
        )
        .padding(.horizontal, -16)
        .padding(.top, -16)

        HStack(spacing: 8) {
          RestAdjustmentButton(title: "-15s") { onAdjust(-15) }
          RestAdjustmentButton(title: "+15s") { onAdjust(15) }
        }

        VStack(spacing: hasNextSuperset ? 8 : 3) {
          NextSetPreview(
            execution: $execution,
            locator: next,
            onExecutionChanged: onExecutionChanged
          )
            .frame(maxHeight: hasNextSuperset ? 244 : 174, alignment: .top)
            .padding(10)
            .overlay {
              RoundedRectangle(cornerRadius: 18)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
            }

          PendingBlockSelector(
            execution: execution,
            next: next,
            onSelect: onSelectBlock
          )
          .frame(maxHeight: hasNextSuperset ? 180 : .infinity, alignment: .top)
        }

        Spacer(minLength: 0)

        Button("Siguiente", action: onContinue)
          .font(.headline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 64)
          .foregroundStyle(Color.gymAccentForeground)
          .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
          .buttonStyle(.plain)
      }
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .onAppear {
        announceCompletionIfNeeded(remaining: remaining)
      }
      .onChange(of: remaining) { _, newValue in
        if newValue > 0 {
          hasAnnouncedCompletion = false
        }
        announceCompletionIfNeeded(remaining: newValue)
      }
    }
  }

  private func announceCompletionIfNeeded(remaining: Int) {
    guard remaining == 0, !hasAnnouncedCompletion else { return }
    hasAnnouncedCompletion = true
    completionWaveID += 1
    TimerCompletionFeedback.play()
  }
}

private struct RestExecutionHeader: View {
  let remaining: Int
  let totalSeconds: Int
  let completionWaveID: Int
  let onContinue: () -> Void

  private var isFinished: Bool { remaining == 0 }
  private var progress: CGFloat {
    CGFloat(remaining) / CGFloat(max(totalSeconds, remaining, 1))
  }

  var body: some View {
    Button(action: {
      guard isFinished else { return }
      onContinue()
    }) {
      ZStack(alignment: .leading) {
        RestProgressBackground(progress: progress, isFinished: isFinished)

        VStack(spacing: 5) {
          Text(isFinished ? "Descanso terminado" : "Descanso")
            .font(.headline.weight(.bold))
          Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
            .font(.system(size: 56, weight: .bold))
            .monospacedDigit()
            .contentTransition(.numericText())
        }
        .foregroundStyle(isFinished ? Color.white : Color.gymAccentForeground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 140)
      .clipShape(
        UnevenRoundedRectangle(
          topLeadingRadius: 0,
          bottomLeadingRadius: 52,
          bottomTrailingRadius: 52,
          topTrailingRadius: 0,
          style: .continuous
        )
      )
      // This sits outside the clipped header shape so it colors the status
      // safe area with the same filling animation as the countdown itself.
      .background(alignment: .top) {
        RestProgressBackground(progress: progress, isFinished: isFinished)
          .frame(height: 160)
          .offset(y: -160)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isFinished ? "Descanso terminado. Continuar" : "Descanso: \(remaining) segundos restantes")
    .accessibilityHint(isFinished ? "Toca para continuar a la siguiente serie" : "El toque estará disponible al finalizar el descanso")
    .background {
      if completionWaveID > 0 {
        TimerCompletionWave()
          .id(completionWaveID)
      }
    }
    .animation(.linear(duration: 0.85), value: remaining)
  }
}

private struct RestProgressBackground: View {
  let progress: CGFloat
  let isFinished: Bool

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle().fill(isFinished ? Color.gymSuccess : Color.gymAccentSecondary)
        Rectangle()
          .fill(isFinished ? Color.gymSuccess : Color.gymAccent)
          .frame(width: geometry.size.width * progress)
      }
    }
    .animation(.linear(duration: 0.85), value: progress)
    .animation(.easeInOut(duration: 0.22), value: isFinished)
  }
}

private struct RestAdjustmentButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(title, action: action)
      .font(.title3.weight(.bold))
      .frame(maxWidth: .infinity, minHeight: 64)
      .foregroundStyle(Color.gymAccent)
      .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 24))
      .overlay {
        RoundedRectangle(cornerRadius: 24)
          .stroke(Color.gymAccent, lineWidth: 1.5)
      }
      .buttonStyle(.plain)
  }
}

private struct PendingBlockSelector: View {
  let execution: WorkoutExecutionState
  let next: WorkoutSetLocator
  let onSelect: (Int) -> Void

  private var options: [PendingBlockOption] {
    guard next.setIndex == 1 else { return [] }
    let recordsByExercise = Set(execution.records.map(\.locator.exerciseIndex))
    let nextExercise = execution.exercise(for: next)
    let nextBlockID = nextExercise?.supersetID.map { "superset:\($0)" } ?? "exercise:\(next.exerciseIndex)"
    var seenBlockIDs = Set<String>()

    return execution.session.exercises.enumerated().compactMap { index, exercise in
      let blockID = exercise.supersetID.map { "superset:\($0)" } ?? "exercise:\(index)"
      guard blockID != nextBlockID,
            seenBlockIDs.insert(blockID).inserted
      else { return nil }

      let members = exercise.supersetID.map { supersetID in
        execution.session.exercises.enumerated()
          .filter { $0.element.supersetID == supersetID }
          .sorted { lhs, rhs in
            (lhs.element.supersetOrder ?? lhs.offset) < (rhs.element.supersetOrder ?? rhs.offset)
          }
      } ?? [(offset: index, element: exercise)]

      guard members.allSatisfy({ !recordsByExercise.contains($0.offset) }),
            let firstMember = members.first
      else { return nil }

      return PendingBlockOption(
        exerciseIndex: firstMember.offset,
        exercises: members.map(\.element),
        isSuperset: exercise.supersetID != nil
      )
    }
  }

  var body: some View {
    if !options.isEmpty {
      VStack(alignment: .leading, spacing: 7) {
        Text("Elegir otro siguiente bloque")
          .font(.caption.weight(.bold))
          .foregroundStyle(Color.gymSecondaryText)
          .textCase(.uppercase)

        ScrollView {
          VStack(spacing: 6) {
            ForEach(options) { option in
              Button {
                onSelect(option.exerciseIndex)
              } label: {
                HStack(spacing: 10) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(option.exerciseNames)
                      .font(.subheadline.weight(.bold))
                      .lineLimit(option.isSuperset ? 2 : 1)
                    HStack(spacing: 5) {
                      if option.isSuperset {
                        Text("Superserie")
                          .font(.caption2.weight(.bold))
                          .foregroundStyle(Color.gymAccent)
                      }
                      Text(option.equipmentSummary)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.gymSecondaryText)
                    }
                  }
                  Spacer(minLength: 0)
                  Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.gymSecondaryText)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 16))
              }
              .buttonStyle(.plain)
            }
          }
        }
        .scrollIndicators(.hidden)
      }
    }
  }
}

private struct PendingBlockOption: Identifiable {
  let exerciseIndex: Int
  let exercises: [TrainingExercise]
  let isSuperset: Bool

  var id: String { exercises.map(\.exerciseID).joined(separator: "+") }
  var exerciseNames: String { exercises.map(\.displayName).joined(separator: " + ") }

  var equipmentSummary: String {
    exercises.reduce(into: [String]()) { labels, exercise in
      let label = exercise.variantLabel ?? exercise.equipment.executionLabel
      if !labels.contains(label) {
        labels.append(label)
      }
    }
    .joined(separator: " + ")
  }
}

private struct NextSetPreview: View {
  @Binding var execution: WorkoutExecutionState
  let locator: WorkoutSetLocator
  let onExecutionChanged: () -> Void

  var body: some View {
    let previews = previews
    if !previews.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(previews.count > 1 ? "Próxima superserie" : "Próxima serie")
          .font(.caption.weight(.bold))
          .foregroundStyle(Color.gymSecondaryText)
          .textCase(.uppercase)

        ScrollView {
          VStack(spacing: 8) {
            ForEach(previews) { preview in
              RestPreviewCard(
                preview: preview,
                onCycleEquipment: { cycleEquipment(for: preview.locator) }
              )
            }
          }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: previews.count > 1 ? 278 : 180)
      }
    }
  }

  private var previews: [RestSetPreview] {
    guard let nextExercise = execution.exercise(for: locator) else { return [] }
    let locators: [WorkoutSetLocator]
    if let supersetID = nextExercise.supersetID {
      locators = execution.session.exercises.enumerated().compactMap { index, exercise in
        guard exercise.supersetID == supersetID,
              exercise.sets.contains(where: { $0.setIndex == locator.setIndex })
        else { return nil }
        return WorkoutSetLocator(exerciseIndex: index, setIndex: locator.setIndex)
      }
    } else {
      locators = [locator]
    }

    return locators.compactMap { current in
      guard let exercise = execution.exercise(for: current),
            let targets = execution.targets(for: current)
      else { return nil }
      return RestSetPreview(locator: current, exercise: exercise, targets: targets, equipment: execution.equipment(for: current) ?? exercise.equipment)
    }
  }

  private func cycleEquipment(for locator: WorkoutSetLocator) {
    guard let exercise = execution.exercise(for: locator) else { return }
    let current = execution.equipment(for: locator) ?? exercise.equipment
    let available = exercise.selectableEquipmentOptions.filter {
      execution.canSelectEquipment($0, for: locator)
    }
    guard available.count > 1,
          let currentIndex = available.firstIndex(of: current)
    else { return }
    let nextEquipment = available[(currentIndex + 1) % available.count]
    guard execution.selectEquipment(nextEquipment, for: locator) else { return }
    onExecutionChanged()
  }
}

private struct RestSetPreview: Identifiable {
  let locator: WorkoutSetLocator
  let exercise: TrainingExercise
  let targets: WorkoutSetTargets
  let equipment: Equipment

  var id: String { "\(exercise.exerciseID)-\(locator.setIndex)" }
}

private struct RestPreviewCard: View {
  let preview: RestSetPreview
  let onCycleEquipment: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text(preview.exercise.displayName)
          .font(.headline.weight(.bold))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
        RestEquipmentChip(
          equipment: preview.equipment,
          variantLabel: preview.equipment == preview.exercise.equipment
            ? preview.exercise.variantLabel
            : nil,
          action: onCycleEquipment
        )
      }

      HStack(spacing: 8) {
        RestPreviewMetric(label: "Serie", value: "\(preview.locator.setIndex)/\(preview.exercise.sets.count)")
        RestPreviewMetric(label: preview.targets.durationSeconds == nil ? "Reps" : "Tiempo", value: workValue)
        RestPreviewMetric(label: loadLabel, value: loadValue, action: onCycleEquipment)
      }
    }
    .padding(14)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(.separator, lineWidth: 1) }
  }

  private var workValue: String {
    if let duration = preview.targets.durationSeconds {
      return "\(duration / 60):\(String(format: "%02d", duration % 60))"
    }
    return preview.targets.reps.map(String.init) ?? "-"
  }

  private var loadLabel: String {
    preview.equipment == .dumbbell ? "Peso c/u" : "Peso"
  }

  private var loadValue: String {
    guard preview.equipment != .bodyweight else { return "0 kg" }
    let amount = preview.targets.weightKg.formatted(.number.precision(.fractionLength(0...2)))
    return preview.equipment == .external ? "+\(amount) kg" : "\(amount) kg"
  }
}

private struct RestPreviewMetric: View {
  let label: String
  let value: String
  var action: (() -> Void)? = nil

  var body: some View {
    let content = VStack(spacing: 4) {
      Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.gymSecondaryText).lineLimit(1)
      Text(value).font(.title3.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, minHeight: 60)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 12))

    if let action {
      Button(action: action) { content }
        .buttonStyle(.plain)
        .accessibilityHint("Toca para cambiar el material y ajustar el peso")
    } else {
      content
    }
  }
}

private struct RestEquipmentChip: View {
  let equipment: Equipment
  let variantLabel: String?
  var action: (() -> Void)? = nil

  var body: some View {
    let content = Text(variantLabel ?? equipment.executionLabel)
      .font(.caption.weight(.semibold))
      .foregroundStyle(Color.gymSecondaryText)
      .lineLimit(1)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(Color.gymCanvas, in: Capsule())

    if let action {
      Button(action: action) { content }
        .buttonStyle(.plain)
        .accessibilityHint("Toca para cambiar el material y ajustar el peso")
    } else {
      content
    }
  }
}

private struct FinishedWorkoutView: View {
  let execution: WorkoutExecutionState
  let startedAt: Date
  let finishedAt: Date
  let exerciseDecisions: [String: String]
  let onFinish: () -> Void
  @State private var csvURL: URL?
  @State private var rewardVisible = false

  private var completedSetCount: Int {
    execution.records.filter { $0.status == .completed }.count
  }

  private var skippedSetCount: Int {
    execution.records.filter { $0.status == .skipped }.count
  }

  private var elapsedSeconds: Int {
    max(0, Int(finishedAt.timeIntervalSince(startedAt).rounded()))
  }

  private var estimateComparison: String {
    let difference = elapsedSeconds - (SessionDurationEstimator.estimate(for: execution.session).totalMinutes * 60)
    if abs(difference) < 60 { return "En el tiempo estimado" }
    let minutes = abs(difference) / 60
    return difference < 0 ? "\(minutes) min por debajo del estimado" : "\(minutes) min por encima del estimado"
  }

  var body: some View {
    VStack(spacing: 18) {
      CompletedWorkoutHeader()
        .padding(.horizontal, -16)
        .padding(.top, -16)

      Spacer(minLength: 0)
      ZStack {
        Circle()
          .stroke(Color.gymSuccess.opacity(0.35), lineWidth: 10)
          .scaleEffect(rewardVisible ? 1.18 : 0.75)
          .opacity(rewardVisible ? 0 : 1)
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 72))
          .foregroundStyle(Color.gymSuccess)
          .symbolEffect(.bounce, value: rewardVisible)
      }
      Text(completionSummary)
        .foregroundStyle(Color.gymSecondaryText)
        .multilineTextAlignment(.center)
      VStack(spacing: 4) {
        Text("\(durationLabel(elapsedSeconds)) reales · \(SessionDurationEstimator.estimate(for: execution.session).totalMinutes) min estimados")
          .font(.headline.weight(.bold))
          .monospacedDigit()
        Text(estimateComparison)
          .font(.subheadline)
          .foregroundStyle(Color.gymSecondaryText)
      }
      Spacer()
      if let csvURL {
        ShareLink(item: csvURL) {
          Label("Exportar CSV", systemImage: "square.and.arrow.up")
        }
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(Color.gymAccentForeground)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
      }
      Button(action: onFinish) {
        Label("Volver a Hoy", systemImage: "house")
      }
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(Color.gymAccentForeground)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
        .buttonStyle(.plain)
    }
    .padding(16)
    .onAppear {
      csvURL = try? WorkoutCSVExporter.write(
        session: execution.session,
        execution: execution,
        exerciseDecisions: exerciseDecisions
      )
      withAnimation(.easeOut(duration: 0.8)) {
        rewardVisible = true
      }
    }
    .sensoryFeedback(.success, trigger: rewardVisible)
  }

  private func durationLabel(_ totalSeconds: Int) -> String {
    "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
  }

  private var completionSummary: String {
    guard skippedSetCount > 0 else {
      return "\(completedSetCount) series registradas en esta sesión."
    }
    return "\(completedSetCount) series registradas · \(skippedSetCount) omitidas."
  }
}

private struct CompletedWorkoutHeader: View {
  var body: some View {
    Text("Entrenamiento completado")
      .font(.system(size: 31, weight: .bold))
      .multilineTextAlignment(.center)
      .minimumScaleFactor(0.8)
      .foregroundStyle(Color.gymAccentForeground)
      .frame(maxWidth: .infinity, minHeight: 132)
      .padding(.horizontal, 24)
      .background(alignment: .top) {
        Color.gymAccent
          .frame(height: 112)
          .offset(y: -112)
      }
      .background {
        UnevenRoundedRectangle(
          topLeadingRadius: 0,
          bottomLeadingRadius: 52,
          bottomTrailingRadius: 52,
          topTrailingRadius: 0,
          style: .continuous
        )
        .fill(Color.gymAccent)
      }
  }
}

private struct BottomActions: View {
  let primaryTitle: String
  let primaryAction: () -> Void
  var skipAction: (() -> Void)? = nil
  var primaryDisabled = false
  let onBack: () -> Void
  let onSessionActionsRequested: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      SessionNavigationButton(
        onBack: onBack,
        onSessionActionsRequested: onSessionActionsRequested
      )

      Button(primaryTitle, action: primaryAction)
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(Color.gymAccentForeground)
        .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
        .buttonStyle(.plain)
        .disabled(primaryDisabled)

      if let skipAction {
        Button(action: skipAction) {
          Image(systemName: "arrowshape.turn.up.right.fill")
            .font(.headline.weight(.bold))
            .frame(width: 64, height: 64)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel("Saltar serie")
        .buttonStyle(.plain)
      }
    }
  }
}

private struct SessionNavigationButton: View {
  let onBack: () -> Void
  let onSessionActionsRequested: () -> Void

  var body: some View {
    Image(systemName: "chevron.left")
      .font(.headline.weight(.bold))
      .frame(width: 64, height: 64)
      .foregroundStyle(.primary)
      .glassEffect(.regular.interactive(), in: Circle())
      .contentShape(Circle())
      .gesture(
        LongPressGesture(minimumDuration: 0.42)
          .onEnded { _ in onSessionActionsRequested() }
          .exclusively(before: TapGesture().onEnded(onBack))
      )
      .accessibilityAddTraits(.isButton)
    .accessibilityHint("Mantén pulsado para abrir las acciones del entrenamiento")
  }
}

private struct SessionActionFan: View {
  let completed: Int
  let total: Int
  let onDismiss: () -> Void
  let onHome: () -> Void
  let onProgress: () -> Void
  let onFinish: () -> Void

  private var percentage: Int {
    Int((Double(completed) / Double(max(total, 1)) * 100).rounded())
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(Color.black.opacity(0.14))
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)

      SessionActionButton(symbol: "house.fill", label: "Casa", action: onHome)
        .offset(x: 4, y: -154)
        .transition(.scale(scale: 0.2, anchor: .bottomLeading).combined(with: .opacity))

      ProgressActionButton(percentage: percentage, action: onProgress)
        .offset(x: 78, y: -104)
        .transition(.scale(scale: 0.2, anchor: .bottomLeading).combined(with: .opacity))

      SessionActionButton(symbol: "stop.fill", label: "Finalizar", tint: .gymDanger, destructive: true, action: onFinish)
        .offset(x: 146, y: -40)
        .transition(.scale(scale: 0.2, anchor: .bottomLeading).combined(with: .opacity))

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(.headline.weight(.bold))
          .frame(width: 64, height: 64)
          .foregroundStyle(.primary)
          .glassEffect(.regular.interactive(), in: Circle())
          .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)
      // The execution screens reserve seven points for the global progress bar.
      // Keep this anchor aligned with the navigation button it replaces.
      .padding(.leading, 16)
      .padding(.bottom, 23)
      .accessibilityLabel("Cerrar acciones del entrenamiento")
    }
    .animation(.smooth(duration: 0.28), value: completed)
  }
}

private struct SessionActionButton: View {
  let symbol: String
  let label: String
  var tint: Color = .gymAccent
  var destructive = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.headline.weight(.bold))
        .frame(width: 56, height: 56)
        .foregroundStyle(destructive ? Color.white : Color.gymAccentForeground)
        .glassEffect(.regular.tint(tint).interactive(), in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

private struct ProgressActionButton: View {
  let percentage: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("\(percentage)%")
        .font(.caption.weight(.bold))
        .monospacedDigit()
        .frame(width: 56, height: 56)
        .foregroundStyle(Color.gymAccent)
        .background(.regularMaterial, in: Circle())
        .overlay {
          Circle()
            .trim(from: 0, to: CGFloat(percentage) / 100)
            .stroke(Color.gymAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(3)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Progreso del entrenamiento: \(percentage) por ciento")
  }
}

private struct ActiveWorkoutProgressView: View {
  let execution: WorkoutExecutionState
  let onBack: () -> Void
  let onHome: () -> Void
  let onFinish: () -> Void

  private var completedSetCount: Int {
    execution.records.filter { $0.status == .completed }.count
  }

  private var skippedSetCount: Int {
    execution.records.filter { $0.status == .skipped }.count
  }

  private var pendingSetCount: Int {
    execution.totalSetCount - execution.records.count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(execution.session.exercises.enumerated()), id: \.element.exerciseID) { index, exercise in
          ExerciseProgressCard(
            exercise: exercise,
            exerciseIndex: index,
            execution: execution
          )
        }
      }
      .padding(16)
      .padding(.bottom, 92)
    }
    .background(GymCanvas())
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(
        title: "Progreso del entrenamiento",
        detail: "\(completedSetCount) hechas · \(skippedSetCount) omitidas · \(pendingSetCount) pendientes"
      )
    }
    .overlay(alignment: .bottom) {
      HStack(spacing: 12) {
        Button(action: onBack) {
          Image(systemName: "chevron.left")
            .font(.headline.weight(.bold))
            .frame(width: 56, height: 56)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Volver al entrenamiento")

        Button(action: onHome) {
          Image(systemName: "house.fill")
            .font(.headline.weight(.bold))
            .frame(width: 56, height: 56)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Volver a Hoy")

        Button("Finalizar", action: onFinish)
          .font(.headline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 56)
          .foregroundStyle(.white)
          .glassEffect(.regular.tint(Color.gymDanger).interactive(), in: Capsule())
          .buttonStyle(.plain)
      }
      .padding(16)
    }
  }
}

private struct ExerciseProgressCard: View {
  let exercise: TrainingExercise
  let exerciseIndex: Int
  let execution: WorkoutExecutionState

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text(exercise.displayName)
          .font(.headline.weight(.bold))
          .lineLimit(2)
        Spacer(minLength: 0)
        Text(execution.equipment(for: WorkoutSetLocator(exerciseIndex: exerciseIndex, setIndex: 1))?.executionLabel ?? exercise.equipment.executionLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.gymSecondaryText)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(Color.gymCanvas, in: Capsule())
      }

      ForEach(exercise.sets, id: \.setIndex) { set in
        let locator = WorkoutSetLocator(exerciseIndex: exerciseIndex, setIndex: set.setIndex)
        let record = execution.records.first { $0.locator == locator }
        HStack {
          Text("Serie \(set.setIndex)")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Text(targetLabel(for: locator))
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
          Text(statusLabel(record))
            .font(.caption.weight(.bold))
            .foregroundStyle(statusColor(record))
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 10))
      }
    }
    .padding(14)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(.separator.opacity(0.7), lineWidth: 1) }
  }

  private func targetLabel(for locator: WorkoutSetLocator) -> String {
    guard let targets = execution.targets(for: locator) else { return "-" }
    if let duration = targets.durationSeconds {
      return "\(duration / 60):\(String(format: "%02d", duration % 60))"
    }
    let reps = targets.reps.map(String.init) ?? "-"
    let weight = targets.weightKg.formatted(.number.precision(.fractionLength(0...2)))
    return "\(reps) x \(weight) kg"
  }

  private func statusLabel(_ record: WorkoutSetRecord?) -> String {
    guard let record else { return "Pendiente" }
    return record.status == .completed ? "Hecha" : "Omitida"
  }

  private func statusColor(_ record: WorkoutSetRecord?) -> Color {
    guard let record else { return Color.gymSecondaryText }
    return record.status == .completed ? Color.gymCompleted : Color.gymWarning
  }
}

private struct SetHeader: View {
  let exercise: TrainingExercise
  let setIndex: Int
  let supersetPosition: Int?
  let supersetSize: Int?

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text(exercise.displayName)
          .font(.system(size: 27, weight: .bold))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let supersetPosition, let supersetSize {
          FeedbackChip(
            text: "Superserie \(supersetPosition)/\(supersetSize)",
            accent: true
          )
        }
      }
      .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)

      SetProgressIndicators(
        setCount: exercise.sets.count,
        currentSetIndex: setIndex
      )
      .padding(.top, 5)
    }
  }
}

private struct MaterialSelector: View {
  @Binding var selection: Equipment
  let options: [Equipment]
  let unavailableOptions: Set<Equipment>

  var body: some View {
    GlassSegmentedSelector(
      selection: $selection,
      options: options,
      unavailableOptions: unavailableOptions,
      label: { $0.executionLabel }
    )
  }
}

private struct SetTargetCard: View {
  let label: String
  let value: String
  var unit: String? = nil
  var numericValue: Double? = nil
  var plateLayout: BarbellPlateLayout? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Text(label)
          .font(.headline.weight(.semibold))
          .foregroundStyle(Color.gymSecondaryText)
        ZStack(alignment: .top) {
          if let plateLayout, !plateLayout.sidePlatesKg.isEmpty {
            PlateStack(plates: plateLayout.sidePlatesKg, side: .left)
            PlateStack(plates: plateLayout.sidePlatesKg, side: .right)
          }
          Text(value)
            .font(.system(size: 58, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .contentTransition(numericValue.map { .numericText(value: $0) } ?? .identity)
            .animation(.snappy(duration: 0.32, extraBounce: 0.04), value: numericValue)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        if let unit {
          Text(unit)
            .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.gymSecondaryText)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 22))
      .overlay {
        RoundedRectangle(cornerRadius: 22)
          .stroke(Color.gymAccent, lineWidth: 2)
      }
    }
    .buttonStyle(.plain)
  }
}

private struct PlateStack: View {
  enum Side { case left, right }

  let plates: [Double]
  let side: Side

  var body: some View {
    HStack {
      if side == .left { stack; Spacer(minLength: 0) }
      else { Spacer(minLength: 0); stack }
    }
    .padding(.horizontal, 8)
    .accessibilityLabel("Discos por lado: \(plates.map { $0.formatted() }.joined(separator: ", ")) kg")
  }

  private var stack: some View {
    VStack(spacing: 4) {
      ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
        Text(plate.formatted(.number.precision(.fractionLength(0...2))))
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.primary)
          .frame(width: plateWidth(plate), height: plateHeight(plate))
          .background(Color.gymAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
          .overlay {
            RoundedRectangle(cornerRadius: 6).stroke(Color.gymAccent.opacity(0.45), lineWidth: 1)
          }
      }
    }
  }

  private func plateWidth(_ plate: Double) -> CGFloat {
    30 + CGFloat(min(plate, 20)) * 1.55
  }

  private func plateHeight(_ plate: Double) -> CGFloat {
    22 + CGFloat(min(plate, 20)) * 0.7
  }
}

private struct SetTargetEditor: View {
  let field: SetEditField
  let initialValue: Double
  let equipment: Equipment
  let onConfirm: (Double) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var value: Double

  init(
    field: SetEditField,
    initialValue: Double,
    equipment: Equipment,
    onConfirm: @escaping (Double) -> Void
  ) {
    self.field = field
    self.initialValue = initialValue
    self.equipment = equipment
    self.onConfirm = onConfirm
    _value = State(initialValue: initialValue)
  }

  var body: some View {
    VStack(spacing: 18) {
      HStack {
        Button(action: dismiss.callAsFunction) {
          Image(systemName: "xmark")
            .font(.headline.weight(.bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel("Descartar cambios")
        .buttonStyle(.plain)
        Spacer()
        Text("Ajustar \(field.title)")
          .font(.headline.weight(.bold))
        Spacer()
        Button {
          onConfirm(value)
          dismiss()
        } label: {
          Image(systemName: "checkmark")
            .font(.headline.weight(.bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(Color.gymAccentForeground)
            .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Circle())
        }
        .accessibilityLabel("Confirmar cambios")
        .buttonStyle(.plain)
      }

      Spacer(minLength: 0)
      Text(displayValue)
        .font(.system(size: 72, weight: .bold))
        .monospacedDigit()
        .contentTransition(.numericText(value: value))

      HStack(spacing: 12) {
        adjustmentButton(symbol: "minus") { adjust(-1) }
        adjustmentButton(symbol: "plus") { adjust(1) }
      }
      Spacer(minLength: 0)
    }
    .padding(20)
  }

  private var displayValue: String {
    field == .reps
      ? "\(Int(value))"
      : "\(value.formatted(.number.precision(.fractionLength(0...2)))) kg"
  }

  private func adjustmentButton(symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 30, weight: .bold))
        .frame(maxWidth: .infinity, minHeight: 76)
        .foregroundStyle(.primary)
        .background(Color.gymAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.gymAccent.opacity(0.45), lineWidth: 1) }
    }
    .buttonStyle(.plain)
  }

  private func adjust(_ direction: Int) {
    if field == .reps {
      value = Double(max(1, Int(value) + direction))
    } else {
      value = EquipmentLoadRules.adjustedWeight(
        from: value,
        equipment: equipment,
        direction: direction
      )
    }
  }
}

private struct TimedSetTarget: View {
  let seconds: Int
  @Binding var endsAt: Date?
  @Binding var pausedRemaining: Int
  let onAdjustDuration: (Int) -> Void
  let onFinishedTap: () -> Void
  let onFinishedChanged: (Bool) -> Void
  @State private var hasStarted = false
  @State private var hasAnnouncedCompletion = false
  @State private var completionWaveID = 0

  private var isRunning: Bool { endsAt != nil }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = remainingSeconds(at: context.date)
      let isFinished = remaining == 0
      let progress = CGFloat(remaining) / CGFloat(max(seconds, 1))

      VStack(spacing: 12) {
        HStack(spacing: 8) {
          RestAdjustmentButton(title: "-15s") { onAdjustDuration(-15) }
          RestAdjustmentButton(title: "+15s") { onAdjustDuration(15) }
        }

        Button {
          if isFinished {
            onFinishedTap()
          } else {
            toggle()
          }
        } label: {
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 30)
              .fill(isFinished ? Color.gymSuccess : Color.gymAccentSecondary)

            GeometryReader { geometry in
              Rectangle()
                .fill(isFinished ? Color.gymSuccess : Color.gymAccent)
                .frame(width: geometry.size.width * progress)
            }

            VStack(spacing: 5) {
              Text(isFinished ? "Ejercicio terminado" : "Tiempo")
                .font(.headline.weight(.bold))
              Text(clock(remaining))
                .font(.system(size: 64, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            }
            .foregroundStyle(isFinished ? Color.white : Color.gymAccentForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .frame(maxWidth: .infinity, minHeight: 128)
          .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
        .background {
          if completionWaveID > 0 {
            TimerCompletionWave()
              .id(completionWaveID)
          }
        }
        .animation(.linear(duration: 0.85), value: remaining)

        HStack(spacing: 12) {
          Button(action: reset) {
            Image(systemName: "arrow.counterclockwise")
              .font(.headline.weight(.bold))
              .frame(width: 58, height: 58)
              .foregroundStyle(.primary)
              .glassEffect(.regular.interactive(), in: Circle())
          }
          .buttonStyle(.plain)

          Button(action: toggle) {
            Label(
              isRunning ? "Pausar" : "Iniciar",
              systemImage: isRunning ? "pause.fill" : "play.fill"
            )
          }
          .font(.headline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 58)
          .foregroundStyle(Color.gymAccentForeground)
          .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
          .buttonStyle(.plain)
          .disabled(isFinished)
          .opacity(isFinished ? 0.45 : 1)
        }
      }
      .onAppear {
        if pausedRemaining == 0, endsAt == nil {
          pausedRemaining = seconds
        }
        onFinishedChanged(false)
      }
      .onChange(of: remaining) { _, newValue in
        if newValue > 0 {
          hasAnnouncedCompletion = false
        }
        let isFinished = hasStarted && newValue == 0
        onFinishedChanged(isFinished)
        if isFinished {
          announceCompletionIfNeeded()
        }
      }
    }
  }

  private func remainingSeconds(at date: Date) -> Int {
    if let endsAt {
      return max(0, Int(endsAt.timeIntervalSince(date).rounded(.up)))
    }
    return pausedRemaining
  }

  private func toggle() {
    if let endsAt {
      pausedRemaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
      self.endsAt = nil
    } else {
      let duration = pausedRemaining > 0 ? pausedRemaining : seconds
      pausedRemaining = duration
      endsAt = .now.addingTimeInterval(TimeInterval(duration))
      hasStarted = true
    }
  }

  private func reset() {
    endsAt = nil
    pausedRemaining = seconds
    hasStarted = false
    hasAnnouncedCompletion = false
    onFinishedChanged(false)
  }

  private func announceCompletionIfNeeded() {
    guard !hasAnnouncedCompletion else { return }
    hasAnnouncedCompletion = true
    completionWaveID += 1
    TimerCompletionFeedback.play()
  }

  private func clock(_ totalSeconds: Int) -> String {
    "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
  }

  private func timeAdjustmentButton(title: String, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .font(.caption.weight(.bold))
      .foregroundStyle(.primary)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(.black.opacity(0.18), in: Capsule())
      .buttonStyle(.plain)
  }
}

private struct TimerCompletionWave: View {
  @State private var isExpanded = false

  var body: some View {
    ZStack {
      waveRing(scale: 24, opacity: 0.30, lineWidth: 3)
      waveRing(scale: 16, opacity: 0.20, lineWidth: 5)
      waveRing(scale: 10, opacity: 0.12, lineWidth: 8)
    }
    .allowsHitTesting(false)
    .onAppear {
      withAnimation(.easeOut(duration: 1.5)) {
        isExpanded = true
      }
    }
  }

  private func waveRing(scale: CGFloat, opacity: Double, lineWidth: CGFloat) -> some View {
    Circle()
      .stroke(Color.gymSuccess.opacity(opacity), lineWidth: lineWidth)
      .frame(width: 88, height: 88)
      .scaleEffect(isExpanded ? scale : 0.05)
      .opacity(isExpanded ? 0 : 1)
  }
}

private enum TimerCompletionFeedback {
  static func play() {
    let feedback = UINotificationFeedbackGenerator()
    feedback.prepare()
    feedback.notificationOccurred(.success)
    AudioServicesPlaySystemSound(1005)
  }
}

@MainActor
private enum WorkoutTimerNotification {
  enum Identifier: String, CaseIterable {
    case rest = "workout-rest-timer"
    case timedSet = "workout-timed-set-timer"
  }

  private static var generations: [Identifier: UInt] = [:]

  static func schedule(
    identifier: Identifier,
    endsAt: Date?,
    title: String,
    body: String
  ) {
    let generation = (generations[identifier] ?? 0) &+ 1
    generations[identifier] = generation

    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [identifier.rawValue])

    guard let endsAt, endsAt > .now else { return }

    Task {
      let settings = await center.notificationSettings()
      let isAuthorized: Bool
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        isAuthorized = true
      case .notDetermined:
        isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
      case .denied:
        isAuthorized = false
      @unknown default:
        isAuthorized = false
      }

      guard isAuthorized,
            generations[identifier] == generation,
            endsAt > .now
      else { return }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default

      let dateComponents = Calendar.current.dateComponents(
        [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
        from: endsAt
      )
      let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
      center.removePendingNotificationRequests(withIdentifiers: [identifier.rawValue])
      let request = UNNotificationRequest(identifier: identifier.rawValue, content: content, trigger: trigger)
      try? await center.add(request)
    }
  }

  static func cancelAll() {
    for identifier in Identifier.allCases {
      generations[identifier] = (generations[identifier] ?? 0) &+ 1
    }
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: Identifier.allCases.map(\.rawValue)
    )
  }
}

extension Equipment {
  var executionLabel: String {
    switch self {
    case .barbell: "Barra"
    case .multipower: "Multipower"
    case .dumbbell: "Mancuernas"
    case .cable: "Polea"
    case .plateLoadedMachine: "Discos"
    case .external: "Lastre"
    case .bodyweight: "Peso corporal"
    }
  }
}
