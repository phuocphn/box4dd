import Foundation
import Testing
import ShelfCore

struct ShakeDetectorTests {
    @Test func quickLeftRightShakeWhileDraggingIsAShake() {
        var detector = ShakeDetector()

        // 5 strokes of 100 pt, 80 ms each: 4 direction changes in 0.4 s.
        let shakes = detector.feed(path(strokes: [100, -100, 100, -100, 100], strokeDuration: 0.08))

        #expect(shakes == 1)
    }

    @Test func longStraightDragIsNotAShake() {
        var detector = ShakeDetector()

        // A fast 1200 pt drag across the screen, then back up a little to drop.
        let shakes = detector.feed(path(strokes: [600, 600, -40], strokeDuration: 0.1))

        #expect(shakes == 0)
    }

    @Test func slowWiggleIsNotAShake() {
        var detector = ShakeDetector()

        // Same 100 pt strokes as a Shake, but 300 ms each: direction changes 0.3 s apart.
        let shakes = detector.feed(path(strokes: [100, -100, 100, -100, 100, -100], strokeDuration: 0.3))

        #expect(shakes == 0)
    }

    @Test func shakingWithoutADragIsNotAShake() {
        var detector = ShakeDetector()

        let shakes = detector.feed(path(strokes: [100, -100, 100, -100, 100], strokeDuration: 0.08), dragInProgress: false)

        #expect(shakes == 0)
    }

    @Test func higherSensitivityCountsASmallerShake() {
        // A gentle Shake: 30 pt strokes, 60 ms each.
        let gentleShake = path(strokes: [30, -30, 30, -30, 30], strokeDuration: 0.06)
        var normal = ShakeDetector()
        var sensitive = ShakeDetector(sensitivity: 1)

        #expect(normal.feed(gentleShake) == 0)
        #expect(sensitive.feed(gentleShake) == 1)
    }

    @Test func lowerSensitivityNeedsABiggerShake() {
        let shake = path(strokes: [60, -60, 60, -60, 60], strokeDuration: 0.08)
        var normal = ShakeDetector()
        var dull = ShakeDetector(sensitivity: 0)

        #expect(normal.feed(shake) == 1)
        #expect(dull.feed(shake) == 0)
    }

    @Test func shakeInAnExcludedAppIsIgnored() {
        let shakeInFigma = path(strokes: [100, -100, 100, -100, 100], strokeDuration: 0.08)
        let shakeInFinder = path(strokes: [100, -100, 100, -100, 100], strokeDuration: 0.08, startingAt: 2)
        var detector = ShakeDetector(excludedApps: ["com.figma.Desktop"])

        #expect(detector.feed(shakeInFigma, frontmostApp: "com.figma.Desktop") == 0)
        #expect(detector.feed(shakeInFinder, frontmostApp: "com.apple.finder") == 1)
    }

    @Test func keepingOnShakingCountsAsOneShake() {
        var detector = ShakeDetector()

        // About 1.3 s of non-stop shaking: 15 direction changes, 80 ms apart.
        let shakes = detector.feed(path(strokes: Array(repeating: [100, -100], count: 8).flatMap { $0 }, strokeDuration: 0.08))

        #expect(shakes == 1)
    }

    @Test func shakingAgainAfterAPauseIsANewShake() {
        var detector = ShakeDetector()
        let firstShake = path(strokes: [100, -100, 100, -100, 100, -100], strokeDuration: 0.08)
        // Same drag, starting again 1.5 s after the first Shake ended, from where it ended.
        let secondShake = path(strokes: [100, -100, 100, -100, 100, -100], strokeDuration: 0.08, startingAt: 2)

        #expect(detector.feed(firstShake) == 1)
        #expect(detector.feed(secondShake) == 1)
    }
}

/// A hand-built pointer path sampled at 100 Hz: starts at (500, 500) and moves horizontally by each stroke in turn.
private func path(strokes: [Double], strokeDuration: TimeInterval, startingAt start: TimeInterval = 0) -> [PointerSample] {
    var samples = [PointerSample(position: CGPoint(x: 500, y: 500), time: start)]
    var x = 500.0, time = start
    let steps = Int((strokeDuration * 100).rounded())
    for stroke in strokes {
        for _ in 0..<steps {
            x += stroke / Double(steps)
            time += strokeDuration / Double(steps)
            samples.append(PointerSample(position: CGPoint(x: x, y: 500), time: time))
        }
    }
    return samples
}

private extension ShakeDetector {
    /// Feeds a whole path and counts how many Shakes the detector reported.
    mutating func feed(_ samples: [PointerSample], dragInProgress: Bool = true, frontmostApp: String? = "com.apple.finder") -> Int {
        var shakes = 0
        for sample in samples where pointerMoved(sample, dragInProgress: dragInProgress, frontmostApp: frontmostApp) {
            shakes += 1
        }
        return shakes
    }
}
