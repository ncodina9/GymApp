import SwiftUI
import SwiftData
import GymAppNativeCore

struct CompletedWorkoutDetailView: View {
  let record: CompletedWorkoutRecord
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var editor: RecordedSetEditDraft?
  @State private var errorMessage: String?

  private var execution: WorkoutExecutionState? {
    guard let data = record.executionData else { return nil }
    return try? JSONDecoder().decode(WorkoutExecutionState.self, from: data)
  }

  var body: some View {
    ScrollView {
      if let execution {
        VStack(alignment: .leading, spacing: 14) {
          Text(execution.session.sessionLabel)
            .font(.gymH1.weight(.bold))
          Text(record.completedAt.formatted(date: .complete, time: .shortened))
            .font(.gymBody)
            .foregroundStyle(Color.gymSecondaryText)

          ForEach(Array(execution.session.exercises.enumerated()), id: \.element.exerciseID) { index, exercise in
            RecordedExerciseCard(
              execution: execution,
              exercise: exercise,
              exerciseIndex: index,
              onEdit: openEditor
            )
          }
        }
        .padding(16)
        .padding(.bottom, 88)
      } else {
        ContentUnavailableView(
          "Registro sin detalle",
          systemImage: "exclamationmark.triangle",
          description: Text("Esta sesión no conserva las series necesarias para corregirla.")
        )
        .frame(maxWidth: .infinity, minHeight: 280)
      }
    }
    .background(GymCanvas())
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      AccentHeaderCard(title: "Corregir series", detail: "Los cambios actualizan el historial y las exportaciones")
    }
    .overlay(alignment: .bottomLeading) {
      Button(action: dismiss.callAsFunction) {
        Image(systemName: "chevron.left")
          .font(.gymH2.weight(.bold))
          .frame(width: 56, height: 56)
          .foregroundStyle(.primary)
          .glassEffect(.regular.interactive(), in: Circle())
      }
      .accessibilityLabel("Atrás")
      .buttonStyle(.plain)
      .padding(.leading, 20)
      .padding(.bottom, 8)
    }
    .sheet(item: $editor) { draft in
      RecordedSetEditor(draft: draft, onConfirm: apply)
        .presentationDetents([.medium])
    }
    .alert("No se pudo guardar", isPresented: Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )) {
      Button("Aceptar", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func openEditor(_ record: WorkoutSetRecord, _ execution: WorkoutExecutionState) {
    guard let targets = execution.targets(for: record),
          let exercise = execution.exercise(for: record.locator)
    else { return }
    editor = RecordedSetEditDraft(
      locator: record.locator,
      exerciseName: exercise.displayName,
      equipment: execution.equipment(for: record) ?? exercise.equipment,
      reps: targets.reps,
      weightKg: targets.weightKg,
      durationSeconds: targets.durationSeconds
    )
  }

  private func apply(_ draft: RecordedSetEditDraft) {
    guard var updatedExecution = execution else { return }
    guard updatedExecution.correctRecordedSet(
      at: draft.locator,
      reps: draft.reps,
      weightKg: draft.weightKg,
      durationSeconds: draft.durationSeconds
    ), let data = try? JSONEncoder().encode(updatedExecution) else {
      errorMessage = "La serie ya no está disponible para corregir."
      return
    }

    record.executionData = data
    try? modelContext.save()
    Task {
      await HealthWorkoutStore.prepareForResync(record: record, in: modelContext)
      await HealthWorkoutStore.syncIfEnabled(record: record, execution: updatedExecution, in: modelContext)
    }
  }
}

private struct RecordedExerciseCard: View {
  let execution: WorkoutExecutionState
  let exercise: TrainingExercise
  let exerciseIndex: Int
  let onEdit: (WorkoutSetRecord, WorkoutExecutionState) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(exercise.displayName)
        .font(.gymH2.weight(.bold))
      ForEach(exercise.sets, id: \.setIndex) { set in
        let locator = WorkoutSetLocator(exerciseIndex: exerciseIndex, setIndex: set.setIndex)
        let record = execution.records.first { $0.locator == locator }
        RecordedSetRow(record: record, execution: execution, onEdit: onEdit)
      }
    }
    .padding(14)
    .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.gymAccent.opacity(0.36), lineWidth: 1) }
  }
}

private struct RecordedSetRow: View {
  let record: WorkoutSetRecord?
  let execution: WorkoutExecutionState
  let onEdit: (WorkoutSetRecord, WorkoutExecutionState) -> Void

