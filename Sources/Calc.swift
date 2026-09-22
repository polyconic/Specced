import Foundation

enum LengthUnit: String, CaseIterable, Identifiable {
    case inches = "in"
    case cm = "cm"
    case mm = "mm"
    case px = "px"

    var id: String { rawValue }

    var perInch: Double? {
        switch self {
        case .inches: 1
        case .cm: 2.54
        case .mm: 25.4
        case .px: nil
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case feet = "ft"
    case meters = "m"

    var id: String { rawValue }

    var inches: Double {
        switch self {
        case .feet: 12
        case .meters: 100 / 2.54
        }
    }
}

struct CalcOutput {
    let pxW: Double
    let pxH: Double
    let bleedPx: (w: Double, h: Double)?
    let inches: (w: Double, h: Double)
    let ratio: String
    let aspect: Double
}

enum Calc {
    static func number(_ text: String) -> Double? {
        guard let v = Double(text.trimmingCharacters(in: .whitespaces)), v.isFinite, v > 0 else { return nil }
        return v
    }

    static func run(width: String, height: String, unit: LengthUnit, dpi: String,
                    bleed: String?, bleedUnit: LengthUnit) -> CalcOutput? {
        guard let w = number(width), let h = number(height), let d = number(dpi) else { return nil }

        guard let perInch = unit.perInch else {
            return CalcOutput(pxW: w, pxH: h, bleedPx: nil, inches: (w / d, h / d),
                              ratio: ratio(w, h), aspect: w / h)
        }

        let inW = w / perInch
        let inH = h / perInch
        var bleedPx: (w: Double, h: Double)?
        if let bleed, let b = number(bleed), let bleedPerInch = bleedUnit.perInch {
            let extra = b / bleedPerInch * 2
            bleedPx = ((inW + extra) * d, (inH + extra) * d)
        }
        return CalcOutput(pxW: inW * d, pxH: inH * d, bleedPx: bleedPx, inches: (inW, inH),
                          ratio: ratio(w, h), aspect: w / h)
    }

    static func minDPI(distanceInches d: Double) -> Double {
        let arcminute = Double.pi / 180 / 60
        return 1 / (d * tan(arcminute))
    }

    static func ratio(_ w: Double, _ h: Double) -> String {
        for scale in [1.0, 10, 100, 1000] {
            let a = (w * scale).rounded()
            let b = (h * scale).rounded()
            guard abs(a - w * scale) < 1e-6, abs(b - h * scale) < 1e-6 else { continue }
            if a >= 1, b >= 1, a < 1e9, b < 1e9 {
                let g = gcd(Int(a), Int(b))
                if max(Int(a), Int(b)) / g <= 25 { return "\(Int(a) / g):\(Int(b) / g)" }
            }
            break
        }
        return w >= h ? "\(fmt(w / h, 2)):1" : "1:\(fmt(h / w, 2))"
    }

    static func warnings(px: (w: Double, h: Double), inches: (w: Double, h: Double)) -> [String] {
        let longest = max(px.w, px.h).rounded()
        var out: [String] = []
        if longest > 300_000 {
            out.append("Over 300,000 px per side — past even Photoshop's PSB limit. Lower the DPI.")
        } else if longest > 30_000 {
            out.append("Over Photoshop's 30,000 px PSD limit — save as PSB (Large Document Format).")
        }
        if longest > 65_535 {
            out.append("Too big for JPEG, which stops at 65,535 px per side.")
        }
        if max(inches.w, inches.h) > 216 {
            out.append("Bigger than InDesign's 216 in page (Illustrator stops at 227 in) — build at 1:10 scale with 10× the DPI.")
        }
        return out
    }

    static func rgbSize(_ w: Double, _ h: Double) -> String? {
        let bytes = w.rounded() * h.rounded() * 3
        guard bytes < 9e18 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    static func fmt(_ v: Double, _ places: Int) -> String {
        var s = String(format: "%.\(places)f", v)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }

    static func fmtPx(_ v: Double) -> String {
        String(format: "%.0f", v.rounded())
    }

    static func pxPair(_ w: Double, _ h: Double) -> String {
        "\(fmtPx(w)) × \(fmtPx(h)) px"
    }

    static func pair(_ w: Double, _ h: Double, _ unit: String, places: Int = 3) -> String {
        "\(fmt(w, places)) × \(fmt(h, places)) \(unit)"
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}
