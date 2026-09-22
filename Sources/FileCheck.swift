import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Vision

struct TextBox {
    let text: String
    let rect: CGRect
}

struct SafeArea {
    let top: Double
    let bottom: Double
    let left: Double
    let right: Double
    let reason: String

    var rect: CGRect {
        CGRect(x: left, y: top, width: 1 - left - right, height: 1 - top - bottom)
    }

    static let metaVertical = SafeArea(top: 0.14, bottom: 0.35, left: 0.06, right: 0.06,
                                       reason: "the app's buttons and captions cover it")
    static let instagramGrid = SafeArea(top: 0, bottom: 0, left: 34.0 / 1080, right: 34.0 / 1080,
                                        reason: "the profile grid crops it off")
    static let youtubeBanner = SafeArea(top: 508.5 / 1440, bottom: 508.5 / 1440, left: 507.0 / 2560, right: 507.0 / 2560,
                                        reason: "phones crop it off")
}

struct ImageFacts {
    enum ColorKind { case srgb, p3, adobeRGB, otherRGB, untagged, cmyk, gray }

    let url: URL
    let width: Int
    let height: Int
    let dpiTag: Double?
    let colorModel: String
    let profile: String?
    let hasAlpha: Bool
    let format: String
    let bytes: Int
    let preview: CGImage

    var color: ColorKind {
        if colorModel == "CMYK" { return .cmyk }
        if colorModel == "Gray" { return .gray }
        guard let p = profile?.lowercased() else { return .untagged }
        if p.contains("srgb") { return .srgb }
        if p.contains("p3") { return .p3 }
        if p.contains("adobe rgb") { return .adobeRGB }
        return .otherRGB
    }

    var colorLabel: String {
        switch color {
        case .untagged: "RGB, no profile"
        case .cmyk, .gray: [colorModel, profile].compactMap { $0 }.joined(separator: " · ")
        default: profile ?? colorModel
        }
    }

    static func read(_ url: URL) -> ImageFacts? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              var width = props[kCGImagePropertyPixelWidth] as? Int,
              var height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        if let orientation = props[kCGImagePropertyOrientation] as? Int, orientation >= 5 {
            swap(&width, &height)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
        ]
        guard let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return ImageFacts(url: url, width: width, height: height,
                          dpiTag: props[kCGImagePropertyDPIWidth] as? Double,
                          colorModel: props[kCGImagePropertyColorModel] as? String ?? "RGB",
                          profile: props[kCGImagePropertyProfileName] as? String,
                          hasAlpha: props[kCGImagePropertyHasAlpha] as? Bool ?? false,
                          format: formatName(CGImageSourceGetType(source) as String?),
                          bytes: bytes, preview: preview)
    }

    static func findText(in image: CGImage) -> [TextBox] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.5 else { return nil }
            let box = observation.boundingBox
            return TextBox(text: candidate.string,
                           rect: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        }
    }

    private static func formatName(_ uti: String?) -> String {
        guard let uti, let type = UTType(uti) else { return "Unknown" }
        if type.conforms(to: .jpeg) { return "JPEG" }
        if type.conforms(to: .png) { return "PNG" }
        if type.conforms(to: .heic) || type.conforms(to: .heif) { return "HEIC" }
        if type.conforms(to: .tiff) { return "TIFF" }
        if type.conforms(to: .webP) { return "WebP" }
        if type.conforms(to: .gif) { return "GIF" }
        if type.identifier == "com.adobe.photoshop-image" { return "PSD" }
        if type.identifier == "public.avif" { return "AVIF" }
        return type.preferredFilenameExtension?.uppercased() ?? "Unknown"
    }
}

struct CheckTarget: Identifiable {
    enum Kind {
        case screen(SizePreset, Pane)
        case print(PrintSpec)
    }

    let id: String
    let name: String
    let kind: Kind

    static func groups(calculator: CalcPrint?) -> [(title: String, targets: [CheckTarget])] {
        var groups: [(title: String, targets: [CheckTarget])] = []
        if let c = calculator {
            groups.append(("Calculator", [CheckTarget(id: "calc", name: "\(c.title) · \(c.spec.kind.rawValue)",
                                                      kind: .print(c.spec))]))
        }
        for pane in [Pane.music, .social, .web] {
            let presets = PresetData.presets(for: pane, printDPI: 300) ?? []
            groups.append((pane.rawValue, presets.map {
                CheckTarget(id: "screen:\($0.name)", name: $0.name, kind: .screen($0, pane))
            }))
        }
        for group in PresetData.printGroups {
            groups.append((group.title, group.sizes.map {
                CheckTarget(id: "print:\($0.title)", name: $0.title, kind: .print($0.spec))
            }))
        }
        return groups
    }

