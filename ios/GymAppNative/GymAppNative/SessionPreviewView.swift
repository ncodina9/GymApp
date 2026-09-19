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
          if block.isSuperset {
            VStack(alignment: .leading, spacing: 12) {
              Text("Superserie")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

              ForEach(block.exercises) { exercise in
                ExercisePreviewRow(exercise: exercise)
              }
            }
            .padding(16)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22))
          } else if let exercise = block.exercises.first {
            ExercisePreviewRow(exercise: exercise)
          }
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
  var exercises: [TrainingExercise]

  var isSuperset: Bool { supersetID != nil }
}

private struct ExercisePreviewRow: View {
  let exercise: TrainingExercise

  private var firstSet: TrainingSet? { exercise.sets.first }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(exercise.baseExerciseName)
          .font(.headline.weight(.semibold))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        EquipmentChip(equipment: exercise.equipment, variantLabel: exercise.variantLabel)
      }

      Text(targetSummary)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 18))
  }

  private var targetSummary: String {
    guard let firstSet else { return "-" }
    if firstSet.type == .timed {
      let duration = firstSet.targetDurationSeconds ?? 0
      return "\(exercise.sets.count) series · \(duration / 60):\(String(format: "%02d", duration % 60))"
    }

    let reps = firstSet.targetReps.map(String.init) ?? "-"
    return "\(exercise.sets.count) × \(reps) · \(loadValue)"
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
