import Foundation

public struct HistoricalWorkoutExecution: Sendable {
  public let completedAt: Date
  public let execution: WorkoutExecutionState

  public init(completedAt: Date, execution: WorkoutExecutionState) {
    self.completedAt = completedAt
    self.execution = execution
  }
}

public struct ExerciseHistoryEntry: Identifiable, Sendable {
  public let id: String
  public let date: Date
  public let equipment: Equipment
  public let weightKg: Double
  public let reps: Int?
  public let durationSeconds: Int?
  public let estimatedOneRepMax: Double?

  public init(
    id: String,
    date: Date,
    equipment: Equipment,
    weightKg: Double,
    reps: Int?,
    durationSeconds: Int?
  ) {
    self.id = id
    self.date = date
    self.equipment = equipment
    self.weightKg = weightKg
    self.reps = reps
    self.durationSeconds = durationSeconds
    if let reps, reps > 0, weightKg > 0 {
      estimatedOneRepMax = weightKg * (1 + Double(reps) / 30)
    } else {
      estimatedOneRepMax = nil
    }
  }
}

public enum ExerciseHistory {
  public static func entries(
    for exercise: TrainingExercise,
    from workouts: [HistoricalWorkoutExecution]
  ) -> [ExerciseHistoryEntry] {
    workouts.flatMap { workout in
      workout.execution.records.compactMap { record in
        guard record.status == .completed,
              let recordedExercise = workout.execution.exercise(for: record.locator),
              recordedExercise.displayGroupID == exercise.displayGroupID,
              let targets = workout.execution.targets(for: record.locator)
        else {
          return nil
        }

        return ExerciseHistoryEntry(
          id: "\(workout.completedAt.timeIntervalSince1970)-\(record.locator.exerciseIndex)-\(record.locator.setIndex)",
          date: record.performedAt,
          equipment: workout.execution.equipment(for: record.locator) ?? recordedExercise.equipment,
          weightKg: targets.weightKg,
          reps: targets.reps,
          durationSeconds: targets.durationSeconds
        )
      }
    }
    .sorted { $0.date > $1.date }
  }
}
