import SwiftUI

@MainActor
final class ScanSession: ObservableObject {
    @Published var pages: [UIImage] = []

    var pageCount: Int { pages.count }
    var hasPages: Bool { !pages.isEmpty }

    func addPage(_ image: UIImage) {
        pages.append(image)
    }

    func removePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.remove(at: index)
    }

    func reset() {
        pages = []
    }
}
