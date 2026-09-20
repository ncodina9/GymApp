import SwiftUI
import SwiftData
import GymAppNativeCore

struct SetExecutionView: View {
  let session: TrainingSession
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
  @State private var transitionOrigin: ExecutionPhase = .workingSet
  @State private var transitionDirection: FlowDirection = .forward
  @State private var startedAt: Date
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  init(session: TrainingSession, onFinishToToday: @escaping () -> Void = {}) {
    self.session = session
    self.onFinishToToday = onFinishToToday
    _execution = State(initialValue: WorkoutExecutionState(session: session))
    _startedAt = State(initialValue: .now)
  }

  init(snapshot: ActiveWorkoutSnapshot, onFinishToToday: @escaping () -> Void = {}) {
    session = snapshot.execution.session
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
              onExecutionChanged: persistActiveWorkout
            )
          } else {
            FinishedWorkoutView(execution: execution, onFinish: onFinishToToday)
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
              onRegister: registerCurrentSet
            )
          }
        case .rest:
          if let restEndsAt, let next = execution.current {
            RestView(
              execution: execution,
              next: next,
              endsAt: restEndsAt,
              totalSeconds: restTotalSeconds,
              onAdjust: adjustRest,
              onContinue: continueFromRest,
              onSelectBlock: selectNextBlock
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
          FinishedWorkoutView(execution: execution, onFinish: onFinishToToday)
        }
      }
      .id(TransitionKey(origin: transitionOrigin, destination: phase))
      .transition(transition)
      .zIndex(1)
    }
    .toolbar(.hidden, for: .navigationBar)
    .overlay(alignment: .top) {
      WorkoutProgressBar(
        completed: execution.completedSetCount,
        total: execution.totalSetCount
      )
      .ignoresSafeArea(edges: .top)
    }
    .onAppear(perform: persistActiveWorkout)
    .onDisappear {
      if phase != .finished {
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
    .onChange(of: setTimerRemaining) { _, _ in persistActiveWorkout() }
    .onChange(of: exerciseDecisions) { _, _ in persistActiveWorkout() }
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
    ActiveWorkoutStore.save(
      ActiveWorkoutSnapshot(
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
        startedAt: startedAt
      ),
      in: modelContext
    )
  }

  private func finishWorkout() {
    withAnimation(.smooth(duration: 0.3)) {
      phase = .finished
    }
    ActiveWorkoutStore.markCompleted(sessionID: session.sessionID, in: modelContext)
    ActiveWorkoutStore.clear(in: modelContext)
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
        Rectangle().fill(Color.secondary.opacity(0.18))
        Rectangle()
          .fill(Color.accentColor)
          .frame(width: geometry.size.width * progress)
      }
    }
    .frame(height: 44)
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
  @State private var editField: SetEditField?

  private var exercise: TrainingExercise? { execution.exercise(for: locator) }
  private var trainingSet: TrainingSet? { execution.trainingSet(for: locator) }
  private var activeEquipment: Equipment { execution.equipment(for: locator) ?? .barbell }
  private var activeTargets: WorkoutSetTargets? { execution.targets(for: locator) }

  var body: some View {
    Group {
      if let exercise, let trainingSet {
        VStack(alignment: .leading, spacing: 12) {
          SetHeader(
            exercise: exercise,
            setIndex: trainingSet.setIndex - 1,
            supersetPosition: supersetPosition(for: exercise),
            supersetSize: supersetSize(for: exercise)
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

          if trainingSet.type == .timed {
            TimedSetTarget(
              seconds: activeTargets?.durationSeconds ?? 0,
              endsAt: $timerEndsAt,
              pausedRemaining: $timerRemaining,
              onAdjustDuration: adjustTimedDuration,
              onFinishedTap: onContinue
            )
          } else {
            VStack(spacing: 10) {
              SetTargetCard(
                label: "Reps",
                value: activeTargets?.reps.map(String.init) ?? "-",
                action: { editField = .reps }
              )
              SetTargetCard(
                label: "Peso",
                value: (activeTargets?.weightKg ?? trainingSet.targetWeightKg)
                  .formatted(.number.precision(.fractionLength(0...1))),
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

          Text(exercise.notes)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))

          BottomActions(
            primaryTitle: "Continuar",
            primaryAction: onContinue,
            skipAction: onSkip,
            primaryDisabled: trainingSet.type == .timed
          )
        }
        .padding(16)
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
    if let equipmentOptions = exercise.equipmentOptions {
      return equipmentOptions
    }

    let variants: [Equipment] = switch exercise.exerciseID {
    case "press-banca-barra", "press-banca-inclinado", "press-militar-sentado", "press-militar-sentado-velocidad":
      [.barbell, .multipower, .dumbbell]
    case "remo-inclinado-barra", "remo-barra-multipower", "press-cerrado-multipower", "hip-thrust-barra", "hip-thrust-volumen":
      [.barbell, .multipower]
    default:
      [exercise.equipment]
    }

    return variants.contains(exercise.equipment)
      ? variants
      : [exercise.equipment] + variants
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

  private var exercise: TrainingExercise? { execution.exercise(for: locator) }
  private var trainingSet: TrainingSet? { execution.trainingSet(for: locator) }
  private var targets: WorkoutSetTargets? { execution.targets(for: locator) }
  private var equipment: Equipment { execution.equipment(for: locator) ?? exercise?.equipment ?? .barbell }
  private var isTimed: Bool { trainingSet?.type == .timed }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      FeedbackHeader(execution: execution, locator: locator, exercise: exercise)

      if isTimed {
        FeedbackMetric(label: "Tiempo", value: feedbackTimeLabel(targets?.durationSeconds ?? 0))
      } else {
        HStack(spacing: 8) {
          FeedbackMetric(label: "Reps", value: targets?.reps.map(String.init) ?? "-")
          FeedbackMetric(
            label: "Peso",
            value: "\(targets?.weightKg.formatted(.number.precision(.fractionLength(0...1))) ?? "-") kg",
            footer: equipment.executionLabel
          )
        }
      }

      VStack(spacing: 8) {
        if !isTimed {
          FeedbackStepper(label: "RIR", value: $rir, range: 0 ... 5)
        }
        PainLevelControl(label: "Rodilla", value: $painKnee)
        PainLevelControl(label: "Muñeca", value: $painWrist)
        PainLevelControl(label: "Hombro", value: $painShoulder)
        PainLevelControl(label: "Lumbar", value: $painLowerBack)
        NotePicker(note: $note)
      }
      .padding(10)
      .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))

      Spacer(minLength: 0)

      HStack(spacing: 12) {
        Button(action: onBack) {
          Image(systemName: "chevron.left")
            .font(.headline.weight(.bold))
            .frame(width: 64, height: 64)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)

        Button("Registrar serie", action: onRegister)
          .font(.headline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 64)
          .foregroundStyle(.white)
          .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
          .buttonStyle(.plain)
      }
    }
    .padding(16)
  }
}

