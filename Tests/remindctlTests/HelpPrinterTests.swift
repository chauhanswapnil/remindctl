import Testing

@testable import remindctl

@MainActor
struct HelpPrinterTests {
  @Test("Root help includes commands")
  func rootHelp() {
    let specs = [
      ShowCommand.spec,
      ListCommand.spec,
      SearchCommand.spec,
      InfoCommand.spec,
      AddCommand.spec,
      AssignCommand.spec,
      StatusCommand.spec,
      AuthorizeCommand.spec,
      DoctorCommand.spec,
      ExportCommand.spec,
      LinkCommand.spec,
      OpenCommand.spec,
      CompletionCommand.spec,
    ]
    let lines = HelpPrinter.renderRoot(version: "0.0.0", rootName: "remindctl", commands: specs)
    let joined = lines.joined(separator: "\n")
    #expect(joined.contains("show"))
    #expect(joined.contains("list"))
    #expect(joined.contains("search"))
    #expect(joined.contains("info"))
    #expect(joined.contains("add"))
    #expect(joined.contains("assign"))
    #expect(joined.contains("status"))
    #expect(joined.contains("authorize"))
    #expect(joined.contains("doctor"))
    #expect(joined.contains("export"))
    #expect(joined.contains("completion"))
  }

  @Test("Assignment help describes participant and clearing options")
  func assignmentHelp() {
    let help = HelpPrinter.renderCommand(rootName: "remindctl", spec: AssignCommand.spec).joined(separator: "\n")

    #expect(help.contains("assignee"))
    #expect(help.contains("--none"))
    #expect(help.contains("private ReminderKit"))
  }

  @Test("Add and edit help include alarm, location, repeat, and URL options")
  func alarmLocationRepeatAndURLHelp() {
    let addHelp = HelpPrinter.renderCommand(rootName: "remindctl", spec: AddCommand.spec).joined(separator: "\n")
    let editHelp = HelpPrinter.renderCommand(rootName: "remindctl", spec: EditCommand.spec).joined(separator: "\n")

    #expect(addHelp.contains("--alarm"))
    #expect(addHelp.contains("--location"))
    #expect(addHelp.contains("--leaving"))
    #expect(addHelp.contains("--url"))
    #expect(addHelp.contains("--repeat"))
    #expect(editHelp.contains("--alarm"))
    #expect(editHelp.contains("--clear-alarm"))
    #expect(editHelp.contains("--url"))
    #expect(editHelp.contains("--clear-url"))
    #expect(editHelp.contains("--repeat"))
    #expect(editHelp.contains("--no-repeat"))
  }

  @Test("Common help includes exact list targeting and table output")
  func listIDAndFormatHelp() {
    let showHelp = HelpPrinter.renderCommand(rootName: "remindctl", spec: ShowCommand.spec).joined(separator: "\n")
    let addHelp = HelpPrinter.renderCommand(rootName: "remindctl", spec: AddCommand.spec).joined(separator: "\n")

    #expect(showHelp.contains("--list-id"))
    #expect(showHelp.contains("--format"))
    #expect(addHelp.contains("--list-id"))
  }
}
