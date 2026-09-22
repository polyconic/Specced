import AppKit
import UniformTypeIdentifiers

@MainActor
final class Checker: ObservableObject {
    let model: SpecModel

    @Published var showing = false
    @Published var facts: ImageFacts?
    @Published var text: [TextBox] = []
    @Published var reading = false
    @Published var targetID = "screen:Instagram post, portrait"
    @Published var dropTargeted = false
    @Published var exporting = false
    @Published var message: String?
    @Published var saved: URL?

    init(model: SpecModel) {
        self.model = model
    }

    var groups: [(title: String, targets: [CheckTarget])] {
        CheckTarget.groups(calculator: model.calcPrint)
    }

    func open(_ url: URL) {
        showing = true
        saved = nil
        message = nil
        guard let f = ImageFacts.read(url) else {
            facts = nil
            message = url.pathExtension.lowercased() == "pdf"
                ? "PDFs aren't supported yet — export the page as a TIFF or JPEG first."
                : "Couldn't read \(url.lastPathComponent) as an image."
            return
        }
        facts = f
        text = []
        reading = true
        if let id = CheckTarget.suggest(for: f, in: groups) { targetID = id }
        let preview = f.preview
        Task.detached(priority: .userInitiated) {
            let found = ImageFacts.findText(in: preview)
            await MainActor.run {
                guard self.facts?.url == url else { return }
                self.text = found
                self.reading = false
            }
        }
    }

    func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = "Choose an image to check"
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func handle(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in self.open(url) }
            }
            return true
        }
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return false }
        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
            guard let url else { return }
            // The provided file is deleted when this handler returns, so keep a copy.
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: copy)
            guard (try? FileManager.default.copyItem(at: url, to: copy)) != nil else { return }
            Task { @MainActor in self.open(copy) }
        }
        return true
    }

    func export(_ plan: FixPlan) {
        guard let f = facts else { return }
        let panel = NSSavePanel()
        let stem = f.url.deletingPathExtension().lastPathComponent
        let suffix = plan.suffix.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(stem) – \(suffix).\(plan.type.preferredFilenameExtension ?? "jpg")"
        panel.allowedContentTypes = [plan.type]
        panel.message = "The fixed copy " + plan.steps.joined(separator: ", ") + "."
        let inTemp = f.url.path.hasPrefix(FileManager.default.temporaryDirectory.path)
        panel.directoryURL = inTemp
            ? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            : f.url.deletingLastPathComponent()
        guard panel.runModal() == .OK, let out = panel.url else { return }

        exporting = true
        message = "Exporting…"
        Task.detached(priority: .userInitiated) {
            let result = Result { try FileFix.export(f, plan, to: out) }
            await MainActor.run {
                self.exporting = false
                switch result {
                case .success:
                    self.saved = out
                    self.message = "Saved \(out.lastPathComponent)"
                case .failure(let error):
                    self.message = "Couldn't export: \(error.localizedDescription)"
                }
            }
        }
    }
}
