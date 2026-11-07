import Foundation

nonisolated enum ProcessRunner {
  struct Result: Equatable, Sendable {
    let status: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool {
      status == 0
    }
  }

  @discardableResult
  static func run(_ executable: String, _ arguments: [String] = []) -> Result {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    do {
      try process.run()
    } catch {
      return Result(status: -1, stdout: "", stderr: error.localizedDescription)
    }

    var outData = Data()
    var errData = Data()
    let group = DispatchGroup()

    group.enter()
    // Readers must not run at a lower QoS than the caller blocked in group.wait()
    // below: callers include userInitiated queues, and a .utility reader under a
    // userInitiated waiter is a priority inversion (Instruments hang-risk report).
    DispatchQueue.global(qos: .userInitiated).async {
      outData = outPipe.fileHandleForReading.readDataToEndOfFile()
      group.leave()
    }

    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
      errData = errPipe.fileHandleForReading.readDataToEndOfFile()
      group.leave()
    }

    group.wait()
    process.waitUntilExit()

    return Result(
      status: process.terminationStatus,
      stdout: String(decoding: outData, as: UTF8.self),
      stderr: String(decoding: errData, as: UTF8.self)
    )
  }

  @discardableResult
  static func runQuietly(_ executable: String, _ arguments: [String] = []) -> Bool {
    run(executable, arguments).succeeded
  }
}
