import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppModel
    @State private var showingSettings = false
    @State private var showingStopHelp = false

    private var statusColor: Color {
        StarPlayTheme.statusColor(for: model.streamState.status)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StarPlayTheme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        statusCard
                        actionButton
                        receiverCard
                        networkCard
                        if model.streamState.isActive {
                            streamDetailsCard
                        }
                        if model.streamState.status == .failed {
                            failureCard
                        }
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 38, height: 38)
                            .background(StarPlayTheme.surface, in: Circle())
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(model: model)
            }
            .alert("Stop mirroring", isPresented: $showingStopHelp) {
                Button("Stop broadcast", role: .destructive) {
                    model.stopMirroring()
                }
                Button("Keep mirroring", role: .cancel) {}
            } message: {
                Text("StarPlay will ask the system broadcast to stop. You can also stop it at any time from Control Center.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppLogoMark(size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppConstants.appName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("iPhone to Windows")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            if model.streamState.status == .streaming {
                HStack(spacing: 6) {
                    StatusDot(color: StarPlayTheme.positive)
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(StarPlayTheme.positive)
                }
            }
        }
        .padding(.top, 10)
    }

    private var statusCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mirror status")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.52))
                        Text(model.streamState.status.displayName)
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.12))
                            .frame(width: 58, height: 58)
                        Image(systemName: model.streamState.isActive ? "rectangle.inset.filled.and.person.filled" : "rectangle.on.rectangle")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                }
                HStack(spacing: 8) {
                    StatusDot(color: statusColor)
                    Text(model.streamState.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)
                }
            }
        }
    }

    private var actionButton: some View {
        Group {
            if model.streamState.isActive {
                Button {
                    showingStopHelp = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Stop mirroring")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("stop-mirroring")
            } else if model.usesModernCapture {
                Button {
                    model.startMirroring()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.inset.filled.and.arrow.forward")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start mirroring")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                }
                .buttonStyle(AccentButtonStyle())
                .accessibilityIdentifier("start-mirroring")
            } else {
                ZStack {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.inset.filled.and.arrow.forward")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start mirroring")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(StarPlayTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [StarPlayTheme.accent, Color(red: 0.45, green: 0.92, blue: 0.91)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    BroadcastPickerView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(0.02)
                }
                .frame(maxWidth: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .simultaneousGesture(TapGesture().onEnded {
                    model.startMirroring()
                })
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Start mirroring")
                .accessibilityHint("Opens the iOS screen broadcast confirmation")
                .accessibilityIdentifier("start-mirroring")
            }
        }
    }

    private var receiverCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Windows receiver")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if model.isSearchingForReceivers {
                        ProgressView()
                            .tint(StarPlayTheme.accent)
                            .scaleEffect(0.8)
                    }
                }
                if let activeReceiverName = model.activeReceiverName {
                    DetailRow(icon: "display", title: "Available device", value: activeReceiverName, tint: StarPlayTheme.accent)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(StarPlayTheme.warning)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No receiver found yet")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Start the Windows receiver on this Wi-Fi network. It will discover your iPhone automatically.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.56))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let error = model.receiverSearchError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(StarPlayTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Settings") {
                        PermissionCenter.openAppSettings()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StarPlayTheme.accent)
                }
            }
        }
    }

    private var networkCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Network")
                    .font(.headline)
                    .foregroundStyle(.white)
                DetailRow(
                    icon: model.network.isWiFi ? "wifi" : "network",
                    title: "Connection",
                    value: model.network.label,
                    tint: model.network.isWiFi ? StarPlayTheme.positive : StarPlayTheme.warning
                )
                DetailRow(
                    icon: "lock.shield",
                    title: "Privacy",
                    value: "Local network only",
                    tint: StarPlayTheme.violet
                )
            }
        }
    }

    private var streamDetailsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Stream details")
                    .font(.headline)
                    .foregroundStyle(.white)
                if model.streamState.width > 0 {
                    DetailRow(
                        icon: "rectangle.portrait.and.arrow.forward",
                        title: "Video",
                        value: "\(model.streamState.width) x \(model.streamState.height)",
                        tint: StarPlayTheme.accent
                    )
                }
                DetailRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Orientation",
                    value: model.streamState.orientation.displayName,
                    tint: StarPlayTheme.violet
                )
                DetailRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Frames sent",
                    value: model.streamState.framesSent.formatted(),
                    tint: StarPlayTheme.positive
                )
                if model.streamState.framesDropped > 0 {
                    DetailRow(
                        icon: "arrow.down.right.and.arrow.up.left",
                        title: "Frames skipped",
                        value: model.streamState.framesDropped.formatted(),
                        tint: StarPlayTheme.warning
                    )
                }
            }
        }
    }

    private var failureCard: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(StarPlayTheme.danger)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Broadcast unavailable")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Check local network access and try again. If the issue continues, stop any existing broadcast from Control Center.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        Text("StarPlay keeps the video on your local network. Your screen is sent only after you confirm the iOS broadcast.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.top, 2)
    }
}