private struct FeedbackHeader: View {
  let execution: WorkoutExecutionState
  let locator: WorkoutSetLocator
  let exercise: TrainingExercise?

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          Text(exercise?.baseExerciseName ?? "Ejercicio")
          .font(.system(size: 27, weight: .bold))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)

        SetProgressIndicators(
          setCount: exercise?.sets.count ?? 0,
          currentSetIndex: locator.setIndex - 1
        )
        .padding(.top, 5)
      }

      if let exercise, let supersetID = exercise.supersetID {
        let members = execution.session.exercises.filter { $0.supersetID == supersetID }
        let position = (members.firstIndex { $0.exerciseID == exercise.exerciseID } ?? 0) + 1
        FeedbackChip(
          text: "Superserie \(position)/\(members.count) · Ronda \(locator.setIndex)/\(exercise.sets.count)",
          accent: true
        )
      }
    }
  }
}

private struct SetProgressIndicators: View {
  let setCount: Int
  let currentSetIndex: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0 ..< max(setCount, 1), id: \.self) { index in
        let isCompleted = index < currentSetIndex
        let isCurrent = index == currentSetIndex
        Circle()
          .fill(isCompleted ? Color.accentColor : .clear)
          .overlay {
            Circle().strokeBorder(
              isCompleted || isCurrent ? Color.accentColor : .secondary.opacity(0.35),
              lineWidth: 2
            )
          }
          .frame(width: 14, height: 14)
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
      .foregroundStyle(accent ? Color.accentColor : .secondary)
      .background(accent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.12), in: Capsule())
  }
}

