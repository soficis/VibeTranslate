import SwiftUI
import UniformTypeIdentifiers

/// Translation memory view
struct TranslationMemoryView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = TranslationMemoryViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Translation Memory")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Clear Memory") {
                    Task {
                        await viewModel.clearMemory()
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            
            // Statistics
            if let stats = viewModel.stats {
                TranslationMemoryStatsCard(stats: stats)
            }
            
            // Search Interface
            VStack(alignment: .leading, spacing: 8) {
                Text("Search Translation Memory")
                    .font(.headline)
                
                HStack {
                    TextField("Enter text to search...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Search") {
                        Task {
                            await viewModel.searchMemory()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.searchText.isEmpty || viewModel.isSearching)
                    
                    if viewModel.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            // Search Results
            if !viewModel.searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Results (\(viewModel.searchResults.count))")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.searchResults, id: \.id) { entry in
                                TranslationMemoryEntryRow(entry: entry)
                            }
                        }
                    }
                    .frame(height: 300)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.configure(with: appContainer)
            Task {
                await viewModel.loadStats()
            }
        }
    }
}

/// Translation memory statistics card
struct TranslationMemoryStatsCard: View {
    let stats: TranslationMemoryStats
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Memory Statistics")
                    .font(.headline)
                Spacer()
            }
            
            // Cache Utilization
            ProgressView(value: stats.cacheUtilization / 100.0) {
                HStack {
                    Text("Cache Usage")
                    Spacer()
                    Text("\(stats.totalEntries) / \(stats.maxCacheSize)")
                }
                .font(.caption)
            }
            
            // Performance Metrics
            HStack {
                VStack(alignment: .leading) {
                    Text("Hit Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", stats.hitRate) + "%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Avg Lookup Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", stats.averageLookupTime * 1000) + "ms")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Total Misses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.totalMisses)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
            
            // Detailed Stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Total Hits:")
                            .font(.caption)
                        Text("\(stats.totalHits)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Total Misses:")
                            .font(.caption)
                        Text("\(stats.totalMisses)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let lastPersist = stats.lastPersistTime {
                        Text("Last Saved:")
                            .font(.caption)
                        Text(lastPersist.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
    }
}

/// Translation memory entry row view
struct TranslationMemoryEntryRow: View {
    let entry: TranslationMemoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(entry.sourceLanguage.flag) \(entry.sourceLanguage.displayName)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("Used \(entry.accessCount)x")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(entry.sourceLanguage.flag)")
                    Text(entry.sourceText)
                        .font(.caption)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("\(entry.targetLanguage.flag)")
                    Text(entry.translatedText)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Export view
struct ExportView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = ExportViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Export Translations")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Export Configuration
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Settings")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Format")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Format", selection: $viewModel.selectedFormat) {
                            ForEach(ExportFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Toggle("Include Metadata", isOn: $viewModel.includeMetadata)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Available Results (Placeholder)
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Translation Results")
                    .font(.headline)
                
                Text("No translation results available. Perform some translations first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // Export Actions
            HStack {
                Button("Generate Preview") {
                    Task {
                        await viewModel.generatePreview()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedResults.isEmpty)
                
                Button("Export to File") {
                    viewModel.showFileSaver = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedResults.isEmpty || viewModel.isExporting)
                
                if viewModel.isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Preview Area
            if !viewModel.exportPreview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Preview")
                        .font(.headline)
                    
                    ScrollView {
                        Text(viewModel.exportPreview)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                }
            }
            
            Spacer()
        }
        .padding()
        .fileExporter(
            isPresented: $viewModel.showFileSaver,
            document: ExportDocument(content: viewModel.exportPreview),
            contentType: .plainText,
            defaultFilename: "translation_export"
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await viewModel.exportResults(to: url)
                }
            case .failure(_):
                print("Export failed")
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.configure(with: appContainer)
        }
    }
}

/// Settings view
struct SettingsView: View {
    @EnvironmentObject var appContainer: AppContainer
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("About Translation Fiesta Swift")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Version", value: "1.0.0")
                    InfoRow(label: "Framework", value: "SwiftUI")
                    InfoRow(label: "Architecture", value: "Clean Architecture")
                    InfoRow(label: "Platform", value: "macOS 14+")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Features")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(feature: "English ↔ Japanese Back-translation", implemented: true)
                    FeatureRow(feature: "Batch Processing", implemented: true)
                    FeatureRow(feature: "Translation Memory Cache", implemented: true)
                    FeatureRow(feature: "Multiple Export Formats", implemented: true)
                    FeatureRow(feature: "EPUB Processing", implemented: true)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            Spacer()
        }
        .padding()
    }
}

/// Info row for settings
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
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
                .foregroundColor(implemented ? .green : .gray)
            
            Text(feature)
                .font(.caption)
                .foregroundColor(implemented ? .primary : .secondary)
            
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
