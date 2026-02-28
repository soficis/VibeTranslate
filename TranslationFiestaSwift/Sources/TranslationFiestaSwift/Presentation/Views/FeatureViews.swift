import SwiftUI
import UniformTypeIdentifiers

/// Batch processing view
struct BatchProcessingView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = BatchProcessingViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider().background(Color.themeBorder)
            
            contentBody
                .padding(Spacing.standard)
        }
        .background(Color.themeBackground.ignoresSafeArea())
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
            handleEpubImport(result)
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
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: Spacing.small) {
            Text("Batch Processing")
                .font(.themeHeadline)
                .foregroundColor(.themeText)
            
            Spacer()
            
            // Configuration Controls
            HStack(spacing: Spacing.small) {
                // API Provider
                Picker("", selection: $viewModel.selectedAPIProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
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
                
                // Source Language
                Picker("Source", selection: $viewModel.sourceLanguage) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
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
                
                // Target Language
                Picker("Target", selection: $viewModel.targetLanguage) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
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
            }
            
            Menu {
                Button("Select Texts/HTML") { viewModel.showFileImporter = true }
                Button("Import EPUB") { viewModel.showEpubImporter = true }
            } label: {
                Image(systemName: "folder.badge.plus")
                    .foregroundColor(.themeTextSecondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, Spacing.small)
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, Spacing.small)
        .padding(.top, Spacing.standard) // Accommodate hidden titlebar
    }
    
    private var contentBody: some View {
        VStack(spacing: Spacing.standard) {
            // Selected files list and status
            if viewModel.selectedFiles.isEmpty {
                emptyStateView
            } else {
                activeStateView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Spacing.standard) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.themeTextSecondary.opacity(0.3))
            
            Text("No Files Selected")
                .font(.themeHeadline)
                .foregroundColor(.themeTextSecondary)
            
            Text("Click the + icon in the top right to import files for batch translation.")
                .font(.themeBody)
                .foregroundColor(.themeTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    private var activeStateView: some View {
        HStack(spacing: Spacing.standard) {
            // Left Column: Selected Files
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack {
                    Text("Selected Files (\(viewModel.selectedFiles.count))")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.micro) {
                        ForEach(viewModel.selectedFiles, id: \.self) { url in
                            HStack(spacing: Spacing.small) {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.themeAccent)
                                Text(url.lastPathComponent)
                                    .font(.themeBody)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(.horizontal, Spacing.small)
                            .padding(.vertical, Spacing.small)
                            .background(Color.themeSurface)
                            .cornerRadius(Radii.small)
                        }
                    }
                }
                .themeSurface(padding: Spacing.micro)
            }
            .frame(maxWidth: .infinity)
            
            // Right Column: Progress & Results
            VStack(alignment: .leading, spacing: Spacing.standard) {
                HStack {
                    Text("Progress")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                
                progressCard
                
                if !viewModel.results.isEmpty {
                    Text("Results")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                        .textCase(.uppercase)
                        .padding(.top, Spacing.small)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Spacing.small) {
                            ForEach(viewModel.results, id: \.id) { result in
                                BatchResultRow(result: result)
                            }
                        }
                    }
                    .themeSurface(padding: Spacing.micro)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .overlay(
                processButton.offset(y: -Spacing.large),
                alignment: .bottomTrailing
            )
        }
    }
    
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let progress = viewModel.progress {
                ProgressView(value: progress.percentComplete / 100.0)
                    .progressViewStyle(.linear)
                    .tint(.themeAccent)
                
                HStack {
                    Text("\(progress.processedFiles) / \(progress.totalFiles) files")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                    Spacer()
                    Text(String(format: "%.1f", progress.percentComplete) + "%")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                }
                
                HStack {
                    Label("Success: \(progress.successfulFiles)", systemImage: "checkmark.circle.fill")
                        .font(.themeCaption)
                        .foregroundColor(.themeSuccess)
                    Spacer()
                    Label("Failed: \(progress.failedFiles)", systemImage: "xmark.circle.fill")
                        .font(.themeCaption)
                        .foregroundColor(.themeDestructive)
                }
            } else {
                Text("Ready to process")
                    .font(.themeBody)
                    .foregroundColor(.themeTextSecondary)
            }
        }
        .themeSurface()
    }
    
    private var processButton: some View {
        Button(action: {
            if viewModel.isProcessing {
                viewModel.cancelBatchProcessing()
            } else {
                Task { await viewModel.startBatchProcessing() }
            }
        }) {
            HStack {
                if viewModel.isProcessing {
                    ProgressView().controlSize(.small).padding(.trailing, 4)
                    Text("Cancel")
                } else {
                    Image(systemName: "play.fill")
                    Text("Start Processing")
                }
            }
            .font(.themeHeadline)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(viewModel.isProcessing ? Color.themeDestructive : Color.themeAccent)
            .foregroundColor(.white)
            .cornerRadius(Radii.xLarge)
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedFiles.isEmpty && !viewModel.isProcessing)
        .opacity((viewModel.selectedFiles.isEmpty && !viewModel.isProcessing) ? 0.5 : 1)
    }
    
    // MARK: - Actions
    
    private func handleEpubImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    do {
                        let text = try await viewModel.extractTextFromEpub(url)
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
}

/// Row view for batch processing results
struct BatchResultRow: View {
    let result: BatchTranslationResult
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .themeSuccess : .themeDestructive)
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.themeBody)
                    .foregroundColor(.themeText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if result.success {
                    Text("Processing time: \(String(format: "%.2f", result.processingTime))s")
                        .font(.themeCaption)
                        .foregroundColor(.themeTextSecondary)
                } else if let error = result.error {
                    Text("Error: \(error)")
                        .font(.themeCaption)
                        .foregroundColor(.themeDestructive)
                }
            }
            
            Spacer()
        }
        .padding(Spacing.small)
        .background(result.success ? Color.themeSuccess.opacity(0.1) : Color.themeDestructive.opacity(0.1))
        .cornerRadius(Radii.standard)
        .overlay(
            RoundedRectangle(cornerRadius: Radii.standard)
                .stroke(result.success ? Color.themeSuccess.opacity(0.3) : Color.themeDestructive.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    BatchProcessingView()
        .environmentObject(AppContainer())
        .frame(width: 800, height: 600)
}