    static func suggest(for f: ImageFacts, in groups: [(title: String, targets: [CheckTarget])]) -> String? {
        let w = Double(f.width), h = Double(f.height), r = w / h
        let targets = groups.flatMap(\.targets)
        func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) / b < 0.005 }
        let screens = [Pane.social, .music, .web].flatMap { pane in
            targets.compactMap { t -> (id: String, preset: SizePreset)? in
                if case .screen(let p, pane) = t.kind { return (t.id, p) }
                return nil
            }
        }

        if let exact = screens.first(where: { $0.preset.width == w && $0.preset.height == h }) { return exact.id }
        if max(w, h) <= 4000, let shaped = screens.first(where: { close(r, $0.preset.width / $0.preset.height) }) {
            return shaped.id
        }
        // Sizes share ratios (half letter and tabloid are both 11:17), so rank by closeness to recommended DPI.
        let long = max(w, h)
        let prints = targets.compactMap { t -> (id: String, score: Double)? in
            guard case .print(let s) = t.kind else { return nil }
            let b = s.bleed
            let trim = (long: max(s.width, s.height), short: min(s.width, s.height))
            let doc = (long: trim.long + 2 * b, short: trim.short + 2 * b)
            let imageRatio = min(w, h) / long
            guard let matched = [trim, doc].first(where: { close(imageRatio, $0.short / $0.long) }) else { return nil }
            return (t.id, abs(log(long / matched.long / Double(s.dpi))))
        }
        return prints.min { $0.score < $1.score }?.id
    }
}

enum CheckStatus { case pass, warn, fail, pending }

struct CheckItem: Identifiable {
    let title: String
    let status: CheckStatus
    let detail: String

    var id: String { title }
}

struct FixPlan {
    var crop: CGRect?
    var size: (w: Int, h: Int)?
    var tiffDPI: Double?
    var png = false
    var maxBytes: Int?
    var minSide: Double?
    var needed = false
    var steps: [String] = []
    var suffix = ""

    var type: UTType {
        tiffDPI != nil ? .tiff : (png ? .png : .jpeg)
    }
}

struct Fit {
    let matches: Bool
    let crop: CGRect
    let croppedW: Double
    let croppedH: Double
    let loss: Double
    let sides: String

    init(_ iw: Double, _ ih: Double, _ tw: Double, _ th: Double) {
        let ri = iw / ih, rt = tw / th
        matches = abs(ri - rt) / rt < 0.01
        if ri > rt {
            let f = rt / ri
            crop = CGRect(x: (1 - f) / 2, y: 0, width: f, height: 1)
            croppedW = iw * f
            croppedH = ih
            sides = "left and right"
            loss = 1 - f
        } else {
            let f = ri / rt
            crop = CGRect(x: 0, y: (1 - f) / 2, width: 1, height: f)
            croppedW = iw
            croppedH = ih * f
            sides = "top and bottom"
            loss = 1 - f
        }
    }

    var exact: Bool { loss < 0.0005 }

    func upscale(to tw: Double, _ th: Double) -> Double {
        max(tw / croppedW, th / croppedH)
    }
}

struct CheckReport {
    var items: [CheckItem] = []
    var crop: CGRect?
    var safe: CGRect?
    var trim: CGRect?
    var flagged: [CGRect] = []
    var plan = FixPlan()

    var verdict: CheckStatus {
        let statuses = items.map(\.status)
        if statuses.contains(.fail) { return .fail }
        if statuses.contains(.warn) { return .warn }
        return .pass
    }

    mutating func add(_ title: String, _ status: CheckStatus, _ detail: String, fixable: Bool = true) {
        items.append(CheckItem(title: title, status: status, detail: detail))
        if fixable, status == .fail || status == .warn { plan.needed = true }
    }

    static func make(_ f: ImageFacts, _ target: CheckTarget, text: [TextBox], textReady: Bool) -> CheckReport {
        switch target.kind {
        case .screen(let preset, let pane): forScreen(f, preset, pane, text, textReady)
        case .print(let spec): forPrint(f, spec, target.name, text, textReady)
        }
    }

