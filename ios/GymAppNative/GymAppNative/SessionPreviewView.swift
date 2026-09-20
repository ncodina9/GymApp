import SwiftUI
import SwiftData
import GymAppNativeCore

struct SessionPreviewView: View {
  let session: TrainingSession
  let activeWorkout: ActiveWorkoutSnapshot?
  let onReturnHome: () -> Void
  let readOnly: Bool
  @State private var startsNewWorkout = false
  @State private var showsRestartConfirmation = false
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  init(
    session: TrainingSession,
    activeWorkout: ActiveWorkoutSnapshot?,
    onReturnHome: @escaping () -> Void,
    readOnly: Bool = false
  ) {
    self.session = session
    self.activeWorkout = activeWorkout
    self.onReturnHome = onReturnHome
    self.readOnly = readOnly
  }

  private var resumableWorkout: ActiveWorkoutSnapshot? {
    guard activeWorkout?.execution.session.sessionID == session.sessionID else { return nil }
    return activeWorkout
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
                ExercisePreviewRow(exercise: exercise, order: exerciseOrder(exercise))
              }
            }
            .padding(16)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22))
          } else if let exercise = block.exercises.first {
            ExercisePreviewRow(exercise: exercise, order: exerciseOrder(exercise))
          }
        }
      }
      .padding(20)
      .padding(.bottom, 116)
    }
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(isPresented: $startsNewWorkout) {
      SetExecutionView(session: session, onFinishToToday: returnToToday)
    }
    .alert("Empezar de nuevo", isPresented: $showsRestartConfirmation) {
      Button("Cancelar", role: .cancel) {}
      Button("Empezar de nuevo", role: .destructive) {
        ActiveWorkoutStore.clear(in: modelContext)
        startsNewWorkout = true
      }
    } message: {
      Text("Se sustituirá el entrenamiento en curso por una nueva sesión de \(session.label).")
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

          if let resumableWorkout {
            NavigationLink {
              SetExecutionView(snapshot: resumableWorkout, onFinishToToday: returnToToday)
            } label: {
              Label("Reanudar", systemImage: "play.fill")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
          }

          Button {
            if activeWorkout != nil {
              showsRestartConfirmation = true
            } else {
              startsNewWorkout = true
            }
          } label: {
            Label("Empezar", systemImage: "chevron.right")
              .font(.headline.weight(.bold))
              .frame(maxWidth: .infinity, minHeight: 56)
              .foregroundStyle(.white)
              .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
          }
          .buttonStyle(.plain)
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

  private func returnToToday() {
    startsNewWorkout = false
    onReturnHome()
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

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        Text("\(order)")
          .font(.subheadline.weight(.bold))
          .frame(width: 32, height: 32)
          .background(.fill.tertiary, in: Circle())

        VStack(alignment: .leading, spacing: 7) {
          Text(exercise.baseExerciseName)
            .font(.headline.weight(.semibold))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)

          EquipmentChip(equipment: exercise.equipment, variantLabel: exercise.variantLabel)
        }
      }

      HStack(spacing: 8) {
        PreviewMetric(label: "Series", value: "\(exercise.sets.count)")
        PreviewMetric(label: workLabel, value: workValue)
        PreviewMetric(label: loadLabel, value: loadValue)
      }
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(.separator, lineWidth: 1)
    }
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
      let amount = set.targetWeightKg.formatted(.number.precision(.fractionLength(0...1)))
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
    VStack(spacing: 5) {
      Text(label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Text(value)
        .font(.subheadline.weight(.bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, minHeight: 58)
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
