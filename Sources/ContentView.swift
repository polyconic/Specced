import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: SpecModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SidebarSearchField()
                Divider()
                List(selection: $model.pane) {
                    ForEach(Pane.allCases) { pane in
                        Label(pane.rawValue, systemImage: pane.icon)
                            .tag(pane)
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            Group {
                if !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    SearchResultsView()
                } else {
                    let pane = model.pane ?? .calculator
                    switch pane {
                    case .calculator:
                        CalculatorView()
                    case .music, .social, .printing, .web:
                        ReferenceView(pane: pane)
                    case .formats:
                        FormatsView()
                    case .handoff:
                        NotesView(title: pane.rawValue, notes: PresetData.handoff)
                    case .dpiGuide:
                        NotesView(title: pane.rawValue, notes: PresetData.guide)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
