import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// State for the menu bar icon rendering.
public enum MenuBarIconState: Equatable, Sendable {
    case idle
    case unconfigured
    case burning(frame: Int)
    case exploded(frame: Int)
    case failed
}

/// Renders native NSImages for menu bar status item and app icons.
public final class BombIconRenderer: @unchecked Sendable {
    public static let shared = BombIconRenderer()

    #if canImport(AppKit)
    /// Creates an NSImage sized for the macOS menu bar (18x18 pt @ 2x).
    public static func menuBarImage(state: MenuBarIconState) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            let ctx = NSGraphicsContext.current?.cgContext
            
            switch state {
            case .idle:
                drawIdleMenuBarBomb(in: bounds, context: ctx, template: true)
            case .unconfigured:
                drawIdleMenuBarBomb(in: bounds, context: ctx, template: true, unconfiguredBadge: true)
            case .burning(let frame):
                drawBurningMenuBarBomb(in: bounds, context: ctx, frame: frame)
            case .exploded(let frame):
                drawExplodingMenuBarBomb(in: bounds, context: ctx, frame: frame)
            case .failed:
                drawFailedMenuBarBomb(in: bounds, context: ctx)
            }
            return true
        }

        if case .idle = state {
            image.isTemplate = true
        } else if case .unconfigured = state {
            image.isTemplate = true
        } else {
            image.isTemplate = false
        }
        return image
    }

    // MARK: - Menu Bar Drawing Routines

    private static func drawIdleMenuBarBomb(in bounds: NSRect, context: CGContext?, template: Bool, unconfiguredBadge: Bool = false) {
        guard let ctx = context else { return }
        ctx.saveGState()

        let baseColor = template ? NSColor.black : NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        baseColor.setFill()
        baseColor.setStroke()

        // 1. Bomb Body (Circle)
        // Center at (9, 7.5), radius 5.5
        let bodyRect = NSRect(x: 3.5, y: 1.5, width: 11, height: 11)
        let bodyPath = NSBezierPath(ovalIn: bodyRect)
        bodyPath.fill()

        // 2. Collar / Cap at top of bomb
        let collarRect = NSRect(x: 7.0, y: 11.5, width: 4.0, height: 2.0)
        let collarPath = NSBezierPath(roundedRect: collarRect, xRadius: 0.5, yRadius: 0.5)
        collarPath.fill()

        // 3. Fuse curve
        let fusePath = NSBezierPath()
        fusePath.move(to: NSPoint(x: 9.0, y: 13.0))
        fusePath.curve(to: NSPoint(x: 13.0, y: 15.0),
                       controlPoint1: NSPoint(x: 9.0, y: 15.0),
                       controlPoint2: NSPoint(x: 11.5, y: 16.0))
        fusePath.lineWidth = 1.2
        fusePath.lineCapStyle = .round
        fusePath.stroke()

        // 4. Spark at fuse tip
        if !template {
            let sparkColor = NSColor(calibratedRed: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
            sparkColor.setFill()
            let sparkRect = NSRect(x: 12.5, y: 14.5, width: 2.5, height: 2.5)
            NSBezierPath(ovalIn: sparkRect).fill()
        }

        // 5. If unconfigured, draw small hollow dot or subtle badge
        if unconfiguredBadge {
            let dotRect = NSRect(x: 8.0, y: 6.0, width: 2.0, height: 2.0)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }

        ctx.restoreGState()
    }

    private static func drawBurningMenuBarBomb(in bounds: NSRect, context: CGContext?, frame: Int) {
        guard let ctx = context else { return }
        ctx.saveGState()

        // Dark charcoal bomb body
        let bodyColor = NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.23, alpha: 1.0)
        bodyColor.setFill()
        let bodyRect = NSRect(x: 3.5, y: 1.5, width: 11, height: 11)
        NSBezierPath(ovalIn: bodyRect).fill()

        // Collar
        let collarRect = NSRect(x: 7.0, y: 11.5, width: 4.0, height: 2.0)
        NSBezierPath(roundedRect: collarRect, xRadius: 0.5, yRadius: 0.5).fill()

        // Fuse
        let fuseColor = NSColor(calibratedRed: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
        fuseColor.setStroke()
        let fusePath = NSBezierPath()
        fusePath.move(to: NSPoint(x: 9.0, y: 13.0))
        fusePath.curve(to: NSPoint(x: 12.5, y: 14.5),
                       controlPoint1: NSPoint(x: 9.0, y: 14.5),
                       controlPoint2: NSPoint(x: 11.0, y: 15.5))
        fusePath.lineWidth = 1.2
        fusePath.stroke()

        // Burning spark: oscillates in size and color based on frame
        let isLarge = (frame % 2 == 0)
        let sparkCenter = NSPoint(x: 13.0, y: 15.0)
        let sparkRadius: CGFloat = isLarge ? 2.8 : 1.8

        // Outer warm glow
        let glowColor = NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.0, alpha: 0.8)
        glowColor.setFill()
        let glowRect = NSRect(x: sparkCenter.x - sparkRadius, y: sparkCenter.y - sparkRadius, width: sparkRadius * 2, height: sparkRadius * 2)
        NSBezierPath(ovalIn: glowRect).fill()

        // Inner bright spark
        let coreColor = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.2, alpha: 1.0)
        coreColor.setFill()
        let coreRect = NSRect(x: sparkCenter.x - 1.0, y: sparkCenter.y - 1.0, width: 2.0, height: 2.0)
        NSBezierPath(ovalIn: coreRect).fill()

        ctx.restoreGState()
    }

    private static func drawExplodingMenuBarBomb(in bounds: NSRect, context: CGContext?, frame: Int) {
        guard let ctx = context else { return }
        ctx.saveGState()

        // Starburst explosion effect
        let center = NSPoint(x: 9.0, y: 9.0)
        let burstColor = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.05, alpha: 1.0)
        burstColor.setFill()
        burstColor.setStroke()

        // Draw radial burst rays
        let rayCount = 8
        let outerR: CGFloat = min(8.5, 5.0 + CGFloat(frame) * 1.5)
        let innerR: CGFloat = max(2.0, 3.5 - CGFloat(frame) * 0.5)

        let starPath = NSBezierPath()
        for i in 0..<(rayCount * 2) {
            let angle = (CGFloat(i) * CGFloat.pi / CGFloat(rayCount)) + (CGFloat(frame) * 0.2)
            let radius = (i % 2 == 0) ? outerR : innerR
            let pt = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if i == 0 {
                starPath.move(to: pt)
            } else {
                starPath.line(to: pt)
            }
        }
        starPath.close()
        starPath.fill()

        // Bright yellow core
        let coreColor = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.4, alpha: 1.0)
        coreColor.setFill()
        let coreRect = NSRect(x: center.x - 2.5, y: center.y - 2.5, width: 5.0, height: 5.0)
        NSBezierPath(ovalIn: coreRect).fill()

        ctx.restoreGState()
    }

    private static func drawFailedMenuBarBomb(in bounds: NSRect, context: CGContext?, template: Bool = false) {
        guard let ctx = context else { return }
        ctx.saveGState()

        // Bomb body in muted charcoal
        let bodyColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)
        bodyColor.setFill()
        let bodyRect = NSRect(x: 3.5, y: 1.5, width: 11, height: 11)
        NSBezierPath(ovalIn: bodyRect).fill()

        // Collar
        let collarRect = NSRect(x: 7.0, y: 11.5, width: 4.0, height: 2.0)
        NSBezierPath(roundedRect: collarRect, xRadius: 0.5, yRadius: 0.5).fill()

        // Small red warning indicator badge on upper right
        let redBadge = NSColor(calibratedRed: 0.95, green: 0.25, blue: 0.25, alpha: 1.0)
        redBadge.setFill()
        let badgeRect = NSRect(x: 12.0, y: 12.0, width: 3.5, height: 3.5)
        NSBezierPath(ovalIn: badgeRect).fill()

        ctx.restoreGState()
    }
    #endif
}
