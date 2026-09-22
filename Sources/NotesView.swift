import SwiftUI

struct NotesView: View {
    let title: String
    let notes: [Note]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.title2.weight(.semibold))
                ForEach(notes) { NoteCard(note: $0) }
            }
            .padding(20)
        }
    }
}

struct NoteCard: View {
    let note: Note

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 5) {
                Text(note.title).font(.body.weight(.semibold))
                Text(note.body).font(.callout).foregroundStyle(.secondary)
            }
            .textSelection(.enabled)
        }
    }
}
