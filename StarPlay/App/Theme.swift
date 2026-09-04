import SwiftUI

enum StarPlayTheme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.11)
    static let surface = Color(red: 0.075, green: 0.105, blue: 0.18)
    static let surfaceElevated = Color(red: 0.105, green: 0.14, blue: 0.23)
    static let border = Color.white.opacity(0.09)
    static let accent = Color(red: 0.29, green: 0.82, blue: 0.96)
    static let violet = Color(red: 0.54, green: 0.47, blue: 0.98)
    static let positive = Color(red: 0.35, green: 0.88, blue: 0.62)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.32)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.42)

    static func statusColor(for status: StreamStatus) -> Color {
        switch status {
        case .streaming: return positive
        case .connected, .waitingForReceiver, .starting, .paused: return accent
        case .stopping: return warning
        case .failed: return danger
        case .idle: return Color.white.opacity(0.58)
        }
    }
}

struct AppLogoMark: View {
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [StarPlayTheme.violet, StarPlayTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: StarPlayTheme.accent.opacity(0.22), radius: 12, y: 5)
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(StarPlayTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(StarPlayTheme.border, lineWidth: 1)
            }
    }
}

struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.7), radius: 5)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
