import SwiftUI
import GymAppNativeCore
import WatchKit

struct ContentView: View {
  @EnvironmentObject private var connectivity: WatchWorkoutConnectivity
  @State private var completedWorkoutName: String?
  @State private var showsTrainingSelection = false
  @State private var previewSession: TrainingSession?

  var body: some View {
    Group {
      if let completedWorkoutName {
        WatchCompletedWorkoutView(workoutName: completedWorkoutName) {
          self.completedWorkoutName = nil
        }
      } else if let workout = connectivity.workout, !showsTrainingSelection {
        WatchWorkoutView(
          workout: workout,
          theme: connectivity.appState.theme,
          isSendingAction: connectivity.isSendingAction,
          onCommand: connectivity.send,
          onBack: {
            previewSession = connectivity.appState.sessions.first {
              $0.sessionID == workout.sessionID
            }
            showsTrainingSelection = true
          }
        )
      } else if let previewSession {
        NavigationStack {
          WatchSessionPreview(
            session: previewSession,
            theme: connectivity.appState.theme,
            activeWorkout: connectivity.workout,
            isSendingAction: connectivity.isSendingAction,
            onCommand: connectivity.send,
            onResume: {
              self.previewSession = nil
              showsTrainingSelection = false
            },
            onClose: {
              self.previewSession = nil
              showsTrainingSelection = true
            }
          )
        }
      } else {
        WatchTrainingList(
          sessions: connectivity.appState.sessions,
          completedSessionIDs: Set(connectivity.appState.completedSessionIDs),
          theme: connectivity.appState.theme,
          activeWorkout: connectivity.workout,
          isSendingAction: connectivity.isSendingAction,
          onCommand: connectivity.send,
          onResume: { showsTrainingSelection = false }
        )
      }
    }
    .preferredColorScheme(WatchPalette(theme: connectivity.appState.theme).colorScheme)
    .foregroundStyle(WatchPalette(theme: connectivity.appState.theme).primaryText)
    .onChange(of: connectivity.workout) { previous, current in
      guard let previous, current == nil else { return }
      completedWorkoutName = previous.workoutName
      WKInterfaceDevice.current().play(.success)
    }
    .onChange(of: connectivity.workout?.sessionID) { _, sessionID in
      if sessionID != nil {
        previewSession = nil
        showsTrainingSelection = false
      }
    }
    .onChange(of: connectivity.workout) { _, current in
      guard showsTrainingSelection,
            let currentPreview = previewSession,
            let current,
            current.sessionID == currentPreview.sessionID,
            current.phase != .rest
      else { return }
      previewSession = nil
      showsTrainingSelection = false
    }
  }
}

private struct WatchCompletedWorkoutView: View {
  let workoutName: String
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 34))
        .foregroundStyle(.green)
      Text("Entrenamiento completado")
        .font(.headline)
        .multilineTextAlignment(.center)
      Text(workoutName)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      Button(action: onClose) { Image(systemName: "checkmark") }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }
    .padding(.horizontal, 10)
  }
}

private struct WatchTrainingList: View {
  let sessions: [TrainingSession]
  let completedSessionIDs: Set<String>
  let theme: WatchWorkoutTheme
  let activeWorkout: WatchWorkoutState?
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  let onResume: () -> Void

  private var recommendedSessionID: String? {
    guard activeWorkout == nil else { return nil }
    let today = Calendar.current.startOfDay(for: .now)
    let pending = sessions
      .filter { !completedSessionIDs.contains($0.sessionID) }
      .sorted { $0.date < $1.date }
    return (pending.first { Self.sessionDate($0) >= today } ?? pending.first)?.sessionID
  }

  var body: some View {
    let palette = WatchPalette(theme: theme)
    NavigationStack {
      List {
        if sessions.isEmpty {
          ContentUnavailableView(
            "Sin entrenamientos",
            systemImage: "checkmark.circle",
            description: Text("No hay entrenamientos pendientes en el iPhone."))
            .listRowBackground(Color.clear)
        } else {
          Section("Entrenamientos") {
            ForEach(sessions) { session in
              if activeWorkout?.sessionID == session.sessionID {
                Button(action: onResume) {
                  WatchTrainingRow(
                    session: session,
                    status: .inProgress,
                    accent: palette.accent,
                    primaryText: palette.primaryText,
                    secondaryText: palette.secondaryText
                  )
                }
              } else {
                NavigationLink {
                  WatchSessionPreview(
                    session: session,
                    theme: theme,
                    activeWorkout: activeWorkout,
                    isSendingAction: isSendingAction,
                    onCommand: onCommand
                  )
                } label: {
                  WatchTrainingRow(
                    session: session,
                    status: completedSessionIDs.contains(session.sessionID)
                      ? .completed
                      : session.sessionID == recommendedSessionID ? .recommended : .standard,
                    accent: palette.accent,
                    primaryText: palette.primaryText,
                    secondaryText: palette.secondaryText
                  )
                }
              }
            }
          }
        }
      }
      .navigationTitle("Entrenar")
      .tint(palette.accent)
      .scrollContentBackground(.hidden)
      .background(palette.canvas)
      .foregroundStyle(palette.primaryText)
    }
  }

  private static func sessionDate(_ session: TrainingSession) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: session.date) ?? .distantPast
  }
}

private struct WatchTrainingRow: View {
  let session: TrainingSession
  let status: WatchTrainingStatus
  let accent: Color
  let primaryText: Color
  let secondaryText: Color

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: status.symbol)
        .foregroundStyle(status.color(accent: accent))
        .font(.headline)
      VStack(alignment: .leading, spacing: 4) {
        Text(session.label)
          .font(.headline)
          .lineLimit(2)
        Text("Semana \(session.week) · \(session.estimatedMinutes) min")
          .font(.caption)
          .foregroundStyle(secondaryText)
      }
    }
    .padding(.vertical, 4)
  }
}

