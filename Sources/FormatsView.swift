import SwiftUI

struct FormatsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(Pane.formats.rawValue).font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Images").font(.headline)
                    FormatList(formats: PresetData.formats)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Video").font(.headline)
                    FormatList(formats: PresetData.video)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Color").font(.headline)
                    ForEach(PresetData.color) { NoteCard(note: $0) }
                }
            }
            .padding(20)
        }
    }
}

struct FormatList: View {
    let formats: [FormatInfo]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(formats.enumerated()), id: \.element.id) { index, format in
                FormatRow(format: format)
                if index < formats.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }
}

struct FormatRow: View {
    let format: FormatInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(format.name).font(.body.weight(.semibold))
                Text(format.use).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 190, alignment: .leading)
            Text(format.detail).font(.callout)
            Spacer(minLength: 0)
        }
        .textSelection(.enabled)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