  var body: some View {
    HStack(spacing: 10) {
      Text("Serie \(record?.locator.setIndex ?? 0)")
        .font(.gymBody.weight(.semibold))
      Spacer(minLength: 0)
      Text(valueLabel)
        .font(.gymBody.weight(.bold))
        .monospacedDigit()
      if let record, record.status == .completed {
        Button {
          onEdit(record, execution)
        } label: {
          Image(systemName: "pencil")
            .font(.gymH3.weight(.bold))
            .frame(width: 38, height: 38)
            .foregroundStyle(Color.gymAccentForeground)
            .background(Color.gymAccent, in: Circle())
        }
        .accessibilityLabel("Corregir serie \(record.locator.setIndex)")
        .buttonStyle(.plain)
      } else {
        Text(record == nil ? "Sin registro" : "Omitida")
          .font(.gymSupport.weight(.bold))
          .foregroundStyle(Color.gymSecondaryText)
      }
    }
    .padding(.leading, 10)
    .padding(.vertical, 7)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 12))
  }

  private var valueLabel: String {
    guard let record, let targets = execution.targets(for: record) else { return "-" }
    if let seconds = targets.durationSeconds {
      return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
    return "\(targets.reps.map(String.init) ?? "-") x \(targets.weightKg.formatted(.number.precision(.fractionLength(0 ... 2)))) kg"
  }
}

struct RecordedSetEditDraft: Identifiable {
  let locator: WorkoutSetLocator
  let exerciseName: String
  let equipment: Equipment
  var reps: Int?
  var weightKg: Double
  var durationSeconds: Int?

  var id: WorkoutSetLocator { locator }
  var isTimed: Bool { durationSeconds != nil }
}

struct RecordedSetEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: RecordedSetEditDraft
  let onConfirm: (RecordedSetEditDraft) -> Void

  init(draft: RecordedSetEditDraft, onConfirm: @escaping (RecordedSetEditDraft) -> Void) {
    _draft = State(initialValue: draft)
    self.onConfirm = onConfirm
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Corregir serie \(draft.locator.setIndex)")
            .font(.gymH2.weight(.bold))
          Text(draft.exerciseName)
            .font(.gymBody)
            .foregroundStyle(Color.gymSecondaryText)
            .lineLimit(1)
        }
        Spacer()
        Button(action: dismiss.callAsFunction) {
          Image(systemName: "xmark")
            .font(.gymH3.weight(.bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(.primary)
            .background(Color.gymCanvas, in: Circle())
        }
        .buttonStyle(.plain)
      }

      if draft.isTimed {
        Stepper(value: Binding(
          get: { draft.durationSeconds ?? 15 },
          set: { draft.durationSeconds = max(15, $0) }
        ), in: 15...7_200, step: 15) {
          editValue(label: "Duración", value: timeLabel(draft.durationSeconds ?? 0))
        }
      } else {
        Stepper(value: Binding(
          get: { draft.reps ?? 1 },
          set: { draft.reps = max(1, $0) }
        ), in: 1...100) {
          editValue(label: "Reps", value: "\(draft.reps ?? 1)")
        }

        Stepper(onIncrement: { adjustWeight(1) }, onDecrement: { adjustWeight(-1) }) {
          editValue(label: "Peso", value: "\(draft.weightKg.formatted(.number.precision(.fractionLength(0 ... 2)))) kg")
        }
        .disabled(draft.equipment == .bodyweight)
      }

      Button("Guardar corrección") {
        onConfirm(draft)
        dismiss()
      }
      .font(.gymH2.weight(.bold))
      .frame(maxWidth: .infinity, minHeight: 56)
      .foregroundStyle(Color.gymAccentForeground)
      .glassEffect(.regular.tint(Color.gymAccent).interactive(), in: Capsule())
      .buttonStyle(.plain)
    }
    .padding(20)
    .presentationBackground(Color.gymSurface)
  }

  private func editValue(label: String, value: String) -> some View {
    HStack {
      Text(label).font(.gymH3.weight(.semibold))
      Spacer()
      Text(value).font(.gymH2.weight(.bold)).monospacedDigit()
    }
  }

  private func adjustWeight(_ direction: Int) {
    draft.weightKg = EquipmentLoadRules.adjustedWeight(
      from: draft.weightKg,
      equipment: draft.equipment,
      direction: direction
    )
  }

  private func timeLabel(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
  }
}