private struct FeedbackMetric: View {
  let label: String
  let value: String
  var footer: String? = nil

  var body: some View {
    VStack(spacing: 5) {
      Text(label).font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
      Text(value).font(.system(size: 31, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
      Text(footer ?? "Material")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .opacity(footer == nil ? 0 : 1)
    }
    .frame(maxWidth: .infinity, minHeight: 94)
    .background(.background, in: RoundedRectangle(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 1) }
  }
}

private struct FeedbackStepper: View {
  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    HStack {
      Text(label).font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
      Spacer()
      Button { value = max(range.lowerBound, value - 1) } label: { Image(systemName: "minus") }
        .feedbackControlButton()
      Text("\(value)").font(.title3.weight(.bold)).monospacedDigit().frame(width: 24)
      Button { value = min(range.upperBound, value + 1) } label: { Image(systemName: "plus") }
        .feedbackControlButton()
    }
  }
}

private struct PainLevelControl: View {
  let label: String
  @Binding var value: Int

  var body: some View {
    HStack(spacing: 6) {
      Text(label).font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
      Spacer()
      ForEach(0 ... 3, id: \.self) { level in
        Button("\(level)") { value = level }
          .font(.subheadline.weight(.bold))
          .frame(width: 40, height: 40)
          .foregroundStyle(value == level ? .white : .primary)
          .background(value == level ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
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
          .frame(maxWidth: .infinity, minHeight: 42)
          .foregroundStyle(note == option ? .white : .primary)
          .background(note == option ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
          .buttonStyle(.plain)
      }
    }
  }
}

private extension View {
  func feedbackControlButton() -> some View {
    self
      .font(.subheadline.weight(.bold))
      .frame(width: 40, height: 40)
      .foregroundStyle(.primary)
      .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      .buttonStyle(.plain)
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
      Text(exercises.count > 1 ? "Evaluar superserie" : "Evaluar ejercicio")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(exercises) { exercise in
            ExerciseDecisionSection(
              exercise: exercise,
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
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
        .buttonStyle(.plain)
    }
    .padding(16)
  }
}

private struct ExerciseDecisionSection: View {
  let exercise: TrainingExercise
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
      Text(exercise.baseExerciseName)
        .font(.title3.weight(.bold))
        .lineLimit(2)
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
      .font(.caption.weight(.bold))
      .frame(maxWidth: .infinity, minHeight: 50)
      .foregroundStyle(selection == option ? .white : decisionColor(option))
      .background(
        selection == option ? decisionColor(option) : decisionColor(option).opacity(0.14),
        in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(decisionColor(option).opacity(selection == option ? 1 : 0.7), lineWidth: 1.5)
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
    if lower.contains("bajar") || lower.contains("molestia") { return .red }
    if lower.contains("subir") { return .green }
    return Color.accentColor
  }
}

private struct RestView: View {
  let execution: WorkoutExecutionState
  let next: WorkoutSetLocator
  let endsAt: Date
  let totalSeconds: Int
  let onAdjust: (Int) -> Void
  let onContinue: () -> Void
  let onSelectBlock: (Int) -> Void

  private var hasNextSuperset: Bool {
    execution.exercise(for: next)?.supersetID != nil
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
      VStack(spacing: 8) {
        RestCountdownBar(remaining: remaining, totalSeconds: totalSeconds, onContinue: onContinue)

        HStack(spacing: 8) {
          RestAdjustmentButton(title: "-15s") { onAdjust(-15) }
          RestAdjustmentButton(title: "+15s") { onAdjust(15) }
        }

        VStack(spacing: hasNextSuperset ? 8 : 3) {
          NextSetPreview(execution: execution, locator: next)
            .frame(maxHeight: hasNextSuperset ? 186 : 132, alignment: .top)
            .padding(10)
            .overlay {
              RoundedRectangle(cornerRadius: 18)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
            }

          PendingBlockSelector(
            execution: execution,
            next: next,
            isRestFinished: remaining == 0,
            onSelect: onSelectBlock
          )
          .frame(maxHeight: hasNextSuperset ? .infinity : 148, alignment: .top)
        }

        Button("Siguiente", action: onContinue)
          .font(.headline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 64)
          .foregroundStyle(.white)
          .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
          .buttonStyle(.plain)
      }
      .padding(16)
    }
  }

}

private struct RestCountdownBar: View {
  let remaining: Int
  let totalSeconds: Int
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
        RoundedRectangle(cornerRadius: 30)
          .fill(isFinished ? Color.green : Color.accentColor.opacity(0.6))

        GeometryReader { geometry in
          Rectangle()
            .fill(isFinished ? Color.green : Color.accentColor)
            .frame(width: geometry.size.width * progress)
        }

        VStack(spacing: 5) {
          Text(isFinished ? "Descanso terminado" : "Descanso")
            .font(.headline.weight(.bold))
          Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
            .font(.system(size: 68, weight: .bold))
            .monospacedDigit()
            .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 160)
      .clipShape(RoundedRectangle(cornerRadius: 30))
    }
    .buttonStyle(.plain)
    .animation(.linear(duration: 0.85), value: remaining)
  }
}

private struct RestAdjustmentButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(title, action: action)
      .font(.title3.weight(.bold))
      .frame(maxWidth: .infinity, minHeight: 64)
      .foregroundStyle(.white)
      .glassEffect(.regular.tint(.accentColor).interactive(), in: RoundedRectangle(cornerRadius: 24))
      .buttonStyle(.plain)
  }
}

