import SwiftUI
import GymAppNativeCore

struct SetExecutionView: View {
  let session: TrainingSession
  let exerciseIndex: Int
  let setIndex: Int
  @State private var selectedEquipment: Equipment
  @Environment(\.dismiss) private var dismiss

  init(session: TrainingSession, exerciseIndex: Int = 0, setIndex: Int = 0) {
    self.session = session
    self.exerciseIndex = exerciseIndex
    self.setIndex = setIndex
    let equipment = session.exercises.indices.contains(exerciseIndex)
      ? session.exercises[exerciseIndex].equipment
      : .barbell
    _selectedEquipment = State(initialValue: equipment)
  }

  private var exercise: TrainingExercise? {
    session.exercises.indices.contains(exerciseIndex) ? session.exercises[exerciseIndex] : nil
  }

  private var trainingSet: TrainingSet? {
    guard let exercise, exercise.sets.indices.contains(setIndex) else { return nil }
    return exercise.sets[setIndex]
  }

  var body: some View {
    Group {
      if let exercise, let trainingSet {
        VStack(alignment: .leading, spacing: 12) {
          SetHeader(exercise: exercise, setIndex: setIndex)

          MaterialSelector(
            selection: $selectedEquipment,
            options: equipmentOptions(for: exercise)
          )

          if trainingSet.type == .timed {
            TimedSetTarget(seconds: trainingSet.targetDurationSeconds ?? 0)
          } else {
            VStack(spacing: 10) {
              SetTargetCard(label: "Reps", value: trainingSet.targetReps.map(String.init) ?? "-")
              SetTargetCard(
                label: "Peso",
                value: trainingSet.targetWeightKg.formatted(.number.precision(.fractionLength(0...1))),
                unit: weightUnit(for: selectedEquipment)
              )
            }
            .frame(maxHeight: .infinity)
          }

          VStack(alignment: .leading, spacing: 4) {
            Text(exercise.notes)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(2)
            Text("Descanso propuesto: \(trainingSet.restSeconds)s")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.secondary)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))

          HStack(spacing: 12) {
            Button(action: { dismiss() }) {
              Image(systemName: "chevron.left")
                .font(.headline.weight(.bold))
                .frame(width: 64, height: 64)
                .foregroundStyle(.primary)
                .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)

            Button("Continuar") {}
              .font(.headline.weight(.bold))
              .frame(maxWidth: .infinity, minHeight: 64)
              .foregroundStyle(.white)
              .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
              .buttonStyle(.plain)
              .disabled(true)
          }
        }
        .padding(16)
      } else {
        ContentUnavailableView(
          "Serie no disponible",
          systemImage: "exclamationmark.triangle",
          description: Text("No se ha podido resolver la primera serie del entrenamiento.")
        )
      }
    }
    .toolbar(.hidden, for: .navigationBar)
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
                  .foregroundStyle(isSelected ? .white : .primary)
              }
              .buttonStyle(.plain)
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
    let minimum = CGFloat.zero
    let maximum = segmentWidth * CGFloat(max(options.count - 1, 0))
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
