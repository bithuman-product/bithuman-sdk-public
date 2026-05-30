// CompareDiT — render a WAV through the avatar engine to a lip-synced MP4.
//
// Used to A/B fp16 vs int4 DiT quality:
//
//   swift build -c release --product compare-dit
//   compare-dit --model expression.imx --audio ref.wav --output fp16.mp4
//   FH_QUANTIZE_DIT=int4 compare-dit --model expression.imx --audio ref.wav --output int4.mp4
//   ffmpeg -i fp16.mp4 -i int4.mp4 -filter_complex "[0:v][1:v]hstack" \
//     -map 0:a side-by-side.mp4
//
// Adapted from bithuman-expression-swift/Examples/HelloWorld; uses
// bitHumanKit's public unmetered factory. SDK-internal constants
// (FRAME_NUM=33, SAMPLE_RATE=16000, TGT_FPS=25) inlined here because
// they're not part of the public API.

import AVFoundation
// Targets the Layer-1 Expression avatar engine directly (engine/expression
// → the `Expression` product). Home of the `Bithuman` actor,
// `Bithuman.Identity`, and `Bithuman.Quality` used below.
import Expression
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

private let SDK_FRAME_NUM = 33
private let SDK_SAMPLE_RATE = 16_000
private let SDK_TGT_FPS = 25

// MARK: - CLI

struct CLIArgs {
    var model: URL
    var audio: URL
    var output: URL
    var identity: URL?
    var driver: URL?
    var quality: Bithuman.Quality = .medium
    var putback: Bool = false

    static func parse() throws -> CLIArgs {
        let raw = Array(CommandLine.arguments.dropFirst())
        var model: URL?, audio: URL?, output: URL?, identity: URL?, driver: URL?
        var quality: Bithuman.Quality = .medium
        var putback = false
        var i = 0
        while i < raw.count {
            let arg = raw[i]
            let val: () throws -> String = {
                guard i + 1 < raw.count else { throw CLIError.missingValue(arg) }
                i += 1
                return raw[i]
            }
            switch arg {
            case "--model", "-m":    model = URL(fileURLWithPath: try val())
            case "--audio", "-a":    audio = URL(fileURLWithPath: try val())
            case "--output", "-o":   output = URL(fileURLWithPath: try val())
            case "--identity", "-i": identity = URL(fileURLWithPath: try val())
            case "--driver", "-d":   driver = URL(fileURLWithPath: try val())
            case "--quality", "-q":
                let v = try val()
                guard let q = Bithuman.Quality(rawValue: v) else {
                    throw CLIError.unknownArg("--quality \(v) (expected: medium|high)")
                }
                quality = q
            case "--putback":        putback = true
            case "-h", "--help":     printUsage(); exit(0)
            default:                 throw CLIError.unknownArg(arg)
            }
            i += 1
        }
        guard let model, let audio else {
            printUsage()
            throw CLIError.missingRequired
        }
        return CLIArgs(
            model: model, audio: audio,
            output: output ?? URL(fileURLWithPath: "demo.mp4"),
            identity: identity,
            driver: driver,
            quality: quality,
            putback: putback
        )
    }

    static func printUsage() {
        print("""
        compare-dit — render a WAV through the avatar engine to MP4

        Usage:
          compare-dit --model PATH --audio PATH [--output PATH] \\
                      [--identity PATH | --driver PATH] \\
                      [--quality medium|high] [--putback]

        Quality:
          medium    2-step DiT (default, realtime-safe)
          high      4-step DiT (offline video) — note: visibly halos
                    the face on the current .bhx; prefer medium

        --putback   Composite the animated head crop back onto the
                    full-resolution --identity portrait. Output mp4 is
                    at source-portrait dimensions.

        --driver    Drive putback with a video instead of a static
                    portrait. First frame becomes engine identity;
                    every video frame becomes the per-tick canvas;
                    Vision face detection runs per-frame and is
                    temporally Gaussian-smoothed (σ=2) to track
                    gentle head motion without jitter. Implicitly
                    enables --putback. Output mp4 is at driver-video
                    dimensions.

        Env:
          FH_QUANTIZE_DIT=int4 (or int8)  Quantize DiT before inference.
        """)
    }
}