private struct PendingBlockSelector: View {
  let execution: WorkoutExecutionState
  let next: WorkoutSetLocator
  let isRestFinished: Bool
  let onSelect: (Int) -> Void

  private var options: [PendingBlockOption] {
    guard next.setIndex == 1 else { return [] }
    var seenSupersets = Set<String>()

    return execution.session.exercises.enumerated().compactMap { index, exercise in
      guard index != next.exerciseIndex,
            !execution.records.contains(where: { $0.locator.exerciseIndex == index })
      else { return nil }

      if let supersetID = exercise.supersetID {
        guard seenSupersets.insert(supersetID).inserted else { return nil }
      }
      return PendingBlockOption(exerciseIndex: index, exercise: exercise)
    }
  }

  var body: some View {
    if !options.isEmpty {
      VStack(alignment: .leading, spacing: 7) {
        Text("Cambiar siguiente bloque")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)

        ScrollView {
          VStack(spacing: 6) {
            ForEach(options) { option in
              Button {
                onSelect(option.exerciseIndex)
              } label: {
                HStack(spacing: 10) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(option.exercise.baseExerciseName)
                      .font(.subheadline.weight(.bold))
                      .lineLimit(1)
                    HStack(spacing: 5) {
                      if option.exercise.supersetID != nil {
                        Text("Superserie")
                          .font(.caption2.weight(.bold))
                          .foregroundStyle(Color.accentColor)
                      }
                      Text(option.exercise.variantLabel ?? option.exercise.equipment.executionLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                  }
                  Spacer(minLength: 0)
                  Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
              }
              .buttonStyle(.plain)
              .disabled(!isRestFinished)
              .opacity(isRestFinished ? 1 : 0.45)
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
  let exercise: TrainingExercise

  var id: Int { exerciseIndex }
}

private struct NextSetPreview: View {
  let execution: WorkoutExecutionState
  let locator: WorkoutSetLocator

  var body: some View {
    let previews = previews
    if !previews.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(previews.count > 1 ? "Próxima superserie" : "Próxima serie")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)

        ScrollView {
          VStack(spacing: 8) {
            ForEach(previews) { preview in
              RestPreviewCard(preview: preview)
            }
          }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: previews.count > 1 ? 230 : 138)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text(preview.exercise.baseExerciseName)
          .font(.subheadline.weight(.bold))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
        RestEquipmentChip(equipment: preview.equipment, variantLabel: preview.exercise.variantLabel)
      }

      HStack(spacing: 8) {
        RestPreviewMetric(label: "Serie", value: "\(preview.locator.setIndex)/\(preview.exercise.sets.count)")
        RestPreviewMetric(label: preview.targets.durationSeconds == nil ? "Reps" : "Tiempo", value: workValue)
        RestPreviewMetric(label: loadLabel, value: loadValue)
      }
    }
    .padding(12)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
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
    let amount = preview.targets.weightKg.formatted(.number.precision(.fractionLength(0...1)))
    return preview.equipment == .external ? "+\(amount) kg" : "\(amount) kg"
  }
}

private struct RestPreviewMetric: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 4) {
      Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
      Text(value).font(.subheadline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, minHeight: 52)
    .background(.background, in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct RestEquipmentChip: View {
  let equipment: Equipment
  let variantLabel: String?

  var body: some View {
    Text(variantLabel ?? equipment.executionLabel)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(.background, in: Capsule())
  }
}

private struct FinishedWorkoutView: View {
  let execution: WorkoutExecutionState
  let onFinish: () -> Void
  @State private var csvURL: URL?
  @State private var rewardVisible = false

  private var completedSetCount: Int {
    execution.records.filter { $0.status == .completed }.count
  }

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      ZStack {
        Circle()
          .stroke(Color.green.opacity(0.35), lineWidth: 10)
          .scaleEffect(rewardVisible ? 1.18 : 0.75)
          .opacity(rewardVisible ? 0 : 1)
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 72))
          .foregroundStyle(.green)
          .symbolEffect(.bounce, value: rewardVisible)
      }
      Text("Entrenamiento completado")
        .font(.largeTitle.weight(.bold))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
      Text("\(completedSetCount) series registradas en esta sesión.")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Spacer()
      if let csvURL {
        ShareLink(item: csvURL) {
          Label("Exportar CSV", systemImage: "square.and.arrow.up")
        }
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
      }
      Button(action: onFinish) {
        Label("Volver a Hoy", systemImage: "house")
      }
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
        .buttonStyle(.plain)
    }
    .padding(16)
    .onAppear {
      csvURL = try? WorkoutCSVExporter.write(session: execution.session, execution: execution)
      withAnimation(.easeOut(duration: 0.8)) {
        rewardVisible = true
      }
    }
    .sensoryFeedback(.success, trigger: rewardVisible)
  }
}

