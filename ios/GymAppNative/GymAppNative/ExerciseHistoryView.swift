import SwiftUI
import SwiftData
import Charts
import GymAppNativeCore

struct ExerciseHistoryView: View {
  let exercise: TrainingExercise
  let records: [CompletedWorkoutRecord]?
  let showsAppChrome: Bool
  @Query private var completedWorkouts: [CompletedWorkoutRecord]
  @Environment(\.dismiss) private var dismiss

  init(
    exercise: TrainingExercise,
    records: [CompletedWorkoutRecord]? = nil,
    showsAppChrome: Bool = true
  ) {
    self.exercise = exercise
    self.records = records
    self.showsAppChrome = showsAppChrome
  }

  var body: some View {
    ScrollView {
      ExerciseHistoryContent(
        exercise: exercise,
        completedWorkouts: records ?? completedWorkouts,
        showsTitle: !showsAppChrome
      )
      .padding(20)
      .padding(.bottom, showsAppChrome ? 88 : 0)
    }
    .background(GymCanvas())
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      if showsAppChrome {
        AccentHeaderCard(title: exercise.baseExerciseName, eyebrow: "Historial")
      }
    }
    .overlay(alignment: .bottomLeading) {
      if showsAppChrome {
        HistoryBackButton(action: { dismiss() })
      }
    }
    .frame(
      width: showsAppChrome ? nil : 340,
      height: showsAppChrome ? nil : 500
    )
  }
}

private struct HistoryBackButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "chevron.left")
        .font(.headline.weight(.bold))
        .frame(width: 56, height: 56)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: Circle())
    }
    .accessibilityLabel("Atrás")
    .buttonStyle(.plain)
    .padding(.leading, 20)
    .padding(.bottom, 8)
  }
}

struct ExerciseHistoryContent: View {
  let exercise: TrainingExercise
  let completedWorkouts: [CompletedWorkoutRecord]
  var showsTitle = true
  @State private var selectedEquipment: Equipment?

  private var entries: [ExerciseHistoryEntry] {
    let nativeEntries = ExerciseHistory.entries(
      for: exercise,
      from: completedWorkouts.compactMap { record in
        guard let data = record.executionData,
              let execution = try? JSONDecoder().decode(WorkoutExecutionState.self, from: data)
        else { return nil }
        return HistoricalWorkoutExecution(completedAt: record.completedAt, execution: execution)
      }
    )

    let importedEntries: [ExerciseHistoryEntry] = completedWorkouts.flatMap { record -> [ExerciseHistoryEntry] in
      guard let data = record.importedSessionData,
            let session = try? JSONDecoder().decode(TrainingBackup.Session.self, from: data)
      else { return [] }

      return (session.events ?? []).compactMap { event in
        guard event.status == "completed",
              belongsToCurrentExercise(event, in: session),
              let performedAt = backupDate(event.performedAt)
        else { return nil }

        return ExerciseHistoryEntry(
          id: "\(session.sessionId)-\(event.id)",
          date: performedAt,
          equipment: equipment(for: event, in: session),
          weightKg: event.actualWeightKg ?? event.plannedWeightKg ?? 0,
          reps: event.actualReps ?? event.plannedReps,
          durationSeconds: event.actualDurationSeconds ?? event.plannedDurationSeconds
        )
      }
    }

    return (nativeEntries + importedEntries).sorted { $0.date > $1.date }
  }

  private var equipment: [Equipment] {
    Array(Set(entries.map(\.equipment))).sorted { equipmentLabel($0) < equipmentLabel($1) }
  }

  private var activeEquipment: Equipment? {
    selectedEquipment ?? equipment.first
  }

  private var filteredEntries: [ExerciseHistoryEntry] {
    guard let activeEquipment else { return entries }
    return entries.filter { $0.equipment == activeEquipment }
  }

  private var bestWeight: ExerciseHistoryEntry? {
    filteredEntries.max { $0.weightKg < $1.weightKg }
  }

  private var bestReps: ExerciseHistoryEntry? {
    filteredEntries.max { ($0.reps ?? 0) < ($1.reps ?? 0) }
  }

