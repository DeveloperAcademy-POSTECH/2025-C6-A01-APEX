import Foundation
import AVFoundation

final class CameraManager {
    static let shared = CameraManager()

    private let sessionQueue = DispatchQueue(label: "camera.prewarm.queue")
    private var hasPrewarmed = false

    func preAuthorize() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    func prewarmIfPossible() {
        guard !hasPrewarmed else { return }
        sessionQueue.async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            guard status == .authorized else { return }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()

            session.startRunning()
            usleep(400_000)
            session.stopRunning()

            self.hasPrewarmed = true
        }
    }
}