    private static let urlPattern = #"(www\.|https?://|@[a-z0-9_.]{2,}|\b[a-z0-9-]+\.(com|net|org|io|co|fm|me|app|link|info|biz|us|uk|de)\b)"#

    private static func quote(_ boxes: [TextBox]) -> String {
        let shown = boxes.prefix(2).map { "\u{201C}\(String($0.text.prefix(28)))\u{201D}" }.joined(separator: ", ")
        return boxes.count > 2 ? "\(shown) and \(boxes.count - 2) more" : shown
    }

    private static func percent(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }

    private static func forScreen(_ f: ImageFacts, _ p: SizePreset, _ pane: Pane,
                                  _ text: [TextBox], _ ready: Bool) -> CheckReport {
        var r = CheckReport()
        r.plan.suffix = p.name
        let iw = Double(f.width), ih = Double(f.height)
        let fit = Fit(iw, ih, p.width, p.height)
        let up = fit.upscale(to: p.width, p.height)
        let have = Calc.pxPair(iw, ih)

        if f.width == Int(p.width), f.height == Int(p.height) {
            r.add("Size", .pass, "Exactly \(p.pixels)")
        } else if up <= 1.0005 {
            if p.minimum {
                r.add("Size", .pass, "\(have) — at or above the \(p.pixels) minimum")
            } else {
                r.add("Size", .pass, "\(have) — bigger than \(p.pixels), so it gets scaled down")
                if up < 0.9995 {
                    r.plan.size = (Int(p.width), Int(p.height))
                    r.plan.needed = true
                }
            }
        } else if let floor = p.floor, min(fit.croppedW, fit.croppedH) >= floor {
            r.add("Size", .warn, "\(have) — above the \(Int(floor)) px minimum, but \(p.pixels) is recommended", fixable: false)
        } else if p.minimum || p.floor != nil {
            let minimum = p.floor.map { Calc.pxPair($0, $0) } ?? p.pixels
            r.add("Size", .fail, "\(have) — below the \(minimum) minimum", fixable: false)
        } else if up <= 1.1 {
            r.add("Size", .warn, "\(have) — a little small, so it gets upscaled \(Calc.fmt(up, 2))×", fixable: false)
        } else {
            r.add("Size", .fail, "\(have) — too small; it gets upscaled \(Calc.fmt(up, 1))× and will look soft. Ask for a bigger original.", fixable: false)
        }

        if fit.matches {
            r.add("Shape", .pass, "\(Calc.ratio(iw, ih)) matches")
        } else {
            r.add("Shape", .warn, "\(Calc.ratio(iw, ih)) vs \(p.ratio) — a center crop cuts \(percent(fit.loss)) off the \(fit.sides)")
            r.crop = fit.crop
        }
        if !fit.exact { r.plan.crop = fit.crop }

        switch f.color {
        case .srgb: r.add("Color", .pass, "sRGB")
        case .gray: r.add("Color", .pass, "Grayscale")
        case .p3: r.add("Color", .warn, "Display P3 — convert to sRGB so it looks the same on every screen")
        case .adobeRGB: r.add("Color", .warn, "Adobe RGB — convert to sRGB or it'll look dull online")
        case .otherRGB: r.add("Color", .warn, "\(f.colorLabel) — convert to sRGB")
        case .untagged: r.add("Color", .warn, "No color profile — export as sRGB so colors don't shift")
        case .cmyk: r.add("Color", .fail, "CMYK — screens need RGB")
        }

        switch f.format {
        case "JPEG", "PNG":
            r.add("Format", .pass, f.format)
        case "WebP", "AVIF":
            r.add("Format", pane == .web ? .pass : .warn,
                  pane == .web ? "\(f.format) — fine for web pages" : "\(f.format) — most platforms want JPEG or PNG")
        case "HEIC":
            r.add("Format", .warn, "HEIC — convert to JPEG before sending")
        case "GIF":
            r.add("Format", .warn, "GIF — 256 colors max; use JPEG or PNG for stills")
        default:
            r.add("Format", .warn, "\(f.format) — upload a JPEG or PNG instead")
        }
        r.plan.png = f.format == "PNG"

        if let cap = p.maxBytes {
            let size = ByteCountFormatter.string(fromByteCount: Int64(f.bytes), countStyle: .file)
            let limit = ByteCountFormatter.string(fromByteCount: Int64(cap), countStyle: .file)
            r.add("File size", f.bytes > cap ? .fail : .pass,
                  f.bytes > cap ? "\(size) — over the \(limit) limit" : "\(size) — under the \(limit) limit")
            r.plan.maxBytes = cap
        }
        if p.minimum { r.plan.minSide = min(p.width, p.height) }

        if !ready {
            if p.safe != nil || p.noText || p.noURLs {
                r.add("Text", .pending, "Looking for text…", fixable: false)
            }
        } else {
            if let safe = p.safe {
                r.safe = safe.rect
                let bad = text.filter { !safe.rect.insetBy(dx: -0.005, dy: -0.005).contains($0.rect) }
                r.flagged += bad.map(\.rect)
                if bad.isEmpty {
                    r.add("Safe zone", .pass, text.isEmpty ? "No text near the edges" : "Text stays clear of the edges")
                } else {
                    r.add("Safe zone", .warn, "\(quote(bad)) sits where \(safe.reason)", fixable: false)
                }
            }
            if p.noText {
                if text.isEmpty {
                    r.add("Text", .pass, "No text — Spotify doesn't allow it here")
                } else {
                    r.add("Text", .fail, "Spotify doesn't allow text on artist images — found \(quote(text))", fixable: false)
                    r.flagged += text.map(\.rect)
                }
            }
            if p.noURLs {
                let links = text.filter { $0.text.range(of: urlPattern, options: [.regularExpression, .caseInsensitive]) != nil }
                if links.isEmpty {
                    r.add("Text", .pass, "No URLs or handles")
                } else {
                    r.add("Text", .fail, "Stores reject URLs and handles on covers — found \(quote(links))", fixable: false)
                    r.flagged += links.map(\.rect)
                }
            }
        }

        if r.plan.crop != nil, !fit.matches { r.plan.steps.append("crops to \(p.ratio)") }
        if let size = r.plan.size { r.plan.steps.append("resizes to \(Calc.pxPair(Double(size.w), Double(size.h)))") }
        if f.color != .srgb { r.plan.steps.append("converts to sRGB") }
        r.plan.steps.append(r.plan.png ? "saves a PNG" : "saves a max-quality JPEG")
        if let cap = r.plan.maxBytes {
            r.plan.steps.append("keeps it under \(ByteCountFormatter.string(fromByteCount: Int64(cap), countStyle: .file))")
        }
        return r
    }

