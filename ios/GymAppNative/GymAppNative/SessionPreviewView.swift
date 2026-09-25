import SwiftUI
import SwiftData
import GymAppNativeCore

struct SessionPreviewView: View {
  let session: TrainingSession
  let onReturnHome: () -> Void
  let readOnly: Bool
  @Query private var activeWorkoutRecords: [ActiveWorkoutRecord]
  @Query private var completedWorkoutRecords: [CompletedWorkoutRecord]
  @AppStorage("warmupEnabled") private var warmupEnabled = true
  @AppStorage("warmupMinutes") private var warmupMinutes = 9
  @State private var showsExecution = false
  @State private var executionSnapshot: ActiveWorkoutSnapshot?
  @State private var showsRestartConfirmation = false
  @State private var pendingExerciseIndex: Int?
  @State private var showsExerciseStartConfirmation = false
  @State private var warmupSelectedExerciseIndex: Int?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  init(
    session: TrainingSession,
    onReturnHome: @escaping () -> Void,
    readOnly: Bool = false
  ) {
    self.session = session
    self.onReturnHome = onReturnHome
    self.readOnly = readOnly
  }

  private var resumableWorkout: ActiveWorkoutSnapshot? {
    guard let activeWorkout = currentActiveWorkout,
          activeWorkout.execution.session.sessionID == session.sessionID
    else { return nil }
    return activeWorkout
  }

  private var currentActiveWorkout: ActiveWorkoutSnapshot? {
    ActiveWorkoutStore.load(from: activeWorkoutRecords)
  }

  private var warmupIsVisible: Bool {
    warmupEnabled || resumableWorkout?.warmupStatus == .running
  }

  private var warmupIsRunning: Bool {
    resumableWorkout?.warmupStatus == .running
  }

  private var hasExerciseInProgress: Bool {
    guard let execution = resumableWorkout?.execution else { return false }
    return session.exercises.indices.contains { index in
      let recorded = execution.records.filter { $0.locator.exerciseIndex == index }.count
      return recorded > 0 && recorded < session.exercises[index].sets.count
    }
  }

