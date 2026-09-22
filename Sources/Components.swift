import SwiftUI

struct CopyableValue: View {
    @EnvironmentObject var model: SpecModel
    let text: String
    var font: Font = .system(.body, design: .monospaced).weight(.medium)

    var body: some View {
        Button {
            model.copy(text)
        } label: {
            HStack(spacing: 5) {
                Text(text).font(font)
                Image(systemName: model.copiedText == text ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(model.copiedText == text ? Color.green : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Copy")
    }
}

// Not .searchable: its clear button empties the field without updating the binding in this CLT build.
struct SidebarSearchField: View {
    @EnvironmentObject var model: SpecModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.12)))
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
    }
}
