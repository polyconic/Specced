import Foundation

enum Search {
    static func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "×", with: "x").filter { !$0.isWhitespace }
    }

    static func hit(_ q: String, _ fields: String?...) -> Bool {
        fields.contains { field in field.map { normalize($0).contains(q) } ?? false }
    }
}

struct SizePreset: Identifiable {
    let name: String
    let pixels: String
    let ratio: String
    var note: String?
    var source: PrintSize?
    var width: Double = 0
    var height: Double = 0
    var minimum = false
    var floor: Double?
    var maxBytes: Int?
    var safe: SafeArea?
    var noText = false
    var noURLs = false

    var id: String { name }

    static func px(_ name: String, _ w: Double, _ h: Double, _ note: String? = nil,
                   minimum: Bool = false, floor: Double? = nil, maxBytes: Int? = nil,
                   safe: SafeArea? = nil, noText: Bool = false, noURLs: Bool = false) -> SizePreset {
        SizePreset(name: name, pixels: Calc.pxPair(w, h), ratio: Calc.ratio(w, h), note: note,
                   width: w, height: h, minimum: minimum, floor: floor, maxBytes: maxBytes,
                   safe: safe, noText: noText, noURLs: noURLs)
    }

    func matches(_ q: String) -> Bool {
        Search.hit(q, name, pixels, ratio, note, source?.kind.rawValue)
    }
}

struct PrintSize {
    let name: String?
    let width: Double
    let height: Double
    let unit: LengthUnit
    var note: String?
    var kind: PrintKind = .flyer

    static func inches(_ w: Double, _ h: Double, name: String? = nil, note: String? = nil) -> PrintSize {
        PrintSize(name: name, width: w, height: h, unit: .inches, note: note)
    }

    static func mm(_ w: Double, _ h: Double, name: String, note: String? = nil) -> PrintSize {
        PrintSize(name: name, width: w, height: h, unit: .mm, note: note)
    }

    var inches: (w: Double, h: Double) {
        let perInch = unit.perInch ?? 1
        return (width / perInch, height / perInch)
    }

    var title: String {
        name ?? Calc.pair(width, height, unit.rawValue)
    }

    var spec: PrintSpec {
        PrintSpec(kind: kind, width: inches.w, height: inches.h, metric: unit == .mm)
    }

    func preset(dpi: Double) -> SizePreset {
        let converted = unit == .mm
            ? Calc.pair(inches.w, inches.h, "in", places: 2)
            : Calc.pair(width * 2.54, height * 2.54, "cm", places: 1)
        let size = name == nil ? converted : "\(Calc.pair(width, height, unit.rawValue)) · \(converted)"
        return SizePreset(name: title,
                          pixels: Calc.pxPair(inches.w * dpi, inches.h * dpi),
                          ratio: Calc.ratio(width, height),
                          note: [size, note].compactMap { $0 }.joined(separator: " — "),
                          source: self,
                          width: inches.w * dpi, height: inches.h * dpi)
    }
}

struct FormatInfo: Identifiable {
    let name: String
    let use: String
    let detail: String

    var id: String { name }

    func matches(_ q: String) -> Bool {
        Search.hit(q, name, use, detail)
    }
}

struct Note: Identifiable {
    let title: String
    let body: String

    var id: String { title }

    func matches(_ q: String) -> Bool {
        Search.hit(q, title, body)
    }
}

enum PresetData {
    static func presets(for pane: Pane, printDPI: Int) -> [SizePreset]? {
        switch pane {
        case .music: music
        case .social: social
        case .web: web
        case .printing: printGroups.flatMap(\.sizes).map { $0.preset(dpi: Double(printDPI)) }
        default: nil
        }
    }

