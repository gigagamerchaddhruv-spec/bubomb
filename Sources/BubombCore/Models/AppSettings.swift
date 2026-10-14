import Foundation

public enum AnimationPreference: String, Codable, CaseIterable, Equatable, Sendable {
    case full = "Full (Sparks & Smoke)"
    case subtle = "Subtle (Sparks Only)"
    case none = "None (Reduced Motion)"
}

/// Persistent user configuration for Bubomb.
public struct AppSettings: Codable, Equatable, Sendable {
    public var activePayload: Payload?
    public var savedPayloads: [Payload]
    public var launchAtLogin: Bool
    public var startSilentlyInMenuBar: Bool
    public var animationPreference: AnimationPreference
    public var confirmDestructiveActions: Bool
    public var playCompletionFeedback: Bool
    public var recentExecutions: [ExecutionRecord]

    public static let currentVersion = "1.0.0"
    public static let buildNumber = "1"

    public init(
        activePayload: Payload? = nil,
        savedPayloads: [Payload] = [],
        launchAtLogin: Bool = false,
        startSilentlyInMenuBar: Bool = true,
        animationPreference: AnimationPreference = .full,
        confirmDestructiveActions: Bool = true,
        playCompletionFeedback: Bool = true,
        recentExecutions: [ExecutionRecord] = []
    ) {
        self.activePayload = activePayload
        self.savedPayloads = savedPayloads
        self.launchAtLogin = launchAtLogin
        self.startSilentlyInMenuBar = startSilentlyInMenuBar
        self.animationPreference = animationPreference
        self.confirmDestructiveActions = confirmDestructiveActions
        self.playCompletionFeedback = playCompletionFeedback
        self.recentExecutions = recentExecutions
    }

    public static var defaultSettings: AppSettings {
        AppSettings(
            activePayload: nil,
            savedPayloads: [],
            launchAtLogin: false,
            startSilentlyInMenuBar: true,
            animationPreference: .full,
            confirmDestructiveActions: true,
            playCompletionFeedback: true,
            recentExecutions: []
        )
    }
}
