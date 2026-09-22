import SwiftUI

struct CalculatorView: View {
    @EnvironmentObject var model: SpecModel

    private var result: CalcOutput? {
        Calc.run(width: model.widthValue, height: model.heightValue, unit: model.unit, dpi: model.dpi,
                 bleed: model.bleedOn && model.unit != .px ? model.bleedValue : nil, bleedUnit: model.bleedUnit)
    }

    private var distanceDPI: Int? {
        guard let d = Calc.number(model.viewingDistance) else { return nil }
        let dpi = Calc.minDPI(distanceInches: d * model.distanceUnit.inches).rounded(.up)
        guard dpi.isFinite, dpi < 1_000_000 else { return nil }
        return Int(dpi)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Calculator").font(.title2.weight(.semibold))
                Text("Physical size × DPI = pixels. Switch the unit to px to go the other way: pixels and a target DPI give the print size.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .bottom, spacing: 10) {
                            field("Width") { TextField("", text: $model.widthValue) }
                                .frame(width: 110)
                            Text("×").foregroundStyle(.secondary).padding(.bottom, 5)
                            field("Height") { TextField("", text: $model.heightValue) }
                                .frame(width: 110)
                            field("Unit") { segmented($model.unit, LengthUnit.allCases) }
                                .frame(width: 180)
                            Spacer()
                        }

                        HStack(alignment: .bottom, spacing: 10) {
                            field(model.unit == .px ? "Target DPI" : "DPI") { TextField("", text: $model.dpi) }
                                .frame(width: 110)
                            ForEach([300, 150, 100, 72], id: \.self) { d in
                                Button("\(d)") { model.dpi = "\(d)" }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .padding(.bottom, 2)
                            }
                            Spacer()
                        }

                        HStack(alignment: .bottom, spacing: 10) {
                            field("Viewing distance") { TextField("", text: $model.viewingDistance) }
                                .frame(width: 110)
                            segmented($model.distanceUnit, DistanceUnit.allCases)
                                .frame(width: 80)
                            if let d = distanceDPI {
                                Text("needs at least \(d) DPI to look sharp")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 4)
                                Button("Use") { model.dpi = String(d) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .padding(.bottom, 2)
                            }
                            Spacer()
                        }

                        if model.unit != .px {
                            HStack(spacing: 10) {
                                Toggle("Add bleed", isOn: $model.bleedOn)
                                    .toggleStyle(.checkbox)
                                if model.bleedOn {
                                    TextField("", text: $model.bleedValue)
                                        .frame(width: 55)
                                    segmented($model.bleedUnit, [.inches, .mm])
                                        .frame(width: 90)
                                    Text("per side").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                }

                if let r = result {
                    let built = r.bleedPx ?? (w: r.pxW, h: r.pxH)
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            if model.unit == .px {
                                resultRow("Print size", Calc.pair(r.inches.w, r.inches.h, "in"), big: true)
                            } else {
                                resultRow("Pixels", Calc.pxPair(r.pxW, r.pxH), big: true)
                                if let b = r.bleedPx {
                                    resultRow("With bleed", Calc.pxPair(b.w, b.h), big: false)
                                }
                            }
                            Divider()
                            Group {
                                Text(physicalLine(r))
                                Text(detailLine(r, built))
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            ForEach(Calc.warnings(px: built, inches: r.inches), id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.callout)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    Card {
                        Text("Enter width, height, and DPI.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let c = model.calcPrint {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Recommended").font(.headline)
                                if let match = c.match {
                                    Text("· \(match.name ?? match.note ?? match.title)").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Picker("Print as", selection: $model.printKind) {
                                    Text("Auto (\(c.auto.rawValue))").tag(PrintKind?.none)
                                    ForEach(PrintKind.allCases) { Text($0.rawValue).tag(Optional($0)) }
                                }
                                .pickerStyle(.menu)
                                .fixedSize()
                            }
                            PrintSpecView(spec: c.spec)
                            Button("Use this bleed and DPI") { model.apply(c.spec) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func physicalLine(_ r: CalcOutput) -> String {
        let (w, h) = r.inches
        let metric = "\(Calc.pair(w * 2.54, h * 2.54, "cm")) · \(Calc.pair(w * 25.4, h * 25.4, "mm"))"
        return model.unit == .px ? metric : "\(Calc.pair(w, h, "in")) · \(metric)"
    }

    private func detailLine(_ r: CalcOutput, _ built: (w: Double, h: Double)) -> String {
        var parts = [r.ratio.contains(".") || r.aspect == 1
            ? "Ratio \(r.ratio)"
            : "Ratio \(r.ratio) (\(Calc.fmt(r.aspect, 3)))"]
        if let size = Calc.rgbSize(built.w, built.h) {
            parts.append("\(size) uncompressed (8-bit RGB)")
        }
        return parts.joined(separator: " · ")
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func segmented<T: Hashable & RawRepresentable>(_ selection: Binding<T>, _ options: [T]) -> some View
        where T.RawValue == String {
        Picker("", selection: selection) {
            ForEach(options, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private func resultRow(_ label: String, _ value: String, big: Bool) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            CopyableValue(text: value,
                          font: big ? .system(.title2, design: .monospaced).weight(.semibold)
                                    : .system(.body, design: .monospaced).weight(.medium))
        }
    }
}
