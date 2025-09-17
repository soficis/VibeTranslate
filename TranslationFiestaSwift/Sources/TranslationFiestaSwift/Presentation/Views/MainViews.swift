import Foundation
import SwiftUI

/// Main application entry point
/// Following Clean Code: simple main function
@main
struct TranslationFiestaSwiftApp: App {
    @StateObject private var appContainer = AppContainer()

    public init() {
        print("🧭 TranslationFiestaSwiftApp init - App starting")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appContainer)
                .frame(minWidth: 800, minHeight: 600)
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

/// Main content view
struct ContentView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab: Int? = 0
    
    var body: some View {
        VStack {
            if appContainer.isInitialized {
                Text("🎉 Translation Fiesta Swift")
                    .font(.largeTitle)
                    .padding()
                
                Text("App is initialized and ready!")
                    .foregroundColor(.green)
                    .padding()
                
                // Simple test content instead of complex navigation
                VStack(spacing: 10) {
                    Text("Services loaded:")
                        .font(.headline)
                    
                    Text("✅ Network Service")
                    Text("✅ Translation Memory Service") 
                    Text("✅ Cost Tracking Service")
                    Text("✅ EPUB Processor")
                    Text("✅ Back Translation Use Case")
                    Text("✅ Export Use Case")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                Button("Test Translation") {
                    // Simple test action
                    print("Translation test button pressed!")
                }
                .padding()
                .buttonStyle(.borderedProminent)
                
            } else {
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(.circular)
                    
                    Text("Initializing Translation Fiesta...")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Setting up services...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("ContentView appeared")
            viewModel.configure(with: appContainer)
            // Marker for runtime verification
            try? "ContentView appeared".write(to: URL(fileURLWithPath: "/tmp/TranslationFiesta_ContentView_marker.txt"), atomically: true, encoding: .utf8)
        }
        .onChange(of: appContainer.isInitialized) { newValue in
            print("[Debug] ContentView observed appContainer.isInitialized = \(newValue)")
        }
    }
}

/// Sidebar navigation
struct Sidebar: View {
    @Binding var selectedTab: Int?
    
    var body: some View {
        List(selection: $selectedTab) {
            NavigationLink(value: 0) {
                Label("Translation", systemImage: "translate")
            }
            
            NavigationLink(value: 1) {
                Label("Batch Processing", systemImage: "folder.badge.gearshape")
            }
            
            NavigationLink(value: 2) {
                Label("Translation Memory", systemImage: "brain.head.profile")
            }
            
            NavigationLink(value: 3) {
                Label("Cost Tracking", systemImage: "dollarsign.circle")
            }
            
            NavigationLink(value: 4) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            
            #if os(macOS)
            NavigationLink(value: 5) {
                Label("Settings", systemImage: "gear")
            }
            #endif
        }
        .listStyle(SidebarListStyle())
        .navigationDestination(for: Int.self) { value in
            switch value {
            case 0:
                TranslationView()
            case 1:
                BatchProcessingView()
            case 2:
                TranslationMemoryView()
            case 3:
                CostTrackingView()
            case 4:
                ExportView()
            case 5:
                SettingsView()
            default:
                TranslationView()
            }
        }
    }
}

/// Main translation view for back-translation
struct TranslationView: View {
    @EnvironmentObject var appContainer: AppContainer
    @StateObject private var viewModel = TranslationViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // API Provider Selection
            HStack {
                Text("API Provider:")
                    .font(.headline)
                
                Picker("API Provider", selection: $viewModel.selectedAPIProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Input Text Area
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Input Text (English)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Load File") {
                        viewModel.showFileImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 150)
                    .border(Color.gray.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Translate Button
            HStack {
                Button("Translate") {
                    Task {
                        await viewModel.performBackTranslation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.inputText.isEmpty || viewModel.isTranslating)
                
                if viewModel.isTranslating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Spacer()
                
                if let result = viewModel.translationResult {
                    Text("Cost: $" + String(format: "%.4f", result.totalCost.costInUSD))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Results Area
            if let result = viewModel.translationResult {
                TranslationResultView(result: result)
            }
            
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.plainText, .html],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImport(result)
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

/// View for displaying translation results
struct TranslationResultView: View {
    let result: BackTranslationResult
    
    var body: some View {
        VStack(spacing: 16) {
            // Japanese Translation
            VStack(alignment: .leading, spacing: 8) {
                Text("Japanese Translation")
                    .font(.headline)
                
                Text(result.japanese)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            
            // Back-translated English
            VStack(alignment: .leading, spacing: 8) {
                Text("Back-translated English")
                    .font(.headline)
                
                Text(result.backTranslatedEnglish)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            
            // Quality Assessment
            HStack {
                VStack(alignment: .leading) {
                    Text("Quality Assessment")
                        .font(.headline)
                    
                    Text("BLEU Score: " + String(format: "%.3f", result.qualityAssessment.bleuScore))
                    Text("Confidence: \(result.qualityAssessment.confidenceLevel.displayName)")
                    Text("Rating: \(result.qualityAssessment.starRating.displayString)")
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Cost Information")
                        .font(.headline)
                    
                    Text("Characters: \(result.totalCost.characterCount)")
                    Text("Total Cost: $" + String(format: "%.4f", result.totalCost.costInUSD))
                    Text("Provider: \(result.totalCost.apiProvider.displayName)")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Recommendations
            if !result.qualityAssessment.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations")
                        .font(.headline)
                    
                    ForEach(Array(result.qualityAssessment.recommendations.enumerated()), id: \.offset) { index, recommendation in
                        Text("• \(recommendation)")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppContainer())
        .frame(width: 1000, height: 700)
}