  private var bestRM: ExerciseHistoryEntry? {
    filteredEntries.max { ($0.estimatedOneRepMax ?? 0) < ($1.estimatedOneRepMax ?? 0) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
          if showsTitle {
            Text(exercise.baseExerciseName)
              .font(.system(size: 31, weight: .bold))
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
          }

          if equipment.count > 1 {
            Picker("Material", selection: $selectedEquipment) {
              ForEach(equipment, id: \.self) { item in
                Text(equipmentLabel(item)).tag(Optional(item))
              }
            }
            .pickerStyle(.segmented)
          }

          if filteredEntries.isEmpty {
            ContentUnavailableView("Sin historial nativo", systemImage: "chart.line.uptrend.xyaxis")
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity, minHeight: 240)
          } else {
            HStack(spacing: 10) {
              HistoryMetric(title: "Peso", value: weightLabel(bestWeight))
              HistoryMetric(title: "Reps", value: bestReps?.reps.map(String.init) ?? "-")
              HistoryMetric(title: "RM Epley", value: rmLabel(bestRM))
            }

            if filteredEntries.count > 1 {
              Chart(filteredEntries.reversed()) { entry in
                LineMark(
                  x: .value("Fecha", entry.date),
                  y: .value("Carga", entry.weightKg)
                )
                .foregroundStyle(Color.gymAccent)
                .interpolationMethod(.catmullRom)
                PointMark(
                  x: .value("Fecha", entry.date),
                  y: .value("Carga", entry.weightKg)
                )
                .foregroundStyle(Color.gymAccent)
              }
              .frame(height: 180)
              .chartYAxisLabel("kg", alignment: .topTrailing)
              .padding(14)
              .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 22))
            }

            VStack(alignment: .leading, spacing: 10) {
              Text("Registros")
                .font(.headline.weight(.bold))
              ForEach(filteredEntries) { entry in
                HStack {
                  Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                  Spacer()
                  Text(weightLabel(entry))
                  Text("·")
                    .foregroundStyle(Color.gymSecondaryText)
                  Text(entry.reps.map { "\($0) reps" } ?? timeLabel(entry.durationSeconds))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.gymSecondaryText)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Divider() }
              }
            }
            .padding(16)
            .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 22))
          }
    }
  }

  private func weightLabel(_ entry: ExerciseHistoryEntry?) -> String {
    guard let entry else { return "-" }
    if entry.equipment == .bodyweight { return "Corporal" }
    let prefix = entry.equipment == .external ? "+" : ""
    return "\(prefix)\(entry.weightKg.formatted(.number.precision(.fractionLength(0 ... 2)))) kg"
  }

  private func rmLabel(_ entry: ExerciseHistoryEntry?) -> String {
    guard let value = entry?.estimatedOneRepMax else { return "-" }
    return "\(value.formatted(.number.precision(.fractionLength(0 ... 1)))) kg"
  }

  private func timeLabel(_ seconds: Int?) -> String {
    guard let seconds else { return "-" }
    return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
  }

  private func equipmentLabel(_ equipment: Equipment) -> String {
    switch equipment {
    case .barbell: "Barra"
    case .multipower: "Multipower"
    case .dumbbell: "Mancuernas"
    case .cable: "Polea"
    case .plateLoadedMachine: "Máquina de discos"
    case .external: "Lastre"
    case .bodyweight: "Peso corporal"
    }
  }

  private func belongsToCurrentExercise(
    _ event: TrainingBackup.Event,
    in session: TrainingBackup.Session
  ) -> Bool {
    if event.exerciseId == exercise.exerciseID || event.exerciseId == exercise.baseExerciseID {
      return true
    }

    return session.planSession?.exercises.first(where: { $0.exerciseID == event.exerciseId })?.baseExerciseID
      == exercise.baseExerciseID
  }

  private func equipment(
    for event: TrainingBackup.Event,
    in session: TrainingBackup.Session
  ) -> Equipment {
    if let rawValue = event.actualEquipment ?? event.plannedEquipment,
       let equipment = Equipment(rawValue: rawValue) {
      return equipment
    }

    return session.planSession?.exercises.first(where: { $0.exerciseID == event.exerciseId })?.equipment
      ?? exercise.equipment
  }

  private func backupDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }
}

private struct HistoryMetric: View {
  let title: String
  let value: String

  var body: some View {
    VStack(spacing: 5) {
      Text(title)
        .font(.caption.weight(.bold))
        .foregroundStyle(Color.gymSecondaryText)
      Text(value)
        .font(.headline.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, minHeight: 76)
    .background(Color.gymCanvas, in: RoundedRectangle(cornerRadius: 16))
  }
}
