import SwiftUI

struct ReferenceView: View {
    @EnvironmentObject var model: SpecModel
    let pane: Pane

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(pane.rawValue).font(.title2.weight(.semibold))
                    Spacer()
                    if pane == .printing {
                        Picker("", selection: $model.printDPI) {
                            ForEach([300, 150, 100, 72], id: \.self) { Text("\($0) DPI").tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                }

                if pane == .printing {
                    Text("Trim sizes at \(model.printDPI) DPI. Click a size for its bleed, safe zone, resolution, color, file and paper specs.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ForEach(PresetData.printGroups, id: \.title) { group in
                        PresetGroup(title: group.title,
                                    presets: group.sizes.map { $0.preset(dpi: Double(model.printDPI)) })
                    }
                } else {
                    PresetGroup(title: nil, presets: PresetData.presets(for: pane, printDPI: model.printDPI) ?? [])
                }
            }
            .padding(20)
        }
    }
}

struct PresetGroup: View {
    let title: String?
    let presets: [SizePreset]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).font(.headline)
            }
            VStack(spacing: 0) {
                ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                    PresetRow(preset: preset)
                    if index < presets.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
        }
    }
}

struct PresetRow: View {
    @EnvironmentObject var model: SpecModel
    let preset: SizePreset

    private var isOpen: Bool {
        preset.source != nil && model.openSpec == preset.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if preset.source != nil {
                    Button {
                        model.openSpec = isOpen ? nil : preset.id
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 10)
                            title
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    title
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    CopyableValue(text: preset.pixels)
                    Text(preset.ratio).font(.caption).foregroundStyle(.secondary)
                }
            }
            if isOpen, let source = preset.source {
                VStack(alignment: .leading, spacing: 12) {
                    PrintSpecView(spec: source.spec)
                    Button("Open in Calculator") { model.load(source) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preset.name).font(.body.weight(.medium))
            if let note = preset.note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PrintSpecView: View {
    let spec: PrintSpec

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 7) {
            row("Bleed", spec.bleedText)
            GridRow {
                label("Document")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(spec.documentSize)
                    Text("→").foregroundStyle(.secondary)
                    CopyableValue(text: spec.documentPixels,
                                  font: .system(.callout, design: .monospaced).weight(.medium))
                    Text("at \(spec.dpi) DPI").foregroundStyle(.secondary)
                }
            }
            row("Safe zone", spec.safeText)
            row("Resolution", "\(spec.dpi) DPI — \(spec.dpiNote)")
            row("Color", spec.color)
            row("File", spec.file)
            if let paper = spec.paper { row("Paper", paper) }
            if let tip = spec.tip { row("Tip", tip) }
        }
        .font(.callout)
    }

    private func row(_ name: String, _ value: String) -> some View {
        GridRow {
            label(name)
            Text(value)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func label(_ name: String) -> some View {
        Text(name).foregroundStyle(.secondary)
    }
}

struct SearchResultsView: View {
    @EnvironmentObject var model: SpecModel

    var body: some View {
        let q = Search.normalize(model.searchText)
        let sizes = Pane.allCases.compactMap { pane -> (pane: Pane, hits: [SizePreset])? in
            let hits = (PresetData.presets(for: pane, printDPI: model.printDPI) ?? []).filter { $0.matches(q) }
            return hits.isEmpty ? nil : (pane, hits)
        }
        let formats = (PresetData.formats + PresetData.video).filter { $0.matches(q) }
        let notes = [("Color", PresetData.color), (Pane.handoff.rawValue, PresetData.handoff), (Pane.dpiGuide.rawValue, PresetData.guide)]
            .compactMap { title, notes -> (title: String, hits: [Note])? in
                let hits = notes.filter { $0.matches(q) }
                return hits.isEmpty ? nil : (title, hits)
            }

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if sizes.isEmpty && formats.isEmpty && notes.isEmpty {
                    Text("No matches for \u{201C}\(model.searchText)\u{201D}")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
                ForEach(sizes, id: \.pane) { group in
                    PresetGroup(title: group.pane.rawValue, presets: group.hits)
                }
                if !formats.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Pane.formats.rawValue).font(.headline)
                        FormatList(formats: formats)
                    }
                }
                ForEach(notes, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title).font(.headline)
                        ForEach(group.hits) { NoteCard(note: $0) }
                    }
                }
            }
            .padding(20)
        }
    }
}
