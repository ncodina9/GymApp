import Foundation
import SwiftData
import GymAppNativeCore

enum PlanRevisionStatus: String, Codable, CaseIterable {
  case proposed
  case accepted
  case rejected

  var label: String {
    switch self {
    case .proposed: "Pendiente"
    case .accepted: "Aceptada"
    case .rejected: "Descartada"
    }
  }
}

@Model
final class PlanRevisionRecord {
  @Attribute(.unique) var id: String
  var basePlanID: String
  var revisionNumber: Int
  var effectiveFrom: Date
  var createdAt: Date
  var updatedAt: Date
  var reason: String
  var statusRaw: String
  var acceptedAt: Date?
  var parentRevisionID: String?
  var planData: Data
  var operationsData: Data?
  var warningsData: Data?
  var impactData: Data?

  var status: PlanRevisionStatus {
    get { PlanRevisionStatus(rawValue: statusRaw) ?? .proposed }
    set { statusRaw = newValue.rawValue }
  }

  init(
    id: String = UUID().uuidString,
    basePlanID: String,
    revisionNumber: Int,
    effectiveFrom: Date,
    reason: String,
    status: PlanRevisionStatus = .proposed,
    parentRevisionID: String? = nil,
    planData: Data,
    operationsData: Data? = nil,
    warningsData: Data? = nil,
    impactData: Data? = nil,
    createdAt: Date = .now,
    acceptedAt: Date? = nil
  ) {
    self.id = id
    self.basePlanID = basePlanID
    self.revisionNumber = revisionNumber
    self.effectiveFrom = effectiveFrom
    self.reason = reason
    statusRaw = status.rawValue
    self.parentRevisionID = parentRevisionID
    self.planData = planData
    self.operationsData = operationsData
    self.warningsData = warningsData
    self.impactData = impactData
    self.createdAt = createdAt
    updatedAt = createdAt
    self.acceptedAt = acceptedAt
  }
}

@MainActor
enum PlanRevisionStore {
  static func resolvedPlan(
    basePlan: TrainingPlan,
    records: [PlanRevisionRecord],
    at date: Date = .now
  ) -> TrainingPlan {
    guard let revision = sourceRevision(for: basePlan, records: records, at: date),
          let plan = try? TrainingPlanLoader.decode(data: revision.planData) else {
      return basePlan
    }
    return plan
  }

  static func sourceRevision(
    for basePlan: TrainingPlan,
    records: [PlanRevisionRecord],
    at date: Date
  ) -> PlanRevisionRecord? {
    records
      .filter { $0.basePlanID == basePlan.planID && $0.status == .accepted && $0.effectiveFrom <= date }
      .sorted {
        if $0.effectiveFrom != $1.effectiveFrom { return $0.effectiveFrom < $1.effectiveFrom }
        return $0.revisionNumber < $1.revisionNumber
      }
      .last
  }

  @discardableResult
  static func propose(
    plan: TrainingPlan,
    basedOn basePlan: TrainingPlan,
    effectiveFrom: Date,
    reason: String,
    in context: ModelContext,
    existingRecords: [PlanRevisionRecord]
  ) -> PlanRevisionRecord? {
    guard let data = try? JSONEncoder().encode(plan) else { return nil }
    let normalizedEffectiveFrom = Calendar.current.startOfDay(for: effectiveFrom)
    let parentRevision = sourceRevision(for: basePlan, records: existingRecords, at: normalizedEffectiveFrom)
    let nextNumber = (existingRecords
      .filter { $0.basePlanID == basePlan.planID }
      .map(\.revisionNumber)
      .max() ?? 0) + 1
    let revision = PlanRevisionRecord(
      basePlanID: basePlan.planID,
      revisionNumber: nextNumber,
      effectiveFrom: normalizedEffectiveFrom,
      reason: reason,
      parentRevisionID: parentRevision?.id,
      planData: data
    )
    context.insert(revision)
    try? context.save()
    return revision
  }

