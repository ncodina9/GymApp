import Foundation
import SwiftData
import GymAppNativeCore

enum PlanningConversationStatus: String, Codable {
  case interpreted
  case needsClarification
  case proposed

  var label: String {
    switch self {
    case .interpreted: "Interpretada"
    case .needsClarification: "Necesita aclaración"
    case .proposed: "Propuesta creada"
    }
  }
}

@Model
final class PlanningConversationRecord {
  @Attribute(.unique) var id: String
  var requestText: String
  var referencedSessionID: String?
  var intentData: Data?
  var draftData: Data?
  var responseText: String
  var statusRaw: String
  var revisionID: String?
  var createdAt: Date
  var updatedAt: Date

  var status: PlanningConversationStatus {
    get { PlanningConversationStatus(rawValue: statusRaw) ?? .needsClarification }
    set { statusRaw = newValue.rawValue }
  }

  init(
    id: String = UUID().uuidString,
    requestText: String,
    referencedSessionID: String?,
    responseText: String = "",
    status: PlanningConversationStatus = .needsClarification,
    createdAt: Date = .now
  ) {
    self.id = id
    self.requestText = requestText
    self.referencedSessionID = referencedSessionID
    intentData = nil
    draftData = nil
    self.responseText = responseText
    statusRaw = status.rawValue
    revisionID = nil
    self.createdAt = createdAt
    updatedAt = createdAt
  }
}

@MainActor
enum PlanningConversationStore {
  @discardableResult
  static func start(_ request: PlanningIntentRequest, in context: ModelContext) -> PlanningConversationRecord {
    let record = PlanningConversationRecord(
      requestText: request.userText,
      referencedSessionID: request.referencedSessionID
    )
    context.insert(record)
    try? context.save()
    return record
  }

  static func interpret(_ intent: PlanningIntent, summary: String, for record: PlanningConversationRecord, in context: ModelContext) {
    record.intentData = try? JSONEncoder().encode(intent)
    record.responseText = summary
    record.status = .interpreted
    record.updatedAt = .now
    try? context.save()
  }

  static func interpret(_ operations: [PlanningOperation], summary: String, for record: PlanningConversationRecord, in context: ModelContext) {
    record.intentData = try? JSONEncoder().encode(operations)
    record.responseText = summary
    record.status = .interpreted
    record.updatedAt = .now
    try? context.save()
  }

  static func needsClarification(_ message: String, for record: PlanningConversationRecord, in context: ModelContext) {
    record.intentData = nil
    record.responseText = message
    record.status = .needsClarification
    record.updatedAt = .now
    try? context.save()
  }

  static func saveDraft(_ draft: CoachConversationDraft, message: String, for record: PlanningConversationRecord, in context: ModelContext) {
    record.draftData = try? JSONEncoder().encode(draft)
    record.responseText = message
    record.status = .needsClarification
    record.updatedAt = .now
    try? context.save()
  }

  static func clearDraft(for record: PlanningConversationRecord, in context: ModelContext) {
    record.draftData = nil
    record.updatedAt = .now
    try? context.save()
  }

  static func link(_ revision: PlanRevisionRecord, to record: PlanningConversationRecord, in context: ModelContext) {
    record.revisionID = revision.id
    record.status = .proposed
    record.updatedAt = .now
    try? context.save()
  }
}