  private var blocks: [PreviewBlock] {
    session.exercises.reduce(into: []) { result, exercise in
      if let supersetID = exercise.supersetID,
         result.last?.supersetID == supersetID {
        result[result.count - 1].exercises.append(exercise)
      } else {
        result.append(
          PreviewBlock(
            id: exercise.supersetID ?? exercise.exerciseID,
            supersetID: exercise.supersetID,
            exercises: [exercise]
          )
        )
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if warmupIsVisible, !warmupIsRunning {
          WarmupPreviewRow(
            minutes: warmupMinutes,
            status: resumableWorkout?.warmupStatus ?? .notStarted
          )
        }

        ForEach(blocks) { block in
          if block.isSuperset {
            VStack(alignment: .leading, spacing: 12) {
              Text("Superserie")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.gymSecondaryText)
                .textCase(.uppercase)

              ForEach(block.exercises) { exercise in
                ExercisePreviewRow(
                  exercise: exercise,
                  order: exerciseOrder(exercise),
                  status: previewStatus(for: exercise),
                  action: rowAction(for: exercise),
                  isWarmupSelected: warmupSelectedExerciseIndex == session.exercises.firstIndex(where: { $0.exerciseID == exercise.exerciseID }),
                  completedWorkoutRecords: completedWorkoutRecords
                )
              }
            }
            .padding(16)
            .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 22))
          } else if let exercise = block.exercises.first {
            ExercisePreviewRow(
              exercise: exercise,
              order: exerciseOrder(exercise),
              status: previewStatus(for: exercise),
              action: rowAction(for: exercise),
              isWarmupSelected: warmupSelectedExerciseIndex == session.exercises.firstIndex(where: { $0.exerciseID == exercise.exerciseID }),
              completedWorkoutRecords: completedWorkoutRecords
            )
          }
        }
      }
      .padding(20)
      .padding(.bottom, 116)
    }
    .background(GymCanvas())
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      if let warmup = resumableWorkout, warmup.warmupStatus == .running,
         let endsAt = warmup.warmupEndsAt {
        WarmupPreviewHeader(
          endsAt: endsAt,
          totalSeconds: max(warmup.warmupRemaining, warmupMinutes * 60),
          onCompleted: completeWarmup
        )
      } else {
        PreviewContextHeader(session: session)
      }
    }
    .navigationDestination(isPresented: $showsExecution) {
      if let executionSnapshot {
        SetExecutionView(snapshot: executionSnapshot, onFinishToToday: returnToToday)
      } else {
        SetExecutionView(session: session, onFinishToToday: returnToToday)
      }
    }
    .alert("Empezar de nuevo", isPresented: $showsRestartConfirmation) {
      Button("Cancelar", role: .cancel) {}
      Button("Empezar de nuevo", role: .destructive) {
        ActiveWorkoutStore.clear(in: modelContext)
        executionSnapshot = nil
        showsExecution = true
      }
    } message: {
      Text("Se sustituirá el entrenamiento en curso por una nueva sesión de \(session.label).")
    }
    .alert("Cambiar el siguiente ejercicio", isPresented: $showsExerciseStartConfirmation) {
      Button("Cancelar", role: .cancel) { pendingExerciseIndex = nil }
      Button("Continuar") { startPendingExercise() }
    } message: {
      if let index = pendingExerciseIndex, session.exercises.indices.contains(index) {
        Text("¿Quieres \(resumableWorkout?.warmupStatus == .completed && resumableWorkout?.execution.records.isEmpty == true ? "empezar" : "continuar") por \(session.exercises[index].displayName)?")
      }
    }
    .overlay(alignment: .bottom) {
      if readOnly {
        Button(action: { dismiss() }) {
          Image(systemName: "chevron.left")
            .font(.headline.weight(.bold))
            .frame(width: 56, height: 56)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
      GlassEffectContainer(spacing: 16) {
        HStack(spacing: 16) {
          Button(action: { dismiss() }) {
            Image(systemName: "house")
              .font(.headline.weight(.bold))
              .frame(width: 56, height: 56)
              .foregroundStyle(.primary)
              .glassEffect(.regular.interactive(), in: Circle())
          }
          .buttonStyle(.plain)

          if warmupIsRunning {
            Button(action: beginWorkoutAfterWarmup) {
              Label("Empezar", systemImage: "play.fill")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Color.gymAccentForeground)
                .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
          } else if let resumableWorkout {
            Button(action: { resume(resumableWorkout) }) {
              Label("Reanudar", systemImage: "play.fill")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Color.gymAccentForeground)
                .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
          } else if warmupEnabled {
            Button(action: { startWarmup() }) {
              Label("Calentar", systemImage: "flame.fill")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Color.gymAccentForeground)
                .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
          }

          if !warmupIsRunning {
            Button {
              if currentActiveWorkout != nil {
                showsRestartConfirmation = true
              } else {
                executionSnapshot = nil
                showsExecution = true
              }
            } label: {
              Label("Empezar", systemImage: "chevron.right")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Color.gymAccentForeground)
                .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 8)
      }
    }
  }

  private func exerciseOrder(_ exercise: TrainingExercise) -> Int {
    (session.exercises.firstIndex { $0.id == exercise.id } ?? 0) + 1
  }

  private func previewStatus(for exercise: TrainingExercise) -> ExercisePreviewStatus {
    guard let execution = resumableWorkout?.execution,
          let index = session.exercises.firstIndex(where: { $0.exerciseID == exercise.exerciseID })
    else { return .pending }

    let recorded = execution.records.filter { $0.locator.exerciseIndex == index }.count
    if recorded >= exercise.sets.count { return .completed }
    if recorded > 0 { return .inProgress }
    return .pending
  }

  private func rowAction(for exercise: TrainingExercise) -> (() -> Void)? {
    guard !readOnly,
          let snapshot = resumableWorkout,
          let index = session.exercises.firstIndex(where: { $0.exerciseID == exercise.exerciseID })
    else { return nil }

    switch previewStatus(for: exercise) {
    case .completed:
      return nil
    case .inProgress:
      return { resume(snapshot) }
    case .pending:
      if snapshot.warmupStatus == .running,
         snapshot.execution.records.isEmpty {
        return { warmupSelectedExerciseIndex = index }
      }
      guard snapshot.warmupStatus == .completed,
            !hasExerciseInProgress,
            snapshot.execution.current?.setIndex == 1
      else { return nil }
      return {
        pendingExerciseIndex = index
        showsExerciseStartConfirmation = true
      }
    }
  }

  private func startWarmup() {
    let seconds = max(1, warmupMinutes) * 60
    ActiveWorkoutStore.save(
      ActiveWorkoutSnapshot(
        execution: WorkoutExecutionState(session: session),
        phase: .workingSet,
        feedback: .init(rir: 2, painKnee: 0, painWrist: 0, painShoulder: 0, painLowerBack: 0, note: "OK"),
        restEndsAt: nil,
        restTotalSeconds: 0,
        setTimerEndsAt: nil,
        setTimerRemaining: 0,
        reviewExerciseIndexes: [],
        reviewRestSeconds: 0,
        exerciseDecisions: [:],
        warmupStatus: .running,
        warmupEndsAt: .now.addingTimeInterval(TimeInterval(seconds)),
        warmupRemaining: seconds,
        startedAt: .now
      ),
      in: modelContext
    )
    warmupSelectedExerciseIndex = nil
  }

  private func resume(_ snapshot: ActiveWorkoutSnapshot) {
    executionSnapshot = snapshot
    showsExecution = true
  }

  private func completeWarmup() {
    guard var snapshot = resumableWorkout,
          snapshot.warmupStatus == .running
    else { return }
    snapshot.warmupStatus = .completed
    snapshot.warmupEndsAt = nil
    snapshot.warmupRemaining = 0
    ActiveWorkoutStore.save(snapshot, in: modelContext)
  }

  private func beginWorkoutAfterWarmup() {
    guard var snapshot = resumableWorkout else { return }
    if snapshot.warmupStatus == .running {
      snapshot.warmupStatus = .completed
      snapshot.warmupEndsAt = nil
      snapshot.warmupRemaining = 0
    }
    if let index = warmupSelectedExerciseIndex {
      guard snapshot.execution.selectNextBlock(exerciseIndex: index) else { return }
    }
    ActiveWorkoutStore.save(snapshot, in: modelContext)
    executionSnapshot = snapshot
    showsExecution = true
  }

  private func startPendingExercise() {
    defer { pendingExerciseIndex = nil }
    guard let index = pendingExerciseIndex,
          var snapshot = resumableWorkout,
          snapshot.execution.selectNextBlock(exerciseIndex: index)
    else { return }

    ActiveWorkoutStore.save(snapshot, in: modelContext)
    executionSnapshot = snapshot
    showsExecution = true
  }

  private func returnToToday() {
    showsExecution = false
    executionSnapshot = nil
    onReturnHome()
  }
}

private struct PreviewContextHeader: View {
  let session: TrainingSession

  var body: some View {
    AccentHeaderCard(
      title: session.label,
      eyebrow: "Semana \(session.week) · \(session.weekFocusLabel)",
      detail: "\(session.exercises.count) ejercicios · \(SessionDurationEstimator.estimate(for: session).totalMinutes) min estimados",
      emphasizesTitle: true
    )
  }
}

private struct WarmupPreviewHeader: View {
  let endsAt: Date
  let totalSeconds: Int
  let onCompleted: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
      let progress = CGFloat(remaining) / CGFloat(max(totalSeconds, 1))

      ZStack(alignment: .leading) {
        WarmupProgressBackground(progress: progress, isFinished: remaining == 0)

        VStack(spacing: 2) {
          Text(remaining == 0 ? "Calentamiento terminado" : "Calentamiento")
            .font(.headline.weight(.bold))
          Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
            .font(.system(size: 56, weight: .bold))
            .monospacedDigit()
            .contentTransition(.numericText())
        }
        .foregroundStyle(Color.gymAccentForeground)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
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
      .background(alignment: .top) {
        WarmupProgressBackground(progress: progress, isFinished: remaining == 0)
          .frame(height: 160)
          .offset(y: -160)
      }
      .animation(.linear(duration: 0.85), value: remaining)
      .onAppear {
        if remaining == 0 { onCompleted() }
      }
      .onChange(of: remaining) { _, newValue in
        if newValue == 0 { onCompleted() }
      }
    }
  }
}

