import Foundation
import RemindCore
import ReminderKitBridge

struct ReminderAssignmentResult: Codable, Sendable, Equatable {
  let reminderId: String
  let cleared: Bool
  let assigneeId: String?
  let assigneeName: String?
  let assigneeAddress: String?

  var assigneeLabel: String? {
    if let assigneeName, let assigneeAddress {
      return "\(assigneeName) <\(assigneeAddress)>"
    }
    return assigneeName ?? assigneeAddress ?? assigneeId
  }
}

enum PrivateReminderAssignment {
  static func set(reminderID: String, assignee: String?) throws -> ReminderAssignmentResult {
    var error: NSError?
    guard let payload = RKSetReminderAssignment(reminderID, assignee, &error) else {
      throw RemindCoreError.operationFailed(
        error?.localizedDescription ?? "ReminderKit assignment failed without an error message")
    }
    guard let reminderId = payload["reminderId"] as? String,
      let cleared = payload["cleared"] as? Bool
    else {
      throw RemindCoreError.operationFailed("ReminderKit returned an invalid assignment result")
    }
    return ReminderAssignmentResult(
      reminderId: reminderId,
      cleared: cleared,
      assigneeId: payload["assigneeId"] as? String,
      assigneeName: payload["assigneeName"] as? String,
      assigneeAddress: payload["assigneeAddress"] as? String
    )
  }
}
