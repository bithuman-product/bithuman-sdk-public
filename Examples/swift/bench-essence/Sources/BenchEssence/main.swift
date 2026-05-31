// BenchEssence — apples-to-apples Essence runtime perf + correctness
// bench harness. Sibling of bithuman-python-sdk/tools/bench_essence.py.
//
// See docs/architecture/essence-port-plan.md Appendix B for the
// metric definitions, warm-up protocol (50 discarded + 250 measured),
// and CSV / meta.json schema. Both this binary and the Python sibling
// MUST emit byte-identical column names + meta keys.
//
// Usage:
//   swift run -c release bench-essence \
//     --fixture path/to/avatar.imx \
//     --audio   path/to/16k_mono.wav \
//     --frames 300 --warmup 50 \
//     --output ./bench-out \
//     [--reference ./reference-frames]
//
// Output:
//   <output>/bench.csv      one row per measured frame
//   <output>/meta.json      summary metrics + host info + fixture sha256s
//
// The harness:
//   1. Loads the .imx via Bithuman.createRuntime, asserts .essence.
//   2. Loads the WAV (must already be 16 kHz mono int16 — resampling
//      is out of scope; the fixture corpus pre-pins this).
//   3. Times cold-start = wall from createRuntime() returning to first
//      frame yielded.
//   4. Drives audio through the runtime in 640-sample (40 ms) chunks,
//      one per frame. Discards `warmup` frames, measures the next
//      `frames - warmup`.
//   5. Per measured frame: wall_time_ms, cluster_idx, frame_sha256,
//      optional PSNR vs reference PNG.
//   6. Sidecar 100 Hz RSS sampler (mach_task_basic_info::resident_size_max),
//      max-aggregated.
//   7. Optional `powermetrics --samplers cpu_power -i 100 -n 50`
//      external invocation; reads back joules averaged over the run.
//   8. Emits CSV + meta.json matching Appendix B's schema.

import AVFoundation
import bitHumanKit
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox

// MARK: - Metallib bootstrap

/// Symlink `mlx.metallib` next to the bench-essence binary at startup.
///
/// SwiftPM's release build doesn't compile MLX's `.metal` shaders into
/// a `default.metallib` automatically, so MLX's `load_default_library`
/// fails on first GPU op. The `Plugins/MLXMetallibBuilder/` build-tool
/// plugin compiles the JIT kernel set into `mlx.metallib` and SwiftPM
/// bundles it into the BenchEssence resource bundle (`Bundle.module`);
/// MLX's loader only checks paths colocated with the binary. Symlink
/// once at startup before any `Bithuman.createRuntime` call.
// Metallib bootstrap disabled — moraga has Command Line Tools only
// (no Metal compiler), and the Essence runtime is CPU-only (NEON +
// Accelerate + vImage), so MLX's load_default_library is never called.
private let _ensureMetalLibraryAtStartup: Void = { () }()

// MARK: - CLI

struct CLIArgs {
    var fixture: URL?
    var audio: URL?
    var frames: Int = 300
    var warmup: Int = 50
    var output: URL?
    var reference: URL?
    var dryRun: Bool = false
    /// When > 0, switch to multi-instance memory check mode: load the
    /// fixture once, build N runtimes off it, drive a couple frames
    /// through each, report peak RSS at every step. Validates the
    /// shared-fixture path's per-instance memory delta.
    var multiInstance: Int = 0
    /// Frames per runtime in `--multi-instance` mode.
    var multiInstanceFrames: Int = 25

    static func parse() -> CLIArgs {
        let raw = Array(CommandLine.arguments.dropFirst())
        var args = CLIArgs()
        var i = 0
        while i < raw.count {
            let a = raw[i]
            func next() -> String? {
                guard i + 1 < raw.count else { return nil }
                i += 1
                return raw[i]
            }
            switch a {
            case "-h", "--help":
                printUsage()
                exit(0)
            case "--fixture":
                guard let v = next() else { fail("--fixture requires a value") }
                args.fixture = URL(fileURLWithPath: v)
            case "--audio":
                guard let v = next() else { fail("--audio requires a value") }
                args.audio = URL(fileURLWithPath: v)
            case "--frames":
                guard let v = next(), let n = Int(v), n > 0 else {
                    fail("--frames requires a positive integer")
                }
                args.frames = n
            case "--warmup":
                guard let v = next(), let n = Int(v), n >= 0 else {
                    fail("--warmup requires a non-negative integer")
                }
                args.warmup = n
            case "--output":
                guard let v = next() else { fail("--output requires a value") }
                args.output = URL(fileURLWithPath: v)
            case "--reference":
                guard let v = next() else { fail("--reference requires a value") }
                args.reference = URL(fileURLWithPath: v)
            case "--dry-run":
                args.dryRun = true
            case "--multi-instance":
                guard let v = next(), let n = Int(v), n > 0 else {
                    fail("--multi-instance requires a positive integer")
                }
                args.multiInstance = n
            case "--multi-instance-frames":
                guard let v = next(), let n = Int(v), n > 0 else {
                    fail("--multi-instance-frames requires a positive integer")
                }
                args.multiInstanceFrames = n
            default:
                fail("unknown arg: \(a)")
            }
            i += 1
        }
        return args
    }
}