enum CLIError: Error, CustomStringConvertible {
    case missingValue(String), unknownArg(String), missingRequired
    var description: String {
        switch self {
        case .missingValue(let a): return "missing value for \(a)"
        case .unknownArg(let a):   return "unknown argument: \(a)"
        case .missingRequired:     return "both --model and --audio are required"
        }
    }
}

enum CompareError: Error, CustomStringConvertible {
    case audio(String), video(String), cli(String)
    var description: String {
        switch self {
        case .audio(let m): return "audio: \(m)"
        case .video(let m): return "video: \(m)"
        case .cli(let m):   return m
        }
    }
}

// MARK: - WAV loader

func loadWAV(_ url: URL) throws -> (samples: [Float], sampleRate: Int) {
    let audioFile = try AVAudioFile(forReading: url)
    let fmt = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: audioFile.processingFormat.sampleRate,
        channels: 1, interleaved: false
    )!
    let frameCount = AVAudioFrameCount(audioFile.length)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else {
        throw CompareError.audio("could not allocate PCM buffer")
    }
    guard let native = AVAudioPCMBuffer(
        pcmFormat: audioFile.processingFormat,
        frameCapacity: frameCount
    ) else {
        throw CompareError.audio("could not allocate native-format buffer")
    }
    try audioFile.read(into: native)

    let converter = AVAudioConverter(from: audioFile.processingFormat, to: fmt)!
    var error: NSError?
    _ = converter.convert(to: buffer, error: &error, withInputFrom: { _, outStatus in
        outStatus.pointee = .haveData
        return native
    })
    if let error { throw CompareError.audio("convert failed: \(error)") }

    let n = Int(buffer.frameLength)
    guard let ptr = buffer.floatChannelData?[0] else {
        throw CompareError.audio("no float channel data")
    }
    return (Array(UnsafeBufferPointer(start: ptr, count: n)), Int(fmt.sampleRate))
}

func resample(_ samples: [Float], from src: Int, to dst: Int) -> [Float] {
    if src == dst { return samples }
    let ratio = Double(dst) / Double(src)
    let n = Int((Double(samples.count) * ratio).rounded())
    var out = [Float](repeating: 0, count: n)
    for i in 0..<n {
        let pos = Double(i) / ratio
        let lo = Int(pos.rounded(.down))
        let hi = min(lo + 1, samples.count - 1)
        let frac = Float(pos - Double(lo))
        out[i] = samples[lo] * (1 - frac) + samples[hi] * frac
    }
    return out
}

// MARK: - MP4 writer