private enum WatchTrainingStatus {
  case standard, recommended, inProgress, completed

  var symbol: String {
    switch self {
    case .standard: "circle"
    case .recommended: "star.circle.fill"
    case .inProgress: "figure.run.circle.fill"
    case .completed: "checkmark.circle.fill"
    }
  }

  func color(accent: Color) -> Color {
    switch self {
    case .standard: .secondary
    case .recommended: accent
    case .inProgress: .orange
    case .completed: .green
    }
  }
}

private struct WatchSessionPreview: View {
  let session: TrainingSession
  let theme: WatchWorkoutTheme
  let activeWorkout: WatchWorkoutState?
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  var onResume: (() -> Void)?
  var onClose: (() -> Void)?
  @State private var selectedExerciseIndex: Int?
  @State private var pendingStart: WatchPreviewStart?
  @Environment(\.dismiss) private var dismiss

  private var selectedExercise: TrainingExercise? {
    guard let selectedExerciseIndex, session.exercises.indices.contains(selectedExerciseIndex) else { return nil }
    return session.exercises[selectedExerciseIndex]
  }

  private var currentExerciseIndex: Int? {
    guard let activeWorkout,
          activeWorkout.sessionID == session.sessionID,
          let currentExerciseID = activeWorkout.currentExerciseID
    else { return nil }
    return session.exercises.firstIndex { $0.exerciseID == currentExerciseID }
  }

  private var mustResumeCurrentExercise: Bool {
    activeWorkout?.sessionID == session.sessionID && activeWorkout?.currentExerciseHasRecordedSets == true
  }

  private var canStartSelection: Bool {
    guard mustResumeCurrentExercise,
          let selectedExerciseIndex,
          let currentExerciseIndex
    else { return true }
    return selectedExerciseIndex == currentExerciseIndex
  }

  private var exerciseBlocks: [WatchPreviewExerciseBlock] {
    session.exercises.enumerated().reduce(into: []) { blocks, item in
      let exercise = WatchPreviewExercise(index: item.offset, exercise: item.element)
      if let supersetID = item.element.supersetID,
         blocks.last?.supersetID == supersetID {
        blocks[blocks.count - 1].exercises.append(exercise)
      } else {
        blocks.append(WatchPreviewExerciseBlock(
          id: item.element.supersetID ?? item.element.exerciseID,
          supersetID: item.element.supersetID,
          exercises: [exercise]
        ))
      }
    }
  }

  var body: some View {
    let palette = WatchPalette(theme: theme)
    List {
      Section {
        VStack(alignment: .leading, spacing: 3) {
          Text("Semana \(session.week) · \(session.weekFocusLabel)")
            .font(.caption2)
            .foregroundStyle(palette.secondaryText)
          Text(session.label).font(.headline)
          Text("\(session.exercises.count) ejercicios · \(session.estimatedMinutes) min")
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
        }
        .padding(.vertical, 4)
      }
      Section("Ejercicios") {
        ForEach(exerciseBlocks) { block in
          if block.supersetID == nil, let item = block.exercises.first {
            exerciseButton(for: item, palette: palette)
          } else {
            VStack(spacing: 0) {
              ForEach(block.exercises) { item in
                exerciseButton(for: item, palette: palette)
                if item.id != block.exercises.last?.id {
                  Divider().padding(.leading, 26)
                }
              }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
              RoundedRectangle(cornerRadius: 12)
                .stroke(palette.accent.opacity(0.72), lineWidth: 1)
            }
            .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
            .listRowBackground(Color.clear)
          }
        }
      }
    }
    .navigationTitle("Previsualizar")
    .navigationBarBackButtonHidden()
    .tint(palette.accent)
    .scrollContentBackground(.hidden)
    .background(palette.canvas)
    .foregroundStyle(palette.primaryText)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        WatchBackButton(action: onClose ?? dismiss.callAsFunction)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button { requestStart(startsWithWarmup: false) } label: { Image(systemName: "play.fill") }
        .disabled(isSendingAction || !canStartSelection)
        .accessibilityLabel(selectedExercise == nil ? "Empezar entrenamiento" : "Empezar por \(selectedExercise!.baseExerciseName)")
      }
      if activeWorkout == nil || activeWorkout?.sessionID != session.sessionID {
        ToolbarItem(placement: .bottomBar) {
          Button { requestStart(startsWithWarmup: true) } label: { Image(systemName: "flame.fill") }
            .disabled(isSendingAction)
        }
      }
    }
    .alert("Descartar entrenamiento en curso", isPresented: Binding(
      get: { pendingStart != nil },
      set: { if !$0 { pendingStart = nil } }
    )) {
      Button("Cancelar", role: .cancel) { pendingStart = nil }
      Button("Descartar y empezar", role: .destructive) {
        guard let pendingStart else { return }
        onCommand(.replaceActiveWorkout(
          sessionID: session.sessionID,
          startsWithWarmup: pendingStart.startsWithWarmup,
          exerciseIndex: pendingStart.exerciseIndex
        ))
        self.pendingStart = nil
      }
    } message: {
      Text("Se descartará el entrenamiento en curso para iniciar \(session.label).")
    }
  }

  private func requestStart(startsWithWarmup: Bool) {
    let exerciseIndex = startsWithWarmup ? nil : selectedExerciseIndex
    if let activeWorkout, activeWorkout.sessionID != session.sessionID {
      pendingStart = WatchPreviewStart(startsWithWarmup: startsWithWarmup, exerciseIndex: exerciseIndex)
      return
    }

    if activeWorkout?.sessionID == session.sessionID {
      if mustResumeCurrentExercise || exerciseIndex == currentExerciseIndex {
        onCommand(.continueAfterTimer)
      } else if let exerciseIndex {
        onCommand(.prioritizeExercise(sessionID: session.sessionID, exerciseIndex: exerciseIndex))
      } else {
        onCommand(.continueAfterTimer)
      }
      onResume?()
    } else if startsWithWarmup {
      onCommand(.startWarmup(sessionID: session.sessionID))
    } else if let exerciseIndex {
      onCommand(.prioritizeExercise(sessionID: session.sessionID, exerciseIndex: exerciseIndex))
    } else {
      onCommand(.startWorkout(sessionID: session.sessionID))
    }
  }

  @ViewBuilder
  private func exerciseButton(for item: WatchPreviewExercise, palette: WatchPalette) -> some View {
    Button { selectedExerciseIndex = item.index } label: {
      WatchExercisePreviewRow(
        order: item.index + 1,
        exercise: item.exercise,
        selected: selectedExerciseIndex == item.index,
        activeWorkout: activeWorkout,
        accent: palette.accent,
        primaryText: palette.primaryText,
        secondaryText: palette.secondaryText
      )
    }
    .buttonStyle(.plain)
    .disabled(activeWorkout?.completedExerciseIDs.contains(item.exercise.exerciseID) == true)
  }
}

