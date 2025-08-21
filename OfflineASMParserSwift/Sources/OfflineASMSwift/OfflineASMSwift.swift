import ArgumentParser

@main
struct OfflineASM: ParsableCommand {
  @Argument(help: "TODO")
  public var input: String
  @Argument(help: "TODO")
  public var offsetExtractor: String
  @Argument(help: "TODO")
  public var output: String
  @Argument(help: "TODO")
  public var arch: String
  @Option(name: .shortAndLong, help: "TODO")
  public var binary_format: String?

  public func run() throws {
    print("Generate swift: ", self.output)
  }
}
