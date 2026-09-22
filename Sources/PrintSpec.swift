import Foundation

enum PrintKind: String, CaseIterable, Identifiable {
    case photo = "Photo print"
    case flyer = "Flyer"
    case poster = "Poster"
    case card = "Card"
    case vinyl = "Vinyl LP jacket"
    case cd = "CD packaging"
    case banner = "Banner / mural"

    var id: String { rawValue }

    static func guess(longSide l: Double) -> PrintKind {
        switch l {
        case ...4: .card
        case ...14: .flyer
        case ...40: .poster
        default: .banner
        }
    }
}

struct PrintSpec {
    let kind: PrintKind
    let width: Double
    let height: Double
    let metric: Bool

    var bleed: Double {
        kind == .photo ? 0 : (metric ? 3 / 25.4 : 0.125)
    }

    var safe: Double {
        switch kind {
        case .poster, .vinyl, .photo: metric ? 6 / 25.4 : 0.25
        case .banner: metric ? 50 / 25.4 : 2
        default: metric ? 3 / 25.4 : 0.125
        }
    }

    var dpi: Int {
        switch kind {
        case .poster: max(width, height) <= 17 ? 300 : 150
        case .banner: 100
        default: 300
        }
    }

    var bleedText: String {
        bleed == 0 ? "None — send the exact size" : "\(length(bleed)) per side"
    }

    var documentSize: String {
        size(width + bleed * 2, height + bleed * 2)
    }

    var documentPixels: String {
        Calc.pxPair((width + bleed * 2) * Double(dpi), (height + bleed * 2) * Double(dpi))
    }

    var safeText: String {
        "Keep text and logos \(length(safe)) inside the trim — live area \(size(width - safe * 2, height - safe * 2))"
    }

    var dpiNote: String {
        switch kind {
        case .photo: "the lab standard"
        case .flyer, .card, .cd: "it gets read up close"
        case .vinyl: "records get handled up close"
        case .poster: dpi == 300
            ? "small posters get read up close"
            : "posters are seen from a step back; use 300 if there's small type"
        case .banner: "most large-format shops ask 100–150 at full size; from far away you can go lower (see viewing distance)"
        }
    }

    var color: String {
        switch kind {
        case .photo: "sRGB (Adobe RGB only if the lab takes it)"
        case .flyer, .card: "CMYK for offset; digital presses often take RGB — ask"
        case .poster: "CMYK for offset; large-format inkjet shops usually prefer RGB — ask"
        case .vinyl, .cd: "CMYK"
        case .banner: "Usually RGB — ask the shop"
        }
    }

    var file: String {
        switch kind {
        case .photo: "JPEG at max quality, cropped to the print's exact ratio (TIFF if the lab takes it)"
        case .flyer, .poster, .card: "PDF/X-4 with bleed and crop marks"
        case .vinyl: "PDF built on the pressing plant's template"
        case .cd: "PDF built on the replicator's template"
        case .banner: "PDF or TIFF at full size — or at 1:10 scale with 10× the DPI"
        }
    }

    var paper: String? {
        switch kind {
        case .photo: "Luster is the usual pro pick; glossy for punch, matte to kill glare"
        case .flyer: "100 lb gloss text (~148 gsm) is standard; 14–16 pt card (~350–400 gsm) for postcard weight"
        case .poster: "80 lb gloss text (~118 gsm) is the standard wall poster; 100 lb text (~148 gsm) lasts longer on a board; cover stock if it has to stand up"
        case .card: "14–16 pt (~350–400 gsm); uncoated or matte if people will write on it"
        case .banner: "13 oz vinyl outdoors; fabric or adhesive vinyl indoors"
        case .vinyl, .cd: nil
        }
    }

    var tip: String? {
        switch kind {
        case .photo: "Labs crop 2–4 mm off each edge on borderless prints, so keep faces and text in from the edges."
        case .vinyl: "Spine width depends on the jacket — get the plant's template before you start."
        case .cd: "Case types vary — start from the replicator's template."
        case .banner: "Grommets or hems push bleed to about 1 in; grommets land every 2–3 ft along the edges."
        default: nil
        }
    }

    private func length(_ inches: Double) -> String {
        metric ? "\(Calc.fmt(inches * 25.4, 1)) mm" : "\(Calc.fmt(inches, 3)) in"
    }

    private func size(_ w: Double, _ h: Double) -> String {
        metric ? Calc.pair(w * 25.4, h * 25.4, "mm", places: 1) : Calc.pair(w, h, "in")
    }
}