private struct WatchPreviewStart {
  let startsWithWarmup: Bool
  let exerciseIndex: Int?
}

private struct WatchPreviewExercise: Identifiable {
  let index: Int
  let exercise: TrainingExercise
  var id: String { exercise.id }
}

private struct WatchPreviewExerciseBlock: Identifiable {
  let id: String
  let supersetID: String?
  var exercises: [WatchPreviewExercise]
}

private struct WatchExercisePreviewRow: View {
  let order: Int
  let exercise: TrainingExercise
  let selected: Bool
  let activeWorkout: WatchWorkoutState?
  let accent: Color
  let primaryText: Color
  let secondaryText: Color

  private var isCompleted: Bool {
    activeWorkout?.completedExerciseIDs.contains(exercise.exerciseID) == true
  }

  private var isCurrent: Bool {
    !isCompleted && activeWorkout?.exerciseName == exercise.baseExerciseName
  }

  var body: some View {
    HStack(spacing: 8) {
      Text("\(order)")
        .font(.caption.weight(.bold))
        .frame(width: 18, height: 18)
        .background(selected ? accent : Color.secondary.opacity(0.2), in: Circle())
        .foregroundStyle(selected ? .white : primaryText)
      VStack(alignment: .leading, spacing: 2) {
        Text(exercise.baseExerciseName).font(.subheadline.weight(.semibold)).lineLimit(2)
        if let firstSet = exercise.sets.first {
          Text(targetLabel(firstSet)).font(.caption2).foregroundStyle(secondaryText)
        }
      }
      Spacer(minLength: 0)
      if isCompleted {
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
      } else if isCurrent {
        Image(systemName: "play.circle.fill").foregroundStyle(.orange)
      } else if selected {
        Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
      }
    }
    .contentShape(Rectangle())
  }

  private func targetLabel(_ set: TrainingSet) -> String {
    if let seconds = set.targetDurationSeconds { return "\(seconds)s · \(exercise.equipmentLabel)" }
    return "\(set.targetReps ?? 0) reps · \(WeightFormatter.string(from: set.targetWeightKg))"
  }
}

private struct WatchWorkoutView: View {
  let workout: WatchWorkoutState
  let theme: WatchWorkoutTheme
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  let onBack: () -> Void

  private var palette: WatchPalette { WatchPalette(theme: theme) }

  private var navigationTitle: String {
    switch workout.phase {
    case .warmup: "Calentamiento"
    case .rest: "Descanso"
    case .feedback: "Evaluar serie"
    case .exerciseReview: "Evaluar ejercicio"
    default: workout.equipmentName
    }
  }

  private var showsSetNumber: Bool {
    workout.phase == .workingSet || workout.phase == .feedback
  }

  private var workoutProgress: Double {
    guard workout.totalSetCount > 0 else { return 0 }
    return min(max(Double(workout.completedSetCount) / Double(workout.totalSetCount), 0), 1)
  }

  private var usesCountdownBackground: Bool {
    workout.phase == .rest || (workout.phase == .workingSet && workout.durationSeconds != nil)
  }

  private var countdownTotalSeconds: Int {
    workout.phase == .rest ? workout.restTotalSeconds : (workout.durationSeconds ?? 0)
  }

