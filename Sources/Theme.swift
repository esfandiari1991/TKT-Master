import SwiftUI
import AppKit

// MARK: - Palette (inspired by the orange "TKT Course" book cover)
enum Theme {
    static let orange     = Color(red: 0.90, green: 0.39, blue: 0.13)   // #E5631F
    static let orangeDeep = Color(red: 0.78, green: 0.27, blue: 0.09)   // #C7461A
    static let amber      = Color(red: 0.95, green: 0.64, blue: 0.22)   // #F2A338
    static let ink        = Color(red: 0.18, green: 0.12, blue: 0.07)
    static let accent     = orange

    static func moduleColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.90, green: 0.39, blue: 0.13)   // orange
        case 2: return Color(red: 0.84, green: 0.54, blue: 0.11)   // amber/gold
        case 3: return Color(red: 0.74, green: 0.24, blue: 0.18)   // warm red
        default: return orange
        }
    }
    static func moduleGradient(_ n: Int) -> LinearGradient {
        let c = moduleColor(n)
        return LinearGradient(colors: [c, c.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.93, green: 0.45, blue: 0.16), Color(red: 0.83, green: 0.30, blue: 0.12)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Fonts (academic, legible — never tiny)
extension Font {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Paper background
struct PaperBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Group {
            if scheme == .dark {
                LinearGradient(colors: [Color(red: 0.13, green: 0.11, blue: 0.09),
                                        Color(red: 0.09, green: 0.08, blue: 0.07)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(colors: [Color(red: 1.00, green: 0.975, blue: 0.94),
                                        Color(red: 0.99, green: 0.93, blue: 0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.orange.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Theme.orange.opacity(scheme == .dark ? 0.0 : 0.10), radius: 14, x: 0, y: 7)
    }
}
extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardModifier(padding: padding)) }
}

// MARK: - Persian support text (fully right-to-left, separated from the English above)
//
// Robust RTL: we prepend a Right-to-Left Mark (U+200F) so the paragraph's base
// direction is RTL (correct ordering of mixed Latin words / numbers like "TKT" or
// "۱، ۲ و ۳"), keep the surrounding layout LTR, and right-align with `.trailing`.
// A thin rule above visually separates the Persian block from the English text.
struct PersianText: View {
    let text: String
    var font: Font = .callout
    var color: Color = .secondary
    var body: some View {
        Text("\u{200F}" + text)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(5)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .textSelection(.enabled)
    }
}

struct FaText: View {
    let text: String
    var font: Font = .callout
    var showDivider: Bool = true
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if showDivider {
                Divider().overlay(Theme.orange.opacity(0.22))
            }
            PersianText(text: text, font: font)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - Entrance animation (staggered fade + rise)
struct AppearModifier: ViewModifier {
    let delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .onAppear { withAnimation(.easeOut(duration: 0.55).delay(delay)) { shown = true } }
    }
}
extension View {
    func appear(_ delay: Double = 0) -> some View { modifier(AppearModifier(delay: delay)) }
}

// MARK: - Hover lift (desktop)
struct HoverLift: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.012 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: hovering)
            .onHover { hovering = $0 }
    }
}
extension View {
    func hoverLift() -> some View { modifier(HoverLift()) }
}

// MARK: - Animated progress ring
struct RingProgress: View {
    let value: Double
    let color: Color
    var size: CGFloat = 60
    @State private var animated: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.16), lineWidth: 7)
            Circle().trim(from: 0, to: animated)
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { animated = value } }
    }
}

// MARK: - Difficulty badge
struct DifficultyBadge: View {
    let level: Int
    var label: String { level <= 1 ? "Easy" : (level == 2 ? "Medium" : "Hard") }
    var color: Color { level <= 1 ? Color(red: 0.20, green: 0.62, blue: 0.36) : (level == 2 ? Theme.amber : Theme.orangeDeep) }
    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

// MARK: - Gentle floating motif (academic)
struct FloatingMotif: View {
    var symbol: String = "graduationcap.fill"
    @State private var up = false
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .offset(y: up ? -6 : 6)
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: up)
            .onAppear { up = true }
    }
}

// MARK: - Hover highlight (background tint on hover)
struct HoverHighlight: ViewModifier {
    var color: Color = Theme.orange
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? color.opacity(0.10) : Color.clear))
            .animation(.easeOut(duration: 0.18), value: hovering)
            .onHover { hovering = $0 }
    }
}
extension View {
    func hoverHighlight(_ color: Color = Theme.orange) -> some View { modifier(HoverHighlight(color: color)) }
}

// MARK: - Interactive key-term chip (hover scales + shows meaning tooltip)
struct TermChip: View {
    let term: String
    let definition: String
    @State private var hover = false
    var body: some View {
        Text(term)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Theme.orange.opacity(hover ? 0.24 : 0.12)))
            .overlay(Capsule().stroke(Theme.orange.opacity(hover ? 0.5 : 0.0), lineWidth: 1))
            .foregroundStyle(Theme.orangeDeep)
            .scaleEffect(hover ? 1.08 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hover)
            .onHover { hover = $0 }
            .help(definition.isEmpty ? term : definition)
    }
}
