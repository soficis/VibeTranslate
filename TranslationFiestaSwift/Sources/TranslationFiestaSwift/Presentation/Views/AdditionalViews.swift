import SwiftUI
import UniformTypeIdentifiers

/// Translation memory view
struct TranslationMemoryView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = TranslationMemoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider().background(Color.themeBorder)
            
            contentBody
                .padding(Spacing.standard)
        }
        .background(Color.themeBackground.ignoresSafeArea())
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage).font(.themeBody)
        }
        .onAppear {
            viewModel.configure(with: appContainer)
            Task {
                await viewModel.loadStats()
            }
        }
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            Text("Translation Memory")
                .font(.themeHeadline)
                .foregroundColor(.themeText)
            
            Spacer()
            
            Button("Clear Memory") {
                Task { await viewModel.clearMemory() }
            }
            .buttonStyle(.plain)
            .font(.themeBody)
            .foregroundColor(.themeDestructive)
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, Spacing.small)
        .padding(.top, Spacing.standard)
    }
    
    private var contentBody: some View {
        VStack(spacing: Spacing.standard) {
            
            // Statistics
            if let stats = viewModel.stats {
                TranslationMemoryStatsCard(stats: stats)
            }
            
            // Search Interface
            HStack(spacing: Spacing.small) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.themeTextSecondary)
                    TextField("Search memory...", text: $viewModel.searchText)
                        .font(.themeBody)
                        .textFieldStyle(.plain)
                }
                .padding(Spacing.small)
                .background(Color.themeSurface)
                .cornerRadius(Radii.standard)
                .overlay(RoundedRectangle(cornerRadius: Radii.standard).stroke(Color.themeBorder, lineWidth: 1))
                
                Button(action: {
                    Task { await viewModel.searchMemory() }
                }) {
                    if viewModel.isSearching {
                        ProgressView().controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(viewModel.searchText.isEmpty || viewModel.isSearching ? .themeTextSecondary.opacity(0.3) : .themeAccent)
                .disabled(viewModel.searchText.isEmpty || viewModel.isSearching)
            }
            
            // Search Results
            if !viewModel.searchResults.isEmpty {
                HStack {
                    Text("Search Results (\(viewModel.searchResults.count))")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.top, Spacing.small)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.small) {
                        ForEach(viewModel.searchResults, id: \.id) { entry in
                            TranslationMemoryEntryRow(entry: entry)
                        }
                    }
                }
                .themeSurface(padding: Spacing.micro)
            } else {
                Spacer()
            }
        }
    }
}

/// Translation memory statistics card
struct TranslationMemoryStatsCard: View {
    let stats: TranslationMemoryStats
    
    var body: some View {
        VStack(spacing: Spacing.standard) {
            HStack {
                Text("Memory Statistics")
                    .font(.themeHeadline)
                Spacer()
                if let lastPersist = stats.lastPersistTime {
                    Text("Saved \(lastPersist.formatted(date: .abbreviated, time: .shortened))")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                }
            }
            
            HStack(spacing: Spacing.large) {
                // Left metrics
                VStack(alignment: .leading, spacing: Spacing.small) {
                    metricInfo(label: "Hit Rate", value: String(format: "%.1f%%", stats.hitRate), color: .themeSuccess)
                    metricInfo(label: "Avg Lookup", value: String(format: "%.1f ms", stats.averageLookupTime * 1000), color: .themeText)
                }
                
                // Right metrics
                VStack(alignment: .leading, spacing: Spacing.small) {
                    metricInfo(label: "Total Hits", value: "\(stats.totalHits)", color: .themeText)
                    metricInfo(label: "Total Misses", value: "\(stats.totalMisses)", color: .themeTextSecondary)
                }
                
                Spacer()
            }
            
            // Cache Utilization
            VStack(alignment: .leading, spacing: Spacing.micro) {
                HStack {
                    Text("Cache Usage")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                    Spacer()
                    Text("\(stats.totalEntries) / \(stats.maxCacheSize)")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                }
                ProgressView(value: stats.cacheUtilization / 100.0)
                    .progressViewStyle(.linear)
                    .tint(.themeAccent)
            }
        }
        .themeSurface()
    }
    
    private func metricInfo(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.themeCaption)
                .foregroundColor(.themeTextSecondary)
            Text(value)
                .font(.themeTitle)
                .foregroundColor(color)
        }
    }
}

/// Translation memory entry row view
struct TranslationMemoryEntryRow: View {
    let entry: TranslationMemoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                Text("\(entry.sourceLanguage.flag) \(entry.sourceLanguage.displayName) → \(entry.targetLanguage.flag) \(entry.targetLanguage.displayName)")
                    .font(.themeCaption)
                    .foregroundColor(.themeTextSecondary)
                
                Spacer()
                
                Text("Used \(entry.accessCount)x")
                    .font(.themeCaption)
                    .foregroundColor(.themeTextSecondary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.micro) {
                Text(entry.sourceText)
                    .font(.themeBody)
                    .lineLimit(2)
                
                Text(entry.translatedText)
                    .font(.themeBody)
                    .foregroundColor(.themeAccent)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.small)
        .background(Color.themeBackground.opacity(0.5))
        .cornerRadius(Radii.standard)
    }
}