  var body: some View {
    ZStack {
      if usesCountdownBackground {
        WatchCountdownProgressBackground(
          palette: palette,
          endsAt: workout.timerEndsAt,
          total: countdownTotalSeconds
        )
      } else {
        palette.canvas
          .ignoresSafeArea()
      }

      NavigationStack {
        Group {
          if workout.phase == .warmup {
            WatchWarmupView(workout: workout, palette: palette, onCommand: onCommand)
          } else if workout.phase == .rest {
            WatchRestView(workout: workout, palette: palette, isSendingAction: isSendingAction, onCommand: onCommand)
          } else if workout.phase == .feedback {
            WatchFeedbackView(
              workout: workout,
              palette: palette,
              isSendingAction: isSendingAction,
              onCommand: onCommand
            )
          } else if workout.phase == .exerciseReview {
            WatchExerciseReviewView(
              workout: workout,
              palette: palette,
              isSendingAction: isSendingAction,
              onCommand: onCommand
            )
          } else {
            WatchSetView(workout: workout, palette: palette, isSendingAction: isSendingAction, onCommand: onCommand)
          }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle {
          Text(navigationTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(palette.colorScheme ?? .dark, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            WatchBackButton(action: onBack)
          }
          if workout.phase == .rest {
            ToolbarItem(placement: .topBarTrailing) {
              WatchWorkoutProgressBadge(progress: workoutProgress, palette: palette)
                .accessibilityLabel("Progreso del entrenamiento: \(Int((workoutProgress * 100).rounded())) por ciento")
            }
          } else if showsSetNumber {
            ToolbarItem(placement: .topBarTrailing) {
              Text("\(workout.exerciseSetNumber)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(palette.accentForeground)
                .frame(width: 28, height: 28)
                .background(palette.accent, in: Circle())
                .accessibilityLabel("Serie \(workout.exerciseSetNumber)")
            }
          }
        }
      }
    }
    .tint(palette.accent)
  }
}

private struct WatchFeedbackView: View {
  let workout: WatchWorkoutState
  let palette: WatchPalette
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  @State private var rir: Int
  @State private var note: String
  @State private var painKnee: Int
  @State private var painWrist: Int
  @State private var painShoulder: Int
  @State private var painLowerBack: Int

  init(
    workout: WatchWorkoutState,
    palette: WatchPalette,
    isSendingAction: Bool,
    onCommand: @escaping (WatchWorkoutCommand) -> Void
  ) {
    self.workout = workout
    self.palette = palette
    self.isSendingAction = isSendingAction
    self.onCommand = onCommand
    _rir = State(initialValue: workout.feedback.rir ?? 2)
    _note = State(initialValue: workout.feedback.note)
    _painKnee = State(initialValue: workout.feedback.painKnee)
    _painWrist = State(initialValue: workout.feedback.painWrist)
    _painShoulder = State(initialValue: workout.feedback.painShoulder)
    _painLowerBack = State(initialValue: workout.feedback.painLowerBack)
  }

  private var isTimed: Bool { workout.durationSeconds != nil }

  var body: some View {
    TabView {
      if !isTimed {
        WatchRIRFeedbackPage(rir: $rir, palette: palette, onRegister: submit)
          .tag(0)
      }

      if isTimed {
        WatchFeedbackNotePage(note: $note, palette: palette, onRegister: submit)
          .tag(1)
      } else {
        WatchFeedbackNotePage(note: $note, palette: palette)
          .tag(1)
      }
      WatchPainFeedbackPage(area: .knee, value: $painKnee, palette: palette)
        .tag(2)
      WatchPainFeedbackPage(area: .wrist, value: $painWrist, palette: palette)
        .tag(3)
      WatchPainFeedbackPage(area: .shoulder, value: $painShoulder, palette: palette)
        .tag(4)
      WatchPainFeedbackPage(
        area: .lowerBack,
        value: $painLowerBack,
        palette: palette
      )
      .tag(5)
    }
    .tabViewStyle(.verticalPage)
    .padding(.top, 28)
    .disabled(isSendingAction)
  }

  private func submit() {
    onCommand(.submitSetFeedback(WorkoutSetFeedback(
      rir: isTimed ? nil : rir,
      painKnee: painKnee,
      painWrist: painWrist,
      painShoulder: painShoulder,
      painLowerBack: painLowerBack,
      note: note
    )))
  }
}

private struct WatchExerciseReviewView: View {
  let workout: WatchWorkoutState
  let palette: WatchPalette
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  @State private var decisions: [String: String]

  init(
    workout: WatchWorkoutState,
    palette: WatchPalette,
    isSendingAction: Bool,
    onCommand: @escaping (WatchWorkoutCommand) -> Void
  ) {
    self.workout = workout
    self.palette = palette
    self.isSendingAction = isSendingAction
    self.onCommand = onCommand
    _decisions = State(initialValue: Dictionary(
      uniqueKeysWithValues: workout.reviewExercises.map { ($0.exerciseID, $0.decision) }
    ))
  }

  var body: some View {
    TabView {
      ForEach(Array(workout.reviewExercises.enumerated()), id: \.element.id) { index, exercise in
        WatchExerciseReviewPage(
          exercise: exercise,
          showsExerciseName: workout.reviewExercises.count > 1,
          selection: Binding(
            get: { decisions[exercise.exerciseID] ?? exercise.decision },
            set: { decisions[exercise.exerciseID] = $0 }
          ),
          palette: palette,
          showsConfirmation: index == workout.reviewExercises.indices.last,
          isFinalReview: workout.isFinalExerciseReview,
          onConfirm: submit
        )
        .tag(index)
      }
    }
    .tabViewStyle(.verticalPage)
    .padding(.top, 2)
    .disabled(isSendingAction)
  }

  private func submit() {
    onCommand(.submitExerciseReview(decisions: decisions))
  }
}

private struct WatchExerciseReviewPage: View {
  let exercise: WatchExerciseReviewItem
  let showsExerciseName: Bool
  @Binding var selection: String
  let palette: WatchPalette
  let showsConfirmation: Bool
  let isFinalReview: Bool
  let onConfirm: () -> Void

  private var options: [WatchExerciseReviewOption] {
    if exercise.isTimed {
      return [
        .init(decision: "Mantener tiempo", label: "Mantener", symbol: "equal"),
        .init(decision: "Subir tiempo", label: "Tiempo", symbol: "arrow.up"),
        .init(decision: "Bajar tiempo", label: "Tiempo", symbol: "arrow.down"),
        .init(decision: "Mejorar posición", label: "Posición", symbol: "figure.strengthtraining.traditional"),
        .init(decision: "Marcar molestia", label: "Molestia", symbol: "cross.case.fill")
      ]
    }

    let canChangeWeight = exercise.equipment != .bodyweight && exercise.equipment != .cable
    var options = [WatchExerciseReviewOption(decision: "Mantener", label: "Mantener", symbol: "equal")]
    if canChangeWeight {
      options += [
        .init(decision: "Subir peso", label: "Peso", symbol: "arrow.up"),
        .init(decision: "Bajar peso", label: "Peso", symbol: "arrow.down")
      ]
    }
    options += [
      .init(decision: "Subir reps", label: "Reps", symbol: "arrow.up"),
      .init(decision: "Bajar reps", label: "Reps", symbol: "arrow.down"),
      .init(decision: "Marcar molestia", label: "Molestia", symbol: "cross.case.fill")
    ]
    return options
  }

  private var columns: [GridItem] {
    [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
  }

  var body: some View {
    VStack(spacing: 7) {
      if showsExerciseName {
        Text(exercise.exerciseName)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .foregroundStyle(palette.secondaryText)
          .frame(maxWidth: .infinity)
      }

      LazyVGrid(columns: columns, spacing: 7) {
        ForEach(options) { option in
          Button { selection = option.decision } label: {
            VStack(spacing: 3) {
              Image(systemName: option.symbol)
                .font(.caption.weight(.bold))
              Text(option.label)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
          }
          .buttonStyle(.plain)
          .foregroundStyle(selection == option.decision ? palette.accentForeground : palette.primaryText)
          .background(
            selection == option.decision ? palette.accent : palette.surface,
            in: RoundedRectangle(cornerRadius: 10)
          )
          .accessibilityLabel(option.decision)
        }
      }

      Spacer(minLength: 0)

      if showsConfirmation {
        Button(action: onConfirm) {
          Image(systemName: isFinalReview ? "checkmark" : "arrow.right")
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(palette.accentForeground)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(palette.accent)
        .accessibilityLabel(isFinalReview ? "Finalizar entrenamiento" : "Continuar")
      }
    }
    .padding(.horizontal, 8)
  }
}

private struct WatchExerciseReviewOption: Identifiable {
  let decision: String
  let label: String
  let symbol: String
  var id: String { decision }
}

private struct WatchRIRFeedbackPage: View {
  @Binding var rir: Int
  let palette: WatchPalette
  let onRegister: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Text("RIR")
        .font(.headline)
      HStack(spacing: 12) {
        Button { rir = max(0, rir - 1) } label: {
          Image(systemName: "minus")
            .frame(width: 44, height: 44)
            .foregroundStyle(palette.accentForeground)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(palette.accent)
        .disabled(rir == 0)

        Text("\(rir)")
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .monospacedDigit()
          .frame(minWidth: 54)

        Button { rir = min(5, rir + 1) } label: {
          Image(systemName: "plus")
            .frame(width: 44, height: 44)
            .foregroundStyle(palette.accentForeground)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(palette.accent)
        .disabled(rir == 5)
      }
      Spacer(minLength: 0)
      Button(action: onRegister) {
        Image(systemName: "checkmark")
          .frame(maxWidth: .infinity, minHeight: 42)
          .foregroundStyle(palette.accentForeground)
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .tint(palette.accent)
    }
    .padding(.horizontal, 10)
  }
}

private struct WatchFeedbackNotePage: View {
  @Binding var note: String
  let palette: WatchPalette
  var onRegister: (() -> Void)?
  private let options = ["OK", "Pesado", "Técnica", "Molestia"]
  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    VStack(spacing: 10) {
      Text("Valoración")
        .font(.headline)
      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(options, id: \.self) { option in
          Button { note = option } label: {
            Text(option)
              .font(.caption.weight(.bold))
              .lineLimit(1)
              .minimumScaleFactor(0.7)
              .frame(maxWidth: .infinity, minHeight: 40)
          }
          .buttonStyle(.plain)
          .foregroundStyle(note == option ? palette.accentForeground : palette.primaryText)
          .background(note == option ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: 10))
        }
      }
      Spacer(minLength: 0)
      if let onRegister {
        Button(action: onRegister) {
          Image(systemName: "checkmark")
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(palette.accentForeground)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(palette.accent)
      }
    }
    .padding(.horizontal, 10)
  }
}

private enum WatchPainArea: CaseIterable {
  case knee, wrist, shoulder, lowerBack

  var label: String {
    switch self {
    case .knee: "Rodilla"
    case .wrist: "Muñeca"
    case .shoulder: "Hombro"
    case .lowerBack: "Lumbar"
    }
  }
}

private struct WatchPainFeedbackPage: View {
  let area: WatchPainArea
  @Binding var value: Int
  let palette: WatchPalette

  var body: some View {
    VStack(spacing: 12) {
      Text(area.label)
        .font(.headline)
      HStack(spacing: 6) {
        ForEach(0 ... 3, id: \.self) { level in
          Button { value = level } label: {
            Text("\(level)")
              .font(.headline.weight(.bold))
              .frame(width: 38, height: 42)
          }
          .buttonStyle(.plain)
          .foregroundStyle(value == level ? palette.accentForeground : palette.primaryText)
          .background(value == level ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: 10))
        }
      }
      Text("Intensidad de la molestia")
        .font(.caption2)
        .foregroundStyle(palette.secondaryText)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
  }
}

private struct WatchSetView: View {
  let workout: WatchWorkoutState
  let palette: WatchPalette
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  @State private var editor: WatchMetricEditor?

  private var isTimed: Bool { workout.durationSeconds != nil }

  var body: some View {
    TabView {
      WatchSetPrimaryPage(
        workout: workout,
        palette: palette,
        isSendingAction: isSendingAction,
        isTimed: isTimed,
        onEdit: { editor = $0 },
        onCommand: onCommand
      )
      .tag(0)

      if let options = workout.equipmentOptions, !options.isEmpty {
        WatchEquipmentPage(
          options: options,
          currentEquipmentName: workout.equipmentName,
          palette: palette,
          onSelect: { onCommand(.selectEquipment($0)) }
        )
        .tag(1)
      }
    }
    .tabViewStyle(.verticalPage)
    .sheet(item: $editor) { metric in
      WatchSetEditor(
        metric: metric,
        reps: workout.reps ?? 0,
        weightKg: workout.weightKg,
        equipment: workout.equipment
      ) { reps, weight in
        onCommand(.updateWorkingSet(reps: reps, weightKg: weight))
      }
    }
  }

}

private struct WatchSetPrimaryPage: View {
  let workout: WatchWorkoutState
  let palette: WatchPalette
  let isSendingAction: Bool
  let isTimed: Bool
  let onEdit: (WatchMetricEditor) -> Void
  let onCommand: (WatchWorkoutCommand) -> Void

  var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 5) {
        Text(workout.exerciseName)
          .font(.subheadline.weight(.bold))
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .minimumScaleFactor(0.68)
        if isTimed {
          WatchTimedSetControls(
            durationSeconds: workout.durationSeconds ?? 0,
            endsAt: workout.timerEndsAt,
            palette: palette,
            isSendingAction: isSendingAction,
            onCommand: onCommand
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          Button { onEdit(.reps) } label: {
            WatchMetricCard(
              label: "Reps",
              value: workout.reps.map(String.init) ?? "-",
              height: metricHeight(in: proxy.size.height),
              palette: palette
            )
          }
          .buttonStyle(.plain)
          Button { onEdit(.weight) } label: {
            WatchMetricCard(
              label: "Peso",
              value: WeightFormatter.string(from: workout.weightKg),
              height: metricHeight(in: proxy.size.height),
              palette: palette
            )
          }
          .buttonStyle(.plain)
        }
        Spacer(minLength: 0)
        WatchSetActions(
          palette: palette,
          isSendingAction: isSendingAction,
          onSkip: { onCommand(.skipSet) },
          onRegister: { onCommand(.registerSet) }
        )
        .frame(height: 42)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
    }
  }

  private func metricHeight(in availableHeight: CGFloat) -> CGFloat {
    max(38, min(54, (availableHeight - 116) / 2))
  }
}

private struct WatchEquipmentPage: View {
  let options: [Equipment]
  let currentEquipmentName: String
  let palette: WatchPalette
  let onSelect: (Equipment) -> Void

  var body: some View {
    VStack(spacing: 8) {
      ForEach(options, id: \.self) { equipment in
        Button { onSelect(equipment) } label: {
          HStack {
            Text(equipment.watchLabel)
              .font(.subheadline.weight(.semibold))
            Spacer()
            if equipment.watchLabel == currentEquipmentName {
              Image(systemName: "checkmark.circle.fill")
            }
          }
          .padding(.horizontal, 10)
          .frame(minHeight: 38)
          .foregroundStyle(
            equipment.watchLabel == currentEquipmentName
              ? palette.accentForeground
              : Color.primary
          )
          .background(
            equipment.watchLabel == currentEquipmentName
              ? palette.accent
              : palette.surface,
            in: RoundedRectangle(cornerRadius: 12)
          )
        }
        .buttonStyle(.plain)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
  }
}

private struct WatchMetricCard: View {
  let label: String
  let value: String
  let height: CGFloat
  let palette: WatchPalette
  var body: some View {
    VStack(spacing: 2) {
      Spacer(minLength: 6)
      Text(value)
        .font(.title3.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 16)
      Spacer(minLength: 2)
    }
    .frame(maxWidth: .infinity, minHeight: height)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    .overlay(alignment: .topLeading) {
      Text(label)
        .font(.caption2.weight(.bold))
        .foregroundStyle(palette.accentForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(palette.accent, in: UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 9, topTrailingRadius: 0))
    }
  }
}

private struct WatchSetActions: View {
  let palette: WatchPalette
  let isSendingAction: Bool
  let onSkip: () -> Void
  let onRegister: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let spacing = 8.0
      let skipWidth = proxy.size.height
      HStack(spacing: spacing) {
        Button(action: onSkip) {
          Image(systemName: "forward.fill")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(palette.primaryText)
        }
        .tint(palette.secondaryAction)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .frame(width: skipWidth, height: proxy.size.height)
        Button(action: onRegister) {
          Image(systemName: "checkmark")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(palette.accentForeground)
        }
        .tint(palette.accent)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .disabled(isSendingAction)
  }
}

private struct WatchIconButton: View {
  let symbol: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.headline.weight(.bold))
        .frame(width: 30, height: 30)
    }
    .buttonStyle(.bordered)
  }
}

private struct WatchBackButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "chevron.left")
        .font(.headline.weight(.bold))
        .frame(width: 28, height: 28)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Volver")
  }
}

