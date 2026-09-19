import SwiftUI
import GymAppNativeCore

struct SessionPreviewView: View {
  let session: TrainingSession

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
            blockLabel: exercise.block,
            exercises: [exercise]
          )
        )
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Semana \(session.week) · \(session.weekFocusLabel)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

          Text(session.label)
            .font(.largeTitle.weight(.bold))

          Text("\(session.exercises.count) ejercicios · \(session.estimatedMinutes) min estimados")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        ForEach(blocks) { block in
          VStack(alignment: .leading, spacing: 12) {
            Text(block.title)
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
              .textCase(.uppercase)

            ForEach(block.exercises) { exercise in
              ExercisePreviewRow(exercise: exercise)
            }
          }
          .padding(16)
          .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22))
        }
      }
      .padding(20)
      .padding(.bottom, 28)
    }
    .navigationTitle("Previsualización")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct PreviewBlock: Identifiable {
  let id: String
  let supersetID: String?
  let blockLabel: String
  var exercises: [TrainingExercise]

  var title: String {
    if exercises.count > 1 {
      return "Superserie"
    }
    return "Bloque \(blockLabel)"
  }
}

private struct ExercisePreviewRow: View {
  let exercise: TrainingExercise

  private var firstSet: TrainingSet? { exercise.sets.first }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(exercise.baseExerciseName)
          .font(.headline.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .leading)

        EquipmentChip(equipment: exercise.equipment, variantLabel: exercise.variantLabel)
      }

      HStack(spacing: 8) {
        PreviewMetric(label: "Series", value: "\(exercise.sets.count)")
        PreviewMetric(label: firstSet?.type == .timed ? "Tiempo" : "Reps", value: targetValue)
        PreviewMetric(label: "Peso", value: loadValue)
      }
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 18))
  }

  private var targetValue: String {
    guard let firstSet else { return "-" }
    if firstSet.type == .timed {
      let duration = firstSet.targetDurationSeconds ?? 0
      return "\(duration / 60):\(String(format: "%02d", duration % 60))"
    }
    return firstSet.targetReps.map(String.init) ?? "-"
  }

  private var loadValue: String {
    guard let firstSet else { return "-" }
    guard exercise.equipment != .bodyweight else { return "0 kg" }

    let amount = firstSet.targetWeightKg.formatted(.number.precision(.fractionLength(0...1)))
    switch exercise.equipment {
    case .external:
      return "+\(amount) kg"
    case .dumbbell:
      return "\(amount) kg c/u"
    default:
      return "\(amount) kg"
    }
  }
}

private struct EquipmentChip: View {
  let equipment: Equipment
  let variantLabel: String?

  var body: some View {
    Text(variantLabel ?? equipment.label)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.fill.quaternary, in: Capsule())
  }
}

private struct PreviewMetric: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 4) {
      Text(label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, minHeight: 56)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
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
