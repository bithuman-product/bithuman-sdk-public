// Putback — Ditto-style composite of the Expression engine's animated
// face crop back onto a driver canvas. Mirrors the algorithm in
// github.com/antgroup/ditto-talkinghead (`core/atomic_components/putback.py`
// + `core/utils/crop.py`):
//
//   1. Compute per-frame M_o2c (original→crop) similarity transform from
//      face landmarks. Anchor for angle = (eye_mid → mouth_mid); bbox =
//      tight rect around all landmarks rotated into face-axis coords;
//      scale = 1.5 with vy_ratio = -0.1 to include forehead. M_c2o is
//      the inverse (crop→original).
//   2. Use a STATIC soft-rectangle mask in CROP space (e.g. 384×384,
//      inner 90% solid, 10% linear feather around the border).
//   3. Warp BOTH the engine render AND the mask by the same M_c2o
//      using vImage Lanczos-style high-quality resampling. The mask
//      naturally follows the render because they share the warp.
//   4. Blend per pixel:
//          result = mask_warped * render_warped + (1 - mask_warped) * driver
//
// Smoothing for driver-video continuity: per-frame raw M_o2c parameters
// (center.x, center.y, size, angle) get 1-D Gaussian smoothing across
// the whole clip (σ=5 default) so Vision landmark noise doesn't cause
// per-frame affine wobble.

import Accelerate
import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Vision

// MARK: - Affine

/// 2D affine x' = a·x + b·y + tx, y' = c·x + d·y + ty.
struct Affine2D {
    var a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double
    static let identity = Affine2D(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    func apply(_ p: CGPoint) -> CGPoint {
        CGPoint(x: a * Double(p.x) + b * Double(p.y) + tx,
                y: c * Double(p.x) + d * Double(p.y) + ty)
    }

    func inverse() -> Affine2D {
        let det = a * d - b * c
        let invDet = 1.0 / det
        let ia =  d * invDet
        let ib = -b * invDet
        let ic = -c * invDet
        let id =  a * invDet
        return Affine2D(
            a: ia, b: ib, c: ic, d: id,
            tx: -(ia * tx + ib * ty),
            ty: -(ic * tx + id * ty)
        )
    }
}

// MARK: - Face params (Ditto-style)

/// Output of `parseRectFromLandmarks`. Determines the crop frame —
/// center+size positions+sizes the face square in the source image,
/// angle aligns it with the face's vertical axis.
struct FaceCropParams {
    var centerX: Double
    var centerY: Double
    var size: Double    // square side = 1.8 * max(faceW, faceH)
    var angle: Double   // radians; rotation of face vertical axis from screen vertical
    var faceW: Double   // Vision face rect width (unsmoothed source)
    var faceH: Double   // Vision face rect height — needed for the engine's
                        // yNudge=-0.20·faceH (NOT max(W,H)) to compute the
                        // exact face anchor position in the engine 384 crop.
}

enum Putback {
    // MARK: - Vision dense landmarks → flat point array

    /// Extract all useful 2D landmark points (eye contours, brows, nose,
    /// lips, face contour, pupils) in TOP-LEFT pixel coords. The bbox +
    /// angle derivation in `parseRectFromLandmarks` uses all of them
    /// for stable centroid + extent estimation.
    static func detectLandmarkPoints(cg: CGImage) -> [CGPoint]? {
        let req = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([req]) } catch { return nil }
        return pointsFromObservation(
            req.results, imgSize: CGSize(width: cg.width, height: cg.height)
        )
    }

