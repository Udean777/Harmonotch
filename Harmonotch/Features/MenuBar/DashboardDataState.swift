import Foundation

enum DashboardDataState<Value> {
  case idle
  case loading
  case loaded(Value, refreshedAt: Date)
  case empty
  case permissionRequired
  case permissionDenied
  case unavailable(String)
  case failed(String)
}

extension DashboardDataState: Equatable where Value: Equatable {}
