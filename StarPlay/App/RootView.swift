import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.hasCompletedOnboarding {
                HomeView(model: model)
            } else {
                OnboardingView(model: model)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            StarPlayTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer(minLength: 22)
                    AppLogoMark(size: 64)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mirror with confidence")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("StarPlay sends your iPhone screen to a Windows receiver on the same local network.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 12) {
                        PermissionStep(
                            number: "01",
                            icon: "wifi",
                            title: "Allow local network access",
                            detail: "This lets StarPlay find a Windows receiver nearby."
                        )
                        PermissionStep(
                            number: "02",
                            icon: "rectangle.inset.filled",
                            title: "Confirm screen broadcast",
                            detail: "iOS shows the system confirmation before any screen leaves your iPhone."
                        )
                        PermissionStep(
                            number: "03",
                            icon: "display",
                            title: "Connect from Windows",
                            detail: "The receiver discovers this iPhone automatically with Bonjour."
                        )
                    }

                    Button(action: model.completeOnboarding) {
                        Text("Continue")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                    }
                    .buttonStyle(AccentButtonStyle())
                    .accessibilityIdentifier("onboarding-continue")

                    Text("StarPlay never starts a broadcast without your confirmation.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.44))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct PermissionStep: View {
    let number: String
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(StarPlayTheme.accent)
                .frame(width: 30, height: 30)
                .background(StarPlayTheme.accent.opacity(0.12), in: Circle())
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(StarPlayTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(StarPlayTheme.background)
            .background(
                LinearGradient(
                    colors: [StarPlayTheme.accent, Color(red: 0.45, green: 0.92, blue: 0.91)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(StarPlayTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(StarPlayTheme.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}
