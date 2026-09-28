import Foundation

/// Where the pointer was, and when (in seconds, from any fixed starting point).
public struct PointerSample: Sendable {
    public var position: CGPoint
    public var time: TimeInterval

    public init(position: CGPoint, time: TimeInterval) {
        self.position = position
        self.time = time
    }
}

/// Watches the pointer and tells when the user made a Shake: quick left-right direction changes
/// while dragging something.
public struct ShakeDetector: Sendable {
    private static let window: TimeInterval = 0.5
    private static let directionChangesNeeded = 3

    /// How easily a Shake counts, from 0 (needs wide strokes) to 1 (small strokes are enough).
    public var sensitivity: Double
    /// Bundle identifiers of the Excluded Apps: a Shake while one of them is in front is ignored.
    public var excludedApps: Set<String>

    /// -1 moving left, +1 moving right, 0 not decided yet.
    private var direction: CGFloat = 0
    /// The farthest point of the current stroke (or the start, before the first stroke).
    private var turningX: CGFloat?
    /// Times of the recent direction changes that may still add up to a Shake.
    private var directionChanges: [TimeInterval] = []
    private var lastDirectionChange: TimeInterval?
    /// After a Shake, the same shaking keeps going until the pointer stops changing direction for a while.
    private var shakeInProgress = false

    public init(sensitivity: Double = 0.5, excludedApps: Set<String> = []) {
        self.sensitivity = sensitivity
        self.excludedApps = excludedApps
    }

    /// How far the pointer must travel one way before a turn counts as a direction change.
    private var minimumStroke: CGFloat {
        90 - 70 * min(max(sensitivity, 0), 1)
    }

    /// Feeds the next pointer position. Returns true when this sample completes a Shake.
    public mutating func pointerMoved(_ sample: PointerSample, dragInProgress: Bool, frontmostApp: String?) -> Bool {
        guard dragInProgress, !excludedApps.contains(frontmostApp ?? "") else {
            self = ShakeDetector(sensitivity: sensitivity, excludedApps: excludedApps)
            return false
        }
        let x = sample.position.x
        guard let turning = turningX else {
            turningX = x
            return false
        }
        if direction == 0 {
            if abs(x - turning) >= minimumStroke {
                direction = x > turning ? 1 : -1
                turningX = x
            }
            return false
        }
        if (x - turning) * direction > 0 {
            turningX = x
            return false
        }
        guard abs(x - turning) >= minimumStroke else { return false }
        direction = -direction
        turningX = x
        let previousChange = lastDirectionChange
        lastDirectionChange = sample.time
        if shakeInProgress, let previousChange, sample.time - previousChange <= Self.window {
            return false
        }
        shakeInProgress = false
        directionChanges.append(sample.time)
        directionChanges.removeAll { sample.time - $0 > Self.window }
        guard directionChanges.count >= Self.directionChangesNeeded else { return false }
        directionChanges.removeAll()
        shakeInProgress = true
        return true
    }
}