func printUsage() {
    let usage = """
    bench-essence — apples-to-apples Essence runtime perf + correctness
    bench harness. See docs/architecture/essence-port-plan.md Appendix B.

    Usage:
      bench-essence --fixture <imx> --audio <wav> --output <dir> \\
        [--frames N=300] [--warmup N=50] [--reference <dir>] [--dry-run]

    Required:
      --fixture <path>   .imx Essence avatar bundle (pinned by sha256
                         in the fixture manifest).
      --audio   <path>   WAV file. Must be 16 kHz mono int16; resampling
                         is OUT OF SCOPE — fixtures pre-pin this.
      --output  <dir>    Output directory. Will be created. bench.csv
                         + meta.json are written here.

    Optional:
      --frames    <N>    Total frames to generate. Default 300.
      --warmup    <N>    First N frames discarded as cold/JIT warm.
                         Default 50. Measured = frames - warmup.
      --reference <dir>  Directory of NNNNN.png reference frames from
                         the OTHER SDK. If passed, PSNR per frame is
                         computed and recorded.
      --dry-run          Skip runtime construction; exercise the CSV
                         writer + RSS sampler with synthetic data.
                         Used by smoke tests.

    Apples-to-apples invariants (Appendix B, NON-NEGOTIABLE):
      - Same machine. Same .imx (sha256). Same WAV (sha256).
      - Discard first 50 frames; measure next 250. Default --frames=300.
      - Per-frame timing measured at SDK call boundary (no audio I/O).
      - peak_rss_mb sampled @100 Hz via mach_task_basic_info; the Python
        sibling uses resource.getrusage(RUSAGE_SELF).ru_maxrss (which on
        macOS reports BYTES, on Linux KB — both convert to MB).
      - sustained_fps = measured_frames / wall_seconds_across_them.
      - energy_joules optional, via `powermetrics --samplers cpu_power`.
    """
    FileHandle.standardError.write(Data((usage + "\n").utf8))
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("bench-essence: error: \(msg)\n".utf8))
    exit(2)
}

// MARK: - WAV loader (16 kHz int16 mono, strict)

enum WAVError: Error, CustomStringConvertible {
    case readFailed(String)
    case wrongSampleRate(Double)
    case wrongChannelCount(UInt32)
    case empty

    var description: String {
        switch self {
        case .readFailed(let s): return "WAV read failed: \(s)"
        case .wrongSampleRate(let r): return "WAV sample rate must be 16000, got \(Int(r))"
        case .wrongChannelCount(let c): return "WAV must be mono (1 channel), got \(c)"
        case .empty: return "WAV is empty"
        }
    }
}

func loadInt16Mono16k(_ url: URL) throws -> [Int16] {
    let file: AVAudioFile
    do {
        file = try AVAudioFile(forReading: url)
    } catch {
        throw WAVError.readFailed("\(error)")
    }
    let nativeFmt = file.processingFormat
    if nativeFmt.sampleRate != 16_000 {
        throw WAVError.wrongSampleRate(nativeFmt.sampleRate)
    }
    if nativeFmt.channelCount != 1 {
        throw WAVError.wrongChannelCount(nativeFmt.channelCount)
    }

    // Read into native (likely float32 mono) and convert to int16.
    let frameCount = AVAudioFrameCount(file.length)
    if frameCount == 0 { throw WAVError.empty }

    guard let nativeBuf = AVAudioPCMBuffer(pcmFormat: nativeFmt, frameCapacity: frameCount) else {
        throw WAVError.readFailed("alloc native buffer")
    }
    try file.read(into: nativeBuf)

    let int16Fmt = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!
    guard let i16Buf = AVAudioPCMBuffer(pcmFormat: int16Fmt, frameCapacity: frameCount) else {
        throw WAVError.readFailed("alloc int16 buffer")
    }
    let conv = AVAudioConverter(from: nativeFmt, to: int16Fmt)!
    var convErr: NSError?
    _ = conv.convert(to: i16Buf, error: &convErr) { _, status in
        status.pointee = .haveData
        return nativeBuf
    }
    if let convErr { throw WAVError.readFailed("convert: \(convErr)") }

    let n = Int(i16Buf.frameLength)
    guard let chans = i16Buf.int16ChannelData else { throw WAVError.readFailed("no int16 channel data") }
    return Array(UnsafeBufferPointer(start: chans[0], count: n))
}

// MARK: - sha256

func sha256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

func sha256OfFile(_ url: URL) throws -> String {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    return sha256Hex(data)
}

/// Render `image` into a tightly-packed RGB byte buffer (R, G, B per
/// pixel, row-major, no padding). Matches the Python sibling's
/// `np.array(PIL.Image.open(...).convert("RGB"))` convention so SHA256
/// + PSNR are computed on identical bytes.
func cgImageRGBBytes(_ image: CGImage) -> Data {
    let w = image.width
    let h = image.height
    // CG doesn't natively support 24-bit RGB contexts on Apple
    // platforms; we render into 32-bit RGBA then strip the alpha.
    let rgbaBytesPerRow = w * 4
    var rgba = [UInt8](repeating: 0, count: rgbaBytesPerRow * h)
    // Use explicit sRGB to match cv2 conventions; DeviceRGB picks up the
    // display profile on Apple Silicon and color-matches sRGB sources.
    let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    rgba.withUnsafeMutableBytes { ptr in
        guard let base = ptr.baseAddress else { return }
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        if let ctx = CGContext(
            data: base,
            width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: rgbaBytesPerRow,
            space: cs, bitmapInfo: info
        ) {
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
    }
    let bytesPerRow = w * 3
    var rgb = [UInt8](repeating: 0, count: bytesPerRow * h)
    for i in 0..<(w * h) {
        rgb[i * 3 + 0] = rgba[i * 4 + 0]
        rgb[i * 3 + 1] = rgba[i * 4 + 1]
        rgb[i * 3 + 2] = rgba[i * 4 + 2]
    }
    return Data(rgb)
}

// MARK: - PSNR

/// Peak-signal-to-noise ratio in dB between two equal-shape RGB byte
/// buffers. Matches the Python sibling's formula exactly:
/// `mse = mean((a - b)^2)`, `psnr = 10*log10(255^2 / mse)`. Returns
/// `+inf` when `mse == 0` (byte-identical frames).
func psnrRGB(_ a: Data, _ b: Data) -> Double {
    precondition(a.count == b.count, "PSNR inputs must be the same size")
    if a.count == 0 { return .infinity }
    var sumSq: UInt64 = 0
    a.withUnsafeBytes { ap in
        b.withUnsafeBytes { bp in
            let pa = ap.bindMemory(to: UInt8.self).baseAddress!
            let pb = bp.bindMemory(to: UInt8.self).baseAddress!
            for i in 0..<a.count {
                let d = Int(pa[i]) - Int(pb[i])
                sumSq &+= UInt64(d * d)
            }
        }
    }
    let mse = Double(sumSq) / Double(a.count)
    if mse == 0 { return .infinity }
    return 10.0 * log10(255.0 * 255.0 / mse)
}

// MARK: - Reference loader

/// Loads `<dir>/<frameIdx-padded-5>.png` if present and returns its
/// RGB bytes. Returns nil if the file doesn't exist.
func loadReferenceRGB(_ dir: URL, frameIdx: Int) -> Data? {
    let name = String(format: "%05d.png", frameIdx)
    let url = dir.appendingPathComponent(name)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        return nil
    }
    return cgImageRGBBytes(img)
}

