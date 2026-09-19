import SwiftUI
import GymAppNativeCore

struct SetExecutionView: View {
  let session: TrainingSession
  @State private var execution: WorkoutExecutionState
  @State private var phase: ExecutionPhase = .workingSet
  @State private var feedback: WorkoutSetFeedback = .ok
  @State private var restEndsAt: Date?
  @Environment(\.dismiss) private var dismiss

  init(session: TrainingSession) {
    self.session = session
    _execution = State(initialValue: WorkoutExecutionState(session: session))
  }

  var body: some View {
    Group {
      switch phase {
      case .workingSet:
        if let locator = execution.current {
          WorkingSetView(
            execution: $execution,
            locator: locator,
            onContinue: { phase = .feedback }
          )
        } else {
          FinishedWorkoutView(completedSetCount: execution.completedSetCount, onFinish: { dismiss() })
        }
      case .feedback:
        FeedbackView(feedback: $feedback, onBack: { phase = .workingSet }, onRegister: registerCurrentSet)
      case .rest:
        if let restEndsAt, let next = execution.current {
          RestView(
            execution: execution,
            next: next,
            endsAt: restEndsAt,
            onContinue: { phase = .workingSet }
          )
        }
      case .finished:
        FinishedWorkoutView(completedSetCount: execution.completedSetCount, onFinish: { dismiss() })
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  private func registerCurrentSet() {
    guard let advance = execution.recordCurrent(feedback: feedback) else {
      phase = .finished
      return
    }

    feedback = .ok
    guard advance.next != nil else {
      phase = .finished
      return
    }

    if let restSeconds = advance.restSeconds, restSeconds > 0 {
      restEndsAt = Date().addingTimeInterval(TimeInterval(restSeconds))
      phase = .rest
    } else {
      phase = .workingSet
    }
  }
}

private enum ExecutionPhase {
  case workingSet
  case feedback
  case rest
  case finished
}

private struct WorkingSetView: View {
  @Binding var execution: WorkoutExecutionState
  let locator: WorkoutSetLocator
  let onContinue: () -> Void

  private var exercise: TrainingExercise? { execution.exercise(for: locator) }
  private var trainingSet: TrainingSet? { execution.trainingSet(for: locator) }
  private var activeEquipment: Equipment { execution.equipment(for: locator) ?? .barbell }
  private var activeTargets: WorkoutSetTargets? { execution.targets(for: locator) }

  var body: some View {
    Group {
      if let exercise, let trainingSet {
        VStack(alignment: .leading, spacing: 12) {
          SetHeader(exercise: exercise, setIndex: trainingSet.setIndex - 1)

          MaterialSelector(
            selection: Binding(
              get: { activeEquipment },
              set: { selectedEquipment in
                _ = execution.selectEquipment(selectedEquipment, for: locator)
              }
            ),
            options: equipmentOptions(for: exercise),
            unavailableOptions: unavailableEquipment(for: exercise)
          )

          if trainingSet.type == .timed {
            TimedSetTarget(seconds: activeTargets?.durationSeconds ?? 0)
          } else {
            VStack(spacing: 10) {
              SetTargetCard(label: "Reps", value: activeTargets?.reps.map(String.init) ?? "-")
              SetTargetCard(
                label: "Peso",
                value: (activeTargets?.weightKg ?? trainingSet.targetWeightKg)
                  .formatted(.number.precision(.fractionLength(0...1))),
                unit: weightUnit(for: activeEquipment)
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

          BottomActions(primaryTitle: "Continuar", primaryAction: onContinue)
        }
        .padding(16)
      } else {
        ContentUnavailableView("Serie no disponible", systemImage: "exclamationmark.triangle")
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
    let variants: [Equipment] = switch exercise.exerciseID {
    case "press-banca-barra", "press-banca-inclinado", "press-militar-sentado", "press-militar-sentado-velocidad":
      [.barbell, .multipower, .dumbbell]
    case "remo-inclinado-barra", "remo-barra-multipower", "press-cerrado-multipower":
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
}

private struct FeedbackView: View {
  @Binding var feedback: WorkoutSetFeedback
  let onBack: () -> Void
  let onRegister: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Feedback de la serie")
          .font(.largeTitle.weight(.bold))
        Text("Marca lo que mejor describa esta ejecución.")
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 10) {
        FeedbackChoice(title: "OK", detail: "Objetivo completado", value: .ok, selection: $feedback)
        FeedbackChoice(title: "Costó", detail: "Requiere revisar la progresión", value: .effort, selection: $feedback)
        FeedbackChoice(title: "Molestia", detail: "Registrar para revisarla después", value: .discomfort, selection: $feedback)
      }
      .frame(maxHeight: .infinity, alignment: .top)

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

private struct FeedbackChoice: View {
  let title: String
  let detail: String
  let value: WorkoutSetFeedback
  @Binding var selection: WorkoutSetFeedback

  var body: some View {
    Button { selection = value } label: {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.headline.weight(.bold))
          Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: selection == value ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(selection == value ? Color.accentColor : .secondary)
      }
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
      .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20))
      .overlay {
        RoundedRectangle(cornerRadius: 20)
          .stroke(
            selection == value ? Color.accentColor : Color.secondary.opacity(0.28),
            lineWidth: selection == value ? 2 : 1
          )
      }
    }
    .buttonStyle(.plain)
  }
}

private struct RestView: View {
  let execution: WorkoutExecutionState
  let next: WorkoutSetLocator
  let endsAt: Date
  let onContinue: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
      VStack(spacing: 16) {
        Text(remaining == 0 ? "Descanso terminado" : "Descanso")
          .font(.title2.weight(.bold))
          .foregroundStyle(remaining == 0 ? .green : .secondary)

        Text(timeLabel(remaining))
          .font(.system(size: 68, weight: .bold))
          .monospacedDigit()
          .frame(maxWidth: .infinity, minHeight: 148)
          .foregroundStyle(.white)
          .background(remaining == 0 ? .green : Color.accentColor, in: RoundedRectangle(cornerRadius: 28))

        NextSetCard(execution: execution, locator: next)
          .frame(maxHeight: .infinity, alignment: .top)

        BottomActions(
          primaryTitle: "Siguiente",
          primaryAction: onContinue,
          primaryDisabled: remaining > 0
        )
      }
      .padding(16)
    }
  }

  private func timeLabel(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
  }
}

private struct NextSetCard: View {
  let execution: WorkoutExecutionState
  let locator: WorkoutSetLocator

  var body: some View {
    if let exercise = execution.exercise(for: locator),
       let targets = execution.targets(for: locator) {
      VStack(alignment: .leading, spacing: 8) {
        Text("A continuación")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text(exercise.baseExerciseName)
          .font(.title3.weight(.bold))
          .lineLimit(2)
        Text("Serie \(locator.setIndex) de \(exercise.sets.count) · \(summary(targets, equipment: execution.equipment(for: locator) ?? exercise.equipment))")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20))
    }
  }

  private func summary(_ targets: WorkoutSetTargets, equipment: Equipment) -> String {
    if let duration = targets.durationSeconds {
      return "\(duration / 60):\(String(format: "%02d", duration % 60))"
    }
    let reps = targets.reps.map(String.init) ?? "-"
    let weight = targets.weightKg.formatted(.number.precision(.fractionLength(0...1)))
    return "\(reps) reps · \(equipment == .external ? "+" : "")\(weight) kg"
  }
}

private struct FinishedWorkoutView: View {
  let completedSetCount: Int
  let onFinish: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 72))
        .foregroundStyle(.green)
      Text("Entrenamiento completado")
        .font(.largeTitle.weight(.bold))
      Text("\(completedSetCount) series registradas en esta sesión.")
        .foregroundStyle(.secondary)
      Spacer()
      Button("Volver a Hoy", action: onFinish)
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
        .buttonStyle(.plain)
    }
    .padding(16)
  }
}

private struct BottomActions: View {
  let primaryTitle: String
  let primaryAction: () -> Void
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
    }
  }
}

private struct SetHeader: View {
  let exercise: TrainingExercise
  let setIndex: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .center, spacing: 12) {
        Text("Serie \(setIndex + 1) de \(exercise.sets.count)")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 6) {
          ForEach(exercise.sets.indices, id: \.self) { index in
            Circle()
              .strokeBorder(index == setIndex ? Color.accentColor : .secondary.opacity(0.35), lineWidth: 2)
              .background(
                Circle().fill(index < setIndex ? Color.accentColor : .clear)
              )
              .frame(width: 14, height: 14)
          }
        }
      }

      Text(exercise.baseExerciseName)
        .font(.system(size: 27, weight: .bold))
        .lineLimit(2)

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

  var body: some View {
    VStack(spacing: 8) {
      Text(label)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.system(size: 58, weight: .bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
}

private struct TimedSetTarget: View {
  let seconds: Int

  var body: some View {
    VStack(spacing: 12) {
      Text("Tiempo")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))")
        .font(.system(size: 64, weight: .bold))
        .monospacedDigit()
      Button("Iniciar") {}
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
        .buttonStyle(.plain)
        .disabled(true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22))
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