/// Export view
struct ExportView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = ExportViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().background(Color.themeBorder)
            contentBody
                .padding(Spacing.standard)
        }
        .background(Color.themeBackground.ignoresSafeArea())
        .fileExporter(
            isPresented: $viewModel.showFileSaver,
            document: ExportDocument(content: viewModel.exportPreview),
            contentType: .plainText,
            defaultFilename: "translation_export"
        ) { result in
            switch result {
            case .success(let url):
                Task { await viewModel.exportResults(to: url) }
            case .failure(_):
                print("Export failed")
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage).font(.themeBody)
        }
        .onAppear {
            viewModel.configure(with: appContainer)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Export Translations")
                .font(.themeHeadline)
            Spacer()
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, Spacing.small)
        .padding(.top, Spacing.standard)
    }
    
    private var contentBody: some View {
        HStack(spacing: Spacing.standard) {
            // Left column
            VStack(alignment: .leading, spacing: Spacing.standard) {
                Text("Export Settings")
                    .font(.themeCaption)
                    .foregroundColor(.themeTextSecondary)
                    .textCase(.uppercase)
                
                VStack(spacing: Spacing.standard) {
                    HStack {
                        Text("Format")
                            .font(.themeBody)
                        Spacer()
                        Picker("", selection: $viewModel.selectedFormat) {
                            ForEach(ExportFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    
                    Toggle("Include Metadata", isOn: $viewModel.includeMetadata)
                        .font(.themeBody)
                        .toggleStyle(SwitchToggleStyle(tint: .themeAccent))
                }
                .themeSurface()
                
                Spacer()
                
                // Actions
                HStack(spacing: Spacing.standard) {
                    Button("Preview") {
                        Task { await viewModel.generatePreview() }
                    }
                    .buttonStyle(.plain)
                    .font(.themeBody)
                    .padding(.horizontal, Spacing.standard)
                    .padding(.vertical, Spacing.small)
                    .background(Color.themeSurface)
                    .cornerRadius(Radii.standard)
                    .disabled(viewModel.selectedResults.isEmpty)
                    
                    Button(action: { viewModel.showFileSaver = true }) {
                        HStack {
                            if viewModel.isExporting {
                                ProgressView().controlSize(.small).padding(.trailing, 4)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                            }
                            Text("Export to File")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.themeHeadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.standard)
                    .padding(.vertical, Spacing.small)
                    .background(viewModel.selectedResults.isEmpty ? Color.themeTextSecondary.opacity(0.3) : Color.themeAccent)
                    .cornerRadius(Radii.standard)
                    .disabled(viewModel.selectedResults.isEmpty || viewModel.isExporting)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right column (Preview)
            VStack(alignment: .leading, spacing: Spacing.standard) {
                Text("Preview")
                    .font(.themeCaption)
                    .foregroundColor(.themeTextSecondary)
                    .textCase(.uppercase)
                
                if viewModel.exportPreview.isEmpty {
                    VStack {
                        Spacer()
                        Text("Nothing to preview yet.")
                            .font(.themeBody)
                            .foregroundColor(.themeTextSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeSurface()
                } else {
                    ScrollView {
                        Text(viewModel.exportPreview)
                            .font(.themeMonospaced)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .themeSurface()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Settings view
struct SettingsView: View {
    @EnvironmentObject var appContainer: AppContainer
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.themeHeadline)
                Spacer()
            }
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, Spacing.small)
            .padding(.top, Spacing.standard)
            
            Divider().background(Color.themeBorder)
            
            ScrollView {
                VStack(spacing: Spacing.medium) {
                    // About Section
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("About")
                            .font(.themeCaption)
                            .foregroundColor(.themeTextSecondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: Spacing.small) {
                            InfoRow(label: "Version", value: "1.0.0")
                            InfoRow(label: "Framework", value: "SwiftUI")
                            InfoRow(label: "Architecture", value: "Clean Architecture")
                            InfoRow(label: "Platform", value: "macOS 14+")
                        }
                        .themeSurface()
                    }
                    
                    // Features Section
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Features")
                            .font(.themeCaption)
                            .foregroundColor(.themeTextSecondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: Spacing.small) {
                            FeatureRow(feature: "English ↔ Japanese Back-translation", implemented: true)
                            FeatureRow(feature: "Batch Processing", implemented: true)
                            FeatureRow(feature: "Translation Memory Cache", implemented: true)
                            FeatureRow(feature: "Multiple Export Formats", implemented: true)
                            FeatureRow(feature: "EPUB Processing", implemented: true)
                        }
                        .themeSurface()
                    }
                }
                .padding(Spacing.standard)
            }
        }
        .background(Color.themeBackground.ignoresSafeArea())
    }
}

/// Info row for settings
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.themeBody)
                .foregroundColor(.themeTextSecondary)
            Spacer()
            Text(value)
                .font(.themeBody)
                .foregroundColor(.themeText)
        }
    }
}

/// Feature row for settings
struct FeatureRow: View {
    let feature: String
    let implemented: Bool
    
    var body: some View {
        HStack {
            Image(systemName: implemented ? "checkmark.circle.fill" : "circle")
                .foregroundColor(implemented ? .themeSuccess : .themeTextSecondary.opacity(0.3))
            
            Text(feature)
                .font(.themeBody)
                .foregroundColor(implemented ? .themeText : .themeTextSecondary)
            
            Spacer()
        }
    }
}

/// Document wrapper for file exporter
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    let content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        self.content = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    TranslationMemoryView()
        .environmentObject(AppContainer())
        .frame(width: 800, height: 600)
}
