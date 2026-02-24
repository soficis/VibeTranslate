import Foundation
import Logging

/// File processing service for loading and validating files.
public final class FileProcessingService: FileRepository {
    private let logger = Logger(label: "FileProcessingService")
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func loadFile(from url: URL) async throws -> TranslatableFile {
        guard fileManager.fileExists(atPath: url.path) else {
            throw TranslationError.fileNotSupported("File does not exist")
        }

        let pathExtension = url.pathExtension.lowercased()
        guard let fileType = SupportedFileType.fromFileExtension(pathExtension) else {
            throw TranslationError.fileNotSupported("Unsupported file type: \(pathExtension)")
        }

        let content: String

        switch fileType {
        case .text, .markdown:
            content = try String(contentsOf: url, encoding: .utf8)

        case .html:
            let htmlContent = try String(contentsOf: url, encoding: .utf8)
            content = try extractTextFromHTML(htmlContent)

        case .epub:
            throw TranslationError.notImplemented("EPUB processing")
        }

        logger.info("File loaded", metadata: [
            "path": "\(url.lastPathComponent)",
            "type": "\(fileType.rawValue)",
            "size": "\(content.count) characters"
        ])

        return try TranslatableFile(url: url, content: content, fileType: fileType)
    }

    public func saveTranslation(_ result: BackTranslationResult, to url: URL) async throws {
        let content = formatTranslationResult(result)
        try content.write(to: url, atomically: true, encoding: .utf8)

        logger.info("Translation saved", metadata: [
            "path": "\(url.lastPathComponent)",
            "size": "\(content.count) characters"
        ])
    }

    public func getSupportedFileTypes() -> [SupportedFileType] {
        SupportedFileType.allCases
    }

    public func validateFile(at url: URL) async throws -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        let pathExtension = url.pathExtension.lowercased()
        let isSupported = SupportedFileType.fromFileExtension(pathExtension) != nil

        if isSupported {
            // Additional validation - check file size (limit to 10MB)
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return fileSize <= 10 * 1024 * 1024
        }

        return false
    }

    private func extractTextFromHTML(_ html: String) throws -> String {
        // Simple HTML text extraction.
        var text = html

        let scriptPattern = "<script[^>]*>[\\s\\S]*?</script>"
        let stylePattern = "<style[^>]*>[\\s\\S]*?</style>"

        text = text.replacingOccurrences(of: scriptPattern, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: stylePattern, with: "", options: .regularExpression)

        let tagPattern = "<[^>]+>"
        text = text.replacingOccurrences(of: tagPattern, with: " ", options: .regularExpression)

        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    private func formatTranslationResult(_ result: BackTranslationResult) -> String {
        var output = "Translation Fiesta Swift - Back-Translation Result\n"
        output += "=" + String(repeating: "=", count: 50) + "\n\n"

        output += "Original English:\n\(result.originalEnglish)\n\n"
        output += "Japanese Translation:\n\(result.japanese)\n\n"
        output += "Back-translated English:\n\(result.backTranslatedEnglish)\n\n"

        output += "Timestamp: \(result.forwardTranslation.timestamp.formatted())\n"

        return output
    }
}

/// Batch processing service.
public final class BatchProcessingService: BatchRepository {
    private let logger = Logger(label: "BatchProcessingService")
    private let fileRepository: FileRepository
    private let backTranslationUseCase: BackTranslationUseCase

    private var runningOperations: [UUID: Task<Void, Error>] = [:]

    public init(
        fileRepository: FileRepository,
        backTranslationUseCase: BackTranslationUseCase
    ) {
        self.fileRepository = fileRepository
        self.backTranslationUseCase = backTranslationUseCase
    }

    public func startBatchOperation(_ operation: BatchOperation) async throws -> AsyncThrowingStream<BatchProgress, Error> {
        logger.info("Starting batch operation", metadata: [
            "id": "\(operation.id)",
            "fileCount": "\(operation.files.count)",
            "sourceLanguage": "\(operation.sourceLanguage.rawValue)",
            "targetLanguage": "\(operation.targetLanguage.rawValue)"
        ])

        return AsyncThrowingStream { continuation in
            let task = Task<Void, Error> {
                var mutableOperation = operation
                mutableOperation.status = .running

                for (_, file) in operation.files.enumerated() {
                    let startTime = CFAbsoluteTimeGetCurrent()

                    do {
                        let translationResult = try await backTranslationUseCase.execute(
                            text: file.content,
                            sourceLanguage: operation.sourceLanguage,
                            targetLanguage: operation.targetLanguage,
                            apiProvider: operation.apiProvider
                        )

                        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                        let batchResult = BatchTranslationResult(
                            fileId: file.id,
                            fileName: file.url.lastPathComponent,
                            success: true,
                            translationResult: translationResult,
                            processingTime: processingTime
                        )

                        mutableOperation.results.append(batchResult)
                        mutableOperation.progress.recordSuccess()

                        logger.debug("File processed successfully", metadata: [
                            "fileName": "\(file.url.lastPathComponent)",
                            "processingTime": "\(processingTime)"
                        ])

                    } catch {
                        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                        let batchResult = BatchTranslationResult(
                            fileId: file.id,
                            fileName: file.url.lastPathComponent,
                            success: false,
                            error: error.localizedDescription,
                            processingTime: processingTime
                        )

                        mutableOperation.results.append(batchResult)
                        mutableOperation.progress.recordFailure()

                        logger.error("File processing failed", metadata: [
                            "fileName": "\(file.url.lastPathComponent)",
                            "error": "\(error.localizedDescription)"
                        ])
                    }

                    continuation.yield(mutableOperation.progress)

                    if Task.isCancelled {
                        mutableOperation.status = .cancelled
                        mutableOperation.endTime = Date()
                        logger.info("Batch operation cancelled")
                        break
                    }
                }

                if !Task.isCancelled {
                    mutableOperation.status = .completed
                    mutableOperation.endTime = Date()

                    logger.info("Batch operation completed", metadata: [
                        "successfulFiles": "\(mutableOperation.progress.successfulFiles)",
                        "failedFiles": "\(mutableOperation.progress.failedFiles)",
                        "totalTime": "\(mutableOperation.duration ?? 0)"
                    ])
                }

                continuation.finish()
                runningOperations.removeValue(forKey: operation.id)
            }

            runningOperations[operation.id] = task

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func cancelBatchOperation(id: UUID) async throws {
        guard let task = runningOperations[id] else {
            throw TranslationError.invalidInput("Batch operation not found")
        }

        task.cancel()
        runningOperations.removeValue(forKey: id)

        logger.info("Batch operation cancelled", metadata: ["id": "\(id)"])
    }

    public func getBatchOperationStatus(id: UUID) async throws -> BatchOperation? {
        // In a real implementation, you'd store operation status.
        nil
    }

    public func getAllBatchOperations() async throws -> [BatchOperation] {
        // In a real implementation, you'd persist and return all operations.
        []
    }
}
