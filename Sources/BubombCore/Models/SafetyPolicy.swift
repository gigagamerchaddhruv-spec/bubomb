import Foundation

/// Safety evaluation for configured commands and payloads.
public struct SafetyPolicy: Sendable {
    public enum RiskLevel: Equatable, Sendable {
        case safe
        case suspicious(reason: String)
        case destructive(reason: String)
        
        public var isDestructive: Bool {
            if case .destructive = self { return true }
            return false
        }
        
        public var warningMessage: String? {
            switch self {
            case .safe:
                return nil
            case .suspicious(let reason):
                return reason
            case .destructive(let reason):
                return reason
            }
        }
    }

    /// Evaluates a command string for known destructive or dangerous patterns.
    public static func evaluate(command: String) -> RiskLevel {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .safe }

        // Destructive patterns: root/home recursive deletion, disk formatting, raw block devices, fork bombs
        let destructivePatterns: [(pattern: String, reason: String)] = [
            (#"\brm\s+-[a-zA-Z]*[rR][a-zA-Z]*[fF][a-zA-Z]*\s+(/|~|\$HOME|\.\./|\*)(?:\s|$|[;&|])"#, "Recursive force removal of system or root/home directory"),
            (#"\brm\s+-[a-zA-Z]*[fF][a-zA-Z]*[rR][a-zA-Z]*\s+(/|~|\$HOME|\.\./|\*)(?:\s|$|[;&|])"#, "Recursive force removal of system or root/home directory"),
            (#"\bmkfs\b"#, "Filesystem formatting command detected"),
            (#"\bdd\s+if=.*of=/dev/(r?disk|sd)"#, "Raw disk overwrite command (dd) detected"),
            (#">\s*/dev/(r?disk|sd)"#, "Direct write redirection to raw disk device"),
            (#"\bchmod\s+-[a-zA-Z]*R[a-zA-Z]*\s+777\s+/"#, "Dangerous root directory permission change"),
            (#":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:"#, "Fork bomb pattern detected"),
            (#"\bdiskutil\s+(eraseDisk|partitionDisk|unmountDisk)\b"#, "Disk erasure or partition command detected")
        ]

        for (pattern, reason) in destructivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return .destructive(reason: reason)
                }
            }
        }

        // Suspicious patterns: sudo, disabling gatekeeper/SIP, curl-pipe-to-sh
        let suspiciousPatterns: [(pattern: String, reason: String)] = [
            (#"\bsudo\b"#, "Command requests superuser privileges (sudo)"),
            (#"\bspctl\s+--master-disable\b"#, "Attempt to disable macOS Gatekeeper"),
            (#"\bcsrutil\s+disable\b"#, "Attempt to disable macOS System Integrity Protection (SIP)"),
            (#"(curl|wget)\s+.*\|\s*(sh|bash|zsh)"#, "Piping remote network script directly into shell")
        ]

        for (pattern, reason) in suspiciousPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return .suspicious(reason: reason)
                }
            }
        }

        return .safe
    }

    /// Determines if an execution must require explicit user confirmation.
    public static func requiresConfirmation(command: String, userSettingAlwaysConfirmDestructive: Bool) -> (required: Bool, reason: String?) {
        let risk = evaluate(command: command)
        switch risk {
        case .destructive(let reason):
            return (true, "⚠️ Potentially destructive operation detected: \(reason)")
        case .suspicious(let reason):
            if userSettingAlwaysConfirmDestructive {
                return (true, "Notice: \(reason)")
            }
            return (false, reason)
        case .safe:
            return (false, nil)
        }
    }
}
