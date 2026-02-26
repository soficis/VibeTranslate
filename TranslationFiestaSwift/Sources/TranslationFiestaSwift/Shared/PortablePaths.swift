import Foundation

public enum PortablePaths {
    public static func dataRoot(fileManager: FileManager = .default) throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["TF_APP_HOME"],
           !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let overrideURL = URL(fileURLWithPath: overridePath, isDirectory: true)
            try fileManager.createDirectory(at: overrideURL, withIntermediateDirectories: true, attributes: nil)
            return overrideURL
        }

        let executablePath = CommandLine.arguments.first ?? fileManager.currentDirectoryPath
        let executableURL = URL(fileURLWithPath: executablePath)
        let appRoot = executableURL.deletingLastPathComponent()
        let dataURL = appRoot.appendingPathComponent("data", isDirectory: true)
        try fileManager.createDirectory(at: dataURL, withIntermediateDirectories: true, attributes: nil)
        return dataURL
    }

    public static func translationMemoryURL(
        persistencePath: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        try dataRoot(fileManager: fileManager).appendingPathComponent(persistencePath)
    }
}