// MARK: - RSS sampler (Mac, mach_task_basic_info)

/// Returns peak resident set size of THIS process in bytes, sampled
/// from `mach_task_basic_info::resident_size_max`. Matches the Python
/// sibling's `resource.getrusage(RUSAGE_SELF).ru_maxrss`; both report
/// the high-water mark, both convert to MB on emit.
func currentPeakRSSBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) { infoPtr -> kern_return_t in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPtr, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return 0 }
    return UInt64(info.resident_size_max)
}

/// Background sampler that polls peak RSS at 100 Hz and reports the
/// max it ever saw on `stop()`.
final class RSSSampler: @unchecked Sendable {
    private let queue = DispatchQueue(label: "bench-essence.rss")
    private var maxBytes: UInt64 = 0
    private var stopped: Bool = false
    private let lock = NSLock()
    private let intervalNs: UInt64 = 10_000_000  // 10 ms = 100 Hz

    func start() {
        queue.async { [weak self] in
            while let self {
                self.lock.lock()
                if self.stopped { self.lock.unlock(); return }
                self.lock.unlock()
                let cur = currentPeakRSSBytes()
                self.lock.lock()
                if cur > self.maxBytes { self.maxBytes = cur }
                self.lock.unlock()
                Thread.sleep(forTimeInterval: TimeInterval(self.intervalNs) / 1e9)
            }
        }
    }

    /// Stop and return peak RSS in megabytes (decimal MB, matching Python).
    func stopAndReportMB() -> Double {
        lock.lock()
        stopped = true
        // Take one last sample so an extremely short run still gets a value.
        let last = currentPeakRSSBytes()
        if last > maxBytes { maxBytes = last }
        let bytes = maxBytes
        lock.unlock()
        return Double(bytes) / (1024.0 * 1024.0)
    }
}

// MARK: - powermetrics

