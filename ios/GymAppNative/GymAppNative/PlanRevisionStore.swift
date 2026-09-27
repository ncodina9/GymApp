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
  var planData: Data

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
    planData: Data,
    createdAt: Date = .now,
    acceptedAt: Date? = nil
  ) {
    self.id = id
    self.basePlanID = basePlanID
    self.revisionNumber = revisionNumber
    self.effectiveFrom = effectiveFrom
    self.reason = reason
    statusRaw = status.rawValue
    self.planData = planData
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
    let accepted = records
      .filter { $0.basePlanID == basePlan.planID && $0.status == .accepted && $0.effectiveFrom <= date }
      .sorted {
        if $0.effectiveFrom != $1.effectiveFrom { return $0.effectiveFrom < $1.effectiveFrom }
        return $0.revisionNumber < $1.revisionNumber
      }

    guard let revision = accepted.last,
          let plan = try? TrainingPlanLoader.decode(data: revision.planData) else {
      return basePlan
    }
    return plan
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
    let nextNumber = (existingRecords
      .filter { $0.basePlanID == basePlan.planID }
      .map(\.revisionNumber)
      .max() ?? 0) + 1
    let revision = PlanRevisionRecord(
      basePlanID: basePlan.planID,
      revisionNumber: nextNumber,
      effectiveFrom: Calendar.current.startOfDay(for: effectiveFrom),
      reason: reason,
      planData: data
    )
    context.insert(revision)
    try? context.save()
    return revision
  }

  static func accept(_ revision: PlanRevisionRecord, in context: ModelContext) {
    guard revision.status == .proposed else { return }
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