    static let music: [SizePreset] = [
        .px("Cover art (Spotify, Apple Music, stores)", 3000, 3000,
            "Apple's minimum is 1400×1400, but send 3000. JPEG or PNG at max quality. No URLs, logos, dates or ads. YouTube Music builds its art tracks from this same file.",
            minimum: true, floor: 1400, noURLs: true),
        .px("Bandcamp cover art", 3000, 3000,
            "Minimum 1400×1400. Bandcamp says bigger is better, so reuse the store cover.",
            minimum: true, floor: 1400),
        .px("SoundCloud track artwork", 800, 800,
            "Minimum. The file must be under 2 MB (JPG or PNG), so compress a larger square to fit. SoundCloud's own distribution wants 3000×3000.",
            minimum: true, maxBytes: 2_000_000),
        .px("SoundCloud profile header", 2480, 520),
        .px("Spotify Canvas", 1080, 1920,
            "3–8 second loop, MP4 (or a still JPG), at least 720 px tall."),
        .px("Spotify artist header", 2660, 1140,
            "Minimum. Spotify's rules: no text, ads, busy backgrounds or tour/release promos.",
            minimum: true, maxBytes: 20_000_000, noText: true),
        .px("Spotify artist image", 750, 750, "Minimum.",
            minimum: true, maxBytes: 20_000_000, noText: true),
    ]

    static let social: [SizePreset] = [
        .px("Instagram post, grid-native", 1080, 1440,
            "Shows uncropped in the feed and on the profile grid — the best default since the 2025 grid change."),
        .px("Instagram post, portrait", 1080, 1350,
            "The profile grid crops it to the center 1012×1350, so keep text centered.",
            safe: .instagramGrid),
        .px("Instagram square", 1080, 1080),
        .px("Instagram landscape", 1080, 566),
        .px("Instagram carousel", 1080, 1440,
            "Any feed ratio works, but every slide takes the first slide's ratio."),
        .px("Instagram story / reel", 1080, 1920,
            "Keep text and logos out of the top ~270 px, bottom ~670 px and ~65 px each side (Meta's 14% / 35% / 6%).",
            safe: .metaVertical),
        .px("Instagram profile photo", 320, 320, "Shown at about 110×110."),
        .px("Facebook feed post", 1080, 1350,
            "Square 1080×1080 and landscape 1080×566 work too; portrait takes the most room on phones."),
        .px("Facebook cover photo", 851, 315,
            "Shows at 820×312 on desktop and 640×360 on phones — keep text centered."),
        .px("Facebook story", 1080, 1920, "Same safe zone as Instagram stories.", safe: .metaVertical),
        .px("X post image", 1600, 900),
        .px("X header", 1500, 500),
        .px("X profile photo", 400, 400),
        .px("YouTube thumbnail", 1280, 720, "At least 640 px wide, under 2 MB.", maxBytes: 2_000_000),
        .px("YouTube channel banner", 2560, 1440,
            "Keep text and logos in the center 1546×423 — the only part every device shows.",
            safe: .youtubeBanner),
        .px("TikTok video", 1080, 1920),
        .px("LinkedIn post", 1200, 627),
        .px("LinkedIn profile banner", 1584, 396),
    ]

    static let printGroups: [(title: String, sizes: [PrintSize])] = [
        group("Photo prints", .photo, [
            .inches(4, 6), .inches(5, 7), .inches(8, 10), .inches(11, 14),
        ]),
        group("Flyers & paper", .flyer, [
            .mm(105, 148, name: "A6", note: "Flyer, postcard"),
            .mm(148, 210, name: "A5", note: "Flyer, zine"),
            .inches(5.5, 8.5, name: "Half letter", note: "Flyer"),
            .inches(8.5, 11, name: "US Letter"),
            .mm(210, 297, name: "A4"),
        ]),
        group("Posters", .poster, [
            .inches(11, 17, note: "Tabloid"),
            .mm(297, 420, name: "A3"),
            .inches(18, 24),
            .mm(420, 594, name: "A2"),
            .inches(24, 36),
            .mm(594, 841, name: "A1"),
        ]),
        group("Cards", .card, [
            .inches(3.5, 2, name: "Business card (US)"),
            .mm(85, 55, name: "Business card (EU)"),
            .inches(6, 4, name: "Postcard (US)"),
        ]),
        group("Vinyl", .vinyl, [
            .inches(12.375, 12.375, name: "LP jacket (12″)", note: "Plants vary — use their template"),
        ]),
        group("CD", .cd, [
            .mm(120, 120, name: "CD booklet"),
            .mm(150, 118, name: "CD tray card", note: "Includes both spines"),
        ]),
    ]

    private static func group(_ title: String, _ kind: PrintKind, _ sizes: [PrintSize]) -> (title: String, sizes: [PrintSize]) {
        (title, sizes.map { size in
            var size = size
            size.kind = kind
            return size
        })
    }