private struct WatchWorkoutProgressBadge: View {
  let progress: Double
  let palette: WatchPalette

  private var percent: Int { Int((progress * 100).rounded()) }

  var body: some View {
    ZStack {
      Circle()
        .stroke(palette.muted, lineWidth: 3)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Text("\(percent)")
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.65)
    }
    .frame(width: 28, height: 28)
  }
}

private struct WatchRestView: View {
  let workout: WatchWorkoutState
  let palette: WatchPalette
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  @State private var crownRestAdjustment = 0.0

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int((workout.timerEndsAt?.timeIntervalSince(context.date) ?? 0).rounded(.up)))
      let complete = workout.timerEndsAt != nil && remaining == 0
      VStack(spacing: 7) {
          Spacer(minLength: 10)
          Text(clock(remaining))
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(complete ? Color.green : palette.primaryText)
            .focusable(true)
            .digitalCrownRotation(
              $crownRestAdjustment,
              from: -60,
              through: 60,
              by: 1,
              sensitivity: .medium,
              isContinuous: false,
              isHapticFeedbackEnabled: true
            )
            .onChange(of: crownRestAdjustment) { previous, current in
              adjustRest(using: current - previous)
            }
            .onChange(of: complete) { _, didFinish in
              if didFinish { WKInterfaceDevice.current().play(.notification) }
            }

          HStack(spacing: 7) {
            Image(systemName: "forward.end.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 1) {
              Text(workout.exerciseName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
              Text(nextSetSummary)
                .font(.system(size: 9))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 8)
          .frame(maxWidth: .infinity, minHeight: 34)
          .background(palette.surface, in: RoundedRectangle(cornerRadius: 10))

          Spacer(minLength: 2)

          Button { onCommand(.continueAfterTimer) } label: {
            Image(systemName: complete ? "arrow.right" : "forward.fill")
              .frame(maxWidth: .infinity, minHeight: 42)
              .foregroundStyle(complete ? Color.white : palette.accentForeground)
          }
          .buttonStyle(.borderedProminent)
          .buttonBorderShape(.capsule)
          .tint(complete ? .green : palette.accent)
          .disabled(isSendingAction)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 2)
    }
  }

  private func adjustRest(using crownDelta: Double) {
    guard !isSendingAction else { return }
    let steps = Int(crownDelta.rounded())
    guard steps != 0 else { return }
    let command: WatchWorkoutCommand = steps > 0 ? .addRest15 : .subtractRest15
    for _ in 0 ..< abs(steps) { onCommand(command) }
  }

  private var nextSetSummary: String {
    if let seconds = workout.durationSeconds { return "\(seconds)s · \(workout.equipmentName)" }
    return "\(workout.reps ?? 0) reps · \(WeightFormatter.string(from: workout.weightKg))"
  }
}

