import Foundation

/// Utilities for validating filesystem paths and URLs.
public enum PathValidator {
    /// Checks whether an executable exists at the given path and is executable.
    public static func validateExecutable(at path: String) -> Result<String, ExecutionError> {
        let expanded = NSString(string: path).expandingTildeInPath
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: expanded) else {
            return .failure(.executableNotFound(expanded))
        }
        guard fileManager.isExecutableFile(atPath: expanded) else {
            return .failure(.permissionDenied("File is not executable: \(expanded)"))
        }
        return .success(expanded)
    }

    /// Checks whether a script file exists at the given path.
    public static func validateScript(at path: String) -> Result<String, ExecutionError> {
        let expanded = NSString(string: path).expandingTildeInPath
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: expanded) else {
            return .failure(.scriptNotFound(expanded))
        }
        guard fileManager.isReadableFile(atPath: expanded) else {
            return .failure(.permissionDenied("Script file is not readable: \(expanded)"))
        }
        return .success(expanded)
    }

    /// Checks whether a working directory exists and is a directory.
    public static func validateWorkingDirectory(_ path: String?) -> Result<String?, ExecutionError> {
        guard let path = path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .success(nil)
        }
        let expanded = NSString(string: path).expandingTildeInPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
            return .success(expanded)
        }
        return .failure(.workingDirectoryNotFound(expanded))
    }

    /// Validates an HTTP or HTTPS URL.
    public static func validateURL(_ urlString: String) -> Result<URL, ExecutionError> {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil,
              !(url.host?.isEmpty ?? true) else {
            return .failure(.invalidURL(urlString))
        }
        return .success(url)
    }

    /// Checks if an application bundle exists.
    public static func validateApplication(at path: String) -> Result<String, ExecutionError> {
        let expanded = NSString(string: path).expandingTildeInPath
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: expanded) else {
            return .failure(.applicationNotFound(expanded))
        }
        return .success(expanded)
    }
}
