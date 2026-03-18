import Flutter
import UIKit
import XCTest

@testable import Runner

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {
  func testExampleRunnerExists() {
    XCTAssertNotNil(UIApplication.shared.delegate)
  }
}