private struct WatchCountdownProgressBackground: View {
  let palette: WatchPalette
  let endsAt: Date?
  let total: Int

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int((endsAt?.timeIntervalSince(context.date) ?? 0).rounded(.up)))
      let isComplete = endsAt != nil && remaining == 0
      let denominator = max(total, remaining)
      let progress = denominator > 0
        ? min(max(CGFloat(remaining) / CGFloat(denominator), 0), 1)
        : 0

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          palette.canvas
          if isComplete {
            Color.green.opacity(0.28)
          } else {
            palette.accent
              .opacity(0.32)
              .frame(width: proxy.size.width * progress, height: proxy.size.height)
              .animation(.linear(duration: 0.9), value: remaining)
          }
        }
        .ignoresSafeArea()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea()
    }
  }
}

private struct WatchWarmupView: View {
  let workout: WatchWorkoutState
  let palette: WatchPalette
  let onCommand: (WatchWorkoutCommand) -> Void
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int((workout.timerEndsAt?.timeIntervalSince(context.date) ?? 0).rounded(.up)))
      let complete = workout.timerEndsAt != nil && remaining == 0
      VStack(spacing: 12) {
        Image(systemName: "flame.fill").font(.title2).foregroundStyle(palette.accent)
        if complete {
          Text("Calentamiento terminado")
            .font(.headline)
            .foregroundStyle(.green)
        }
        Text(clock(remaining)).font(.system(size: 38, weight: .bold, design: .rounded)).monospacedDigit()
        Text("No afecta a las series").font(.caption).foregroundStyle(palette.secondaryText)
        Button {
          onCommand(.continueAfterTimer)
        } label: {
          Image(systemName: complete ? "arrow.right" : "checkmark")
            .foregroundStyle(complete ? Color.white : palette.accentForeground)
        }
          .buttonStyle(.borderedProminent).tint(complete ? .green : palette.accent)
      }
      .padding(.horizontal, 8)
    }
  }
}

