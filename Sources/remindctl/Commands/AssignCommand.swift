import Commander
import Foundation
import RemindCore

enum AssignCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "assign",
      abstract: "Assign a shared-list reminder",
      discussion: "Experimental: uses Apple's private ReminderKit framework.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "id", help: "Index or ID prefix", isOptional: false),
            .make(label: "assignee", help: "Participant name or email", isOptional: true),
          ],
          flags: [
            .make(label: "none", names: [.long("none")], help: "Clear the current assignment")
          ]
        )
      ),
      usageExamples: [
        "remindctl assign 1 \"person@example.com\"",
        "remindctl assign 4A83 \"Alex Smith\"",
        "remindctl assign 4A83 --none",
      ]
    ) { values, runtime in
      guard let input = values.argument(0) else {
        throw ParsedValuesError.missingArgument("id")
      }
      let assignee = values.argument(1)
      let clear = values.flag("none")
      if clear && assignee != nil {
        throw RemindCoreError.operationFailed("Use either an assignee or --none, not both")
      }
      if !clear && assignee == nil {
        throw RemindCoreError.operationFailed("Provide a participant name or email, or use --none")
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try CommandHelpers.resolveShowIdentifiers([input], from: reminders)
      guard let reminder = resolved.first else {
        throw RemindCoreError.reminderNotFound(input)
      }

      let result = try PrivateReminderAssignment.set(
        reminderID: reminder.id,
        assignee: clear ? nil : assignee
      )
      printResult(result, reminder: reminder, format: runtime.outputFormat)
    }
  }

  private static func printResult(
    _ result: ReminderAssignmentResult,
    reminder: ReminderItem,
    format: OutputFormat
  ) {
    switch format {
    case .json:
      OutputRenderer.printJSON(result)
    case .plain:
      Swift.print([result.reminderId, result.cleared ? "" : (result.assigneeLabel ?? "")].joined(separator: "\t"))
    case .quiet:
      break
    case .standard, .table:
      if result.cleared {
        Swift.print("Cleared assignment for \"\(reminder.title)\"")
      } else {
        Swift.print("Assigned \"\(reminder.title)\" to \(result.assigneeLabel ?? "participant")")
      }
    }
  }
}