private struct WarmupProgressBackground: View {
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

private struct PreviewBlock: Identifiable {
  let id: String
  let supersetID: String?
  var exercises: [TrainingExercise]

  var isSuperset: Bool { supersetID != nil }
}

private struct ExercisePreviewRow: View {
  let exercise: TrainingExercise
  let order: Int
  let status: ExercisePreviewStatus
  let action: (() -> Void)?
  let isWarmupSelected: Bool
  let completedWorkoutRecords: [CompletedWorkoutRecord]
  @State private var showsHistory = false

  var body: some View {
    Group {
      if let action {
        Button(action: action) { content }
          .buttonStyle(.plain)
      } else {
        content
      }
    }
    .contextMenu {
      Button("Ver historial", systemImage: "chart.line.uptrend.xyaxis") {
        showsHistory = true
      }
    } preview: {
      ExerciseHistoryView(
        exercise: exercise,
        records: completedWorkoutRecords,
        showsAppChrome: false
      )
    }
    .sheet(isPresented: $showsHistory) {
      ExerciseHistoryView(exercise: exercise, records: completedWorkoutRecords)
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        Text("\(order)")
          .font(.subheadline.weight(.bold))
          .frame(width: 32, height: 32)
          .background(Color.gymSurface, in: Circle())

        VStack(alignment: .leading, spacing: 7) {
          Text(exercise.displayName)
            .font(.headline.weight(.semibold))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)

          EquipmentChip(equipment: exercise.equipment, variantLabel: exercise.variantLabel)
        }

        if isWarmupSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.title3.weight(.bold))
            .foregroundStyle(Color.gymAccent)
            .accessibilityLabel("Ejercicio seleccionado para empezar al terminar el calentamiento")
        } else if let label = status.label, let color = status.color {
          Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
        }
      }

      HStack(spacing: 8) {
        PreviewMetric(label: "Series", value: "\(exercise.sets.count)")
        PreviewMetric(label: workLabel, value: workValue)
        PreviewMetric(label: loadLabel, value: loadValue)
      }
    }
    .padding(14)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(
          isWarmupSelected ? Color.gymAccent : (status.color ?? Color.secondary.opacity(0.3)),
          lineWidth: isWarmupSelected || status != .pending ? 2 : 1
        )
    }
    .contentShape(RoundedRectangle(cornerRadius: 18))
  }

  private var workLabel: String {
    exercise.sets.first?.type == .timed ? "Tiempo" : "Reps"
  }

  private var workValue: String {
    if exercise.sets.first?.type == .timed {
      return uniqueValues(exercise.sets.map { set in
        let seconds = set.targetDurationSeconds ?? 0
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
      })
    }

    return uniqueValues(exercise.sets.map { $0.targetReps.map(String.init) ?? "-" })
  }

  private var loadValue: String {
    guard exercise.equipment != .bodyweight else { return "0 kg" }

    return uniqueValues(exercise.sets.map { set in
      let amount = set.targetWeightKg.formatted(.number.precision(.fractionLength(0...2)))
      return exercise.equipment == .external ? "+\(amount) kg" : "\(amount) kg"
    })
  }

  private var loadLabel: String {
    exercise.equipment == .dumbbell ? "Peso c/u" : "Peso"
  }

  private func uniqueValues(_ values: [String]) -> String {
    values.reduce(into: [String]()) { unique, value in
      if !unique.contains(value) {
        unique.append(value)
      }
    }
    .joined(separator: "/")
  }
}

