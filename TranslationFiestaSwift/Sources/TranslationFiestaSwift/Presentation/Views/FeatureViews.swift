import SwiftUI
import UniformTypeIdentifiers

/// Batch processing view
struct BatchProcessingView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = BatchProcessingViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Batch Processing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button("Select Files") { viewModel.showFileImporter = true }
                    Button("Import EPUB") { viewModel.showEpubImporter = true }
                } label: {
                    Label("Files", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
            }
            
            // File Selection Area
            if !viewModel.selectedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Files (\(viewModel.selectedFiles.count))")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.selectedFiles, id: \.self) { url in
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.blue)
                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Configuration
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("API Provider")
                        .font(.headline)
                    
                    Picker("API Provider", selection: $viewModel.selectedAPIProvider) {
                        ForEach(APIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Source Language")
                        .font(.headline)
                    
                    Picker("Source", selection: $viewModel.sourceLanguage) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Target Language")
                        .font(.headline)
                    
                    Picker("Target", selection: $viewModel.targetLanguage) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            // Process Button
            HStack {
                Button(viewModel.isProcessing ? "Cancel" : "Start Processing") {
                    if viewModel.isProcessing {
                        viewModel.cancelBatchProcessing()
                    } else {
                        Task {
                            await viewModel.startBatchProcessing()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedFiles.isEmpty)
                
                if viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Progress Display
            if let progress = viewModel.progress {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(.headline)
                    
                    ProgressView(value: progress.percentComplete / 100.0) {
                        HStack {
                            Text("\(progress.processedFiles) / \(progress.totalFiles) files")
                            Spacer()
                            Text(String(format: "%.1f", progress.percentComplete) + "%")
                        }
                        .font(.caption)
                    }
                    
                    HStack {
                        Text("✓ Success: \(progress.successfulFiles)")
                            .foregroundColor(.green)
                        Spacer()
                        Text("✗ Failed: \(progress.failedFiles)")
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Results Display
            if !viewModel.results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Results")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.results, id: \.id) { result in
                                BatchResultRow(result: result)
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.plainText, .html],
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileSelection(result)
        }
        .fileImporter(
            isPresented: $viewModel.showEpubImporter,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        do {
                            let text = try await viewModel.extractTextFromEpub(url)
                            // Put extracted text into first selected file or show it separately
                            await MainActor.run {
                                viewModel.extractedEpubText = text
                            }
                        } catch {
                            viewModel.showErrorMessage("Failed to import EPUB: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure:
                viewModel.showErrorMessage("EPUB selection failed")
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

/// Row view for batch processing results
struct BatchResultRow: View {
    let result: BatchTranslationResult
    
    private var processingTimeText: String {
        String(format: "%.2f", result.processingTime)
    }
    
    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if result.success {
                    Text("Processing time: \(processingTimeText)s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if let error = result.error {
                    Text("Error: \(error)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(4)
    }
}

/// Cost tracking view
struct CostTrackingView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = CostTrackingViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Cost Tracking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await viewModel.loadCostData()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            if viewModel.isLoading {
                ProgressView("Loading cost data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Budget Status
                        if let budgetStatus = viewModel.budgetStatus {
                            BudgetStatusCard(status: budgetStatus)
                        }
                        
                        // Budget Configuration
                        BudgetConfigurationCard(
                            monthlyLimit: $viewModel.monthlyBudgetLimit,
                            alertThreshold: $viewModel.alertThreshold,
                            onUpdate: {
                                Task {
                                    await viewModel.updateBudget()
                                }
                            }
                        )
                        
                        // Cost Analysis
                        if let analysis = viewModel.costAnalysis {
                            CostAnalysisCard(analysis: analysis)
                        }
                    }
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
                await viewModel.loadCostData()
            }
        }
    }
}

/// Budget status card
struct BudgetStatusCard: View {
    let status: BudgetStatus
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Monthly Budget Status")
                    .font(.headline)
                Spacer()
                Text("\(status.daysRemainingInMonth) days remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Usage Progress
            ProgressView(value: status.usagePercentage / 100.0) {
                HStack {
                    Text("$" + String(format: "%.2f", status.currentMonthUsageUSD))
                    Spacer()
                    Text("$" + String(format: "%.2f", status.monthlyLimitUSD))
                }
                .font(.caption)
            }
            .progressViewStyle(LinearProgressViewStyle(tint: status.isOverBudget ? .red : .blue))
            
            // Status Info
            HStack {
                VStack(alignment: .leading) {
                    Text("Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", status.usagePercentage) + "%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(status.isOverBudget ? .red : .primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$" + String(format: "%.2f", status.remainingBudgetUSD))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(status.remainingBudgetUSD > 0 ? .green : .red)
                }
            }
            
            if status.shouldAlert {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Alert threshold reached (" + String(format: "%.0f", status.alertThresholdPercent) + "%)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Budget configuration card
struct BudgetConfigurationCard: View {
    @Binding var monthlyLimit: Double
    @Binding var alertThreshold: Double
    let onUpdate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Configuration")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Monthly Limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Monthly Limit", value: $monthlyLimit, format: .currency(code: "USD"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Alert Threshold (%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Alert Threshold", value: $alertThreshold, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Button("Update") {
                    onUpdate()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Cost analysis card
struct CostAnalysisCard: View {
    let analysis: CostAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Analysis")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Last 7 Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$" + String(format: "%.4f", analysis.sevenDayReport.totalCostUSD))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(analysis.sevenDayReport.entryCount) translations")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last 30 Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$" + String(format: "%.4f", analysis.thirtyDayReport.totalCostUSD))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(analysis.thirtyDayReport.entryCount) translations")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Trend Indicator
            HStack {
                Image(systemName: trendIcon)
                    .foregroundColor(trendColor)
                Text("Spending trend: \(trendText)")
                    .font(.caption)
                    .foregroundColor(trendColor)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var trendIcon: String {
        switch analysis.trendIndicator {
        case .increasing: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        case .decreasing: return "arrow.down.circle.fill"
        }
    }
    
    private var trendColor: Color {
        switch analysis.trendIndicator {
        case .increasing: return .red
        case .stable: return .orange
        case .decreasing: return .green
        }
    }
    
    private var trendText: String {
        switch analysis.trendIndicator {
        case .increasing: return "Increasing"
        case .stable: return "Stable"
        case .decreasing: return "Decreasing"
        }
    }
}

#Preview {
    BatchProcessingView()
        .environmentObject(AppContainer())
        .frame(width: 800, height: 600)
}