    static func match(_ inches: (w: Double, h: Double)) -> PrintSize? {
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }
        return printGroups.flatMap(\.sizes).first { size in
            let s = size.inches
            return (near(s.w, inches.w) && near(s.h, inches.h)) || (near(s.w, inches.h) && near(s.h, inches.w))
        }
    }

    static let web: [SizePreset] = [
        .px("Website hero / banner", 1920, 1080),
        .px("Website hero @2x (retina)", 3840, 2160),
        .px("Open Graph / link preview", 1200, 630,
            "The image shown when a link is shared — also a good blog featured image. Under 600×315, Facebook shows it as a small thumbnail."),
        .px("Favicon master", 512, 512,
            "Export down to 16, 32, 48, 180 (Apple touch) and 192 (Android)."),
        .px("macOS app icon master", 1024, 1024, "Every smaller size is rendered from it."),
        .px("Email header", 1200, 400,
            "Displayed at 600 px wide — export at 2× so it's sharp on retina screens."),
        .px("Desktop wallpaper, 1440p", 2560, 1440),
        .px("Desktop wallpaper, 4K", 3840, 2160),
        .px("Desktop wallpaper, 5K", 5120, 2880, "Apple Studio Display."),
    ]

    static let formats: [FormatInfo] = [
        FormatInfo(name: "JPEG", use: "Photos, most web & social",
                   detail: "Lossy, no transparency. Export at max quality — platforms recompress anyway, so start from the best file."),
        FormatInfo(name: "PNG", use: "Transparency, logos, text-heavy graphics, screenshots",
                   detail: "Lossless. 24-bit for photos or soft transparency, 8-bit for flat color to keep files small."),
        FormatInfo(name: "TIFF", use: "Print masters & photo labs",
                   detail: "Lossless, big files. What photo labs and fine-art printers want; layouts with type go as PDF."),
        FormatInfo(name: "PDF", use: "Print-ready layouts",
                   detail: "Embeds fonts, keeps vectors sharp, carries bleed and crop marks. PDF/X-4 is the modern default; use PDF/X-1a if the printer asks."),
        FormatInfo(name: "SVG", use: "Logos, icons, line art",
                   detail: "Vector — scales to any size at a tiny file size. Not for photos. Send printers vector art as PDF."),
        FormatInfo(name: "WebP / AVIF", use: "Web pages",
                   detail: "Smaller than JPEG/PNG at the same quality, and every major browser supports both — but clients and print shops often can't open them."),
        FormatInfo(name: "HEIC", use: "iPhone photos",
                   detail: "Great compression, poor support outside Apple. Convert to JPEG before sending anything out."),
        FormatInfo(name: "GIF", use: "Legacy animation",
                   detail: "256 colors max. Use MP4 or animated WebP where you can."),
        FormatInfo(name: "RAW", use: "Camera originals",
                   detail: "Never a deliverable — always export from it."),
    ]

    static let video: [FormatInfo] = [
        FormatInfo(name: "H.264 (MP4)", use: "Delivery & every social platform",
                   detail: "The safe default. Keep the source frame rate; AAC audio at 48 kHz."),
        FormatInfo(name: "HEVC (H.265)", use: "Smaller 4K and HDR files",
                   detail: "Up to about half the size of H.264 at the same quality. Some Windows PCs need an extra codec to play it."),
        FormatInfo(name: "ProRes 422 / 4444", use: "Editing masters & handoff",
                   detail: "Near-lossless and huge — for editors and colorists, never for upload. 4444 keeps an alpha channel."),
        FormatInfo(name: "YouTube bitrates", use: "Recommended upload rates (SDR)",
                   detail: "1080p: 8 Mbps at 24–30 fps, 12 Mbps at 48–60 fps. 4K: 35–45 Mbps at 24–30 fps, 53–68 Mbps at 48–60 fps."),
    ]

    static let color: [Note] = [
        Note(title: "RGB",
             body: "Screens, web, social, streaming artwork. Export sRGB with the profile embedded unless a client asks otherwise."),
        Note(title: "CMYK",
             body: "Offset print. Ask before converting — many digital and large-format printers prefer RGB and convert on their own gear. If you do convert, do it last and proof it: saturated blues and greens shift the most."),
        Note(title: "Rich black",
             body: "For big black areas, build a rich black (e.g. C60 M40 Y40 K100) — plain 100K prints as a washed-out dark gray. Small text stays 100K only, or slight plate misregistration blurs it. Registration black (400%) is for crop marks only."),
    ]

    private static let distanceLine = [1, 2, 3, 6, 10, 20]
        .map { "\($0) ft → \(Calc.fmt(Calc.minDPI(distanceInches: Double($0) * 12).rounded(.up), 0))" }
        .joined(separator: " · ")

    static let guide: [Note] = [
        Note(title: "DPI vs PPI",
             body: "PPI (pixels per inch) describes an image; DPI (dots per inch) technically describes a printer's output. Everyone says DPI for both — what matters is the formula: physical size × DPI = pixels."),
        Note(title: "Screens don't care",
             body: "DPI only matters on paper. A 1080×1350 image looks identical on Instagram whether it's tagged 72 or 300 — only the pixel count counts. \u{201C}Export at 300 in case it goes to print\u{201D} doesn't make a screen image bigger; building a bigger canvas does."),
        Note(title: "Pick DPI by viewing distance",
             body: "20/20 eyes can't separate details finer than about 1 arcminute, so the DPI you need is roughly 3438 ÷ viewing distance in inches: \(distanceLine). That's where the usual numbers come from — 300 for things held in the hand, 150 at arm's length, 72–100 for walls seen from a few steps back. Murals get walked up to, so many printers still ask for 100–150. Billboards and building wraps: use the vendor's spec sheet — they usually send a scaled template."),
        Note(title: "Bleed & safe zone",
             body: "Add 0.125 in (3 mm) per side to anything trimmed after printing — that's +0.25 in (+6 mm) per dimension, or +75 px per dimension at 300 DPI. Keep text and logos at least as far inside the trim; LP jackets want 0.25 in."),
        Note(title: "Never upscale",
             body: "Downscaling is free; upscaling looks soft. Build the master at the largest size you'll ever need and scale down for smaller deliverables — never the other way around."),
        Note(title: "Building big",
             body: "Photoshop's PSD format stops at 30,000 px per side; past that, save as PSB (up to 300,000). JPEG stops at 65,535 px. InDesign pages max out at 216 in and Illustrator artboards at 227 in — for bigger pieces, build at 1:10 scale with 10× the DPI. Same pixels, smaller page."),
        Note(title: "InDesign gotcha",
             body: "A pixel-sized InDesign doc is really points (1 px = 1 pt = 1/72 in). Export at 72 PPI and the pixel count stays 1:1. Export the same doc at 300 PPI and it's resampled up by 300 ÷ 72 — a 1920×1080 doc becomes 8000×4500. Text and vector art get sharper; placed photos gain nothing unless they were already that big. Set social/web docs up in pixels and export at 72; set print docs up in inches or mm and export at 300."),
    ]

    static let handoff: [Note] = [
        Note(title: "Print shop",
             body: """
             • PDF/X-4, unless they ask for PDF/X-1a
             • 0.125 in (3 mm) bleed on every side, crop marks on
             • Text and logos at least 0.125 in (3 mm) inside the trim
             • 300 DPI at final size — or what the viewing distance calls for on big pieces
             • Ask whether they want CMYK or RGB before converting
             • Rich black for large black areas, 100K for small text
             • A small JPEG proof alongside, so they can check what they're printing
             """),
        Note(title: "Social & web",
             body: """
             • sRGB with the profile embedded
             • The platform's exact pixel size, never upscaled to get there
             • JPEG at max quality (it gets recompressed anyway); PNG for text-heavy graphics
             • Location metadata stripped — Crate's Strip metadata does this
             """),
        Note(title: "Distributor & stores",
             body: """
             • 3000 × 3000 px, square, RGB JPEG or PNG at max quality
             • No URLs, social handles, logos, prices or release dates on the cover
             • Nothing blurry, pixelated or upscaled — stores reject it
             """),
        Note(title: "Client delivery",
             body: """
             • The master plus every web/social export, one folder per format
             • Files named with project, format and version
             • Zipped without __MACOSX junk — Crate handles all three
             """),
    ]
}