private enum ExercisePreviewStatus: Equatable {
  case pending
  case inProgress
  case completed

  var label: String? {
    switch self {
    case .pending: nil
    case .inProgress: "En curso"
    case .completed: "Completado"
    }
  }

  var color: Color? {
    switch self {
    case .pending: nil
    case .inProgress: Color(red: 0.76, green: 0.32, blue: 0.04)
    case .completed: Color.gymCompleted
    }
  }
}

private struct WarmupPreviewRow: View {
  let minutes: Int
  let status: WorkoutWarmupStatus

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "flame.fill")
        .font(.headline.weight(.bold))
        .foregroundStyle(Color.gymAccent)
        .frame(width: 32, height: 32)
        .background(Color.gymSurface, in: Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text("Calentamiento")
          .font(.headline.weight(.bold))
        Text("\(minutes) min · No afecta a las series")
          .font(.caption)
          .foregroundStyle(Color.gymSecondaryText)
      }

      Spacer(minLength: 8)

      if status == .completed {
        Text("Completado")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(Color.gymCompleted, in: Capsule())
      } else if status == .running {
        Text("En curso")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(Color(red: 0.76, green: 0.32, blue: 0.04), in: Capsule())
      }
    }
    .padding(14)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(status == .completed ? Color.gymCompleted : Color.secondary.opacity(0.3), lineWidth: status == .completed ? 2 : 1)
    }
  }
}

private struct EquipmentChip: View {
  let equipment: Equipment
  let variantLabel: String?

  var body: some View {
    Text(variantLabel ?? equipment.label)
      .font(.caption.weight(.semibold))
      .foregroundStyle(Color.gymSecondaryText)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.gymSurface.opacity(0.72), in: Capsule())
  }
}

private struct PreviewMetric: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 5) {
      Text(label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.gymSecondaryText)
        .lineLimit(1)
      Text(value)
        .font(.subheadline.weight(.bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, minHeight: 58)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 12))
  }
}

private extension Equipment {
  var label: String {
    switch self {
    case .barbell: "Barra"
    case .multipower: "Multipower"
    case .dumbbell: "Mancuernas"
    case .cable: "Polea"
    case .plateLoadedMachine: "Discos"
    case .external: "Lastre"
    case .bodyweight: "Corporal"
    }
  }
}
