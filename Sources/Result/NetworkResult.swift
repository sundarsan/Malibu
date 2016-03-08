import Foundation
import When

public class NetworkResult: Equatable {

  public let data: NSData
  public let request: NSURLRequest
  public let response: NSHTTPURLResponse
  
  public init(data: NSData, request: NSURLRequest, response: NSHTTPURLResponse) {
    self.data = data
    self.request = request
    self.response = response
  }
}

// MARK: - Equatable

public func ==(lhs: NetworkResult, rhs: NetworkResult) -> Bool {
  return lhs.data == rhs.data
    && lhs.request == rhs.request
    && lhs.response == rhs.response
}