    private static func forPrint(_ f: ImageFacts, _ spec: PrintSpec, _ name: String,
                                 _ text: [TextBox], _ ready: Bool) -> CheckReport {
        var r = CheckReport()
        r.plan.suffix = "print \(name)"
        let iw = Double(f.width), ih = Double(f.height)
        var tw = spec.width, th = spec.height
        if (iw > ih) != (tw > th), tw != th { swap(&tw, &th) }
        let b = spec.bleed
        let hasBleed = b > 0 && abs(iw / ih - (tw + 2 * b) / (th + 2 * b)) < abs(iw / ih - tw / th)
        let bw = hasBleed ? tw + 2 * b : tw
        let bh = hasBleed ? th + 2 * b : th
        let fit = Fit(iw, ih, bw, bh)
        let dpi = fit.croppedW / bw
        let need = Double(spec.dpi)
        let sizeText = spec.size(tw, th)
        let docPixels = Calc.pxPair((tw + 2 * b) * need, (th + 2 * b) * need)

        if dpi >= need * 0.995 {
            r.add("Resolution", .pass, "\(Int(dpi)) DPI at \(sizeText) — \(spec.dpi) recommended")
        } else if dpi >= need * 2 / 3 {
            r.add("Resolution", .warn, "\(Int(dpi)) DPI — fine from a step back, soft up close (\(spec.dpi) recommended)", fixable: false)
        } else {
            r.add("Resolution", .fail, "\(Int(dpi)) DPI — too low. This needs \(docPixels) at \(spec.dpi) DPI; if it came through Messages or email, ask for the original.", fixable: false)
        }

        let frame = fit.matches ? CGRect(x: 0, y: 0, width: 1, height: 1) : fit.crop
        if fit.matches {
            r.add("Shape", .pass, "Matches \(sizeText)\(hasBleed ? " plus bleed" : "")")
        } else {
            r.add("Shape", .warn, "\(Calc.ratio(iw, ih)) doesn't match \(sizeText) — a center crop cuts \(percent(fit.loss)) off the \(fit.sides)")
            r.crop = fit.crop
            r.plan.crop = fit.crop
            r.plan.steps.append("crops to \(sizeText)\(hasBleed ? " plus bleed" : "")")
        }

        if spec.kind == .photo {
            r.add("Bleed", .pass, "None needed for lab prints")
        } else if hasBleed {
            r.add("Bleed", .pass, "Includes \(spec.length(b)) bleed")
            r.trim = CGRect(x: frame.minX + b / bw * frame.width, y: frame.minY + b / bh * frame.height,
                            width: tw / bw * frame.width, height: th / bh * frame.height)
        } else {
            r.add("Bleed", .warn, "No bleed — extend the art \(spec.length(b)) past every edge (\(spec.size(tw + 2 * b, th + 2 * b)) document)", fixable: false)
        }

        if !ready {
            r.add("Safe zone", .pending, "Looking for text near the edges…", fixable: false)
        } else {
            let inset = (hasBleed ? b : 0) + spec.safe
            let safe = CGRect(x: frame.minX + inset / bw * frame.width, y: frame.minY + inset / bh * frame.height,
                              width: (bw - 2 * inset) / bw * frame.width, height: (bh - 2 * inset) / bh * frame.height)
            r.safe = safe
            let bad = text.filter { !safe.insetBy(dx: -0.002, dy: -0.002).contains($0.rect) }
            r.flagged += bad.map(\.rect)
            if bad.isEmpty {
                r.add("Safe zone", .pass, text.isEmpty ? "No text near the edges" : "Text is at least \(spec.length(spec.safe)) inside the trim")
            } else {
                r.add("Safe zone", .warn, "\(quote(bad)) is within \(spec.length(spec.safe)) of the trim — it could get cut", fixable: false)
            }
        }

        switch f.color {
        case .untagged:
            r.add("Color", .warn, "No color profile — the printer has to guess; embed one", fixable: false)
        case .gray:
            r.add("Color", .pass, "Grayscale")
        case .cmyk:
            switch spec.kind {
            case .photo: r.add("Color", .fail, "CMYK — photo labs print from RGB", fixable: false)
            case .banner: r.add("Color", .pass, "CMYK — fine, though many large-format shops prefer RGB")
            default: r.add("Color", .pass, "CMYK — ready for offset")
            }
        default:
            switch spec.kind {
            case .photo:
                if f.color == .p3 {
                    r.add("Color", .warn, "Display P3 — convert to sRGB (or Adobe RGB if the lab takes it)", fixable: false)
                } else {
                    r.add("Color", .pass, f.colorLabel)
                }
            case .banner: r.add("Color", .pass, "\(f.colorLabel) — large-format printers usually want RGB")
            case .vinyl, .cd: r.add("Color", .warn, "\(f.colorLabel) — plants want CMYK; convert or ask", fixable: false)
            default: r.add("Color", .warn, "\(f.colorLabel) — fine for digital and large-format; ask before sending to offset", fixable: false)
            }
        }

        switch f.format {
        case "TIFF", "PSD", "PNG":
            r.add("Format", .pass, f.format)
        case "JPEG":
            r.add("Format", .pass, "JPEG — fine at max quality; TIFF avoids recompression")
        case "GIF":
            r.add("Format", .fail, "GIF — 256 colors can't hold a print; use TIFF")
        default:
            r.add("Format", .warn, "\(f.format) — convert to TIFF or JPEG before sending")
        }

        if let tag = f.dpiTag, tag > 0, abs(tag - dpi) / dpi > 0.05 {
            let placed = spec.metric
                ? Calc.pair(iw / tag * 25.4, ih / tag * 25.4, "mm", places: 0)
                : Calc.pair(iw / tag, ih / tag, "in", places: 1)
            r.add("DPI tag", .warn, "Tagged \(Int(tag)) DPI, so layout apps place it at \(placed) — the fixed copy retags it to \(Int(dpi.rounded())) DPI")
        }
        r.plan.tiffDPI = dpi
        r.plan.steps.append("tags it \(Int(dpi.rounded())) DPI")
        r.plan.steps.append("saves a lossless TIFF with the colors untouched")
        return r
    }
}
