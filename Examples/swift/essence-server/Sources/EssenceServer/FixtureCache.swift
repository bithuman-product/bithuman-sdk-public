// FixtureCache — one `EssenceFixture` per avatarID, shared across
// every `EssenceRuntime` we spin up for that avatar.
//
// Why a cache: `Bithuman.loadEssenceFixture(modelPath:)` is the
// expensive call (~1–2 s, ~200 MB resident). Once loaded, building a
// runtime off it (`Bithuman.createRuntime(fixture:)`) is ~50–100 ms
// and adds only ~30–40 MB per instance. Hosting N concurrent avatars
// of the same model costs `200 + 30N` MB instead of `230N`.
//
// EssenceFixture is reference-counted — once every runtime built from
// it has been released, the fixture deallocates. We hold a strong
// reference here for the lifetime of the process, deliberately: the
// expectation is that `agent-root` has a small set of hot avatars
// that benefit from being kept warm. If avatar churn becomes a real
// concern, swap this for an LRU.

import Foundation
import bitHumanKit

actor FixtureCache {
    enum FixtureError: Error, CustomStringConvertible {
        case loadFailed(avatarID: String, path: String, underlying: Error)
        var description: String {
            switch self {
            case .loadFailed(let id, let path, let err):
                return "fixture load failed (\(id) at \(path)): \(err)"
            }
        }
    }

    private var fixtures: [String: EssenceFixture] = [:]
    private var inflight: [String: Task<EssenceFixture, Error>] = [:]

    /// Return a (cached) fixture for `avatarID`, loading from disk on
    /// first request. Concurrent callers for the same avatarID share a
    /// single load Task.
    func get(avatarID: String, imxPath: URL) async throws -> EssenceFixture {
        if let hit = fixtures[avatarID] { return hit }
        if let task = inflight[avatarID] { return try await task.value }

        let task = Task<EssenceFixture, Error> {
            do {
                return try Bithuman.loadEssenceFixture(modelPath: imxPath)
            } catch {
                throw FixtureError.loadFailed(avatarID: avatarID, path: imxPath.path, underlying: error)
            }
        }
        inflight[avatarID] = task
        defer { inflight[avatarID] = nil }

        let fixture = try await task.value
        fixtures[avatarID] = fixture
        return fixture
    }

    /// Number of avatars currently warm — surfaced via `/status` if
    /// useful for diagnostics.
    func warmCount() -> Int { fixtures.count }
    func warmIDs()   -> [String] { Array(fixtures.keys) }
}
