//
//  SettingsView.swift
//  Sudoku
//

import SwiftUI

/// Appearance, game rules and assists. Changes apply immediately, except the mistake limit,
/// which is fixed when a game starts.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker(selection: $settings.theme) {
                        ForEach(AppSettings.Theme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    } label: {
                        Label("Theme", systemImage: "circle.lefthalf.filled")
                    }
                }

                Section {
                    Toggle(isOn: $settings.showsMistakes) {
                        Label("Show Mistakes", systemImage: "exclamationmark.circle")
                    }
                    Picker(selection: $settings.mistakeLimit) {
                        ForEach(AppSettings.MistakeLimit.allCases) { limit in
                            Text(limit.title).tag(limit)
                        }
                    } label: {
                        Label("Mistake Limit", systemImage: "heart")
                    }
                    .disabled(!settings.showsMistakes)
                    Toggle(isOn: Binding(get: { settings.hintLimit > 0 }, set: { settings.hintLimit = $0 ? 3 : 0 })) {
                        Label("Limit Hints", systemImage: "lightbulb")
                    }
                    if settings.hintLimit > 0 {
                        Stepper(value: $settings.hintLimit, in: 1...20) {
                            Text("Hints per Game: \(settings.hintLimit)")
                        }
                    }
                    Toggle(isOn: $settings.showsTimer) {
                        Label("Show Timer", systemImage: "timer")
                    }
                } header: {
                    Text("Game")
                } footer: {
                    Text("The mistake and hint limits also apply to the game in progress. When mistakes are hidden, there is no mistake limit.")
                }

                Section("Assists") {
                    Toggle(isOn: $settings.highlightsRelatedCells) {
                        Label("Highlight Row, Column and Box", systemImage: "square.grid.3x3.middle.filled")
                    }
                    Toggle(isOn: $settings.highlightsSameDigits) {
                        Label("Highlight Same Digits", systemImage: "number")
                    }
                    Toggle(isOn: $settings.removesNotesAutomatically) {
                        Label("Remove Notes Automatically", systemImage: "pencil.slash")
                    }
                    Toggle(isOn: $settings.dimsCompletedDigits) {
                        Label("Dim Completed Digits", systemImage: "checkmark.circle")
                    }
                    Toggle(isOn: $settings.showsAutoNotesButton) {
                        Label("Auto Notes Button", systemImage: "square.grid.3x3")
                    }
                }

                Section("Feedback") {
                    Toggle(isOn: $settings.hapticsEnabled) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
    }
}

private extension AppSettings.Theme {
    var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

private extension AppSettings.MistakeLimit {
    var title: LocalizedStringResource {
        switch self {
        case .off: "Off"
        case .three: "3 Mistakes"
        case .five: "5 Mistakes"
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings())
}
