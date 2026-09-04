import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var profile = SharedStateStore.readProfile()
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                StarPlayTheme.background.ignoresSafeArea()
                Form {
                    Section {
                        HStack(spacing: 14) {
                            AppLogoMark(size: 50)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("StarPlay")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Video mirroring to Windows")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.56))
                            }
                        }
                        .listRowBackground(StarPlayTheme.surface)
                    }

                    Section {
                        Picker("Video profile", selection: $profile.maxDimension) {
                            ForEach(StreamProfile.availableDimensions, id: \.self) { dimension in
                                Text(dimension == 1920 ? "High detail" : dimension == 960 ? "Balanced" : "Standard")
                                    .tag(dimension)
                            }
                        }
                        .onChange(of: profile.maxDimension) { _, _ in saveProfile() }
                        Picker("Frame rate", selection: $profile.frameRate) {
                            ForEach(StreamProfile.availableFrameRates, id: \.self) { rate in
                                Text("Up to \(rate) fps").tag(rate)
                            }
                        }
                        .onChange(of: profile.frameRate) { _, _ in saveProfile() }
                    } header: {
                        Text("Video")
                    } footer: {
                        Text("StarPlay uses hardware H.264 encoding and adapts the frame size to balance clarity, latency, and battery use.")
                    }
                    .listRowBackground(StarPlayTheme.surface)

                    Section {
                        LabeledContent("Device name") {
                            Text(UIDevice.current.name)
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                        }
                        LabeledContent("Network discovery") {
                            Text("Bonjour")
                                .foregroundStyle(.white.opacity(0.56))
                        }
                        LabeledContent("Protocol") {
                            Text("StarPlay \(AppConstants.protocolVersion)")
                                .foregroundStyle(.white.opacity(0.56))
                        }
                    } header: {
                        Text("Connection")
                    } footer: {
                        Text("A Windows receiver discovers this iPhone as an _starplay._tcp service and connects over a local TCP stream.")
                    }
                    .listRowBackground(StarPlayTheme.surface)

                    Section {
                        Button {
                            PermissionCenter.openAppSettings()
                        } label: {
                            Label("Local network permission", systemImage: "wifi.slash")
                        }
                        Button {
                            showingAbout = true
                        } label: {
                            Label("About StarPlay", systemImage: "info.circle")
                        }
                    } header: {
                        Text("Privacy and help")
                    }
                    .listRowBackground(StarPlayTheme.surface)
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StarPlayTheme.accent)
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }

    private func saveProfile() {
        model.updateProfile(profile)
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                StarPlayTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    AppLogoMark(size: 76)
                    Text("StarPlay")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A focused, local-first screen bridge for iPhone and Windows.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.64))
                        .padding(.horizontal, 28)
                    Divider().overlay(StarPlayTheme.border)
                    VStack(spacing: 10) {
                        AboutRow(label: "Developer", value: AppConstants.developerName)
                        AboutRow(label: "Version", value: "1.0.0")
                        AboutRow(label: "Video", value: "H.264 hardware encoding")
                        AboutRow(label: "Transport", value: "Bonjour and TCP")
                    }
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StarPlayTheme.accent)
                }
            }
        }
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.54))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
        }
        .font(.subheadline)
    }
}
