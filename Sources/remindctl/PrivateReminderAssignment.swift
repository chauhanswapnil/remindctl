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

struct ReminderAssigneeOption: Codable, Sendable, Equatable {
  let id: String
  let name: String?
  let address: String?
  let isCurrentUser: Bool

  var label: String {
    if let name, let address { return "\(name) <\(address)>" }
    return name ?? address ?? id
  }
}

enum PrivateReminderAssignment {
  static func listAssignees(reminderID: String) throws -> [ReminderAssigneeOption] {
    var error: NSError?
    guard let payload = RKListReminderAssignees(reminderID, &error) else {
      throw RemindCoreError.operationFailed(
        error?.localizedDescription ?? "ReminderKit participant lookup failed without an error message")
    }
    return try payload.map { item in
      guard let id = item["id"] as? String,
        let isCurrentUser = item["isCurrentUser"] as? Bool
      else {
        throw RemindCoreError.operationFailed("ReminderKit returned an invalid participant result")
      }
      return ReminderAssigneeOption(
        id: id,
        name: item["name"] as? String,
        address: item["address"] as? String,
        isCurrentUser: isCurrentUser
      )
    }
  }

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
