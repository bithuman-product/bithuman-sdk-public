// ModelStore — lazy resolver for `{agentRoot}/{avatarID}/*.imx`.
//
// Mirrors the Python dispatcher's `_ensure_model_available`:
//   1. Glob the avatar's directory; return any matching .imx.
//   2. If absent and `modelURL` is provided, download to disk under a
//      `.downloading` lock then atomic-rename into place.
//   3. If absent and no URL, throw .notFound (the dispatcher returns 400).
//
// One actor for the whole process — serializes downloads of the same
// avatarID, doesn't block lookups for other avatars (all I/O happens
// inside the actor; concurrent readers of distinct avatars share zero
// state once the path is resolved).

import Foundation

actor ModelStore {
    enum ModelError: Error, CustomStringConvertible {
        case notFound(avatarID: String, root: String)
        case downloadFailed(URL, underlying: Error)
        case writeFailed(String, underlying: Error)

        var description: String {
            switch self {
            case .notFound(let id, let root):
                return "model not found: no .imx under \(root)/\(id)/ and no model_url provided"
            case .downloadFailed(let url, let err):
                return "model download failed (\(url.absoluteString)): \(err)"
            case .writeFailed(let path, let err):
                return "model write failed (\(path)): \(err)"
            }
        }
    }

    let agentRoot: URL
    private var inflight: [String: Task<URL, Error>] = [:]

    init(agentRoot: URL) { self.agentRoot = agentRoot }

    /// Resolve `avatarID` to a usable .imx path, downloading from
    /// `modelURL` if necessary. Concurrent calls for the same avatarID
    /// coalesce onto a single download Task.
    func resolve(avatarID: String, modelURL: URL?) async throws -> URL {
        if let hit = scan(avatarID: avatarID) { return hit }

        if let task = inflight[avatarID] {
            return try await task.value
        }
        guard let modelURL else {
            throw ModelError.notFound(avatarID: avatarID, root: agentRoot.path)
        }
        let task = Task<URL, Error> { [agentRoot] in
            try await Self.download(modelURL: modelURL, into: agentRoot, avatarID: avatarID)
        }
        inflight[avatarID] = task
        defer { inflight[avatarID] = nil }
        return try await task.value
    }

    private func scan(avatarID: String) -> URL? {
        let dir = agentRoot.appendingPathComponent(avatarID)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return nil }
        return entries.first(where: { $0.pathExtension == "imx" })
    }

    private static func download(modelURL: URL, into agentRoot: URL, avatarID: String) async throws -> URL {
        let dir = agentRoot.appendingPathComponent(avatarID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("model.imx")
        let tmp  = dir.appendingPathComponent(".model.imx.downloading")

        do {
            let (downloaded, _) = try await URLSession.shared.download(from: modelURL)
            // Atomic rename over `dest` — replaces any partial leftover.
            _ = try FileManager.default.replaceItemAt(dest, withItemAt: downloaded)
            try? FileManager.default.removeItem(at: tmp)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw ModelError.downloadFailed(modelURL, underlying: error)
        }
        return dest
    }
}