    static func detectLandmarkPoints(pixelBuffer: CVPixelBuffer) -> [CGPoint]? {
        let req = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do { try handler.perform([req]) } catch { return nil }
        return pointsFromObservation(
            req.results,
            imgSize: CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                            height: CVPixelBufferGetHeight(pixelBuffer))
        )
    }

    private static func pointsFromObservation(
        _ results: [VNFaceObservation]?, imgSize: CGSize
    ) -> [CGPoint]? {
        guard let faces = results, !faces.isEmpty else { return nil }
        let face = faces.max {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }!
        guard let lm = face.landmarks else { return nil }
        let H = imgSize.height
        func ptsTL(_ r: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let r = r else { return [] }
            return r.pointsInImage(imageSize: imgSize).map { CGPoint(x: $0.x, y: H - $0.y) }
        }
        var pts: [CGPoint] = []
        pts.append(contentsOf: ptsTL(lm.faceContour))
        pts.append(contentsOf: ptsTL(lm.leftEye))
        pts.append(contentsOf: ptsTL(lm.rightEye))
        pts.append(contentsOf: ptsTL(lm.leftEyebrow))
        pts.append(contentsOf: ptsTL(lm.rightEyebrow))
        pts.append(contentsOf: ptsTL(lm.nose))
        pts.append(contentsOf: ptsTL(lm.noseCrest))
        pts.append(contentsOf: ptsTL(lm.outerLips))
        return pts.isEmpty ? nil : pts
    }

    // MARK: - Vision bbox + axis anchors

    /// Convert a Vision normalized bbox (bottom-left origin, [0,1])
    /// to a pixel-coord CGRect (top-left origin).
    static func visionBBoxToPixelRect(_ bb: CGRect, imgSize: CGSize) -> CGRect {
        let x = bb.origin.x * imgSize.width
        let y = (1.0 - bb.origin.y - bb.height) * imgSize.height
        let w = bb.width * imgSize.width
        let h = bb.height * imgSize.height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Extract eye_mid and mouth_mid centroids from VNFaceLandmarks2D
    /// in top-left pixel coords. Returns (nil, nil) if not detectable.
    static func extractAxisAnchors(
        landmarks lm: VNFaceLandmarks2D?, imgSize: CGSize
    ) -> (CGPoint?, CGPoint?) {
        guard let lm = lm else { return (nil, nil) }
        let H = imgSize.height
        func centroid(_ r: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let r = r else { return nil }
            let pts = r.pointsInImage(imageSize: imgSize).map { CGPoint(x: $0.x, y: H - $0.y) }
            guard !pts.isEmpty else { return nil }
            let sx = pts.reduce(0) { $0 + $1.x } / CGFloat(pts.count)
            let sy = pts.reduce(0) { $0 + $1.y } / CGFloat(pts.count)
            return CGPoint(x: sx, y: sy)
        }
        let lEye = centroid(lm.leftEye) ?? centroid(lm.leftPupil)
        let rEye = centroid(lm.rightEye) ?? centroid(lm.rightPupil)
        let lips = centroid(lm.outerLips) ?? centroid(lm.innerLips)
        let eyeMid: CGPoint? = {
            if let l = lEye, let r = rEye {
                return CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
            }
            return lEye ?? rEye
        }()
        return (eyeMid, lips)
    }

    // MARK: - Face transform (Ditto's parse_rect_from_landmark)

    /// Eye centroid + mouth centroid → 2-point face axis (uy = eye→mouth).
    /// Falls back gracefully if mouth is missing.
    private static func axisAnchors(cg: CGImage, imgSize: CGSize) -> (CGPoint, CGPoint)? {
        // Re-run a focused request just to grab eye + lip centroids;
        // callers that already have landmarks could re-use them, but
        // the API stays simple this way.
        let req = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        guard let face = req.results?.max(by: {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }), let lm = face.landmarks else { return nil }
        let H = imgSize.height
        func centroid(_ r: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let r = r else { return nil }
            let pts = r.pointsInImage(imageSize: imgSize).map { CGPoint(x: $0.x, y: H - $0.y) }
            guard !pts.isEmpty else { return nil }
            let sx = pts.reduce(0) { $0 + $1.x } / CGFloat(pts.count)
            let sy = pts.reduce(0) { $0 + $1.y } / CGFloat(pts.count)
            return CGPoint(x: sx, y: sy)
        }
        let lEye = centroid(lm.leftEye) ?? centroid(lm.leftPupil)
        let rEye = centroid(lm.rightEye) ?? centroid(lm.rightPupil)
        let lips = centroid(lm.outerLips) ?? centroid(lm.innerLips)
        guard let lEye, let rEye, let lips else { return nil }
        let eyeMid = CGPoint(x: (lEye.x + rEye.x) / 2, y: (lEye.y + rEye.y) / 2)
        return (eyeMid, lips)
    }

    /// Build FaceCropParams matching the Bithuman Expression engine's
    /// internal crop EXACTLY (ImagePreprocess.faceAwareCropRect):
    ///
    ///   contextSide = max(faceW, faceH) * 1.8
    ///   yNudge      = -0.20 * faceH                      (shifts up)
    ///   center      = (faceCenter.x, faceCenter.y + yNudge)   (image-Y)
    ///
    /// The engine does an AXIS-ALIGNED crop (no rotation). The angle
    /// recorded here is the face's tilt in canvas coords — used by
    /// compositeFrame to compute the RELATIVE rotation between the
    /// current frame and the first frame (the engine output's face
    /// orientation matches whatever the first frame had).
    static func paramsFromFaceRect(
        faceRect: CGRect, eyeMid: CGPoint?, mouthMid: CGPoint?,
        contextScale: Double = 1.8
    ) -> FaceCropParams {
        let faceW = Double(faceRect.width)
        let faceH = Double(faceRect.height)
        let faceCenterX = Double(faceRect.origin.x) + faceW / 2
        let faceCenterY = Double(faceRect.origin.y) + faceH / 2
        let size = max(faceW, faceH) * contextScale
        var angle = 0.0
        if let e = eyeMid, let m = mouthMid {
            let dx = Double(m.x - e.x)
            let dy = Double(m.y - e.y)
            let l = (dx * dx + dy * dy).squareRoot()
            if l > 1e-3 {
                let uyx = dx / l, uyy = dy / l
                let uxx = uyy
                let uxy = -uyx
                var a = acos(max(-1.0, min(1.0, uxx)))
                if uxy < 0 { a = -a }
                angle = a
            }
        }
        // params.center stays at the ACTUAL face center (no yNudge baked
        // into the params). The yNudge is already baked into the engine's
        // 384 output (face is at (192, 234.67) inside, not (192, 192))
        // because the engine's faceAwareCropRect applies yNudge to the
        // crop region. We account for that in buildM_o2c by mapping the
        // face center to the engine's face anchor, not the crop center.
        return FaceCropParams(centerX: faceCenterX, centerY: faceCenterY,
                              size: size, angle: angle,
                              faceW: faceW, faceH: faceH)
    }

    /// Build M_o2c (original→crop). `targetCenter` is the crop pixel
    /// where the canvas face center should land. For our setup that's
    /// the engine's face anchor inside the 384 output, NOT the geometric
    /// crop center — because the engine's faceAwareCropRect bakes the
    /// yNudge into the crop, placing the face at (192, 234.67) when
    /// the engine uses 1.8 context scale and -0.20 yNudge ratio.
    ///
    /// Rotation pivots around params.center (the face center on canvas)
    /// so a tilted face maps to (targetCenter.x, targetCenter.y) for all θ.
    static func buildM_o2c(params: FaceCropParams, dsize: Double,
                            targetCenter: CGPoint) -> Affine2D {
        let s = dsize / params.size
        let cosA = cos(params.angle), sinA = sin(params.angle)
        let cx = params.centerX, cy = params.centerY
        let tcx = Double(targetCenter.x), tcy = Double(targetCenter.y)
        return Affine2D(
            a:  s * cosA,
            b:  s * sinA,
            c: -s * sinA,
            d:  s * cosA,
            tx: tcx - s * ( cosA * cx + sinA * cy),
            ty: tcy - s * (-sinA * cx + cosA * cy)
        )
    }

    // MARK: - Smoothing FaceCropParams across frames

    private static func interpolateParams(_ xs: [FaceCropParams?]) -> [FaceCropParams?] {
        let n = xs.count
        guard n > 0 else { return xs }
        let valid = (0..<n).filter { xs[$0] != nil }
        guard !valid.isEmpty else { return xs }
        var out = xs
        let first = valid.first!, last = valid.last!
        for i in 0..<first { out[i] = xs[first] }
        for i in (last + 1)..<n { out[i] = xs[last] }
        for k in 0..<(valid.count - 1) {
            let lo = valid[k], hi = valid[k + 1]
            if hi - lo <= 1 { continue }
            let a = xs[lo]!, b = xs[hi]!
            let span = Double(hi - lo)
            for j in (lo + 1)..<hi {
                let t = Double(j - lo) / span
                out[j] = FaceCropParams(
                    centerX: a.centerX + (b.centerX - a.centerX) * t,
                    centerY: a.centerY + (b.centerY - a.centerY) * t,
                    size:    a.size    + (b.size    - a.size)    * t,
                    angle:   a.angle   + (b.angle   - a.angle)   * t,
                    faceW:   a.faceW   + (b.faceW   - a.faceW)   * t,
                    faceH:   a.faceH   + (b.faceH   - a.faceH)   * t
                )
            }
        }
        return out
    }

    private static func gaussianSmooth(_ xs: [Double], sigma: Double) -> [Double] {
        let n = xs.count
        guard n > 1, sigma > 0 else { return xs }
        let radius = max(1, Int((3.0 * sigma).rounded()))
        var kernel = [Double](repeating: 0, count: 2 * radius + 1)
        var ksum = 0.0
        for i in -radius...radius {
            let w = exp(-Double(i * i) / (2 * sigma * sigma))
            kernel[i + radius] = w
            ksum += w
        }
        for k in 0..<kernel.count { kernel[k] /= ksum }
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var s = 0.0
            for k in -radius...radius {
                let idx = min(max(i + k, 0), n - 1)
                s += xs[idx] * kernel[k + radius]
            }
            out[i] = s
        }
        return out
    }

    /// Smooth per-frame face crop params with a 1-D temporal Gaussian.
    /// σ=5 by default; size + angle could conceivably use a larger σ
    /// since they should be near-constant for a talking head, but σ=5
    /// is already heavy enough.
    /// Smooth per-frame face crop params with a 1-D temporal Gaussian.
    /// Asymmetric σ: position (center) gets σ_pos = 5 to track gentle head
    /// translation; size + angle + faceW/H get σ_size = 20 because a still
    /// talking head shouldn't change size/orientation meaningfully — heavier
    /// smoothing kills Vision noise that would otherwise show as breathing/
    /// jitter in the warp.
    static func smoothParams(_ raw: [FaceCropParams?],
                              sigmaPos: Double = 2.0,
                              sigmaSize: Double = 10.0) -> [FaceCropParams] {
        let filled = interpolateParams(raw)
        if filled.allSatisfy({ $0 == nil }) {
            return Array(repeating: FaceCropParams(centerX: 0, centerY: 0, size: 1,
                                                    angle: 0, faceW: 1, faceH: 1),
                         count: raw.count)
        }
        let cxs = filled.map { $0?.centerX ?? 0 }
        let cys = filled.map { $0?.centerY ?? 0 }
        let szs = filled.map { $0?.size ?? 1 }
        let ans = filled.map { $0?.angle ?? 0 }
        let fws = filled.map { $0?.faceW ?? 1 }
        let fhs = filled.map { $0?.faceH ?? 1 }
        let sCx = gaussianSmooth(cxs, sigma: sigmaPos)
        let sCy = gaussianSmooth(cys, sigma: sigmaPos)
        let sSz = gaussianSmooth(szs, sigma: sigmaSize)
        let sAn = gaussianSmooth(ans, sigma: sigmaSize)
        let sFw = gaussianSmooth(fws, sigma: sigmaSize)
        let sFh = gaussianSmooth(fhs, sigma: sigmaSize)
        var out = [FaceCropParams]()
        out.reserveCapacity(raw.count)
        for i in 0..<raw.count {
            out.append(FaceCropParams(centerX: sCx[i], centerY: sCy[i],
                                       size: sSz[i], angle: sAn[i],
                                       faceW: sFw[i], faceH: sFh[i]))
        }
        return out
    }

    // MARK: - Face polygon (face-shape mask in canvas coords)

    /// Build an ordered ring of face-boundary points for a single image.
    /// Returns polygon vertices in canvas pixel coords (top-left origin):
    ///   jawline left → chin → jawline right → forehead arc (estimated
    ///   by extending the eyebrow midline upward by ~0.55·eye_distance) →
    ///   back to jawline left.
    ///
    /// Returns nil if landmark detection fails.
    static func extractFacePolygon(cg: CGImage) -> [CGPoint]? {
        let req = VNDetectFaceLandmarksRequest()
        do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req]) }
        catch { return nil }
        guard let face = req.results?.max(by: {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }), let lm = face.landmarks else { return nil }
        let imgSize = CGSize(width: cg.width, height: cg.height)
        let H = imgSize.height
        func ptsTL(_ r: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let r = r else { return [] }
            return r.pointsInImage(imageSize: imgSize).map { CGPoint(x: $0.x, y: H - $0.y) }
        }
        return facePolygonFromRegions(
            faceContour: ptsTL(lm.faceContour),
            leftEyebrow: ptsTL(lm.leftEyebrow),
            rightEyebrow: ptsTL(lm.rightEyebrow),
            leftEye: ptsTL(lm.leftEye),
            rightEye: ptsTL(lm.rightEye)
        )
    }

    /// CVPixelBuffer variant (used in driver streaming path).
    static func extractFacePolygon(pixelBuffer: CVPixelBuffer) -> [CGPoint]? {
        let req = VNDetectFaceLandmarksRequest()
        do { try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([req]) }
        catch { return nil }
        guard let face = req.results?.max(by: {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }), let lm = face.landmarks else { return nil }
        let imgSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                              height: CVPixelBufferGetHeight(pixelBuffer))
        let H = imgSize.height
        func ptsTL(_ r: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let r = r else { return [] }
            return r.pointsInImage(imageSize: imgSize).map { CGPoint(x: $0.x, y: H - $0.y) }
        }
        return facePolygonFromRegions(
            faceContour: ptsTL(lm.faceContour),
            leftEyebrow: ptsTL(lm.leftEyebrow),
            rightEyebrow: ptsTL(lm.rightEyebrow),
            leftEye: ptsTL(lm.leftEye),
            rightEye: ptsTL(lm.rightEye)
        )
    }

    private static func facePolygonFromRegions(
        faceContour: [CGPoint],
        leftEyebrow: [CGPoint], rightEyebrow: [CGPoint],
        leftEye: [CGPoint], rightEye: [CGPoint]
    ) -> [CGPoint]? {
        guard !faceContour.isEmpty else { return nil }
        // Vision faceContour: ~17 points from one temple along the jawline
        // to the other temple (no forehead). We add an estimated forehead
        // arc above the eyebrows so the polygon encloses the whole face.

        // Eye-line distance for forehead-height estimate.
        let leftEyeC = centroid(leftEye)
        let rightEyeC = centroid(rightEye)
        let eyeDist: CGFloat
        if let l = leftEyeC, let r = rightEyeC {
            eyeDist = hypot(l.x - r.x, l.y - r.y)
        } else {
            // Fallback: face contour width
            let xs = faceContour.map { $0.x }
            eyeDist = (xs.max()! - xs.min()!) * 0.5
        }
        // Forehead arc: extend eyebrows upward in the local "face up"
        // direction. For a near-upright face the up direction is image-Y
        // negative. Use eye centroid → eyebrow centroid direction
        // as the "face up" axis so we handle tilted heads correctly.
        let foreheadHeight: CGFloat = eyeDist * 0.55
        let leftBrowC = centroid(leftEyebrow) ?? leftEyeC
        let rightBrowC = centroid(rightEyebrow) ?? rightEyeC
        var foreheadArc: [CGPoint] = []
        if let l = leftBrowC, let r = rightBrowC, let le = leftEyeC, let re = rightEyeC {
            // Per-eyebrow "up" vector: from eye centroid to eyebrow centroid,
            // normalized then scaled to foreheadHeight.
            func extendUp(eyebrow: CGPoint, eye: CGPoint) -> CGPoint {
                var dx = eyebrow.x - eye.x
                var dy = eyebrow.y - eye.y
                let len = hypot(dx, dy)
                if len < 1 { dx = 0; dy = -1 } else { dx /= len; dy /= len }
                return CGPoint(x: eyebrow.x + dx * foreheadHeight,
                               y: eyebrow.y + dy * foreheadHeight)
            }
            let lFar = extendUp(eyebrow: l, eye: le)
            let rFar = extendUp(eyebrow: r, eye: re)
            // Build arc with one extra interpolated point at the top of
            // the forehead so the polygon traces a curve, not a triangle.
            let topMid = CGPoint(x: (lFar.x + rFar.x) / 2,
                                 y: (lFar.y + rFar.y) / 2)
            foreheadArc = [lFar, topMid, rFar]
        }

        // Assemble polygon: face contour (assumed temple→chin→temple) +
        // forehead arc (right→left). Direction order matters for the
        // winding-rule fill, but CG handles both — choose consistent.
        // Vision's faceContour appears to go in a single direction along
        // the jawline; we follow it then append forehead arc reversed
        // so the polygon closes naturally.
        var polygon = faceContour
        polygon.append(contentsOf: foreheadArc)   // last → reversed in close
        // If contour ends near the LEFT side and forehead arc starts on
        // the LEFT, we'd double-back. Sort the polygon by angle around
        // its centroid to get a clean ring — robust against Vision's
        // contour ordering quirks.
        return sortRing(polygon)
    }

    private static func centroid(_ pts: [CGPoint]) -> CGPoint? {
        guard !pts.isEmpty else { return nil }
        let sx = pts.reduce(0) { $0 + $1.x } / CGFloat(pts.count)
        let sy = pts.reduce(0) { $0 + $1.y } / CGFloat(pts.count)
        return CGPoint(x: sx, y: sy)
    }

    /// Sort polygon vertices by angle around their centroid so they form
    /// a clean ring (no self-intersections).
    private static func sortRing(_ pts: [CGPoint]) -> [CGPoint] {
        guard pts.count >= 3 else { return pts }
        let c = centroid(pts)!
        return pts.sorted { a, b in
            atan2(a.y - c.y, a.x - c.x) < atan2(b.y - c.y, b.x - c.x)
        }
    }

    /// Rasterize a face polygon to a single-channel float32 mask in canvas
    /// coords (top-left origin), with a Gaussian-feathered edge. Inside
    /// the polygon = 1.0; outside = 0.0; edge transitions smoothly.
    static func rasterizeFacePolygonMask(
        polygon: [CGPoint], W: Int, H: Int, featherSigma: Double = 12.0
    ) -> [Float] {
        guard polygon.count >= 3 else {
            return [Float](repeating: 0, count: W * H)
        }
        // 1. Draw filled polygon to an 8-bit grayscale buffer.
        var bytes = [UInt8](repeating: 0, count: W * H)
        bytes.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: W, height: H,
                bitsPerComponent: 8, bytesPerRow: W,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            // CG bitmap contexts use bottom-left origin by default; flip
            // Y so our top-left coords map directly.
            ctx.translateBy(x: 0, y: CGFloat(H))
            ctx.scaleBy(x: 1, y: -1)
            ctx.setFillColor(gray: 1.0, alpha: 1.0)
            ctx.beginPath()
            ctx.move(to: polygon[0])
            for p in polygon.dropFirst() { ctx.addLine(to: p) }
            ctx.closePath()
            ctx.fillPath()
        }
        // 2. Convert to float, apply Gaussian blur for feathered edge.
        var floatMask = [Float](repeating: 0, count: W * H)
        for i in 0..<bytes.count { floatMask[i] = Float(bytes[i]) / 255.0 }
        if featherSigma > 0 {
            floatMask = gaussianBlur2D(floatMask, W: W, H: H, sigma: featherSigma)
        }
        return floatMask
    }

    /// Simple separable Gaussian blur on a 1-channel float buffer.
    private static func gaussianBlur2D(_ src: [Float], W: Int, H: Int, sigma: Double) -> [Float] {
        let radius = max(1, Int((3.0 * sigma).rounded()))
        var kernel = [Float](repeating: 0, count: 2 * radius + 1)
        var ksum: Float = 0
        for i in -radius...radius {
            let w = Float(exp(-Double(i * i) / (2 * sigma * sigma)))
            kernel[i + radius] = w
            ksum += w
        }
        for k in 0..<kernel.count { kernel[k] /= ksum }
        // Horizontal pass
        var tmp = [Float](repeating: 0, count: W * H)
        for y in 0..<H {
            let row = y * W
            for x in 0..<W {
                var s: Float = 0
                for k in -radius...radius {
                    let xi = min(max(x + k, 0), W - 1)
                    s += src[row + xi] * kernel[k + radius]
                }
                tmp[row + x] = s
            }
        }
        // Vertical pass
        var dst = [Float](repeating: 0, count: W * H)
        for y in 0..<H {
            let row = y * W
            for x in 0..<W {
                var s: Float = 0
                for k in -radius...radius {
                    let yi = min(max(y + k, 0), H - 1)
                    s += tmp[yi * W + x] * kernel[k + radius]
                }
                dst[row + x] = s
            }
        }
        return dst
    }

    // MARK: - Soft rectangle mask (port of light-avatar/core/utils/get_mask.py)

    /// Direct port of Ditto / light-avatar's get_mask. W×H float32, inner
    /// rect (ratio_w · ratio_h) is solid 1.0, the outer border is a
    /// radial-distance feather to 0. The mask is centered at the crop's
    /// geometric center (W/2, H/2) — same as the reference implementation.
    static func buildCropMaskF32(W: Int, H: Int, ratioW: Double = 0.9, ratioH: Double = 0.9) -> [Float] {
        let w = Int(Double(W) * ratioW)
        let h = Int(Double(H) * ratioH)
        let x1 = (W - w) / 2, x2 = x1 + w
        let y1 = (H - h) / 2, y2 = y1 + h
        var mask = [Float](repeating: 0, count: W * H)
        // Inner rect: solid 1
        for y in y1..<y2 {
            let row = y * W
            for x in x1..<x2 { mask[row + x] = 1.0 }
        }
        // Top edge (y in [0, y1), x in [x1, x2)): vertical fade 0→1
        for y in 0..<y1 {
            let v = Float(y) / Float(max(1, y1 - 1))
            let row = y * W
            for x in x1..<x2 { mask[row + x] = v }
        }
        let denBot = max(1, H - y2 - 1)
        for y in y2..<H {
            let v = Float(H - 1 - y) / Float(denBot)
            let row = y * W
            for x in x1..<x2 { mask[row + x] = v }
        }
        for x in 0..<x1 {
            let v = Float(x) / Float(max(1, x1 - 1))
            for y in y1..<y2 { mask[y * W + x] = v }
        }
        let denRight = max(1, W - x2 - 1)
        for x in x2..<W {
            let v = Float(W - 1 - x) / Float(denRight)
            for y in y1..<y2 { mask[y * W + x] = v }
        }
        // Corners — radial fade from 1 at the inner corner to 0 at the outer.
        for y in 0..<y1 {
            for x in 0..<x1 {
                let dx = Float(x1 - 1 - x) / Float(max(1, x1 - 1))
                let dy = Float(y1 - 1 - y) / Float(max(1, y1 - 1))
                let r = (dx * dx + dy * dy).squareRoot()
                mask[y * W + x] = max(0, 1 - min(1, r))
            }
        }
        for y in 0..<y1 {
            for x in x2..<W {
                let dx = Float(x - x2) / Float(denRight)
                let dy = Float(y1 - 1 - y) / Float(max(1, y1 - 1))
                let r = (dx * dx + dy * dy).squareRoot()
                mask[y * W + x] = max(0, 1 - min(1, r))
            }
        }
        for y in y2..<H {
            for x in 0..<x1 {
                let dx = Float(x1 - 1 - x) / Float(max(1, x1 - 1))
                let dy = Float(y - y2) / Float(denBot)
                let r = (dx * dx + dy * dy).squareRoot()
                mask[y * W + x] = max(0, 1 - min(1, r))
            }
        }
        for y in y2..<H {
            for x in x2..<W {
                let dx = Float(x - x2) / Float(denRight)
                let dy = Float(y - y2) / Float(denBot)
                let r = (dx * dx + dy * dy).squareRoot()
                mask[y * W + x] = max(0, 1 - min(1, r))
            }
        }
        return mask
    }

    // MARK: - vImage warp helpers

    /// Warp an ARGB8888 byte buffer by a 2D affine using vImage Lanczos.
    /// `affine` is the destination→source map (vImage convention).
    @discardableResult
    private static func vImageWarpARGB(
        src: UnsafeMutableRawPointer, srcW: Int, srcH: Int, srcBPR: Int,
        dst: UnsafeMutableRawPointer, dstW: Int, dstH: Int, dstBPR: Int,
        affine: Affine2D
    ) -> Int {
        var s = vImage_Buffer(data: src, height: vImagePixelCount(srcH),
                              width: vImagePixelCount(srcW), rowBytes: srcBPR)
        var d = vImage_Buffer(data: dst, height: vImagePixelCount(dstH),
                              width: vImagePixelCount(dstW), rowBytes: dstBPR)
        var transform = vImage_AffineTransform_Double(
            a:  affine.a, b: affine.b,
            c:  affine.c, d: affine.d,
            tx: affine.tx, ty: affine.ty
        )
        var bg: UInt32 = 0
        let flags = vImage_Flags(kvImageHighQualityResampling | kvImageBackgroundColorFill)
        return Int(vImageAffineWarpD_ARGB8888(&s, &d, nil, &transform, &bg, flags))
    }

    @discardableResult
    private static func vImageWarpFloat(
        src: UnsafeMutableRawPointer, srcW: Int, srcH: Int, srcBPR: Int,
        dst: UnsafeMutableRawPointer, dstW: Int, dstH: Int, dstBPR: Int,
        affine: Affine2D
    ) -> Int {
        var s = vImage_Buffer(data: src, height: vImagePixelCount(srcH),
                              width: vImagePixelCount(srcW), rowBytes: srcBPR)
        var d = vImage_Buffer(data: dst, height: vImagePixelCount(dstH),
                              width: vImagePixelCount(dstW), rowBytes: dstBPR)
        var transform = vImage_AffineTransform_Double(
            a:  affine.a, b: affine.b,
            c:  affine.c, d: affine.d,
            tx: affine.tx, ty: affine.ty
        )
        let bg: Float = 0
        let flags = vImage_Flags(kvImageHighQualityResampling | kvImageBackgroundColorFill)
        return Int(vImageAffineWarpD_PlanarF(&s, &d, nil, &transform, bg, flags))
    }

    private static func renderBGRA(_ cg: CGImage, w: Int, h: Int) -> ([UInt8], Int)? {
        let bytesPerRow = w * 4
        var bytes = [UInt8](repeating: 0, count: h * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        let ok: Bool = bytes.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: space, bitmapInfo: bitmapInfo
            ) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (bytes, bytesPerRow) : nil
    }

    // MARK: - Plan

    struct PutbackPlan {
        let outWidth: Int
        let outHeight: Int
        let canvasFrames: [[UInt8]]
        let canvasFPS: Double
        let bytesPerRow: Int
        /// Per-canvas-frame face crop params (smoothed). count == canvasFrames.count.
        let paramsPerFrame: [FaceCropParams]
        /// Per-canvas-frame DRIVER face polygon vertices (canvas pixel
        /// coords, top-left origin). count == canvasFrames.count.
        /// Used to build a face-shaped mask per output frame so only the
        /// face skin gets engine pixels — hair/neck/background pass
        /// through unchanged from the driver.
        let driverFacePolygonPerFrame: [[CGPoint]]
        /// First-frame RAW params (no smoothing). The engine processed the
        /// first frame's RAW Vision face rect to compute its internal
        /// M_o2c; we need the same raw values for an exact match.
        let firstFrameRawParams: FaceCropParams
        /// Engine's face anchor in the 384 crop, computed exactly from
        /// the first frame's faceW/faceH ratio:
        ///   anchor_y = 192 + (384·0.20/1.8) · (faceH_first / max(faceW_first, faceH_first))
        /// This deviates from the hardcoded 234.67 when the first frame's
        /// face rect isn't perfectly square.
        let engineFaceAnchorY: Double
        /// Static crop-space mask. ENGINE_CROP_SIZE×ENGINE_CROP_SIZE float [0,1].
        /// LEGACY: kept for static-portrait mode (no driver per-frame
        /// landmarks). Driver mode uses `driverFacePolygonPerFrame` instead.
        let cropMask: [Float]
        let cropMaskSize: Int
    }

    // ----------------------------------------------------------------
    // Bithuman Expression engine constants — must mirror the values in
    // bitHumanKit/Sources/Expression/ML/Rendering/ImagePreprocess.swift
    // faceAwareCropRect() and the engine's 384×384 output resolution.
    // ----------------------------------------------------------------

    /// Engine output canvas size (resampled to from `contextSide`).
    static let engineCropSize: Int = 384

    /// `contextSide = max(faceW, faceH) * engineContextScale`
    static let engineContextScale: Double = 1.8

    /// `yNudge = engineYNudgeRatio * faceH`  (shifts crop top-left up
    /// when negative, putting more forehead/hair in the crop).
    static let engineYNudgeRatio: Double = -0.20

    /// Theoretical engine face anchor in the 384 crop, derived analytically
    /// from the first frame's Vision face W and H using the SDK's exact
    /// formula. This is the FIRST-FRAME baseline — the actual engine
    /// output drifts from this per frame due to animation (mouth opening
    /// etc.). For per-frame alignment, use `detectFaceCenterInCrop` on
    /// each engine output and smooth across frames; this baseline is only
    /// used as a fallback when detection fails.
    static func engineFaceAnchor(faceW: Double, faceH: Double) -> CGPoint {
        let half = Double(engineCropSize) / 2.0
        let s = Double(engineCropSize) / (engineContextScale * max(faceW, faceH))
        let shift = s * (-engineYNudgeRatio) * faceH
        return CGPoint(x: half, y: half + shift)
    }

    /// Per-frame face pose detected via Vision landmarks. Center is in
    /// top-left pixel coords. Angle is the eye-mid → mouth-mid axis tilt
    /// (radians, same convention as parseRectFromLandmarks). Used on the
    /// engine output AND driver frames for per-frame alignment without
    /// any first-frame baked-in reference.
    struct FacePose {
        var center: CGPoint
        var angle: Double
    }

    /// Detect face center + angle on any frame (engine output or driver).
    /// Uses Vision face landmarks for both — the center is the face-rect
    /// midpoint (matches the engine's identity setup convention) and the
    /// angle is derived from eye_mid → mouth_mid axis (same convention as
    /// the driver-side params).
    static func detectFacePose(cg: CGImage) -> FacePose? {
        let req = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([req]) } catch { return nil }
        guard let faces = req.results, !faces.isEmpty else { return nil }
        let face = faces.max {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }!
        let imgSize = CGSize(width: cg.width, height: cg.height)
        let bb = face.boundingBox
        // Center: face bbox midpoint in top-left pixel coords.
        let cx = (bb.origin.x + bb.width / 2) * imgSize.width
        let cy = (1.0 - bb.origin.y - bb.height / 2) * imgSize.height
        // Angle: from eye-mid → mouth-mid axis (same as paramsFromFaceRect).
        let (eyeMid, mouthMid) = extractAxisAnchors(landmarks: face.landmarks, imgSize: imgSize)
        var angle = 0.0
        if let e = eyeMid, let m = mouthMid {
            let dx = Double(m.x - e.x), dy = Double(m.y - e.y)
            let l = (dx * dx + dy * dy).squareRoot()
            if l > 1e-3 {
                let uyx = dx / l, uyy = dy / l
                let uxx = uyy
                let uxy = -uyx
                var a = acos(max(-1.0, min(1.0, uxx)))
                if uxy < 0 { a = -a }
                angle = a
            }
        }
        return FacePose(center: CGPoint(x: cx, y: cy), angle: angle)
    }

    /// Convenience: detect just the face center (no angle), faster than
    /// `detectFacePose` because it uses face-rectangle detection only.
    /// Kept for callers that don't need angle.
    static func detectFaceCenterInCrop(cg: CGImage) -> CGPoint? {
        return detectFacePose(cg: cg)?.center
    }

    /// Smooth a [FacePose?] series independently per axis + angle.
    static func smoothPoses(_ raw: [FacePose?], sigma: Double = 3.0) -> [FacePose] {
        let n = raw.count
        guard n > 0 else { return [] }
        let centers = raw.map { $0?.center }
        let angles  = raw.map { $0?.angle  }
        let smoothCenters = smoothPoints(centers, sigma: sigma)
        // Smooth angles with same interp + Gaussian pipeline
        let valid = (0..<n).filter { angles[$0] != nil }
        let firstA = valid.first.map { angles[$0]! } ?? 0
        let lastA  = valid.last.map { angles[$0]! } ?? 0
        var filledA = [Double]()
        var nextValid = 0
        for i in 0..<n {
            if let a = angles[i] {
                filledA.append(a)
                while nextValid < valid.count && valid[nextValid] <= i { nextValid += 1 }
            } else if valid.isEmpty {
                filledA.append(0)
            } else if i < valid.first! {
                filledA.append(firstA)
            } else if i > valid.last! {
                filledA.append(lastA)
            } else {
                let lo = valid[nextValid - 1], hi = valid[nextValid]
                let t = Double(i - lo) / Double(hi - lo)
                filledA.append(angles[lo]! + (angles[hi]! - angles[lo]!) * t)
            }
        }
        let smoothA = gaussianSmooth(filledA, sigma: sigma)
        return (0..<n).map { FacePose(center: smoothCenters[$0], angle: smoothA[$0]) }
    }

    /// Temporal smoothing for a [CGPoint?] series — linear interp for nils
    /// then Gaussian smooth each axis.
    static func smoothPoints(_ raw: [CGPoint?], sigma: Double = 5.0) -> [CGPoint] {
        let n = raw.count
        guard n > 0 else { return [] }
        let valid = (0..<n).filter { raw[$0] != nil }
        guard !valid.isEmpty else { return Array(repeating: .zero, count: n) }
        // Fill nils with nearest valid (linear interp on interior gaps)
        var filled: [CGPoint] = []
        filled.reserveCapacity(n)
        let firstValid = raw[valid.first!]!
        let lastValid = raw[valid.last!]!
        var nextValidIdx = 0
        for i in 0..<n {
            if let p = raw[i] {
                filled.append(p)
                while nextValidIdx < valid.count && valid[nextValidIdx] <= i { nextValidIdx += 1 }
            } else if i < valid.first! {
                filled.append(firstValid)
            } else if i > valid.last! {
                filled.append(lastValid)
            } else {
                // Interp between previous valid (valid[nextValidIdx - 1])
                // and next valid (valid[nextValidIdx]).
                let lo = valid[nextValidIdx - 1], hi = valid[nextValidIdx]
                let a = raw[lo]!, b = raw[hi]!
                let t = CGFloat(Double(i - lo) / Double(hi - lo))
                filled.append(CGPoint(x: a.x + (b.x - a.x) * t,
                                       y: a.y + (b.y - a.y) * t))
            }
        }
        let xs = filled.map { Double($0.x) }
        let ys = filled.map { Double($0.y) }
        let sx = gaussianSmooth(xs, sigma: sigma)
        let sy = gaussianSmooth(ys, sigma: sigma)
        return (0..<n).map { CGPoint(x: sx[$0], y: sy[$0]) }
    }

    static func makePlan(portraitURL: URL) throws -> PutbackPlan {
        guard let src = CGImageSourceCreateWithURL(portraitURL as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { throw CompareError.cli("could not decode portrait: \(portraitURL.path)") }
        guard let (sourceBytes, bpr) = renderBGRA(cg, w: cg.width, h: cg.height) else {
            throw CompareError.cli("source portrait render failed")
        }
        let imgSize = CGSize(width: cg.width, height: cg.height)
        // Run a single landmark request so we get both the face bbox
        // (for engine-matching crop sizing) and eye/mouth centroids
        // (for the rotation).
        let req = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        guard let face = req.results?.max(by: {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }) else {
            throw CompareError.cli("no face detected in portrait")
        }
        let faceRect = visionBBoxToPixelRect(face.boundingBox, imgSize: imgSize)
        let (eyeMid, mouthMid) = extractAxisAnchors(landmarks: face.landmarks, imgSize: imgSize)
        let params = paramsFromFaceRect(faceRect: faceRect, eyeMid: eyeMid, mouthMid: mouthMid)
        let mask = buildCropMaskF32(W: engineCropSize, H: engineCropSize)
        // For a static portrait there's only one frame, so smoothed[0] == raw.
        let anchor = engineFaceAnchor(faceW: params.faceW, faceH: params.faceH)
        // Face polygon (chin → temples → forehead arc) for canvas-coords
        // mask. Empty array = fallback to legacy crop-warp mask.
        let polygon = extractFacePolygon(cg: cg) ?? []
        return PutbackPlan(
            outWidth: cg.width, outHeight: cg.height,
            canvasFrames: [sourceBytes],
            canvasFPS: 25.0,
            bytesPerRow: bpr,
            paramsPerFrame: [params],
            driverFacePolygonPerFrame: [polygon],
            firstFrameRawParams: params,
            engineFaceAnchorY: Double(anchor.y),
            cropMask: mask,
            cropMaskSize: engineCropSize
        )
    }

    static func firstFrame(of url: URL) throws -> CGImage {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        do { return try gen.copyCGImage(at: .zero, actualTime: nil) }
        catch { throw CompareError.cli("could not extract first frame from \(url.path): \(error)") }
    }

    static func makeDriverPlan(driverURL: URL) throws -> PutbackPlan {
        let asset = AVURLAsset(url: driverURL)
        let semaphore = DispatchSemaphore(value: 0)
        var loadedTrack: AVAssetTrack?
        var loadedFPS: Double = 24.0
        var loadErr: Error?
        Task {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                if let t = tracks.first {
                    let fps: Float = try await t.load(.nominalFrameRate)
                    loadedFPS = Double(fps)
                    loadedTrack = t
                }
            } catch { loadErr = error }
            semaphore.signal()
        }
        semaphore.wait()
        if let loadErr { throw CompareError.cli("driver track load failed: \(loadErr)") }
        guard let track = loadedTrack else {
            throw CompareError.cli("driver video has no video track: \(driverURL.path)")
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else {
            throw CompareError.cli("AVAssetReader startReading failed")
        }

        var frames: [[UInt8]] = []
        var rawParams: [FaceCropParams?] = []
        var rawPolygons: [[CGPoint]] = []
        var outW = 0, outH = 0, bytesPerRow = 0

        while let sbuf = output.copyNextSampleBuffer() {
            guard let pb = CMSampleBufferGetImageBuffer(sbuf) else { continue }
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            let w = CVPixelBufferGetWidth(pb)
            let h = CVPixelBufferGetHeight(pb)
            let srcBPR = CVPixelBufferGetBytesPerRow(pb)
            let base = CVPixelBufferGetBaseAddress(pb)!
            let tightBPR = w * 4
            var buf = [UInt8](repeating: 0, count: h * tightBPR)
            buf.withUnsafeMutableBytes { dst in
                for y in 0..<h {
                    memcpy(dst.baseAddress!.advanced(by: y * tightBPR),
                           base.advanced(by: y * srcBPR), tightBPR)
                }
            }
            // Detect face + landmarks directly on the pb (no CGImage roundtrip).
            let req = VNDetectFaceLandmarksRequest()
            try? VNImageRequestHandler(cvPixelBuffer: pb, options: [:]).perform([req])
            let imgSize = CGSize(width: w, height: h)
            var params: FaceCropParams? = nil
            var polygon: [CGPoint] = []
            if let face = req.results?.max(by: {
                $0.boundingBox.width * $0.boundingBox.height
                    < $1.boundingBox.width * $1.boundingBox.height
            }) {
                let faceRect = visionBBoxToPixelRect(face.boundingBox, imgSize: imgSize)
                let (eyeMid, mouthMid) = extractAxisAnchors(landmarks: face.landmarks, imgSize: imgSize)
                params = paramsFromFaceRect(faceRect: faceRect, eyeMid: eyeMid, mouthMid: mouthMid)
                // Build face polygon from the SAME landmark detection.
                if let lm = face.landmarks {
                    let H = imgSize.height
                    func ptsTL(_ r: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                        guard let r = r else { return [] }
                        return r.pointsInImage(imageSize: imgSize).map { CGPoint(x: $0.x, y: H - $0.y) }
                    }
                    polygon = facePolygonFromRegions(
                        faceContour: ptsTL(lm.faceContour),
                        leftEyebrow: ptsTL(lm.leftEyebrow),
                        rightEyebrow: ptsTL(lm.rightEyebrow),
                        leftEye: ptsTL(lm.leftEye),
                        rightEye: ptsTL(lm.rightEye)
                    ) ?? []
                }
            }
            CVPixelBufferUnlockBaseAddress(pb, .readOnly)
            if outW == 0 { outW = w; outH = h; bytesPerRow = tightBPR }
            frames.append(buf)
            rawParams.append(params)
            rawPolygons.append(polygon)
        }
        if reader.status == .failed {
            throw CompareError.cli("AVAssetReader read failed: \(reader.error?.localizedDescription ?? "unknown")")
        }
        guard !frames.isEmpty else { throw CompareError.cli("driver yielded zero frames") }
        let det = rawParams.compactMap { $0 }.count
        FileHandle.standardError.write(Data(
            "[Putback] driver: \(frames.count) frames, \(det) landmark detections, FPS \(loadedFPS)\n".utf8
        ))
        let smoothed = smoothParams(rawParams)
        let mask = buildCropMaskF32(W: engineCropSize, H: engineCropSize)
        // Engine processed the RAW first frame's Vision face rect for the
        // identity crop — for an exact putback alignment match, we use
        // the RAW (not smoothed) first-frame params to compute the
        // engine's face anchor and the rotation reference.
        let firstRaw = rawParams.first(where: { $0 != nil }) ??
                       FaceCropParams(centerX: 0, centerY: 0, size: 1, angle: 0,
                                       faceW: 1, faceH: 1)
        let unwrapped = firstRaw!
        let anchor = engineFaceAnchor(faceW: unwrapped.faceW, faceH: unwrapped.faceH)
        return PutbackPlan(
            outWidth: outW, outHeight: outH,
            canvasFrames: frames,
            canvasFPS: loadedFPS > 0 ? loadedFPS : 24.0,
            bytesPerRow: bytesPerRow,
            paramsPerFrame: smoothed,
            driverFacePolygonPerFrame: rawPolygons,
            firstFrameRawParams: unwrapped,
            engineFaceAnchorY: Double(anchor.y),
            cropMask: mask,
            cropMaskSize: engineCropSize
        )
    }

    // MARK: - Per-frame compositor (Ditto-exact)

    /// 1. Compute M_c2o (crop→original) from this frame's smoothed params.
    /// 2. vImageAffineWarpD_ARGB8888 on engine BGRA → warped BGRA canvas.
    /// 3. vImageAffineWarpD_PlanarF on the crop mask → warped float mask canvas.
    /// 4. Per-pixel blend: result = m * warped_render + (1 - m) * driver.
    static func compositeFrame(
        plan: PutbackPlan, animatedFace: CGImage, frameIndex: Int,
        engineAnchorOverride: CGPoint? = nil,
        engineAngleOverride: Double? = nil
    ) -> CGImage? {
        // Pick canvas frame + face params via FPS rate-map.
        let canvasIdx: Int
        if plan.canvasFrames.count == 1 {
            canvasIdx = 0
        } else {
            let mapped = Int((Double(frameIndex) * plan.canvasFPS / 25.0).rounded(.down))
            canvasIdx = min(mapped, plan.canvasFrames.count - 1)
        }
        let params = plan.paramsPerFrame[canvasIdx]
        let outW = plan.outWidth, outH = plan.outHeight
        let bpr = plan.bytesPerRow
        let dsize = Double(plan.cropMaskSize)

        // Per-frame relative rotation: prefer engine_angle DETECTED on
        // this engine output frame (rather than first-frame-baked angle).
        // If detection unavailable, fall back to the first-frame raw
        // angle as a baseline.
        let engineAngle = engineAngleOverride ?? plan.firstFrameRawParams.angle
        let relParams = FaceCropParams(
            centerX: params.centerX,
            centerY: params.centerY,
            size: params.size,
            angle: params.angle - engineAngle,
            faceW: params.faceW,
            faceH: params.faceH
        )
        // Per-frame engine face anchor (detected via Vision per engine
        // 384 output frame). Falls back to first-frame analytical anchor.
        let targetCenter = engineAnchorOverride
            ?? CGPoint(x: dsize / 2, y: plan.engineFaceAnchorY)
        let m_o2c = buildM_o2c(params: relParams, dsize: dsize, targetCenter: targetCenter)
        // For each canvas pixel (px, py), we want the corresponding
        // crop pixel via M_o2c.apply((px, py)). Bilinear sample both
        // engine and mask at that crop coord, then alpha-blend.
        if frameIndex == 0 {
            let probe = m_o2c.apply(CGPoint(x: params.centerX, y: params.centerY))
            FileHandle.standardError.write(Data(String(format:
                "[Putback] f0 params: center=(%.0f,%.0f) size=%.0f angle=%.2f°  M_o2c face_center→crop=(%.1f,%.1f) [expect (%.1f,%.1f)]\n",
                params.centerX, params.centerY, params.size, params.angle * 180 / .pi,
                probe.x, probe.y, targetCenter.x, targetCenter.y
            ).utf8))
        }

        // Render engine to a 384×384 BGRA tight buffer for bilinear sampling.
        guard let (engineBytes, eBPR) = renderBGRA(animatedFace,
                                                   w: plan.cropMaskSize,
                                                   h: plan.cropMaskSize) else { return nil }
        let cropSize = plan.cropMaskSize
        let cropMaxX = Double(cropSize - 1)
        let cropMaxY = Double(cropSize - 1)

        var canvas = plan.canvasFrames[canvasIdx]
        let map = m_o2c   // canvas (px, py) → crop (cx, cy)

        // FACE-POLYGON MASK PATH: if a non-empty face polygon is stored
        // for this frame, rasterize it into a canvas-coords float mask
        // and use that for the alpha blend. The mask shape follows the
        // driver's actual face boundary — no rectangle, no hair/neck
        // leakage. Inside the polygon, engine pixels visible; outside,
        // driver passes through. Feathered edge softens the seam.
        let driverPolygon = plan.driverFacePolygonPerFrame[canvasIdx]
        let useFacePolygon = driverPolygon.count >= 3
        let polygonMask: [Float]? = useFacePolygon
            ? rasterizeFacePolygonMask(polygon: driverPolygon, W: outW, H: outH, featherSigma: 12.0)
            : nil

        canvas.withUnsafeMutableBufferPointer { dst in
            engineBytes.withUnsafeBufferPointer { eb in
                plan.cropMask.withUnsafeBufferPointer { cropMb in
                    for py in 0..<outH {
                        let pyD = Double(py)
                        let dstRow = py * bpr
                        for px in 0..<outW {
                            let pxD = Double(px)
                            let cx = map.a * pxD + map.b * pyD + map.tx
                            let cy = map.c * pxD + map.d * pyD + map.ty
                            if cx < 0 || cy < 0 || cx >= cropMaxX || cy >= cropMaxY { continue }

                            let ix = Int(cx.rounded(.down))
                            let iy = Int(cy.rounded(.down))
                            let fx = cx - Double(ix)
                            let fy = cy - Double(iy)
                            let w00 = (1 - fx) * (1 - fy)
                            let w10 = fx * (1 - fy)
                            let w01 = (1 - fx) * fy
                            let w11 = fx * fy

                            // Alpha selection: face polygon mask in canvas
                            // coords (preferred), else legacy crop-warp mask.
                            let alpha: Double
                            if let pm = polygonMask {
                                alpha = Double(pm[py * outW + px])
                            } else {
                                let m00 = Double(cropMb[iy * cropSize + ix])
                                let m10 = Double(cropMb[iy * cropSize + (ix + 1)])
                                let m01 = Double(cropMb[(iy + 1) * cropSize + ix])
                                let m11 = Double(cropMb[(iy + 1) * cropSize + (ix + 1)])
                                alpha = w00 * m00 + w10 * m10 + w01 * m01 + w11 * m11
                            }
                            if alpha <= 0.001 { continue }
                            let alphaC = max(0.0, min(1.0, alpha))
                            let oneMinus = 1.0 - alphaC

                            // Bilinear sample engine BGRA.
                            let o00 = iy * eBPR + ix * 4
                            let o10 = o00 + 4
                            let o01 = o00 + eBPR
                            let o11 = o01 + 4
                            let dOff = dstRow + px * 4
                            for c in 0...2 {
                                let s = w00 * Double(eb[o00 + c])
                                      + w10 * Double(eb[o10 + c])
                                      + w01 * Double(eb[o01 + c])
                                      + w11 * Double(eb[o11 + c])
                                let dCur = Double(dst[dOff + c])
                                let blended = alphaC * s + oneMinus * dCur
                                dst[dOff + c] = UInt8(max(0, min(255, blended.rounded())))
                            }
                            dst[dOff + 3] = 255
                        }
                    }
                }
            }
        }

        let space = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        let provider = CGDataProvider(data: NSData(bytes: canvas, length: canvas.count))!
        return CGImage(
            width: outW, height: outH,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: bpr, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

// MARK: - Aliases so CompareQuality still compiles

typealias PutbackPlan = Putback.PutbackPlan
