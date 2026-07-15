import SwiftUI
import AinkradAppKit

/// Shared gaming-HUD styling for Leyline, mirroring the host's OverlayChrome /
/// Git Mage vocabulary but synthesized from the 7 `HostThemeTokens` colors only
/// (borders/glows are opacity + gradient derivations of the accents).
enum LeylineHUD {
    static let rowRadius: CGFloat = 9

    /// A horizontal glow hairline used INSTEAD of separator lines.
    static func glowRule(_ t: HostThemeTokens) -> some View {
        LinearGradient(colors: [.clear, t.accentSecondary.opacity(0.35), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
    }

    /// The dark, bordered surface a sheet's content sits on so it reads as a HUD
    /// panel rather than a stock macOS sheet.
    static func sheetBackground(_ t: HostThemeTokens) -> some View {
        ZStack {
            t.background
            LinearGradient(colors: [t.accentPrimary.opacity(0.06), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }
}

/// Glowing section-header tick + kerned monospace caps title.
struct HudTitle: View {
    let text: String
    let tokens: HostThemeTokens
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1).fill(tokens.accentSecondary)
                .frame(width: 3, height: 14)
                .shadow(color: tokens.accentSecondary.opacity(0.8), radius: 4)
            Text(text.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced)).kerning(2)
                .foregroundStyle(tokens.foreground.opacity(0.9))
        }
    }
}

/// A circular HUD icon button — `surfaceElevated` fill + accent rim that lifts
/// on hover. Matches Git Mage's `RowIconButton`.
struct HudIconButton: View {
    let systemName: String
    let help: String
    let tokens: HostThemeTokens
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tokens.foreground.opacity(hovering ? 1 : 0.7))
                .frame(width: 26, height: 26)
                .background(Circle().fill(tokens.surfaceElevated.opacity(hovering ? 0.95 : 0.55)))
                .overlay(Circle().strokeBorder(tokens.accentPrimary.opacity(hovering ? 0.5 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovering = h } }
    }
}

/// The primary Connect action — an accent-filled bolt chip with glassy top
/// gloss, gradient rim, and a neon glow that intensifies on hover.
struct ConnectChip: View {
    let tokens: HostThemeTokens
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                Text("Connect").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [tokens.accentPrimary.opacity(0.92), tokens.accentPrimary],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                                 startPoint: .top, endPoint: .center))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tokens.accentSecondary.opacity(hovering ? 0.85 : 0.5), lineWidth: 1)
                    )
            )
            .shadow(color: tokens.accentPrimary.opacity(hovering ? 0.55 : 0.35), radius: hovering ? 12 : 8)
        }
        .buttonStyle(.plain)
        .help("Connect (opens Terminal)")
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovering = h } }
    }
}

enum HudButtonKind { case primary, secondary, destructive }

/// Text HUD button mirroring Git Mage's `hudButtonSurface` (gradient fill for
/// primary, glassy top gloss, gradient rim, accent glow on hover).
struct HudButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: HudButtonKind = .secondary
    var disabled = false
    let tokens: HostThemeTokens
    let action: () -> Void
    @State private var hovering = false

    private var accent: Color {
        switch kind {
        case .primary: return tokens.accentPrimary
        case .secondary: return tokens.accentSecondary
        case .destructive: return tokens.accentTertiary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .bold)) }
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(kind == .primary ? Color.white : tokens.foreground.opacity(0.9))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(fill)
            .shadow(color: accent.opacity(hovering ? 0.5 : (kind == .primary ? 0.3 : 0.12)),
                    radius: hovering ? 11 : 6)
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovering = h } }
    }

    private var fill: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return ZStack {
            if kind == .primary {
                shape.fill(LinearGradient(colors: [accent.opacity(0.92), accent],
                                          startPoint: .top, endPoint: .bottom))
            } else {
                shape.fill(tokens.surfaceElevated.opacity(hovering ? 0.85 : 0.4))
            }
            shape.fill(LinearGradient(colors: [.white.opacity(kind == .primary ? 0.2 : 0.08), .clear],
                                      startPoint: .top, endPoint: .center))
            shape.strokeBorder(accent.opacity(hovering ? 0.8 : 0.4), lineWidth: 1)
        }
    }
}

/// A labeled HUD input (text or secure) with a monospace caps label and a
/// focus glow on the field.
struct HudField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var secure = false
    let tokens: HostThemeTokens
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced)).kerning(1.5)
                .foregroundStyle(tokens.foreground.opacity(0.5))
            Group {
                if secure { SecureField(placeholder, text: $text) }
                else { TextField(placeholder, text: $text) }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(tokens.foreground)
            .focused($focused)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tokens.surface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tokens.accentPrimary.opacity(focused ? 0.55 : 0.18), lineWidth: 1))
            .shadow(color: tokens.accentPrimary.opacity(focused ? 0.18 : 0), radius: 6)
            .animation(.easeOut(duration: 0.14), value: focused)
        }
    }
}

/// A compact HUD segmented control (2–3 options).
struct HudSegmented<T: Hashable>: View {
    let options: [(value: T, title: String)]
    @Binding var selection: T
    let tokens: HostThemeTokens

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { opt in
                let sel = selection == opt.value
                Text(opt.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(sel ? Color.white : tokens.foreground.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(sel ? tokens.accentPrimary.opacity(0.9) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(tokens.accentSecondary.opacity(sel ? 0.7 : 0), lineWidth: 1))
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.14)) { selection = opt.value } }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tokens.surface.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(tokens.foreground.opacity(0.1), lineWidth: 1))
    }
}
