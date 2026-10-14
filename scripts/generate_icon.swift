import AppKit

let size = NSSize(width: 512, height: 512)
let img = NSImage(size: size, flipped: false) { bounds in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
    
    // Background squircle / rounded rect for macOS icon
    let iconRect = NSRect(x: 32, y: 32, width: 448, height: 448)
    let bgPath = NSBezierPath(roundedRect: iconRect, xRadius: 96, yRadius: 96)
    
    // Background gradient: dark charcoal
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.20, alpha: 1.0),
                              ending: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
    gradient?.draw(in: bgPath, angle: -45)
    
    // Subtle border
    NSColor(calibratedWhite: 1.0, alpha: 0.12).setStroke()
    bgPath.lineWidth = 2
    bgPath.stroke()
    
    // Bomb fuse curve
    let fusePath = NSBezierPath()
    fusePath.move(to: NSPoint(x: 256, y: 330))
    fusePath.curve(to: NSPoint(x: 370, y: 410),
                   controlPoint1: NSPoint(x: 256, y: 410),
                   controlPoint2: NSPoint(x: 330, y: 430))
    fusePath.lineWidth = 14
    fusePath.lineCapStyle = .round
    NSColor(calibratedRed: 0.72, green: 0.60, blue: 0.44, alpha: 1.0).setStroke()
    fusePath.stroke()
    
    // Collar at top of bomb
    let collarRect = NSRect(x: 220, y: 310, width: 72, height: 32)
    let collarPath = NSBezierPath(roundedRect: collarRect, xRadius: 6, yRadius: 6)
    NSColor(calibratedRed: 0.25, green: 0.26, blue: 0.30, alpha: 1.0).setFill()
    collarPath.fill()
    
    // Bomb body
    let bodyRect = NSRect(x: 106, y: 80, width: 300, height: 300)
    let bodyPath = NSBezierPath(ovalIn: bodyRect)
    
    let bodyGradient = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.32, green: 0.34, blue: 0.40, alpha: 1.0), 0.0),
        (NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.18, alpha: 1.0), 0.6),
        (NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0), 1.0)
    )
    bodyGradient?.draw(in: bodyPath, relativeCenterPosition: NSPoint(x: -0.25, y: 0.35))
    
    // Specular shine curve
    ctx.saveGState()
    let shinePath = NSBezierPath()
    shinePath.appendArc(withCenter: NSPoint(x: 215, y: 255), radius: 105, startAngle: 110, endAngle: 175)
    shinePath.lineWidth = 12
    shinePath.lineCapStyle = .round
    NSColor(calibratedWhite: 1.0, alpha: 0.35).setStroke()
    shinePath.stroke()
    ctx.restoreGState()
    
    // Mischievous cute eyes
    let leftEye = NSBezierPath(ovalIn: NSRect(x: 220, y: 195, width: 18, height: 26))
    let rightEye = NSBezierPath(ovalIn: NSRect(x: 274, y: 195, width: 18, height: 26))
    NSColor(calibratedWhite: 0.95, alpha: 1.0).setFill()
    leftEye.fill()
    rightEye.fill()
    
    // Pupils
    let leftPupil = NSBezierPath(ovalIn: NSRect(x: 226, y: 199, width: 9, height: 11))
    let rightPupil = NSBezierPath(ovalIn: NSRect(x: 280, y: 199, width: 9, height: 11))
    NSColor(calibratedWhite: 0.05, alpha: 1.0).setFill()
    leftPupil.fill()
    rightPupil.fill()
    
    // Spark at fuse tip
    let sparkCenter = NSPoint(x: 370, y: 410)
    let sparkGlow = NSBezierPath(ovalIn: NSRect(x: sparkCenter.x - 36, y: sparkCenter.y - 36, width: 72, height: 72))
    let glowGrad = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 1.0, green: 0.5, blue: 0.0, alpha: 0.9), 0.0),
        (NSColor(calibratedRed: 1.0, green: 0.7, blue: 0.0, alpha: 0.4), 0.5),
        (NSColor.clear, 1.0)
    )
    glowGrad?.draw(in: sparkGlow, relativeCenterPosition: .zero)
    
    let sparkCore = NSBezierPath(ovalIn: NSRect(x: sparkCenter.x - 12, y: sparkCenter.y - 12, width: 24, height: 24))
    NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.3, alpha: 1.0).setFill()
    sparkCore.fill()
    
    return true
}

if let tiff = img.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff),
   let png = bitmap.representation(using: .png, properties: [:]) {
    let outURL = URL(fileURLWithPath: "/Users/macbook/bubomb/Resources/AppIcon.png")
    try? png.write(to: outURL)
    print("Generated AppIcon.png successfully!")
}
