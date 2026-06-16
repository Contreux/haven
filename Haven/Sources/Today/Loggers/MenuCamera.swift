import SwiftUI
import UIKit
import AVFoundation

/// Drives a live back-camera preview and still capture for the menu scanner.
/// Session work runs on a private queue; published state is updated on the main queue.
final class MenuCameraModel: NSObject, ObservableObject, @unchecked Sendable {
    enum Access { case unknown, granted, denied }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "haven.menu.camera")
    private var onPhoto: ((Data?) -> Void)?

    @Published var access: Access = .unknown
    @Published var ready = false   // a camera input has been configured (false on devices without a camera)

    /// Request permission if needed, then configure and start the preview.
    func startIfPermitted() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .granted; configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.access = granted ? .granted : .denied
                    if granted { self?.configureAndStart() }
                }
            }
        default:
            access = .denied
        }
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device) else { return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if self.session.canAddInput(input) { self.session.addInput(input) }
                if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.ready = true }
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capture(_ completion: @escaping (Data?) -> Void) {
        onPhoto = completion
        queue.async { [weak self] in
            guard let self else { return }
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }
}

extension MenuCameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async { self.onPhoto?(data); self.onPhoto = nil }
    }
}

/// A live preview of an `AVCaptureSession`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
