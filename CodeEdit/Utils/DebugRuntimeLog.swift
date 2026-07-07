import Foundation

@inline(__always)
func debugRuntimeLog(_ message: String) {
    #if DEBUG
    guard let data = "\(message)\n".data(using: .utf8) else { return }
    let logURL = URL(fileURLWithPath: "/tmp/codeedit_runtime.log")
    if FileManager.default.fileExists(atPath: logURL.path) {
        if let handle = try? FileHandle(forWritingTo: logURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
            return
        }
    } else {
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            try? handle.write(contentsOf: data)
            try? handle.close()
            return
        }
    }
    FileHandle.standardError.write(data)
    #endif
}
