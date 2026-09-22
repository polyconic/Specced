import Foundation
import AppKit

enum Pane: String, CaseIterable, Identifiable {
    case calculator = "Calculator"
    case music = "Music & Streaming"
    case social = "Social Media"
    case printing = "Print"
    case web = "Web & Screen"
    case formats = "File Formats"
    case handoff = "Sending Out"
    case dpiGuide = "DPI vs PPI"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .calculator: "number"
        case .music: "waveform"
        case .social: "camera"
        case .printing: "printer"
        case .web: "display"
        case .formats: "doc.text"
        case .handoff: "paperplane"
        case .dpiGuide: "questionmark.circle"
        }
    }
}

struct CalcPrint {
    let title: String
    let match: PrintSize?
    let auto: PrintKind
    let spec: PrintSpec
}

// No @State anywhere: this CLT SwiftUI SDK has no SwiftUIMacros plugin, so it won't compile. UI state lives here.
@MainActor
final class SpecModel: ObservableObject {
    @Published var pane: Pane? = .calculator
    @Published var searchText = ""

    @Published var widthValue = "5" {
        didSet { if widthValue != oldValue { printKind = nil } }
    }
    @Published var heightValue = "7" {
        didSet { if heightValue != oldValue { printKind = nil } }
    }
    @Published var unit: LengthUnit = .inches {
        didSet { if unit != oldValue { printKind = nil } }
    }
    @Published var printKind: PrintKind?
    @Published var dpi = "300"
    @Published var viewingDistance = "10"
    @Published var distanceUnit: DistanceUnit = .feet
    @Published var bleedOn = false
    @Published var bleedValue = "0.125"
    @Published var bleedUnit: LengthUnit = .inches {
        didSet {
            if bleedValue == Self.standardBleed(oldValue) { bleedValue = Self.standardBleed(bleedUnit) }
        }
    }

    @Published var printDPI = 300
    @Published var openSpec: String?

    @Published var copiedText: String?
    private var copyTask: Task<Void, Never>?

    private static func standardBleed(_ unit: LengthUnit) -> String {
        unit == .mm ? "3" : "0.125"
    }

    var calcPrint: CalcPrint? {
        guard unit != .px,
              let w = Calc.number(widthValue), let h = Calc.number(heightValue),
              let r = Calc.run(width: widthValue, height: heightValue, unit: unit, dpi: dpi,
                               bleed: nil, bleedUnit: bleedUnit) else { return nil }
        let match = PresetData.match(r.inches)
        let auto = match?.kind ?? PrintKind.guess(longSide: max(r.inches.w, r.inches.h))
        return CalcPrint(title: Calc.pair(w, h, unit.rawValue), match: match, auto: auto,
                         spec: PrintSpec(kind: printKind ?? auto, width: r.inches.w, height: r.inches.h,
                                         metric: unit != .inches))
    }

    func load(_ size: PrintSize) {
        widthValue = Calc.fmt(size.width, 3)
        heightValue = Calc.fmt(size.height, 3)
        unit = size.unit
        printKind = size.kind
        apply(size.spec)
        searchText = ""
        pane = .calculator
    }

    func apply(_ spec: PrintSpec) {
        dpi = String(spec.dpi)
        bleedOn = spec.bleed > 0
        guard spec.bleed > 0 else { return }
        bleedUnit = spec.metric ? .mm : .inches
        bleedValue = spec.metric ? Calc.fmt(spec.bleed * 25.4, 2) : Calc.fmt(spec.bleed, 3)
    }

    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        copiedText = text
        copyTask?.cancel()
        copyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            if !Task.isCancelled, copiedText == text {
                copiedText = nil
            }
        }
    }
}
