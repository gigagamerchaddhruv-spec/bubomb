import SwiftUI

/// High-fidelity vector bomb illustration with interactive spark and fuse animations.
public struct AnimatedBombView: View {
    public var size: CGFloat = 80
    public var isDetonating: Bool = false
    public var onClick: (() -> Void)? = nil

    @State private var sparkPhase: Double = 0
    @State private var hoverState: Bool = false

    public init(size: CGFloat = 80, isDetonating: Bool = false, onClick: (() -> Void)? = nil) {
        self.size = size
        self.isDetonating = isDetonating
        self.onClick = onClick
    }

    public var body: some View {
        Button(action: {
            onClick?()
        }) {
            ZStack {
                // Glow behind the bomb when detonating
                if isDetonating {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [BubombTheme.accentOrange.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: size * 0.2,
                                endRadius: size * 0.8
                            )
                        )
                        .scaleEffect(1.2)
                }

                Canvas { context, canvasSize in
                    let w = canvasSize.width
                    let h = canvasSize.height
                    let scale = min(w, h) / 100.0

                    // 1. Fuse (Curved rope)
                    var fuse = Path()
                    fuse.move(to: CGPoint(x: 50 * scale, y: 35 * scale))
                    fuse.addCurve(
                        to: CGPoint(x: 75 * scale, y: 18 * scale),
                        control1: CGPoint(x: 50 * scale, y: 20 * scale),
                        control2: CGPoint(x: 65 * scale, y: 15 * scale)
                    )
                    context.stroke(
                        fuse,
                        with: .color(Color(red: 0.65, green: 0.55, blue: 0.40)),
                        lineWidth: 4 * scale
                    )

                    // 2. Collar / Cap
                    let collarRect = CGRect(x: 42 * scale, y: 28 * scale, width: 16 * scale, height: 9 * scale)
                    let collarPath = Path(roundedRect: collarRect, cornerRadius: 2 * scale)
                    context.fill(
                        collarPath,
                        with: .linearGradient(
                            Gradient(colors: [Color(red: 0.25, green: 0.25, blue: 0.30), Color(red: 0.15, green: 0.15, blue: 0.18)]),
                            startPoint: CGPoint(x: 50 * scale, y: 28 * scale),
                            endPoint: CGPoint(x: 50 * scale, y: 37 * scale)
                        )
                    )

                    // 3. Main Bomb Sphere
                    let sphereRect = CGRect(x: 15 * scale, y: 33 * scale, width: 70 * scale, height: 70 * scale)
                    let spherePath = Path(ellipseIn: sphereRect)
                    context.fill(
                        spherePath,
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 0.28, green: 0.29, blue: 0.34),
                                Color(red: 0.14, green: 0.14, blue: 0.17),
                                Color(red: 0.08, green: 0.08, blue: 0.10)
                            ]),
                            center: CGPoint(x: 40 * scale, y: 55 * scale),
                            startRadius: 5 * scale,
                            endRadius: 38 * scale
                        )
                    )

                    // 4. Specular gloss highlight (Upper-left shine)
                    var gloss = Path()
                    gloss.addArc(
                        center: CGPoint(x: 36 * scale, y: 52 * scale),
                        radius: 24 * scale,
                        startAngle: .degrees(190),
                        endAngle: .degrees(260),
                        clockwise: false
                    )
                    context.stroke(
                        gloss,
                        with: .color(Color.white.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 3.5 * scale, lineCap: .round)
                    )

                    // 5. Mischievous cute eyes (Restrained, subtle)
                    let leftEye = Path(ellipseIn: CGRect(x: 42 * scale, y: 64 * scale, width: 4 * scale, height: 5.5 * scale))
                    let rightEye = Path(ellipseIn: CGRect(x: 54 * scale, y: 64 * scale, width: 4 * scale, height: 5.5 * scale))
                    context.fill(leftEye, with: .color(Color.white.opacity(0.85)))
                    context.fill(rightEye, with: .color(Color.white.opacity(0.85)))

                    // Eye pupils / shine
                    let leftShine = Path(ellipseIn: CGRect(x: 43.5 * scale, y: 65 * scale, width: 1.8 * scale, height: 1.8 * scale))
                    let rightShine = Path(ellipseIn: CGRect(x: 55.5 * scale, y: 65 * scale, width: 1.8 * scale, height: 1.8 * scale))
                    context.fill(leftShine, with: .color(Color.black))
                    context.fill(rightShine, with: .color(Color.black))

                    // 6. Spark at fuse tip
                    let sparkCenter = CGPoint(x: 75 * scale, y: 18 * scale)
                    let sparkRadius = (isDetonating ? 12 : 6) * scale

                    // Spark Outer Glow
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: sparkCenter.x - sparkRadius,
                            y: sparkCenter.y - sparkRadius,
                            width: sparkRadius * 2,
                            height: sparkRadius * 2
                        )),
                        with: .radialGradient(
                            Gradient(colors: [
                                BubombTheme.accentOrange,
                                BubombTheme.accentAmber.opacity(0.5),
                                Color.clear
                            ]),
                            center: sparkCenter,
                            startRadius: 1 * scale,
                            endRadius: sparkRadius
                        )
                    )

                    // Spark Core
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: sparkCenter.x - 2.5 * scale,
                            y: sparkCenter.y - 2.5 * scale,
                            width: 5 * scale,
                            height: 5 * scale
                        )),
                        with: .color(Color(red: 1.0, green: 0.95, blue: 0.4))
                    )
                }
                .frame(width: size, height: size)
            }
            .scaleEffect(hoverState ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hoverState)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            self.hoverState = isHovered
        }
    }
}