/// Runs `powermetrics --samplers cpu_power -i 100 -n 50` synchronously,
/// parses the average CPU Power lines, and converts to total joules
/// over the sampling window. Returns nil if powermetrics isn't
/// available, fails (it requires sudo on most setups), or the output
/// can't be parsed.
///
/// Note on energy units: `powermetrics` reports power in mW (or W
/// depending on macOS version). We sum power across the 50 100-ms
/// samples = 5 s window: `J = sum(W_i * 0.1)`. Mac-only.
func runPowermetrics(intervalMs: Int = 100, samples: Int = 50) -> Double? {
    // Skipped on moraga capacity-test runs — powermetrics needs sudo, and we
    // care about CPU/RAM/throughput, not joules.
    return nil
    let p = Process()
    p.launchPath = "/usr/bin/sudo"
    p.arguments = [
        "-n",  // non-interactive; if no NOPASSWD this fails immediately
        "powermetrics",
        "--samplers", "cpu_power",
        "-i", "\(intervalMs)",
        "-n", "\(samples)",
    ]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    do {
        try p.run()
    } catch {
        return nil
    }
    p.waitUntilExit()
    if p.terminationStatus != 0 { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let txt = String(data: data, encoding: .utf8) else { return nil }
    return parsePowermetricsJoules(txt, intervalMs: intervalMs)
}

func parsePowermetricsJoules(_ output: String, intervalMs: Int) -> Double? {
    // Look for lines like:
    //   "CPU Power: 1234 mW"  or  "Combined Power (CPU + GPU + ANE): 1.5 W"
    // Sum the numeric values, treating mW as mW, W as W.
    var totalJ: Double = 0
    var matched = 0
    let intervalSec = Double(intervalMs) / 1000.0
    for line in output.split(separator: "\n") {
        let s = String(line)
        guard s.lowercased().contains("cpu power:") else { continue }
        // Tail after the colon.
        guard let colon = s.firstIndex(of: ":") else { continue }
        let tail = s[s.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        // Expect "<num> mW" or "<num> W".
        let parts = tail.split(separator: " ", maxSplits: 1).map { String($0) }
        guard parts.count == 2, let v = Double(parts[0]) else { continue }
        let watts: Double
        switch parts[1].lowercased() {
        case "mw": watts = v / 1000.0
        case "w":  watts = v
        default:   continue
        }
        totalJ += watts * intervalSec
        matched += 1
    }
    return matched > 0 ? totalJ : nil
}

// MARK: - CSV writer

struct FrameRow {
    let frameIdx: Int
    let wallTimeMs: Double
    let clusterIdx: Int
    let frameSha256: String
    /// `nil` when no reference dir was passed; `+inf` for byte-identical frames.
    let psnrVsReference: Double?
}

struct CSVWriter {
    let url: URL

    func write(_ rows: [FrameRow]) throws {
        var lines = ["frame_idx,wall_time_ms,cluster_idx,frame_sha256,psnr_vs_reference"]
        for r in rows {
            let psnrField: String
            if let p = r.psnrVsReference {
                if p.isInfinite {
                    psnrField = "inf"
                } else {
                    psnrField = String(format: "%.6f", p)
                }
            } else {
                psnrField = ""
            }
            // `%.6f` for ms is enough — 1 ns resolution.
            lines.append(String(
                format: "%d,%.6f,%d,%@,%@",
                r.frameIdx, r.wallTimeMs, r.clusterIdx,
                r.frameSha256 as NSString, psnrField as NSString
            ))
        }
        let blob = lines.joined(separator: "\n") + "\n"
        try blob.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - meta.json

struct MetaHostInfo: Encodable {
    let machine: String
    let os: String
    let mlx_version: String
    let cpu_count: Int
    let physical_memory_bytes: UInt64
}

struct MetaFixture: Encodable {
    let imx_path: String
    let imx_sha256: String
    let audio_path: String
    let audio_sha256: String
    let frame_count_total: Int
    let warmup_frames: Int
    let measured_frames: Int
}

struct MetaMetrics: Encodable {
    let cold_start_ms: Double
    let per_frame_ms_mean: Double
    let per_frame_ms_p99: Double
    let peak_rss_mb: Double
    let sustained_fps: Double
    let energy_joules: Double?

    // Swift's default Optional encoding omits the key when the value
    // is nil, which would drift from the Python sibling's
    // `json.dumps(asdict(...))` (which emits `"energy_joules": null`).
    // Force-emit the key so both sides have an identical meta.json
    // schema regardless of whether powermetrics ran.
    enum CodingKeys: String, CodingKey {
        case cold_start_ms, per_frame_ms_mean, per_frame_ms_p99
        case peak_rss_mb, sustained_fps, energy_joules
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cold_start_ms, forKey: .cold_start_ms)
        try c.encode(per_frame_ms_mean, forKey: .per_frame_ms_mean)
        try c.encode(per_frame_ms_p99, forKey: .per_frame_ms_p99)
        try c.encode(peak_rss_mb, forKey: .peak_rss_mb)
        try c.encode(sustained_fps, forKey: .sustained_fps)
        if let e = energy_joules {
            try c.encode(e, forKey: .energy_joules)
        } else {
            try c.encodeNil(forKey: .energy_joules)
        }
    }
}

struct MetaCorrectness: Encodable {
    let reference_dir: String?
    let psnr_mean: Double?
    let psnr_min: Double?
    let psnr_p1: Double?
    let frames_with_reference: Int

    // Force-emit nullable keys (see MetaMetrics for rationale).
    enum CodingKeys: String, CodingKey {
        case reference_dir, psnr_mean, psnr_min, psnr_p1, frames_with_reference
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let v = reference_dir { try c.encode(v, forKey: .reference_dir) }
        else { try c.encodeNil(forKey: .reference_dir) }
        if let v = psnr_mean { try c.encode(v, forKey: .psnr_mean) }
        else { try c.encodeNil(forKey: .psnr_mean) }
        if let v = psnr_min { try c.encode(v, forKey: .psnr_min) }
        else { try c.encodeNil(forKey: .psnr_min) }
        if let v = psnr_p1 { try c.encode(v, forKey: .psnr_p1) }
        else { try c.encodeNil(forKey: .psnr_p1) }
        try c.encode(frames_with_reference, forKey: .frames_with_reference)
    }
}

struct Meta: Encodable {
    let sdk: String
    let sdk_version: String
    let host: MetaHostInfo
    let fixture: MetaFixture
    let metrics: MetaMetrics
    let correctness: MetaCorrectness
}

func hostMachineString() -> String {
    // `uname.machine` is a fixed-size C char array; Swift imports it
    // as a tuple. `sysctlbyname("hw.machine", ...)` is the cleaner
    // path and gives the same answer (e.g. "arm64", "x86_64") plus
    // `hw.model` for the human-readable model string.
    var size: size_t = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    if size > 0 {
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        return String(cString: buf)
    }
    return "unknown"
}

func hostInfo() -> MetaHostInfo {
    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    let cpuCount = ProcessInfo.processInfo.processorCount
    let physMem = ProcessInfo.processInfo.physicalMemory
    // mlx_version: not trivially queryable from Swift at runtime.
    // Leave as the build-pinned major; the Python side fills the
    // resolved version. Both sides record the value they have.
    let mlxVersion = "0.31.x (Package.swift pin)"
    return MetaHostInfo(
        machine: hostMachineString(),
        os: osVersion,
        mlx_version: mlxVersion,
        cpu_count: cpuCount,
        physical_memory_bytes: physMem
    )
}

// MARK: - Stats helpers

func percentile(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return .nan }
    let sorted = values.sorted()
    let pos = max(0.0, min(1.0, p)) * Double(sorted.count - 1)
    let lo = Int(pos.rounded(.down))
    let hi = min(lo + 1, sorted.count - 1)
    let frac = pos - Double(lo)
    return sorted[lo] * (1 - frac) + sorted[hi] * frac
}

func mean(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return .nan }
    return values.reduce(0, +) / Double(values.count)
}

// MARK: - Dry-run mode (smoke test for CSV writer + RSS sampler)

func runDryRun(output: URL) throws {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let sampler = RSSSampler()
    sampler.start()
    var rows: [FrameRow] = []
    let measuredCount = 5
    for i in 0..<measuredCount {
        let t0 = DispatchTime.now().uptimeNanoseconds
        // Pretend we did some work.
        Thread.sleep(forTimeInterval: 0.005)
        let t1 = DispatchTime.now().uptimeNanoseconds
        rows.append(FrameRow(
            frameIdx: i,
            wallTimeMs: Double(t1 - t0) / 1_000_000.0,
            clusterIdx: i % 7,
            frameSha256: String(repeating: "0", count: 64),
            psnrVsReference: nil
        ))
    }
    let peakMB = sampler.stopAndReportMB()
    let csvURL = output.appendingPathComponent("bench.csv")
    try CSVWriter(url: csvURL).write(rows)

    let times = rows.map { $0.wallTimeMs }
    let metaURL = output.appendingPathComponent("meta.json")
    let meta = Meta(
        sdk: "swift",
        sdk_version: "0.0.0-dryrun",
        host: hostInfo(),
        fixture: MetaFixture(
            imx_path: "<dry-run>",
            imx_sha256: String(repeating: "0", count: 64),
            audio_path: "<dry-run>",
            audio_sha256: String(repeating: "0", count: 64),
            frame_count_total: measuredCount,
            warmup_frames: 0,
            measured_frames: measuredCount
        ),
        metrics: MetaMetrics(
            cold_start_ms: 0,
            per_frame_ms_mean: mean(times),
            per_frame_ms_p99: percentile(times, 0.99),
            peak_rss_mb: peakMB,
            sustained_fps: 0,
            energy_joules: nil
        ),
        correctness: MetaCorrectness(
            reference_dir: nil,
            psnr_mean: nil,
            psnr_min: nil,
            psnr_p1: nil,
            frames_with_reference: 0
        )
    )
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try enc.encode(meta)
    try data.write(to: metaURL)
    print("dry-run wrote \(csvURL.path) and \(metaURL.path); peak_rss_mb=\(String(format: "%.2f", peakMB))")
}

// MARK: - Multi-instance memory check

/// Validates the shared-fixture API: load one ``EssenceFixture``,
/// build N runtimes off it, drive a few frames through each, sample
/// peak RSS at each step. Reports the per-instance RSS delta — the
/// metric that matters for "how many concurrent avatars fit on this
/// machine."
func runMultiInstanceCheck(args: CLIArgs) async throws {
    guard let fixture = args.fixture else { fail("--fixture is required") }
    guard let audio = args.audio else { fail("--audio is required") }
    if !FileManager.default.fileExists(atPath: fixture.path) {
        fail("fixture not found: \(fixture.path)")
    }
    if !FileManager.default.fileExists(atPath: audio.path) {
        fail("audio not found: \(audio.path)")
    }

    let n = args.multiInstance
    let perInstanceFrames = args.multiInstanceFrames
    let samplesPerFrame = 640
    let samples = try loadInt16Mono16k(audio)
    if samples.count < perInstanceFrames * samplesPerFrame {
        fail("audio has \(samples.count) samples; need \(perInstanceFrames * samplesPerFrame) for \(perInstanceFrames) frames")
    }

    func mb(_ bytes: UInt64) -> Double { Double(bytes) / (1024.0 * 1024.0) }
    let baselineRSS = currentPeakRSSBytes()
    print(String(format: "multi-instance check: N=%d, framesPerInstance=%d", n, perInstanceFrames))
    print(String(format: "  baseline RSS                                    %8.2f MB", mb(baselineRSS)))

    let fixtureLoadStart = DispatchTime.now().uptimeNanoseconds
    let essenceFixture = try Bithuman.loadEssenceFixture(modelPath: fixture)
    let fixtureLoadEnd = DispatchTime.now().uptimeNanoseconds
    let fixtureLoadMs = Double(fixtureLoadEnd - fixtureLoadStart) / 1_000_000.0
    let postFixtureRSS = currentPeakRSSBytes()
    print(String(format: "  fixture loaded in %.1f ms; RSS                  %8.2f MB  (Δ %+8.2f)",
                 fixtureLoadMs, mb(postFixtureRSS), mb(postFixtureRSS) - mb(baselineRSS)))

    var runtimes: [EssenceRuntime] = []
    runtimes.reserveCapacity(n)
    var rssAfter: [UInt64] = []
    rssAfter.reserveCapacity(n)
    for k in 0..<n {
        let createStart = DispatchTime.now().uptimeNanoseconds
        let rt = try Bithuman.createRuntime(fixture: essenceFixture)
        let createEnd = DispatchTime.now().uptimeNanoseconds
        let createMs = Double(createEnd - createStart) / 1_000_000.0
        // Drive a small audio batch to populate per-instance LRU + composedCache.
        for idx in 0..<perInstanceFrames {
            let off = idx * samplesPerFrame
            let chunk = Array(samples[off..<(off + samplesPerFrame)])
            _ = try await rt._generateFrameDetailedForBench(audioChunk: chunk)
        }
        runtimes.append(rt)
        let rss = currentPeakRSSBytes()
        rssAfter.append(rss)
        let priorRSS = k == 0 ? postFixtureRSS : rssAfter[k - 1]
        print(String(format: "  +runtime[%2d] built in %.1f ms + drove %d frames; RSS %8.2f MB  (Δ %+7.2f)",
                     k, createMs, perInstanceFrames, mb(rss), mb(rss) - mb(priorRSS)))
    }

    let finalRSS = rssAfter.last ?? postFixtureRSS
    let totalSharedDelta = mb(postFixtureRSS) - mb(baselineRSS)
    let totalRuntimesDelta = mb(finalRSS) - mb(postFixtureRSS)
    let perInstanceMean = n > 0 ? totalRuntimesDelta / Double(n) : 0
    print("---")
    print(String(format: "  fixture buffers (shared once)                  %8.2f MB", totalSharedDelta))
    print(String(format: "  N=%d runtime instances delta                    %8.2f MB  (mean %.2f MB / runtime)",
                 n, totalRuntimesDelta, perInstanceMean))
    print(String(format: "  total RSS at end                               %8.2f MB", mb(finalRSS)))

    // Verify all runtimes produced consistent idle frames (their
    // pre-computed shared CGImage should be byte-identical).
    let firstIdle = await runtimes[0].idleFrame
    var allMatch = true
    for k in 1..<runtimes.count {
        let img = await runtimes[k].idleFrame
        if img.width != firstIdle.width || img.height != firstIdle.height {
            allMatch = false
            print("  ⚠ runtime[\(k)].idleFrame dim mismatch: \(img.width)×\(img.height) vs \(firstIdle.width)×\(firstIdle.height)")
        }
    }
    if allMatch {
        print(String(format: "  ✓ all %d runtimes report identical idleFrame dims (%dx%d)",
                     n, firstIdle.width, firstIdle.height))
    }

    // ── Concurrent real-time stress (moraga capacity test) ────────────
    //
    // The serial check above proves N runtimes FIT in memory. This phase
    // proves they can be DRIVEN at 25 FPS concurrently. Spawn N async
    // tasks; each pushes one 640-sample chunk per "tick" for `concurrentTicks`
    // ticks; we measure aggregate p50/p99 frame time and whether any
    // runtime fell behind real-time (> 40 ms / frame).
    let concurrentTicks = ProcessInfo.processInfo.environment["BITHUMAN_CONC_TICKS"].flatMap { Int($0) } ?? 75
    let h264Enabled = ProcessInfo.processInfo.environment["BITHUMAN_BENCH_H264"] == "1"
    if concurrentTicks > 0, samples.count >= concurrentTicks * samplesPerFrame {
        print("---")
        let mode = h264Enabled ? "render + H.264 encode (VideoToolbox HW)" : "render only"
        print(String(format: "  concurrent real-time drive: N=%d × %d ticks (%@) — target 40 ms/frame @ 25 FPS",
                     n, concurrentTicks, mode))
        // Pre-slice the audio chunks once so per-tick overhead is just the dispatch.
        var chunks: [[Int16]] = []
        chunks.reserveCapacity(concurrentTicks)
        for t in 0..<concurrentTicks {
            let off = t * samplesPerFrame
            chunks.append(Array(samples[off..<(off + samplesPerFrame)]))
        }
        actor TimingCollector {
            var samples: [Double] = []
            func add(_ ms: Double) { samples.append(ms) }
        }
        let collector = TimingCollector()
        // Resolution is fixed per fixture; query once for VTCompressionSession setup.
        let firstRt = runtimes[0]
        let resolution = await firstRt.resolution
        let outW = Int32(resolution.width)
        let outH = Int32(resolution.height)
        let wallStart = DispatchTime.now().uptimeNanoseconds
        await withTaskGroup(of: Void.self) { group in
            for k in 0..<n {
                let rt = runtimes[k]
                let myChunks = chunks
                group.addTask {
                    // Each task owns its own H.264 encoder (production server
                    // would have one per session for independent egress).
                    var encSession: VTCompressionSession?
                    if h264Enabled {
                        let attrs: [String: Any] = [
                            kVTCompressionPropertyKey_RealTime as String: true,
                            kVTCompressionPropertyKey_AllowFrameReordering as String: false,
                        ]
                        VTCompressionSessionCreate(
                            allocator: nil, width: outW, height: outH,
                            codecType: kCMVideoCodecType_H264,
                            encoderSpecification: nil,
                            imageBufferAttributes: nil,
                            compressedDataAllocator: nil,
                            outputCallback: nil, refcon: nil,
                            compressionSessionOut: &encSession)
                        if let s = encSession {
                            for (k, v) in attrs {
                                VTSessionSetProperty(s, key: k as CFString, value: v as CFTypeRef)
                            }
                            VTSessionSetProperty(s, key: kVTCompressionPropertyKey_AverageBitRate, value: 2_000_000 as CFNumber)
                            VTSessionSetProperty(s, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 25 as CFNumber)
                            VTCompressionSessionPrepareToEncodeFrames(s)
                        }
                    }
                    var pts = CMTime(value: 0, timescale: 25)
                    for chunk in myChunks {
                        let s = DispatchTime.now().uptimeNanoseconds
                        let detail = try? await rt._generateFrameDetailedForBench(audioChunk: chunk)
                        if h264Enabled, let img = detail?.image, let session = encSession {
                            // CGImage → CVPixelBuffer (BGRA), then encode.
                            var pb: CVPixelBuffer?
                            let pbAttrs: [String: Any] = [
                                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                            ]
                            CVPixelBufferCreate(nil, Int(outW), Int(outH),
                                                kCVPixelFormatType_32BGRA,
                                                pbAttrs as CFDictionary, &pb)
                            if let pixelBuffer = pb {
                                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                                let ctx = CGContext(
                                    data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                    width: Int(outW), height: Int(outH),
                                    bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                              | CGBitmapInfo.byteOrder32Little.rawValue
                                )
                                ctx?.draw(img, in: CGRect(x: 0, y: 0, width: Int(outW), height: Int(outH)))
                                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                                VTCompressionSessionEncodeFrame(
                                    session, imageBuffer: pixelBuffer,
                                    presentationTimeStamp: pts,
                                    duration: CMTime(value: 1, timescale: 25),
                                    frameProperties: nil,
                                    sourceFrameRefcon: nil,
                                    infoFlagsOut: nil)
                                VTCompressionSessionCompleteFrames(session,
                                    untilPresentationTimeStamp: pts)
                            }
                            pts = CMTime(value: pts.value + 1, timescale: 25)
                        }
                        let e = DispatchTime.now().uptimeNanoseconds
                        await collector.add(Double(e - s) / 1_000_000.0)
                    }
                    if let s = encSession { VTCompressionSessionInvalidate(s) }
                }
            }
        }
        let wallEnd = DispatchTime.now().uptimeNanoseconds
        let wallSec = Double(wallEnd - wallStart) / 1e9
        let timings = await collector.samples
        let sorted = timings.sorted()
        let p50 = sorted[sorted.count / 2]
        let p99 = sorted[Int(Double(sorted.count) * 0.99)]
        let mean = timings.reduce(0, +) / Double(timings.count)
        let maxMs = sorted.last ?? 0
        let overBudget = timings.filter { $0 > 40.0 }.count
        let totalFrames = timings.count
        let aggregateFps = Double(totalFrames) / wallSec
        let perInstanceFps = aggregateFps / Double(n)
        let realTimeRatio = perInstanceFps / 25.0
        print(String(format: "  wall=%.2fs  total_frames=%d  aggregate_fps=%.1f  per_instance_fps=%.2f (real-time ratio %.2fx)",
                     wallSec, totalFrames, aggregateFps, perInstanceFps, realTimeRatio))
        print(String(format: "  per-frame ms — mean=%.2f  p50=%.2f  p99=%.2f  max=%.2f  over_40ms=%d (%.1f%%)",
                     mean, p50, p99, maxMs, overBudget, 100.0 * Double(overBudget) / Double(totalFrames)))
    }

    _ = runtimes  // pin for measurement; release happens at scope exit
}

// MARK: - Main

func runBench(args: CLIArgs) async throws {
    guard let fixture = args.fixture else { fail("--fixture is required") }
    guard let audio = args.audio else { fail("--audio is required") }
    guard let output = args.output else { fail("--output is required") }
    guard args.warmup < args.frames else {
        fail("--warmup (\(args.warmup)) must be < --frames (\(args.frames))")
    }
    if !FileManager.default.fileExists(atPath: fixture.path) {
        fail("fixture not found: \(fixture.path)")
    }
    if !FileManager.default.fileExists(atPath: audio.path) {
        fail("audio not found: \(audio.path)")
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    // --- Hash inputs ---------------------------------------------------
    let imxSha = try sha256OfFile(fixture)
    let audioSha = try sha256OfFile(audio)

    // --- Load WAV ------------------------------------------------------
    let samples = try loadInt16Mono16k(audio)
    let samplesPerFrame = 640  // 16 kHz / 25 fps
    let needSamples = samplesPerFrame * args.frames
    if samples.count < needSamples {
        fail("audio has \(samples.count) samples; need at least \(needSamples) for \(args.frames) frames at 25 FPS / 16 kHz")
    }

    // --- Start RSS sampler --------------------------------------------
    let rss = RSSSampler()
    rss.start()

    // --- Load runtime + cold-start timer ------------------------------
    let createReturnedAt = DispatchTime.now().uptimeNanoseconds
    let runtimeSum = try Bithuman.createRuntime(modelPath: fixture)
    guard case .essence(let runtime) = runtimeSum else {
        fail(".imx is not an Essence model (createRuntime returned \(runtimeSum))")
    }

    // --- Optional: dump audio encoder embedding for a fixed mel input
    // Used to verify the Swift MLX encoder agrees with the ONNX
    // reference. BITHUMAN_DUMP_EMB=<melPath>:<outPath> reads a raw
    // float32 mel of shape (1, 1, 80, 16) and writes the (1, 512, 1, 1)
    // embedding as flat row-major float32 to outPath. After the dump
    // the bench exits cleanly so the comparator can run against it.
    if let spec = ProcessInfo.processInfo.environment["BITHUMAN_DUMP_EMB"] {
        let parts = spec.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { fail("BITHUMAN_DUMP_EMB must be melPath:outPath") }
        let melData = try Data(contentsOf: URL(fileURLWithPath: parts[0]))
        let melCount = 80 * 16
        guard melData.count == melCount * MemoryLayout<Float>.size else {
            fail("mel input must be \(melCount) float32 values; got \(melData.count) bytes")
        }
        var mel = [Float](repeating: 0, count: melCount)
        _ = mel.withUnsafeMutableBytes { dst in
            melData.copyBytes(to: dst, count: melData.count)
        }
        let emb = await runtime._encodeMelForBench(mel: mel)
        let outURL = URL(fileURLWithPath: parts[1])
        let outBytes = emb.withUnsafeBufferPointer { bp in
            Data(bytes: bp.baseAddress!, count: bp.count * MemoryLayout<Float>.size)
        }
        try outBytes.write(to: outURL)
        print("wrote \(emb.count) float32 embedding values to \(outURL.path)")
        return
    }

    // --- Run frames ----------------------------------------------------
    var firstFrameWallNs: UInt64 = 0
    var rows: [FrameRow] = []
    rows.reserveCapacity(args.frames - args.warmup)
    var measuredStartNs: UInt64 = 0
    var measuredEndNs: UInt64 = 0

    let referenceDir = args.reference
    if let r = referenceDir, !FileManager.default.fileExists(atPath: r.path) {
        fail("reference dir does not exist: \(r.path)")
    }

    for idx in 0..<args.frames {
        let off = idx * samplesPerFrame
        let chunk = Array(samples[off..<(off + samplesPerFrame)])

        let frameStart = DispatchTime.now().uptimeNanoseconds
        let detail = try await runtime._generateFrameDetailedForBench(audioChunk: chunk)
        let frameEnd = DispatchTime.now().uptimeNanoseconds

        if firstFrameWallNs == 0 { firstFrameWallNs = frameEnd }

        // BITHUMAN_DUMP_EMB_NORM=1 prints the encoder embedding L2
        // norm per frame so the int8 vs fp32 divergence (the v0.18.4
        // cluster-collapse bug) can be diagnosed without a full
        // numpy round-trip. fp32 path embeddings on real audio sit
        // around |emb| ≈ 5–8; int8 path tends to ≈ 1–2 when the
        // collapse is firing.
        if ProcessInfo.processInfo.environment["BITHUMAN_DUMP_EMB_NORM"] == "1" {
            FileHandle.standardError.write(Data(
                String(format: "frame=%4d cluster=%3d |emb|=%6.3f\n",
                       idx, detail.clusterIdx, detail.embedNorm).utf8
            ))
        }

        if idx >= args.warmup {
            if measuredStartNs == 0 { measuredStartNs = frameStart }
            measuredEndNs = frameEnd

            let rgb = cgImageRGBBytes(detail.image)
            let sha = sha256Hex(rgb)

            // Dump first 5 measured frames to <output>/frames/NNNNN.png for
            // visual debug. Always on for now — cheap, ~5 PNGs total.
            if idx - args.warmup < 5 {
                let framesDir = output.appendingPathComponent("frames")
                try? FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
                let fname = String(format: "%05d.png", idx)
                let pngURL = framesDir.appendingPathComponent(fname)
                if let dest = CGImageDestinationCreateWithURL(pngURL as CFURL, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(dest, detail.image, nil)
                    _ = CGImageDestinationFinalize(dest)
                }
            }

            var psnr: Double? = nil
            if let refDir = referenceDir,
               let refRGB = loadReferenceRGB(refDir, frameIdx: idx),
               refRGB.count == rgb.count {
                psnr = psnrRGB(rgb, refRGB)
            }

            rows.append(FrameRow(
                frameIdx: idx,
                wallTimeMs: Double(frameEnd - frameStart) / 1_000_000.0,
                clusterIdx: detail.clusterIdx,
                frameSha256: sha,
                psnrVsReference: psnr
            ))
        }
    }

    let coldStartMs = Double(firstFrameWallNs - createReturnedAt) / 1_000_000.0
    let peakRSSMB = rss.stopAndReportMB()

    // --- Optional energy measurement (mac only) -----------------------
    // Per spec we run powermetrics OVER the measured window, but since
    // it samples at 100 ms × 50 = 5 s, and our measured window may be
    // shorter or longer, we run it after the fact on a quiescent run
    // — same spec command as the Python side, same parsing.
    let energy = runPowermetrics()

    // --- Aggregate metrics --------------------------------------------
    let times = rows.map { $0.wallTimeMs }
    let measuredFrames = rows.count
    let measuredWallSec = Double(measuredEndNs - measuredStartNs) / 1e9
    let sustainedFps = measuredWallSec > 0 ? Double(measuredFrames) / measuredWallSec : 0

    // Correctness aggregates.
    let psnrValues: [Double] = rows.compactMap { row -> Double? in
        guard let p = row.psnrVsReference else { return nil }
        // Skip +inf for distribution stats (it'd skew p1/min).
        return p.isInfinite ? nil : p
    }
    let psnrMean: Double? = psnrValues.isEmpty ? nil : mean(psnrValues)
    let psnrMin: Double? = psnrValues.isEmpty ? nil : psnrValues.min()
    let psnrP1: Double? = psnrValues.isEmpty ? nil : percentile(psnrValues, 0.01)
    let framesWithRef = rows.filter { $0.psnrVsReference != nil }.count

    // --- Write CSV + meta.json ----------------------------------------
    let csvURL = output.appendingPathComponent("bench.csv")
    try CSVWriter(url: csvURL).write(rows)

    let meta = Meta(
        sdk: "swift",
        sdk_version: bithumanSDKVersion(),
        host: hostInfo(),
        fixture: MetaFixture(
            imx_path: fixture.path,
            imx_sha256: imxSha,
            audio_path: audio.path,
            audio_sha256: audioSha,
            frame_count_total: args.frames,
            warmup_frames: args.warmup,
            measured_frames: measuredFrames
        ),
        metrics: MetaMetrics(
            cold_start_ms: coldStartMs,
            per_frame_ms_mean: mean(times),
            per_frame_ms_p99: percentile(times, 0.99),
            peak_rss_mb: peakRSSMB,
            sustained_fps: sustainedFps,
            energy_joules: energy
        ),
        correctness: MetaCorrectness(
            reference_dir: referenceDir?.path,
            psnr_mean: psnrMean,
            psnr_min: psnrMin,
            psnr_p1: psnrP1,
            frames_with_reference: framesWithRef
        )
    )
    let metaURL = output.appendingPathComponent("meta.json")
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.nonConformingFloatEncodingStrategy = .convertToString(
        positiveInfinity: "Infinity",
        negativeInfinity: "-Infinity",
        nan: "NaN"
    )
    let data = try enc.encode(meta)
    try data.write(to: metaURL)

    print("wrote \(csvURL.path) (\(rows.count) rows)")
    print("wrote \(metaURL.path)")
    print("cold_start_ms=\(String(format: "%.2f", coldStartMs)) per_frame_ms_mean=\(String(format: "%.3f", mean(times))) per_frame_ms_p99=\(String(format: "%.3f", percentile(times, 0.99))) peak_rss_mb=\(String(format: "%.2f", peakRSSMB)) sustained_fps=\(String(format: "%.2f", sustainedFps))")
    if ProcessInfo.processInfo.environment["BITHUMAN_PROFILE"] == "1" {
        await runtime._dumpProfileForBench()
    }
}

/// SDK version string. There's no compile-time bake of the SemVer in
/// the `Bithuman` product; Swift surfaces the resolved Package.resolved
/// tag at build time only. The bench harness reports the value embedded
/// in `Package.swift` minor pin notation, which is consistent across the
/// matrix of binaries we ship from this repo.
func bithumanSDKVersion() -> String {
    // TODO when the `Bithuman` product exposes a static `version`
    // constant, swap this. For now the value is hand-aligned to the
    // latest tag.
    "0.10.0"
}

// MARK: - Entry point

// Touch the metallib bootstrap so it actually runs (top-level lets
// in executable targets are otherwise lazy on first reference).
_ = _ensureMetalLibraryAtStartup

let args = CLIArgs.parse()

if args.dryRun {
    do {
        guard let output = args.output else {
            fail("--output is required for --dry-run")
        }
        try runDryRun(output: output)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("dry-run failed: \(error)\n".utf8))
        exit(1)
    }
}

// Keep a Task reference alive across dispatchMain; the Task closure
// itself terminates the process via `exit(...)`, so dispatchMain is
// the right primary loop here.
_ = Task {
    do {
        if args.multiInstance > 0 {
            try await runMultiInstanceCheck(args: args)
        } else {
            try await runBench(args: args)
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("bench-essence failed: \(error)\n".utf8))
        exit(1)
    }
}

dispatchMain()
