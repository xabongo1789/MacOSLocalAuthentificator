import SwiftUI

struct LiquidGlassBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !reduceTransparency {
                RadialGradient(
                    colors: [
                        Color.cyan.opacity(colorScheme == .dark ? 0.18 : 0.16),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 520
                )

                RadialGradient(
                    colors: [
                        Color.mint.opacity(colorScheme == .dark ? 0.14 : 0.12),
                        .clear
                    ],
                    center: UnitPoint(x: 0.78, y: 0.18),
                    startRadius: 60,
                    endRadius: 460
                )

                RadialGradient(
                    colors: [
                        Color.pink.opacity(colorScheme == .dark ? 0.12 : 0.10),
                        .clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 60,
                    endRadius: 560
                )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.40 : 0.30)
            }
        }
    }
}

struct LiquidGlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var material: Material = .regularMaterial
    var shadowRadius: CGFloat = 18
    var shadowOpacity: Double = 0.14

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                ZStack {
                    shape
                        .fill(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : .clear)

                    if !reduceTransparency {
                        shape.fill(material)
                    }

                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.18 : 0.42),
                                    .white.opacity(colorScheme == .dark ? 0.06 : 0.18),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.28 : 0.58),
                                .white.opacity(colorScheme == .dark ? 0.08 : 0.22),
                                .black.opacity(colorScheme == .dark ? 0.34 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? shadowOpacity + 0.12 : shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.42
            )
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    var material: Material = .thinMaterial

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Capsule()
                        .fill(reduceTransparency ? Color(nsColor: .controlBackgroundColor) : .clear)

                    if !reduceTransparency {
                        Capsule().fill(material)
                    }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.14 : 0.32),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.16 : 0.42), lineWidth: 1)
            }
    }
}

enum LiquidGlassButtonProminence {
    case standard
    case prominent
    case icon
}

struct LiquidGlassButtonStyle: ButtonStyle {
    var prominence: LiquidGlassButtonProminence = .standard

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(foregroundColor(for: configuration.role))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, prominence == .icon ? 0 : 14)
            .padding(.vertical, prominence == .icon ? 0 : 8)
            .frame(width: prominence == .icon ? 34 : nil, height: prominence == .icon ? 34 : nil)
            .background {
                ZStack {
                    Capsule()
                        .fill(reduceTransparency ? Color(nsColor: .controlBackgroundColor) : .clear)

                    if !reduceTransparency {
                        Capsule().fill(prominence == .prominent ? .regularMaterial : .thinMaterial)
                    }

                    if prominence == .prominent {
                        Capsule()
                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.58 : 0.74))
                    }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.18 : 0.38),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.44), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.48)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private func foregroundColor(for role: ButtonRole?) -> Color {
        if role == .destructive {
            return .red
        }

        if prominence == .prominent {
            return .white
        }

        return .primary
    }
}

extension View {
    func liquidGlassPanel(
        cornerRadius: CGFloat = 20,
        material: Material = .regularMaterial,
        shadowRadius: CGFloat = 18,
        shadowOpacity: Double = 0.14
    ) -> some View {
        modifier(
            LiquidGlassPanelModifier(
                cornerRadius: cornerRadius,
                material: material,
                shadowRadius: shadowRadius,
                shadowOpacity: shadowOpacity
            )
        )
    }

    func liquidGlassCapsule(material: Material = .thinMaterial) -> some View {
        modifier(LiquidGlassCapsuleModifier(material: material))
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }

    static var liquidGlassProminent: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(prominence: .prominent)
    }

    static var liquidGlassIcon: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(prominence: .icon)
    }
}