private struct WatchTimedSetControls: View {
  let durationSeconds: Int
  let endsAt: Date?
  let palette: WatchPalette
  let isSendingAction: Bool
  let onCommand: (WatchWorkoutCommand) -> Void
  @State private var didAnnounceCompletion = false
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int((endsAt?.timeIntervalSince(context.date) ?? 0).rounded(.up)))
      let isComplete = endsAt != nil && remaining == 0
      VStack(spacing: 10) {
        Spacer(minLength: 8)
        Text(clock(endsAt == nil ? durationSeconds : remaining))
          .font(.system(size: 46, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(isComplete ? Color.green : palette.primaryText)
          .onChange(of: isComplete) { _, finished in
            guard finished, !didAnnounceCompletion else { return }
            didAnnounceCompletion = true
            WKInterfaceDevice.current().play(.notification)
          }
        if !isComplete {
          Button {
            onCommand(endsAt == nil ? .startTimedSet : .pauseTimedSet)
          } label: {
            Image(systemName: endsAt == nil ? "play.fill" : "pause.fill")
              .frame(width: 40, height: 40)
              .foregroundStyle(palette.accentForeground)
          }
          .buttonStyle(.borderedProminent)
          .buttonBorderShape(.circle)
          .tint(palette.accent)
        }
        Spacer(minLength: 8)
      }
      .disabled(isSendingAction)
    }
  }
}

private enum WatchMetricEditor: String, Identifiable { case reps, weight; var id: String { rawValue } }

private struct WatchSetEditor: View {
  let metric: WatchMetricEditor
  let reps: Int
  let weightKg: Double
  let equipment: Equipment
  let onConfirm: (Int?, Double) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var crownValue: Double

  init(
    metric: WatchMetricEditor,
    reps: Int,
    weightKg: Double,
    equipment: Equipment,
    onConfirm: @escaping (Int?, Double) -> Void
  ) {
    self.metric = metric
    self.reps = reps
    self.weightKg = weightKg
    self.equipment = equipment
    self.onConfirm = onConfirm

    let loads = EquipmentLoadRules.availableLoads(for: equipment)
    let closestIndex = loads.indices.min {
      abs(loads[$0] - weightKg) < abs(loads[$1] - weightKg)
    } ?? 0
    _crownValue = State(initialValue: metric == .weight ? Double(closestIndex) : 0)
  }

  private var availableWeights: [Double] {
    EquipmentLoadRules.availableLoads(for: equipment)
  }

  private var selectedWeightIndex: Int {
    min(max(Int(crownValue.rounded()), 0), availableWeights.count - 1)
  }

  private var value: Double {
    metric == .reps
      ? Double(reps) + crownValue
      : availableWeights[selectedWeightIndex]
  }

