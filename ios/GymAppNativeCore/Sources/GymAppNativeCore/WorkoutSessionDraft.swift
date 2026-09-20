import Foundation

public struct WorkoutSetTargets: Codable, Equatable, Sendable {
  public let reps: Int?
  public let weightKg: Double
  public let durationSeconds: Int?

  public init(reps: Int?, weightKg: Double, durationSeconds: Int?) {
    self.reps = reps
    self.weightKg = weightKg
    self.durationSeconds = durationSeconds
  }
}

public struct WorkoutSessionDraft: Codable, Sendable {
  public let session: TrainingSession
  private var equipmentByExerciseID: [String: Equipment]
  private var targetOverrides: [SetTargetKey: TargetOverride]

  public init(session: TrainingSession) {
    self.session = session
    equipmentByExerciseID = Dictionary(
      uniqueKeysWithValues: session.exercises.map { ($0.exerciseID, $0.equipment) }
    )
    targetOverrides = [:]
  }

  public func equipment(for exerciseID: String) -> Equipment? {
    equipmentByExerciseID[exerciseID]
  }

  public func targets(for exerciseID: String, setIndex: Int) -> WorkoutSetTargets? {
    guard let exercise = exercise(withID: exerciseID),
          let trainingSet = exercise.sets.first(where: { $0.setIndex == setIndex })
    else {
      return nil
    }

    let override = targetOverrides[SetTargetKey(exerciseID: exerciseID, setIndex: setIndex)]
    let equipment = equipment(for: exerciseID) ?? exercise.equipment
    let referenceWeightKg = override?.referenceWeightKg ?? EquipmentLoadRules.referenceWeightKg(
      trainingSet.targetWeightKg,
      equipment: exercise.equipment
    )

    return WorkoutSetTargets(
      reps: override?.reps ?? trainingSet.targetReps,
      weightKg: EquipmentLoadRules.weightForReferenceWeight(
        referenceWeightKg,
        equipment: equipment
      ),
      durationSeconds: override?.durationSeconds ?? trainingSet.targetDurationSeconds
    )
  }

  public func canSelectEquipment(_ equipment: Equipment, for exerciseID: String) -> Bool {
    guard let exercise = exercise(withID: exerciseID) else { return false }

    return exercise.sets.allSatisfy { trainingSet in
      let override = targetOverrides[
        SetTargetKey(exerciseID: exerciseID, setIndex: trainingSet.setIndex)
      ]
      let referenceWeightKg = override?.referenceWeightKg ?? EquipmentLoadRules.referenceWeightKg(
        trainingSet.targetWeightKg,
        equipment: exercise.equipment
      )
      return EquipmentLoadRules.canUse(
        equipment: equipment,
        referenceWeightKg: referenceWeightKg
      )
    }
  }

  @discardableResult
  public mutating func selectEquipment(_ equipment: Equipment, for exerciseID: String) -> Bool {
    guard canSelectEquipment(equipment, for: exerciseID) else { return false }
    equipmentByExerciseID[exerciseID] = equipment
    return true
  }

  public mutating func updateWorkingTargets(
    for exerciseID: String,
    setIndex: Int,
    reps: Int?,
    weightKg: Double
  ) {
    guard let exercise = exercise(withID: exerciseID),
          let currentPosition = exercise.sets.firstIndex(where: { $0.setIndex == setIndex })
    else {
      return
    }

    let equipment = equipment(for: exerciseID) ?? exercise.equipment
    let currentPlannedSet = exercise.sets[currentPosition]
    let override = TargetOverride(
      reps: reps,
      referenceWeightKg: EquipmentLoadRules.referenceWeightKg(weightKg, equipment: equipment),
      durationSeconds: currentPlannedSet.targetDurationSeconds
    )

    for trainingSet in exercise.sets[currentPosition...] {
      guard hasSamePlannedTarget(currentPlannedSet, trainingSet) else { break }
      targetOverrides[
        SetTargetKey(exerciseID: exerciseID, setIndex: trainingSet.setIndex)
      ] = override
    }
  }

  private func exercise(withID exerciseID: String) -> TrainingExercise? {
    session.exercises.first { $0.exerciseID == exerciseID }
  }

  private func hasSamePlannedTarget(_ lhs: TrainingSet, _ rhs: TrainingSet) -> Bool {
    lhs.targetReps == rhs.targetReps &&
      lhs.targetWeightKg == rhs.targetWeightKg &&
      lhs.targetDurationSeconds == rhs.targetDurationSeconds
  }
}

private struct SetTargetKey: Codable, Hashable, Sendable {
  let exerciseID: String
  let setIndex: Int
}

private struct TargetOverride: Codable, Sendable {
  let reps: Int?
  let referenceWeightKg: Double
  let durationSeconds: Int?
}
