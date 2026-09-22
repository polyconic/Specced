import SwiftUI
import AppKit

struct CheckView: View {
    @EnvironmentObject var checker: Checker

    var body: some View {
        let groups = checker.groups
        let targets = groups.flatMap(\.targets)
        let target = targets.first { $0.id == checker.targetID } ?? targets[0]

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Check a File").font(.title3.weight(.semibold))
                Spacer()
                Picker("Check against", selection: Binding(get: { target.id }, set: { checker.targetID = $0 })) {
                    ForEach(groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.targets) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 340)
                Button("Done") { checker.showing = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            if let facts = checker.facts {
                ReportView(facts: facts,
                           report: CheckReport.make(facts, target, text: checker.text, textReady: !checker.reading))
            } else {
                dropZone
            }
        }
        .frame(width: 840, height: 640)
        .onDrop(of: [.fileURL, .image], isTargeted: $checker.dropTargeted) { checker.handle($0) }
    }

    private var dropZone: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(checker.dropTargeted ? Color.accentColor : .secondary)
            Text("Drop an image to check it").font(.title2.weight(.medium))
            Text("Pick what it's for above — a poster, a story, a cover — and Specced checks the actual file: resolution, shape, bleed, color, format and text near the edges.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Button("Choose…") { checker.choose() }
                .controlSize(.large)
            if let message = checker.message {
                Text(message).font(.callout).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(checker.dropTargeted ? Color.accentColor : Color.secondary.opacity(0.35))
                .padding(20)
        }
    }
}

struct ReportView: View {
    @EnvironmentObject var checker: Checker
    let facts: ImageFacts
    let report: CheckReport

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                CheckPreview(image: facts.preview, report: report)
                    .frame(maxWidth: 300, maxHeight: 440)
                legend
            }
            .frame(width: 300)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(facts.url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(summary).font(.callout).foregroundStyle(.secondary)
                }
                Label(headline, systemImage: report.verdict.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(report.verdict.color)
                ScrollView {
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(report.items) { CheckRow(item: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button("Check Another…") { checker.choose() }
                    if let saved = checker.saved {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([saved]) }
                    }
                    Spacer()
                    Button(report.plan.needed ? "Export Fixed Copy…" : "Nothing to Fix") { checker.export(report.plan) }
                        .disabled(!report.plan.needed || checker.exporting)
                        .keyboardShortcut(.defaultAction)
                }
                if let message = checker.message {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }

    private var summary: String {
        var parts = [Calc.pxPair(Double(facts.width), Double(facts.height)), facts.format, facts.colorLabel,
                     ByteCountFormatter.string(fromByteCount: Int64(facts.bytes), countStyle: .file)]
        if let tag = facts.dpiTag { parts.append("tagged \(Int(tag)) DPI") }
        return parts.joined(separator: " · ")
    }

    private var headline: String {
        switch report.verdict {
        case .fail: "Needs fixing"
        case .warn: "Worth a look"
        default: "Ready to send"
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 3) {
            if report.crop != nil { Text("Red box: what survives the crop") }
            if report.safe != nil { Text("Shaded: keep text out of here") }
            if report.trim != nil { Text("Dashed: trim line") }
            if !report.flagged.isEmpty { Text("Outlined: text in the way") }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct CheckPreview: View {
    let image: CGImage
    let report: CheckReport

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    if let safe = report.safe {
                        Path { path in
                            path.addRect(CGRect(origin: .zero, size: size))
                            path.addRect(scaled(safe, size))
                        }
                        .fill(Color.orange.opacity(0.28), style: FillStyle(eoFill: true))
                    }
                    if let trim = report.trim {
                        Path { $0.addRect(scaled(trim, size)) }
                            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    if let crop = report.crop {
                        Path { $0.addRect(scaled(crop, size)) }
                            .stroke(Color.red, lineWidth: 2)
                    }
                    ForEach(report.flagged.indices, id: \.self) { i in
                        Path { $0.addRect(scaled(report.flagged[i], size).insetBy(dx: -2, dy: -2)) }
                            .stroke(Color.orange, lineWidth: 1.5)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func scaled(_ r: CGRect, _ s: CGSize) -> CGRect {
        CGRect(x: r.minX * s.width, y: r.minY * s.height, width: r.width * s.width, height: r.height * s.height)
    }
}

struct CheckRow: View {
    let item: CheckItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: item.status.icon)
                .foregroundStyle(item.status.color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.body.weight(.semibold))
                Text(item.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

extension CheckStatus {
    var icon: String {
        switch self {
        case .pass: "checkmark.circle.fill"
        case .warn: "exclamationmark.triangle.fill"
        case .fail: "xmark.octagon.fill"
        case .pending: "hourglass"
        }
    }

    var color: Color {
        switch self {
        case .pass: .green
        case .warn: .orange
        case .fail: .red
        case .pending: .secondary
        }
    }
}