private struct BottomActions: View {
  let primaryTitle: String
  let primaryAction: () -> Void
  var skipAction: (() -> Void)? = nil
  var primaryDisabled = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    HStack(spacing: 12) {
      Button(action: { dismiss() }) {
        Image(systemName: "chevron.left")
          .font(.headline.weight(.bold))
          .frame(width: 64, height: 64)
          .foregroundStyle(.primary)
          .glassEffect(.regular.interactive(), in: Circle())
      }
      .buttonStyle(.plain)

      Button(primaryTitle, action: primaryAction)
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
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

private struct SetHeader: View {
  let exercise: TrainingExercise
  let setIndex: Int
  let supersetPosition: Int?
  let supersetSize: Int?

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text(exercise.baseExerciseName)
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
  @State private var dragOffset: CGFloat = 0

  private var selectedIndex: Int {
    options.firstIndex(of: selection) ?? 0
  }

  var body: some View {
    GlassEffectContainer(spacing: 0) {
      GeometryReader { geometry in
        let segmentWidth = geometry.size.width / CGFloat(max(options.count, 1))
        let indicatorOffset = clampedIndicatorOffset(segmentWidth: segmentWidth)

        ZStack(alignment: .leading) {
          Capsule()
            .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
            .frame(width: segmentWidth, height: 42)
            .offset(x: indicatorOffset)
            .allowsHitTesting(false)

          HStack(spacing: 0) {
            ForEach(options, id: \.self) { equipment in
              let isAvailable = !unavailableOptions.contains(equipment)
              let isSelected = isVisuallySelected(
                equipment,
                segmentWidth: segmentWidth
              )
              Button {
                select(equipment)
              } label: {
                Text(equipment.executionLabel)
                  .font(.caption.weight(.bold))
                  .lineLimit(1)
                  .minimumScaleFactor(0.7)
                  .frame(maxWidth: .infinity, minHeight: 42)
                  .foregroundStyle(
                    isSelected ? .white : (isAvailable ? .primary : .red)
                  )
              }
              .buttonStyle(.plain)
              .disabled(!isAvailable)
            }
          }
          .simultaneousGesture(dragGesture(segmentWidth: segmentWidth))
        }
      }
      .frame(height: 42)
      .padding(4)
      .glassEffect(.regular, in: Capsule())
    }
    .disabled(options.count == 1)
  }

  private func clampedIndicatorOffset(segmentWidth: CGFloat) -> CGFloat {
    let availableIndexes = options.indices.filter {
      !unavailableOptions.contains(options[$0])
    }
    let minimum = segmentWidth * CGFloat(availableIndexes.first ?? 0)
    let maximum = segmentWidth * CGFloat(availableIndexes.last ?? 0)
    let proposed = CGFloat(selectedIndex) * segmentWidth + dragOffset
    return min(max(proposed, minimum), maximum)
  }

  private func isVisuallySelected(
    _ equipment: Equipment,
    segmentWidth: CGFloat
  ) -> Bool {
    let indicatorOffset = clampedIndicatorOffset(segmentWidth: segmentWidth)
    let indicatorIndex = min(
      max(Int((indicatorOffset / segmentWidth).rounded()), 0),
      max(options.count - 1, 0)
    )
    return equipment == options[indicatorIndex]
  }

  private func dragGesture(segmentWidth: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 6)
      .onChanged { gesture in
        dragOffset = gesture.translation.width
      }
      .onEnded { _ in
        let offset = clampedIndicatorOffset(segmentWidth: segmentWidth)
        let targetIndex = min(
          max(Int((offset / segmentWidth).rounded()), 0),
          max(options.count - 1, 0)
        )

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
          selection = options[targetIndex]
          dragOffset = 0
        }
      }
  }

