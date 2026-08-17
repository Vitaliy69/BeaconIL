import Foundation
@testable import BeaconILMath

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ name: String) {
    if condition {
        passed += 1
        print("PASS  \(name)")
    } else {
        failed += 1
        print("FAIL  \(name)")
    }
}

func approximates(_ actual: [Double], _ expected: [Double], tolerance: Double) -> Bool {
    guard actual.count == expected.count else { return false }
    return zip(actual, expected).allSatisfy { abs($0.0 - $0.1) <= tolerance }
}

let anchors2D = [[0.0, 0.0], [4.0, 0.0], [0.0, 6.0]]

// Valid inputs

expect(
    approximates(
        LMAMath().solve(
            positions: anchors2D,
            distances: [(3.0 * 3.0 + 2.5 * 2.5).squareRoot(),
                        (1.0 * 1.0 + 2.5 * 2.5).squareRoot(),
                        (3.0 * 3.0 + 3.5 * 3.5).squareRoot()]),
        [3.0, 2.5],
        tolerance: 1e-8),
    "exact 2D solution")

expect(
    approximates(
        LMAMath().solve(
            positions: [[0.0, 0.0], [4.0, 0.0], [0.0, 6.0], [4.0, 6.0]],
            distances: [3.6, 2.7, 4.5, 3.0]),
        [2.925188367664, 2.694029293817],
        tolerance: 1e-9),
    "noisy 2D solution, four anchors")

expect(
    approximates(
        LMAMath().solve(
            positions: [[1.5, 5.0, 0.5], [-4.5, -6.7, 3.0], [18.5, 12.5, 0.5], [10.5, 15.6, 2.75]],
            distances: [3.0, 4.0, 5.9, 13.1]),
        [5.135439927156, 2.047128999590, 1.810980955190],
        tolerance: 1e-9),
    "solution in three axes, four anchors")

expect(
    approximates(
        LMAMath().solve(
            positions: [[0.0, 0.0], [6.0, 0.0], [0.0, 4.0], [6.0, 4.0], [3.0, 4.0]],
            distances: [2.8, 3.4, 3.1, 4.2, 1.9]),
        [2.548075272562, 1.824575072572],
        tolerance: 1e-9),
    "matches the Go port (lmamath) on a noisy vector")

// Rejected inputs

expect(LMAMath().solve(positions: [[0.0, 0.0], [4.0, 0.0]], distances: [3.0, 2.0]).isEmpty,
      "too few anchors rejected")
expect(LMAMath().solve(positions: anchors2D, distances: [3.0, 2.0]).isEmpty,
      "count mismatch rejected")
expect(LMAMath().solve(positions: [[0.0, 0.0], [4.0, 0.0, 1.0], [0.0, 6.0]], distances: [3.0, 2.0, 4.0]).isEmpty,
      "inconsistent dimensionality rejected")
expect(LMAMath().solve(positions: anchors2D, distances: [3.5, 0.0, 4.3]).isEmpty,
      "zero distance rejected")
expect(LMAMath().solve(positions: anchors2D, distances: [3.5, -2.0, 4.3]).isEmpty,
      "negative distance rejected")
expect(LMAMath().solve(positions: anchors2D, distances: [3.5, .nan, 4.3]).isEmpty,
      "NaN distance rejected")
expect(LMAMath().solve(positions: [[0.0, 0.0], [4.0, .infinity], [0.0, 6.0]], distances: [3.5, 2.0, 4.3]).isEmpty,
      "infinite coordinate rejected")

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