  @discardableResult
  static func propose(
    operations: [PlanningOperation],
    basedOn basePlan: TrainingPlan,
    effectiveFrom: Date,
    reason: String,
    constraints: PlanningConstraints,
    in context: ModelContext,
    existingRecords: [PlanRevisionRecord]
  ) throws -> PlanRevisionRecord {
    let normalizedEffectiveFrom = Calendar.current.startOfDay(for: effectiveFrom)
    let parentRevision = sourceRevision(for: basePlan, records: existingRecords, at: normalizedEffectiveFrom)
    let effectiveBasePlan: TrainingPlan
    if let parentRevision, let decoded = try? TrainingPlanLoader.decode(data: parentRevision.planData) {
      effectiveBasePlan = decoded
    } else {
      effectiveBasePlan = basePlan
    }
    let proposal = try PlanningOperationEngine.preview(
      basePlan: effectiveBasePlan,
      operations: operations,
      constraints: constraints
    )
    guard let planData = try? JSONEncoder().encode(proposal.plan),
          let operationsData = try? JSONEncoder().encode(operations),
          let warningsData = try? JSONEncoder().encode(proposal.warnings),
          let impactData = try? JSONEncoder().encode(proposal.impact) else {
      throw PlanRevisionStoreError.encodingFailed
    }
    let nextNumber = (existingRecords
      .filter { $0.basePlanID == basePlan.planID }
      .map(\.revisionNumber)
      .max() ?? 0) + 1
    let revision = PlanRevisionRecord(
      basePlanID: basePlan.planID,
      revisionNumber: nextNumber,
      effectiveFrom: normalizedEffectiveFrom,
      reason: reason,
      parentRevisionID: parentRevision?.id,
      planData: planData,
      operationsData: operationsData,
      warningsData: warningsData,
      impactData: impactData
    )
    context.insert(revision)
    try? context.save()
    return revision
  }

  static func operations(for revision: PlanRevisionRecord) -> [PlanningOperation] {
    guard let data = revision.operationsData else { return [] }
    return (try? JSONDecoder().decode([PlanningOperation].self, from: data)) ?? []
  }

  static func warnings(for revision: PlanRevisionRecord) -> [PlanningWarning] {
    guard let data = revision.warningsData else { return [] }
    return (try? JSONDecoder().decode([PlanningWarning].self, from: data)) ?? []
  }

  static func impact(for revision: PlanRevisionRecord) -> PlanningImpact? {
    guard let data = revision.impactData else { return nil }
    return try? JSONDecoder().decode(PlanningImpact.self, from: data)
  }

  static func isCurrent(
    _ revision: PlanRevisionRecord,
    basedOn basePlan: TrainingPlan,
    records: [PlanRevisionRecord]
  ) -> Bool {
    sourceRevision(for: basePlan, records: records, at: revision.effectiveFrom)?.id == revision.parentRevisionID
  }

  static func refresh(
    _ revision: PlanRevisionRecord,
    basedOn basePlan: TrainingPlan,
    records: [PlanRevisionRecord],
    constraints: PlanningConstraints,
    in context: ModelContext
  ) throws {
    guard revision.status == .proposed else { return }
    let operations = operations(for: revision)
    guard !operations.isEmpty else { throw PlanRevisionStoreError.missingOperations }
    let parentRevision = sourceRevision(for: basePlan, records: records, at: revision.effectiveFrom)
    let effectiveBasePlan: TrainingPlan
    if let parentRevision, let decoded = try? TrainingPlanLoader.decode(data: parentRevision.planData) {
      effectiveBasePlan = decoded
    } else {
      effectiveBasePlan = basePlan
    }
    let proposal = try PlanningOperationEngine.preview(
      basePlan: effectiveBasePlan,
      operations: operations,
      constraints: constraints
    )
    guard let planData = try? JSONEncoder().encode(proposal.plan),
          let warningsData = try? JSONEncoder().encode(proposal.warnings),
          let impactData = try? JSONEncoder().encode(proposal.impact) else {
      throw PlanRevisionStoreError.encodingFailed
    }
    revision.parentRevisionID = parentRevision?.id
    revision.planData = planData
    revision.warningsData = warningsData
    revision.impactData = impactData
    revision.updatedAt = .now
    try context.save()
  }

  static func accept(
    _ revision: PlanRevisionRecord,
    basedOn basePlan: TrainingPlan,
    records: [PlanRevisionRecord],
    in context: ModelContext
  ) throws {
    guard revision.status == .proposed else { return }
    let currentParentID = sourceRevision(for: basePlan, records: records, at: revision.effectiveFrom)?.id
    guard currentParentID == revision.parentRevisionID else {
      throw PlanRevisionStoreError.staleProposal
    }
    revision.status = .accepted
    revision.acceptedAt = .now
    revision.updatedAt = .now
    try? context.save()
  }

  static func reject(_ revision: PlanRevisionRecord, in context: ModelContext) {
    guard revision.status == .proposed else { return }
    revision.status = .rejected
    revision.updatedAt = .now
    try? context.save()
  }
}

enum PlanRevisionStoreError: LocalizedError {
  case encodingFailed
  case staleProposal
  case missingOperations

  var errorDescription: String? {
    switch self {
    case .encodingFailed: "No se pudo guardar la propuesta de planificación."
    case .staleProposal:
      "Esta propuesta se basó en una planificación anterior. Crea una nueva propuesta para combinarla con los cambios ya aceptados."
    case .missingOperations:
      "Esta propuesta antigua no contiene operaciones para poder actualizarse."
    }
  }
}