  var body: some View {
    VStack(spacing: 10) {
      Text(metric == .reps ? "Modificar reps" : "Modificar peso").font(.headline)
      Text(displayValue).font(.system(size: 34, weight: .bold, design: .rounded)).focusable(true)
        .digitalCrownRotation($crownValue, from: lowerBound, through: upperBound, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
      Text("Gira la corona digital").font(.caption).foregroundStyle(.secondary)
      Button {
        if metric == .reps { onConfirm(max(0, Int(value.rounded())), weightKg) }
        else { onConfirm(reps, max(0, value)) }
        dismiss()
      } label: { Image(systemName: "checkmark") }.buttonStyle(.borderedProminent)
    }.padding()
  }
  private var displayValue: String { metric == .reps ? "\(max(0, Int(value.rounded())))" : WeightFormatter.string(from: max(0, value)) }
  private var lowerBound: Double { metric == .reps ? -Double(reps) : 0 }
  private var upperBound: Double {
    metric == .reps ? 40 : Double(max(availableWeights.count - 1, 0))
  }
}

private struct WatchPalette {
  let theme: WatchWorkoutTheme
  private var usesDarkCanvas: Bool { theme.appearance != "light" }
  var colorScheme: ColorScheme? { usesDarkCanvas ? .dark : .light }
  var primaryText: Color { usesDarkCanvas ? .white : .black }
  var secondaryText: Color { primaryText.opacity(usesDarkCanvas ? 0.72 : 0.62) }
  var canvas: Color {
    guard let premium = theme.premiumScheme else { return usesDarkCanvas ? .black : .white }
    return premiumCanvas(premium)
  }
  var surface: Color {
    guard theme.premiumScheme != nil else { return standardSurface }
    return accent.opacity(usesDarkCanvas ? 0.12 : 0.07)
  }
  var muted: Color { primaryText.opacity(usesDarkCanvas ? 0.32 : 0.26) }
  var secondaryAction: Color { primaryText.opacity(usesDarkCanvas ? 0.25 : 0.18) }
  var accentForeground: Color {
    theme.premiumScheme == nil ? .white : (usesDarkCanvas ? .black : .white)
  }
  var accent: Color {
    if let premium = theme.premiumScheme { return premiumAccent(premium) }
    return switch theme.accent {
    case "red": Color(red: 0.56, green: 0.14, blue: 0.18)
    case "amber": Color(red: 0.52, green: 0.31, blue: 0.00)
    case "graphite": Color(red: 0.19, green: 0.23, blue: 0.28)
    default: Color(red: 0.00, green: 0.33, blue: 0.62)
    }
  }

  private var standardSurface: Color {
    switch (theme.accent, usesDarkCanvas) {
    case ("red", true): Color(red: 0.133, green: 0.078, blue: 0.094)
    case ("red", false): Color(red: 0.984, green: 0.941, blue: 0.945)
    case ("amber", true): Color(red: 0.129, green: 0.102, blue: 0.055)
    case ("amber", false): Color(red: 0.984, green: 0.961, blue: 0.910)
    case ("graphite", true): Color(red: 0.102, green: 0.125, blue: 0.157)
    case ("graphite", false): Color(red: 0.941, green: 0.953, blue: 0.965)
    case (_, true): Color(red: 0.067, green: 0.110, blue: 0.145)
    default: Color(red: 0.929, green: 0.957, blue: 0.976)
    }
  }

  private func premiumCanvas(_ scheme: String) -> Color {
    switch (scheme, usesDarkCanvas) {
    case ("amberViolet", true): Color(red: 0.20, green: 0.09, blue: 0.34)
    case ("amberViolet", false): Color(red: 0.70, green: 0.44, blue: 0.13)
    case ("greenBlue", true): Color(red: 0.12, green: 0.22, blue: 0.32)
    case ("greenBlue", false): Color(red: 0.40, green: 0.62, blue: 0.49)
    case ("whiteNavy", true): Color(red: 0.02, green: 0.12, blue: 0.24)
    case ("whiteNavy", false): .white
    case ("grayBurgundy", true): Color(red: 0.40, green: 0.06, blue: 0.12)
    case ("grayBurgundy", false): Color(red: 0.89, green: 0.90, blue: 0.92)
    case ("monochrome", true): .black
    default: .white
    }
  }

  private func premiumAccent(_ scheme: String) -> Color {
    switch (scheme, usesDarkCanvas) {
    case ("amberViolet", true): Color(red: 0.70, green: 0.44, blue: 0.13)
    case ("amberViolet", false): Color(red: 0.20, green: 0.09, blue: 0.34)
    case ("greenBlue", true): Color(red: 0.40, green: 0.62, blue: 0.49)
    case ("greenBlue", false): Color(red: 0.12, green: 0.22, blue: 0.32)
    case ("whiteNavy", true): .white
    case ("whiteNavy", false): Color(red: 0.02, green: 0.12, blue: 0.24)
    case ("grayBurgundy", true): Color(red: 0.89, green: 0.90, blue: 0.92)
    case ("grayBurgundy", false): Color(red: 0.40, green: 0.06, blue: 0.12)
    case ("monochrome", true): .white
    default: .black
    }
  }
}

private enum WeightFormatter {
  static func string(from value: Double) -> String {
    let formatted = value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(Locale(identifier: "es_ES")))
    return "\(formatted) kg"
  }
}

private func clock(_ seconds: Int) -> String { "\(seconds / 60):\(String(format: "%02d", seconds % 60))" }

private extension TrainingExercise {
  var equipmentLabel: String {
    switch equipment {
    case .barbell: "Barra"
    case .multipower: "Multipower"
    case .dumbbell: "Mancuernas"
    case .cable: "Polea"
    case .plateLoadedMachine: "Discos"
    case .external: "Externo"
    case .bodyweight: "Corporal"
    }
  }
}

private extension Equipment {
  var watchLabel: String {
    switch self {
    case .barbell: "Barra"
    case .multipower: "Multipower"
    case .dumbbell: "Mancuernas"
    case .cable: "Polea"
    case .plateLoadedMachine: "Discos"
    case .external: "Externo"
    case .bodyweight: "Corporal"
    }
  }
}

#Preview {
  ContentView().environmentObject(WatchWorkoutConnectivity())
}
