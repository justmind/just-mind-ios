import SwiftUI

enum JMColor {
    static let background        = Color("BrandBackground")
    static let primary           = Color("BrandPrimary")
    static let secondary         = Color("BrandSecondary")
    static let surface           = Color("BrandSurface")
    static let surfaceElevated   = Color("BrandSurfaceElevated")
    static let textPrimary       = Color("BrandTextPrimary")
    static let textSecondary     = Color("BrandTextSecondary")
    static let divider           = Color("BrandDivider")
    static let success           = Color("BrandSuccess")
    static let warning           = Color("BrandWarning")
}

/// Typography in the spirit of Ive: subtraction, restraint, type as the primary
/// interface element. Display sizes are large but light-weight; body type is
/// regular and not crowded by ornamentation. Tracking is slightly tightened on
/// large display sizes to feel considered, not casual.
enum JMFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let heroNumber = display(64, weight: .ultraLight)
    static let display    = display(40, weight: .light)
    static let largeTitle = display(34, weight: .light)
    static let title      = display(26, weight: .regular)
    static let headline   = display(20, weight: .medium)
    static let blogTitle  = display(20, weight: .bold)
    static let body       = text(17)
    static let bodyEmph   = text(17, weight: .medium)
    static let callout    = text(15)
    static let footnote   = text(13)
    static let caption    = text(12)
    static let micro      = text(11, weight: .medium)

    /// 32pt / 700. Used for the dominant home-screen greeting — meant to be
    /// the loudest typographic element on the screen, by intention.
    static let greeting   = display(32, weight: .bold)

    /// 12pt / 500, uppercase, tracked. Used for "TODAY", "QUICK ACTIONS",
    /// "SETTINGS" — small, quiet, considered.
    static let sectionLabel = text(12, weight: .medium)
}

extension View {
    /// Subtle negative-letter-spacing applied to display-sized text so big
    /// numbers and titles read as deliberate rather than loose.
    func jmDisplayTracking() -> some View {
        self.tracking(-0.4)
    }
}

enum JMRadius {
    static let card: CGFloat = 18
    static let chip: CGFloat = 18
    static let button: CGFloat = 14
    static let inset: CGFloat = 12
}

enum JMSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 36
    static let xxxl: CGFloat = 48

    /// 20pt — minimum vertical card padding (per design spec, "every pixel
    /// should earn its place — give content breathing room").
    static let cardV: CGFloat = 20
    /// 14pt — gap between Home-screen cards.
    static let homeCardGap: CGFloat = 14
    /// 28pt — space between the home greeting and the first card below.
    static let greetingTrailing: CGFloat = 28
}

/// True 0.5pt rule, regardless of scale. Used in lieu of shadows for grouping.
struct JMHairline: View {
    static let width: CGFloat = 0.5
    var body: some View {
        Rectangle()
            .fill(JMColor.divider)
            .frame(height: Self.width)
    }
}

/// A quiet, content-deferential surface: no shadow, just a hairline border
/// against the background. The Ive-leaning default for grouping content.
/// Vertical padding defaults to 20pt — the design spec's minimum for cards
/// during vulnerable-moment use.
struct JMQuietCardStyle: ViewModifier {
    var horizontal: CGFloat = JMSpacing.l
    var vertical: CGFloat = JMSpacing.cardV
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(JMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                    .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
            )
    }
}

/// A second, more elevated surface — used sparingly, e.g. for a single
/// item that genuinely deserves emphasis (sticky CTAs, lock overlays).
/// Even here the shadow is intentionally faint.
struct JMCardStyle: ViewModifier {
    var elevated: Bool
    var horizontal: CGFloat = JMSpacing.l
    var vertical: CGFloat = JMSpacing.cardV
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(elevated ? JMColor.surfaceElevated : JMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                    .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
            )
            .shadow(color: .black.opacity(elevated ? 0.05 : 0), radius: elevated ? 14 : 0, y: elevated ? 6 : 0)
    }
}

extension View {
    func jmCard(elevated: Bool = false, horizontal: CGFloat = JMSpacing.l, vertical: CGFloat = JMSpacing.cardV) -> some View {
        modifier(JMCardStyle(elevated: elevated, horizontal: horizontal, vertical: vertical))
    }
    func jmQuietCard(horizontal: CGFloat = JMSpacing.l, vertical: CGFloat = JMSpacing.cardV) -> some View {
        modifier(JMQuietCardStyle(horizontal: horizontal, vertical: vertical))
    }
    /// Convenience: when a card needs zero internal padding (used by grouped
    /// rows that supply their own padding via row insets).
    func jmQuietCardFlush() -> some View {
        modifier(JMQuietCardStyle(horizontal: 0, vertical: 0))
    }
}

struct JMPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(JMFont.bodyEmph)
            .tracking(0.1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(JMColor.primary.opacity(configuration.isPressed ? 0.85 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: JMRadius.button, style: .continuous))
    }
}

/// Borderless ghost button — the secondary action stays out of the way.
struct JMGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(JMFont.bodyEmph)
            .foregroundStyle(JMColor.primary.opacity(configuration.isPressed ? 0.6 : 1.0))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
    }
}

/// Hairline-outlined secondary button. Used when there's a real visual peer
/// to the primary action and we need them to feel balanced.
struct JMOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(JMFont.bodyEmph)
            .foregroundStyle(JMColor.textPrimary.opacity(configuration.isPressed ? 0.6 : 1.0))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: JMRadius.button, style: .continuous)
                    .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
            )
    }
}

extension ButtonStyle where Self == JMPrimaryButtonStyle {
    static var jmPrimary: JMPrimaryButtonStyle { JMPrimaryButtonStyle() }
}
extension ButtonStyle where Self == JMGhostButtonStyle {
    static var jmGhost: JMGhostButtonStyle { JMGhostButtonStyle() }
}
extension ButtonStyle where Self == JMOutlineButtonStyle {
    static var jmOutline: JMOutlineButtonStyle { JMOutlineButtonStyle() }
}

/// Backwards-compat alias: prior code used `.jmSecondary` to mean
/// "the quieter peer of jmPrimary". Map it to the new outline style.
struct JMSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        JMOutlineButtonStyle().makeBody(configuration: configuration)
    }
}
extension ButtonStyle where Self == JMSecondaryButtonStyle {
    static var jmSecondary: JMSecondaryButtonStyle { JMSecondaryButtonStyle() }
}
