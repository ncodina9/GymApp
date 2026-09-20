import Foundation
import GymAppNativeCore

enum WorkoutCSVExporter {
  static func write(
    session: TrainingSession,
    execution: WorkoutExecutionState,
    exerciseDecisions: [String: String] = [:]
  ) throws -> URL {
    let headers = [
      "date", "performed_at", "week", "session", "exercise_id", "base_exercise_id",
      "exercise", "base_exercise", "variant_label", "type", "target", "set_number",
      "status", "load_kg", "load_type", "planned_equipment", "actual_equipment", "reps",
      "rir", "pain_knee", "pain_wrist", "pain_shoulder", "pain_lumbar", "pain_other",
      "set_note", "exercise_decision", "exercise_note", "superset_id", "superset_order",
      "round_number"
    ]

    let orderedRecords = execution.records.sorted { $0.performedAt < $1.performedAt }
    let lastRecordIndexByExercise = orderedRecords.enumerated().reduce(into: [String: Int]()) { result, item in
      guard let exercise = execution.exercise(for: item.element.locator) else { return }
      result[exercise.exerciseID] = item.offset
    }
    let rows = orderedRecords.enumerated().compactMap { index, record -> [String]? in
      guard let exercise = execution.exercise(for: record.locator),
            let targets = execution.targets(for: record.locator)
      else { return nil }

      let equipment = execution.equipment(for: record.locator) ?? exercise.equipment
      let isSkipped = record.status == .skipped
      let isTimed = targets.durationSeconds != nil

      return [
        session.date,
        timestamp(record.performedAt),
        "\(session.week)",
        session.sessionLabel,
        exercise.exerciseID,
        exercise.baseExerciseID,
        exercise.name,
        exercise.baseExerciseName,
        exercise.variantLabel ?? "",
        exercise.type,
        exercise.target,
        "\(record.locator.setIndex)",
        isSkipped ? "skipped" : "done",
        isSkipped || equipment == .bodyweight ? "" : number(targets.weightKg),
        loadType(for: equipment),
        exercise.equipment.rawValue,
        equipment.rawValue,
        isSkipped ? "" : (isTimed ? "\(targets.durationSeconds ?? 0)s" : "\(targets.reps ?? 0)"),
        isSkipped || isTimed ? "" : record.feedback.rir.map(String.init) ?? "",
        "\(record.feedback.painKnee)",
        "\(record.feedback.painWrist)",
        "\(record.feedback.painShoulder)",
        "\(record.feedback.painLowerBack)",
        lastRecordIndexByExercise[exercise.exerciseID] == index
          ? exerciseDecisions[exercise.exerciseID] ?? ""
          : "",
        isSkipped ? "skipped" : record.feedback.note,
        "",
        exercise.notes,
        exercise.supersetID ?? "",
        exercise.supersetOrder.map(String.init) ?? "",
        "\(record.locator.setIndex)"
      ]
    }

    let csv = ([headers] + rows)
      .map { $0.map(escape).joined(separator: ",") }
      .joined(separator: "\n")

    let name = "\(session.date)-\(slug(session.label)).csv"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    guard let data = csv.data(using: .utf8) else {
      throw CocoaError(.fileWriteInapplicableStringEncoding)
    }
    try data.write(to: url, options: .atomic)
    return url
  }

  private static func timestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func loadType(for equipment: Equipment) -> String {
    switch equipment {
    case .barbell, .multipower, .plateLoadedMachine: "total"
    case .dumbbell: "per_dumbbell"
    case .cable: "machine"
    case .external: "external"
    case .bodyweight: "bodyweight"
    }
  }

  private static func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0 ... 1)))
  }

  nonisolated private static func escape(_ value: String) -> String {
    value.rangeOfCharacter(from: CharacterSet(charactersIn: ",\"\n")) == nil
      ? value
      : "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  private static func slug(_ value: String) -> String {
    value.folding(options: .diacriticInsensitive, locale: .current)
      .lowercased()
      .replacingOccurrences(of: " ", with: "-")
      .replacingOccurrences(of: "/", with: "-")
  }
}
