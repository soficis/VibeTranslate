import Foundation
import SwiftUI

@main
struct TranslationFiestaSwiftApp: App {
    @StateObject private var appContainer = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appContainer)
                .frame(minWidth: 900, minHeight: 650)
                .task {
                    await appContainer.initialize()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unifiedCompact)

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appContainer)
        }
        #endif
    }
}

struct ContentView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab: SidebarTab? = .translation

    var body: some View {
        NavigationSplitView {
            Sidebar(selectedTab: $selectedTab)
        } detail: {
            Group {
                if appContainer.isInitialized {
                    switch selectedTab {
                    case .batch:
                        BatchProcessingView()
                    case .translationMemory:
                        TranslationMemoryView()
                    case .export:
                        ExportView()
                    case .settings:
                        SettingsView()
                    case .translation, .none:
                        TranslationView()
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.2)
                        Text("Initializing…")
                            .font(.headline)
                        Text("Setting up services")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.configure(with: appContainer)
        }
    }
}

private enum SidebarTab: Int, CaseIterable, Identifiable {
    case translation
    case batch
    case translationMemory
    case export
    case settings

    var id: Int { rawValue }
}

private struct Sidebar: View {
    @Binding var selectedTab: SidebarTab?

    var body: some View {
        List(selection: $selectedTab) {
            Label("Translation", systemImage: "translate")
                .tag(SidebarTab.translation as SidebarTab?)

            Label("Batch", systemImage: "folder.badge.gearshape")
                .tag(SidebarTab.batch as SidebarTab?)

            Label("Translation Memory", systemImage: "brain.head.profile")
                .tag(SidebarTab.translationMemory as SidebarTab?)

            Label("Export", systemImage: "square.and.arrow.up")
                .tag(SidebarTab.export as SidebarTab?)

            Label("Settings", systemImage: "gearshape")
                .tag(SidebarTab.settings as SidebarTab?)
        }
        .listStyle(.sidebar)
        .navigationTitle("Translation Fiesta")
    }
}

struct TranslationView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = TranslationViewModel()

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Provider")
                    .font(.headline)
                Picker("Provider", selection: $viewModel.selectedAPIProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Input")
                        .font(.headline)
                    Spacer()
                    Button("Load File") { viewModel.showFileImporter = true }
                        .buttonStyle(.bordered)
                }
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            }

            HStack {
                Button("Translate") {
                    Task { await viewModel.performBackTranslation() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslating)

                if viewModel.isTranslating {
                    ProgressView().scaleEffect(0.85)
                }

                Spacer()
            }

            if let result = viewModel.translationResult {
                TranslationResultView(result: result)
            }

            Spacer()
        }
        .onAppear {
            viewModel.configure(with: appContainer)
        }
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.plainText, .html],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImport(result)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
