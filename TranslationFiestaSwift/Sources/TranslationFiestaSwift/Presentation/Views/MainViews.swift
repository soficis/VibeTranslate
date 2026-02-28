import Foundation
import SwiftUI

struct TranslationFiestaSwiftApp: App {
    @StateObject private var appContainer = AppContainer()

    // Enforce dark mode at the app level
    var body: some Scene {
        WindowGroup("TranslationFiesta Swift") {
            ContentView()
                .environmentObject(appContainer)
                .frame(minWidth: 900, minHeight: 650)
                .task {
                    await appContainer.initialize()
                }
                .preferredColorScheme(.dark) 
                .font(.themeBody)
        }
        .windowStyle(.hiddenTitleBar) // Minimalist macOS window style
        .windowToolbarStyle(.unifiedCompact)

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appContainer)
                .preferredColorScheme(.dark)
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
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            ZStack {
                Color.themeBackground.ignoresSafeArea()
                
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
                        VStack(spacing: Spacing.standard) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.2)
                            Text("Initializing…")
                                .font(.themeHeadline)
                            Text("Setting up services")
                                .font(.themeCaption)
                                .foregroundColor(.themeTextSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
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
        ZStack {
            Color.themeSurfaceSecondary.ignoresSafeArea()
            
            List(selection: $selectedTab) {
                Spacer().frame(height: Spacing.medium) // Push down from hidden titlebar
                
                Label("Translation", systemImage: "quote.bubble")
                    .tag(SidebarTab.translation as SidebarTab?)
                    .padding(.vertical, Spacing.micro)

                Label("Batch", systemImage: "rectangle.stack")
                    .tag(SidebarTab.batch as SidebarTab?)
                    .padding(.vertical, Spacing.micro)

                Label("Memory", systemImage: "brain")
                    .tag(SidebarTab.translationMemory as SidebarTab?)
                    .padding(.vertical, Spacing.micro)

                Label("Export", systemImage: "square.and.arrow.up")
                    .tag(SidebarTab.export as SidebarTab?)
                    .padding(.vertical, Spacing.micro)

                Spacer().frame(height: Spacing.large)
                
                Label("Settings", systemImage: "slider.horizontal.3")
                    .tag(SidebarTab.settings as SidebarTab?)
                    .padding(.vertical, Spacing.micro)
            }
            .listStyle(.sidebar)
            .font(.themeBody)
        }
    }
}

struct TranslationView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = TranslationViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header: Top Toolbar Area
            headerView
            
            Divider().background(Color.themeBorder)
            
            // Main Content Area
            contentBody
                .padding(Spacing.standard)
        }
        .background(Color.themeBackground.ignoresSafeArea())
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
            Text(viewModel.errorMessage).font(.themeBody)
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            // Document Title
            Text("New Translation")
                .font(.themeHeadline)
                .foregroundColor(.themeText)
            
            Spacer()
            
            // Sleek Provider Picker
            Picker("", selection: $viewModel.selectedAPIProvider) {
                ForEach(APIProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName)
                        .font(.themeBody)
                        .tag(provider)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .padding(.horizontal, Spacing.small)
            .background(Color.themeSurface)
            .cornerRadius(Radii.standard)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.standard)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
            
            // Load File Button
            Button(action: { viewModel.showFileImporter = true }) {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(.themeTextSecondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, Spacing.small)
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, Spacing.small)
        .padding(.top, Spacing.standard) // Padding for hidden titlebar area
    }
    
    private var contentBody: some View {
        GeometryReader { geometry in
            HStack(spacing: Spacing.standard) {
                
                // LEFT: Input Area
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Source")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                        .textCase(.uppercase)
                    
                    TextEditor(text: $viewModel.inputText)
                        .premiumTextEditor()
                        .frame(maxHeight: .infinity)
                }
                .frame(width: geometry.size.width / 2.0 - Spacing.standard / 2.0)
                
                // RIGHT: Output Area
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Text("Target")
                            .font(.themeCaption)
                            .foregroundColor(.themeTextSecondary)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    
                    ZStack {
                        // Background structure matched with input
                        RoundedRectangle(cornerRadius: Radii.standard)
                            .fill(Color.themeSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radii.standard)
                                    .stroke(Color.themeBorder, lineWidth: 1)
                            )
                        
                        if viewModel.isTranslating {
                            VStack(spacing: Spacing.standard) {
                                ProgressView()
                                    .controlSize(.regular)
                                Text("Translating…")
                                    .font(.themeCaption)
                                    .foregroundColor(.themeTextSecondary)
                            }
                        } else if let result = viewModel.translationResult {
                            TranslationResultView(result: result)
                                .padding(Spacing.small)
                        } else {
                            Text("Ready")
                                .font(.themeBody)
                                .foregroundColor(.themeTextSecondary.opacity(0.5))
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(width: geometry.size.width / 2.0 - Spacing.standard / 2.0)
                .overlay(
                    // Translate Button floating in the gap
                    translateButton
                        .offset(x: -(geometry.size.width / 2.0 - Spacing.standard / 2.0) - Spacing.standard / 2.0),
                    alignment: .bottomTrailing
                )
            }
        }
    }
    
    private var translateButton: some View {
        Button(action: {
            Task { await viewModel.performBackTranslation() }
        }) {
            Image(systemName: "arrow.right.circle.fill")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundColor(
                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslating 
                    ? .themeTextSecondary.opacity(0.3) 
                    : .themeAccent
                )
                .background(Circle().fill(Color.themeBackground))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslating)
        .padding(.bottom, Spacing.large)
    }
}
