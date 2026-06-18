import SwiftUI
import VisionKit

/// Apple's document scanner (live edge detection, auto crop + de-skew). Returns the first
/// scanned page as JPEG data — so the AI only ever sees the menu, not the surrounding scene.
/// `VNDocumentCameraViewController.isSupported` is false on the simulator (no camera).
struct DocumentScanner: UIViewControllerRepresentable {
    let onComplete: (Data?) -> Void   // nil = cancelled or failed
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let data = scan.pageCount > 0 ? scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.9) : nil
            parent.onComplete(data); parent.dismiss()
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onComplete(nil); parent.dismiss()
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.onComplete(nil); parent.dismiss()
        }
    }
}