  private func select(_ equipment: Equipment) {
    guard !unavailableOptions.contains(equipment) else { return }
    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
      selection = equipment
      dragOffset = 0
    }
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
          .foregroundStyle(.secondary)
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
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.background, in: RoundedRectangle(cornerRadius: 22))
      .overlay {
        RoundedRectangle(cornerRadius: 22)
          .stroke(Color.accentColor, lineWidth: 2)
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
          .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
          .overlay {
            RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
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
            .foregroundStyle(.white)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: Circle())
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
      : "\(value.formatted(.number.precision(.fractionLength(0...1)))) kg"
  }

  private func adjustmentButton(symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 30, weight: .bold))
        .frame(maxWidth: .infinity, minHeight: 76)
        .foregroundStyle(.primary)
        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.accentColor.opacity(0.45), lineWidth: 1) }
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
              .fill(isFinished ? Color.green : Color.accentColor.opacity(0.6))

            GeometryReader { geometry in
              Rectangle()
                .fill(isFinished ? Color.green : Color.accentColor)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .frame(maxWidth: .infinity, minHeight: 128)
          .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
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
          .foregroundStyle(.white)
          .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
          .buttonStyle(.plain)
          .disabled(isFinished)
          .opacity(isFinished ? 0.45 : 1)
        }
      }
      .onAppear {
        if pausedRemaining == 0, endsAt == nil {
          pausedRemaining = seconds
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
    }
  }

  private func reset() {
    endsAt = nil
    pausedRemaining = seconds
  }

  private func clock(_ totalSeconds: Int) -> String {
    "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
  }

  private func timeAdjustmentButton(title: String, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(.black.opacity(0.18), in: Capsule())
      .buttonStyle(.plain)
  }
}

private extension Equipment {
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