final class MP4Writer: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private let pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private let videoFPS: Int32 = 25
    private let audioSR: Int32 = 24_000
    private let width: Int
    private let height: Int

    private let videoQueue = DispatchQueue(label: "compare-dit.mp4.video")
    private let audioQueue = DispatchQueue(label: "compare-dit.mp4.audio")

    private let lock = NSLock()
    private var pendingFrames: [(CGImage, CMTime)] = []
    private var pendingAudio:  [CMSampleBuffer]     = []
    private var videoEOS = false
    private var audioEOS = false
    private var videoMarkedFinished = false
    private var audioMarkedFinished = false
    private var finishStarted = false
    private var nextFrameIndex: Int = 0
    private var audioSamplesWritten: Int64 = 0

    private let maxPendingFrames = 50
    private let maxPendingAudio  = 10

    init(url: URL, width: Int, height: Int) throws {
        try? FileManager.default.removeItem(at: url)
        self.writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        self.width  = width
        self.height = height

        let videoSettings: [String: Any] = [
            AVVideoCodecKey:  AVVideoCodecType.h264,
            AVVideoWidthKey:  width,
            AVVideoHeightKey: height,
        ]
        self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        self.videoInput.expectsMediaDataInRealTime = false

        let audioSettings: [String: Any] = [
            AVFormatIDKey:         kAudioFormatMPEG4AAC,
            AVSampleRateKey:       audioSR,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey:   64_000,
        ]
        self.audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        self.audioInput.expectsMediaDataInRealTime = false

        self.pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String:           width,
                kCVPixelBufferHeightKey as String:          height,
            ]
        )

        writer.add(videoInput)
        writer.add(audioInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        videoInput.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
            self?.drainVideo()
        }
        audioInput.requestMediaDataWhenReady(on: audioQueue) { [weak self] in
            self?.drainAudio()
        }
    }

    func append(frame: CGImage) async throws {
        try checkWriterStatus()
        try lock.withLock {
            if finishStarted { throw CompareError.video("append(frame:) after finish()") }
            let pts = CMTime(value: CMTimeValue(nextFrameIndex), timescale: videoFPS)
            nextFrameIndex += 1
            pendingFrames.append((frame, pts))
        }
        try await applyBackpressure(kind: .video)
    }

    func append(audio samples: [Float]) async throws {
        guard !samples.isEmpty else { return }
        try checkWriterStatus()
        let pts: CMTime = try lock.withLock {
            if finishStarted { throw CompareError.audio("append(audio:) after finish()") }
            let pts = CMTime(value: audioSamplesWritten, timescale: audioSR)
            audioSamplesWritten &+= Int64(samples.count)
            return pts
        }
        guard let sbuf = Self.makeAudioSampleBuffer(samples: samples, pts: pts, sampleRate: audioSR) else {
            throw CompareError.audio("could not build CMSampleBuffer for \(samples.count) samples")
        }
        lock.withLock { pendingAudio.append(sbuf) }
        try await applyBackpressure(kind: .audio)
    }

    private enum BackpressureKind { case video, audio }

    private func applyBackpressure(kind: BackpressureKind) async throws {
        while true {
            try checkWriterStatus()
            let tooFull: Bool = lock.withLock {
                switch kind {
                case .video: return pendingFrames.count > maxPendingFrames
                case .audio: return pendingAudio.count  > maxPendingAudio
                }
            }
            if !tooFull { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func drainVideo() {
        while videoInput.isReadyForMoreMediaData {
            let item: (CGImage, CMTime)?
            let shouldFinish: Bool
            (item, shouldFinish) = lock.withLock {
                if pendingFrames.isEmpty {
                    return (nil, videoEOS && !videoMarkedFinished)
                }
                return (pendingFrames.removeFirst(), false)
            }
            if let (cg, pts) = item {
                appendPixelBuffer(for: cg, pts: pts)
                continue
            }
            if shouldFinish {
                videoInput.markAsFinished()
                lock.withLock { videoMarkedFinished = true }
            }
            return
        }
    }

    private func drainAudio() {
        while audioInput.isReadyForMoreMediaData {
            let sbuf: CMSampleBuffer?
            let shouldFinish: Bool
            (sbuf, shouldFinish) = lock.withLock {
                if pendingAudio.isEmpty {
                    return (nil, audioEOS && !audioMarkedFinished)
                }
                return (pendingAudio.removeFirst(), false)
            }
            if let sbuf {
                audioInput.append(sbuf)
                continue
            }
            if shouldFinish {
                audioInput.markAsFinished()
                lock.withLock { audioMarkedFinished = true }
            }
            return
        }
    }

    private func appendPixelBuffer(for frame: CGImage, pts: CMTime) {
        guard let pool = pixelAdaptor.pixelBufferPool else { return }
        var buf: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buf)
        guard let pb = buf else { return }

        CVPixelBufferLockBaseAddress(pb, [])
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        ctx?.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pb, [])

        pixelAdaptor.append(pb, withPresentationTime: pts)
    }

    private static func makeAudioSampleBuffer(
        samples: [Float], pts: CMTime, sampleRate: Int32
    ) -> CMSampleBuffer? {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1,
            mBytesPerFrame: 4, mChannelsPerFrame: 1,
            mBitsPerChannel: 32, mReserved: 0
        )
        var formatDesc: CMFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &asbd,
            layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil,
            extensions: nil, formatDescriptionOut: &formatDesc
        )
        guard let formatDesc else { return nil }

        var block: CMBlockBuffer?
        let bytes = samples.count * MemoryLayout<Float>.size
        CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: bytes, blockAllocator: nil, customBlockSource: nil,
            offsetToData: 0, dataLength: bytes, flags: 0, blockBufferOut: &block
        )
        guard let block else { return nil }
        _ = samples.withUnsafeBufferPointer { ptr -> OSStatus in
            CMBlockBufferReplaceDataBytes(
                with: ptr.baseAddress!, blockBuffer: block,
                offsetIntoDestination: 0, dataLength: bytes
            )
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: CMTimeValue(samples.count), timescale: sampleRate),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )
        var sampleSize = MemoryLayout<Float>.size
        var sbuf: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: block, dataReady: true,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDesc,
            sampleCount: CMItemCount(samples.count),
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
            sampleBufferOut: &sbuf
        )
        return sbuf
    }

    private func checkWriterStatus() throws {
        if writer.status == .failed {
            throw CompareError.video("AVAssetWriter failed: \(writer.error?.localizedDescription ?? "unknown")")
        }
        if writer.status == .cancelled {
            throw CompareError.video("AVAssetWriter cancelled")
        }
    }

    func finish() async throws {
        let alreadyStarted: Bool = lock.withLock {
            if finishStarted { return true }
            finishStarted = true
            videoEOS = true
            audioEOS = true
            return false
        }
        if alreadyStarted { return }

        videoQueue.async { [weak self] in self?.drainVideo() }
        audioQueue.async { [weak self] in self?.drainAudio() }

        let deadline = CFAbsoluteTimeGetCurrent() + 120.0
        while true {
            try checkWriterStatus()
            let done: Bool = lock.withLock {
                videoMarkedFinished && audioMarkedFinished
                    && pendingFrames.isEmpty && pendingAudio.isEmpty
            }
            if done { break }
            if CFAbsoluteTimeGetCurrent() > deadline {
                throw CompareError.video("finish() timed out (status=\(writer.status.rawValue))")
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        await writer.finishWriting()
    }
}

private extension NSLock {
    @inline(__always)
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
    @inline(__always)
    func withLock<T>(_ body: () throws -> T) throws -> T {
        lock(); defer { unlock() }
        return try body()
    }
}

// MARK: - main

@main
struct CompareDiT {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run() async throws {
        let args = try CLIArgs.parse()
        let fm = FileManager.default
        guard fm.fileExists(atPath: args.model.path) else {
            throw CompareError.cli("model file not found: \(args.model.path)")
        }
        guard fm.fileExists(atPath: args.audio.path) else {
            throw CompareError.cli("audio file not found: \(args.audio.path)")
        }
        if let ident = args.identity, !fm.fileExists(atPath: ident.path) {
            throw CompareError.cli("identity file not found: \(ident.path)")
        }
        if let drv = args.driver, !fm.fileExists(atPath: drv.path) {
            throw CompareError.cli("driver video not found: \(drv.path)")
        }
        if args.identity != nil && args.driver != nil {
            throw CompareError.cli("--identity and --driver are mutually exclusive")
        }
        if args.putback && args.driver == nil {
            guard let ident = args.identity else {
                throw CompareError.cli("--putback requires --identity PATH or --driver PATH")
            }
            let ext = ident.pathExtension.lowercased()
            guard ext != "npy" else {
                throw CompareError.cli("--putback needs an image portrait, not a pre-encoded latent")
            }
        }
        do { _ = try AVAudioFile(forReading: args.audio) } catch {
            throw CompareError.audio("could not read \(args.audio.lastPathComponent) — \(error.localizedDescription)")
        }

        let dtypeLabel = ProcessInfo.processInfo.environment["FH_QUANTIZE_DIT"] ?? "fp16"
        print("→ DiT mode: \(dtypeLabel)")
        print("→ Quality: \(args.quality.rawValue) (\(args.quality.nSteps)-step)")
        print("→ Loading model: \(args.model.lastPathComponent)")

        // --driver: extract the driver's first frame, write it out as a
        // JPEG to /tmp, and use that as the engine identity so the
        // animated face matches the person in the video.
        var derivedIdentityURL: URL?
        if let drv = args.driver {
            print("→ Driver video: \(drv.lastPathComponent) — extracting first frame")
            let firstCG = try Putback.firstFrame(of: drv)
            let outURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("compare-dit-driver-id-\(ProcessInfo.processInfo.processIdentifier).jpg")
            guard let dest = CGImageDestinationCreateWithURL(
                outURL as CFURL, "public.jpeg" as CFString, 1, nil
            ) else { throw CompareError.cli("could not write driver identity jpg") }
            CGImageDestinationAddImage(dest, firstCG, [
                kCGImageDestinationLossyCompressionQuality as String: 0.95
            ] as CFDictionary)
            guard CGImageDestinationFinalize(dest) else {
                throw CompareError.cli("could not finalize driver identity jpg")
            }
            derivedIdentityURL = outURL
        }

        let identity: Bithuman.Identity = {
            if let url = derivedIdentityURL { return .image(url) }
            guard let ident = args.identity else { return .default }
            let ext = ident.pathExtension.lowercased()
            return (ext == "npy") ? .preEncoded(ident) : .image(ident)
        }()

        let result = try Bithuman.create(
            modelPath: args.model, identity: identity, quality: args.quality
        )
        let bithuman = result.bithuman
        let size = bithuman.frameSize
        print("→ Ready: \(Int(size.width))×\(Int(size.height))")

        let samples: [Float]
        let sr: Int
        do {
            (samples, sr) = try loadWAV(args.audio)
        } catch {
            throw CompareError.audio("could not read \(args.audio.lastPathComponent) — \(error.localizedDescription)")
        }
        let samples16 = resample(samples, from: sr, to: 16_000)
        let samples24 = resample(samples, from: sr, to: 24_000)
        print(String(format: "→ Pushed %.2fs of audio @ %d Hz", Double(samples.count) / Double(sr), sr))

        try await bithuman.pushAudio(audio24k: samples24, audio16k: samples16)

        let dispatchSamples16 = SDK_FRAME_NUM * SDK_SAMPLE_RATE / SDK_TGT_FPS
        if samples16.count < dispatchSamples16 {
            await bithuman.flushTailIfNeeded()
        }

        // Decide canvas mode:
        //   driver        → per-frame video canvas, per-frame smoothed crop
        //   putback+ident → static portrait canvas, single crop
        //   else          → head-only (engine crop, no putback)
        let putbackPlan: PutbackPlan?
        let outW: Int
        let outH: Int
        if let drv = args.driver {
            let plan = try Putback.makeDriverPlan(driverURL: drv)
            let p0 = plan.paramsPerFrame.first
            print(String(format: "→ Driver-putback: canvas %d×%d @ %.1f fps, %d frames, crop_size[0]=%.0fpx angle[0]=%.1f°",
                          plan.outWidth, plan.outHeight, plan.canvasFPS,
                          plan.canvasFrames.count,
                          p0?.size ?? 0,
                          (p0?.angle ?? 0) * 180 / .pi))
            putbackPlan = plan
            outW = plan.outWidth
            outH = plan.outHeight
        } else if args.putback, let portraitURL = args.identity {
            let plan = try Putback.makePlan(portraitURL: portraitURL)
            let p0 = plan.paramsPerFrame[0]
            print(String(format: "→ Putback: source %d×%d, crop_size=%.0fpx angle=%.1f°",
                          plan.outWidth, plan.outHeight, p0.size,
                          p0.angle * 180 / .pi))
            putbackPlan = plan
            outW = plan.outWidth
            outH = plan.outHeight
        } else {
            putbackPlan = nil
            outW = Int(size.width)
            outH = Int(size.height)
        }

        let writer = try MP4Writer(
            url: args.output,
            width: outW,
            height: outH
        )

        // === Two-phase render for putback ===
        //
        // Ditto-style putback needs the engine output's *smoothed* anchor
        // trajectory to compute clean per-frame affines, which means we
        // have to know all engine frames before we can composite. So:
        //
        //   Phase A: drain all engine chunks → cache frames + per-frame
        //            engine anchors. Audio gets written to mp4 streaming
        //            (it doesn't depend on the smoothed anchors).
        //   Phase B: temporally Gaussian-smooth the engine anchors, then
        //            composite each frame onto its matching driver frame
        //            and append to the writer.
        //
        // For head-only mode (no putbackPlan), phase A degenerates to
        // direct frame writing — no buffering, no phase B.

        var frameCount = 0
        var tailPadded = false
        let startupTimeout: TimeInterval = 60.0
        let startTime = CFAbsoluteTimeGetCurrent()

        var bufferedFrames: [CGImage] = []
        var bufferedEnginePoses: [Putback.FacePose?] = []

        func consumeChunk(_ chunk: TimedChunk) async throws {
            if let audio = chunk.audio24k {
                try await writer.append(audio: audio)
            }
            for frame in chunk.frames {
                if putbackPlan != nil {
                    // Phase A: buffer + detect full face pose (center +
                    // angle) on each engine output for per-frame alignment.
                    bufferedFrames.append(frame)
                    bufferedEnginePoses.append(Putback.detectFacePose(cg: frame))
                    frameCount += 1
                } else {
                    try await writer.append(frame: frame)
                    frameCount += 1
                }
            }
        }

        while true {
            if let chunk = bithuman.tryDequeueChunk() {
                try await consumeChunk(chunk)
                continue
            }
            try await Task.sleep(nanoseconds: 20_000_000)
            if frameCount == 0 {
                if CFAbsoluteTimeGetCurrent() - startTime > startupTimeout {
                    throw CompareError.video("timed out waiting for first frame")
                }
                continue
            }
            let snap = bithuman.snapshot
            if !snap.inFlight && (snap.pendingAudio16Count == 0 || snap.tailFlushedThisResponse) {
                while let chunk = bithuman.tryDequeueChunk() {
                    try await consumeChunk(chunk)
                }
                break
            }
            if !tailPadded && !snap.inFlight && snap.pendingAudio16Count > 0 {
                await bithuman.flushTailIfNeeded()
                tailPadded = true
            }
        }

        // Phase B: putback composite. Smooth the per-frame engine FacePose
        // (center + angle, detected during phase A) with light σ so the
        // per-frame target tracks actual animation-induced shifts while
        // suppressing Vision detection noise. Both engine and driver are
        // detected per frame; M_o2c is built with the actual position
        // and orientation each frame.
        if let plan = putbackPlan {
            let detectedEng = bufferedEnginePoses.compactMap { $0 }.count
            FileHandle.standardError.write(Data(
                "[Putback] engine: \(bufferedFrames.count) frames, \(detectedEng) FacePose detections\n".utf8
            ))
            let smoothedEnginePoses = Putback.smoothPoses(bufferedEnginePoses, sigma: 3.0)
            for (i, engineFrame) in bufferedFrames.enumerated() {
                let pose = smoothedEnginePoses[i]
                guard let comp = Putback.compositeFrame(
                    plan: plan,
                    animatedFace: engineFrame,
                    frameIndex: i,
                    engineAnchorOverride: pose.center,
                    engineAngleOverride: pose.angle
                ) else {
                    throw CompareError.video("putback composite returned nil at frame \(i)")
                }
                try await writer.append(frame: comp)
            }
        }

        await bithuman.shutdown()
        try await writer.finish()

        print("→ ✓ Wrote \(args.output.lastPathComponent) — \(frameCount) frames @ 25 FPS (\(String(format: "%.1f", Double(frameCount)/25.0))s)")
    }
}
