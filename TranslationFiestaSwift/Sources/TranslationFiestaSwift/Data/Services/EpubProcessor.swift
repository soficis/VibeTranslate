import Foundation
import ZIPFoundation

/// Minimal EPUB processor: extracts textual content from XHTML/HTML files inside EPUB.
public final class EpubProcessor {
    public init() {}

    /// Extracts readable text from the EPUB at `url` by unzipping and concatenating .xhtml/.html files.
    public func extractText(from url: URL) async throws -> String {
        // Perform extraction on a background thread to avoid blocking the main actor
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .utility).async {
                let threadInfo = Thread.isMainThread ? "main" : "background"
                print("[EpubProcessor] Starting extractText on \(threadInfo) thread for \(url.lastPathComponent)")

                let fileManager = FileManager.default
                let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

                    let archive = try Archive(url: url, accessMode: .read)
                    var aggregated = ""

                    for entry in archive {
                        let lower = entry.path.lowercased()
                        if lower.hasSuffix(".xhtml") || lower.hasSuffix(".html") || lower.hasSuffix(".htm") {
                            let destination = tempDir.appendingPathComponent(UUID().uuidString)
                            _ = try archive.extract(entry, to: destination)
                            if let data = try? Data(contentsOf: destination), let string = String(data: data, encoding: .utf8) {
                                let stripped = string.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                                aggregated += "\n" + stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }

                    // Clean up
                    try? fileManager.removeItem(at: tempDir)

                    print("[EpubProcessor] Finished extractText on \(threadInfo) thread; result length=\(aggregated.count)")
                    continuation.resume(returning: aggregated.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    try? fileManager.removeItem(at: tempDir)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
