import Foundation

enum ProcessActivityError: Error, Equatable {
  /// No application process could be read at all.
  case noReadableProcesses
  case sampleFailed
}
