//
//  CameraCapture.swift
//  Intake
//

import SwiftUI

#if os(iOS)
@preconcurrency import AVFoundation
import UIKit

final class CameraCaptureController: NSObject, ObservableObject {
    enum PermissionState {
        case unknown
        case authorized
        case denied
        case unavailable
    }

    @Published var permissionState: PermissionState = .unknown
    @Published var isSessionRunning = false
    @Published var errorMessage: String?
    @Published var activePosition: AVCaptureDevice.Position = .back

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "intake.camera.session")
    private var photoDelegate: PhotoCaptureDelegate?

    func startIfAuthorized() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            permissionState = .authorized
            configureAndStart()
        } else {
            refreshPermissionState()
        }
    }

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.permissionState = granted ? .authorized : .denied
                    if granted {
                        self.configureAndStart()
                    }
                }
            }
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .unavailable
        }
    }

    func switchCamera() {
        guard permissionState == .authorized else {
            requestAccessAndStart()
            return
        }

        let nextPosition: AVCaptureDevice.Position = activePosition == .back ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            for input in self.session.inputs {
                self.session.removeInput(input)
            }

            guard self.addVideoInput(position: nextPosition) else {
                _ = self.addVideoInput(position: self.activePosition)
                Task { @MainActor in
                    self.errorMessage = "That camera is unavailable on this device."
                }
                return
            }

            Task { @MainActor in
                self.activePosition = nextPosition
                self.errorMessage = nil
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard permissionState == .authorized else {
            completion(nil)
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        let delegate = PhotoCaptureDelegate { [weak self] data in
            Task { @MainActor in
                self?.photoDelegate = nil
                completion(data)
            }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func refreshPermissionState() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
        case .notDetermined:
            permissionState = .unknown
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .unavailable
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard self.addVideoInput(position: self.activePosition) else {
                    self.finishConfigurationWithError("Camera unavailable on this device.")
                    return
                }

                guard self.session.canAddOutput(self.photoOutput) else {
                    self.finishConfigurationWithError("Photo output unavailable.")
                    return
                }

                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                self.session.commitConfiguration()
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            Task { @MainActor in
                self.errorMessage = nil
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    private func addVideoInput(position: AVCaptureDevice.Position) -> Bool {
        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            return false
        }

        session.addInput(input)
        return true
    }

    private func finishConfigurationWithError(_ message: String) {
        session.commitConfiguration()
        Task { @MainActor in
            self.permissionState = .unavailable
            self.errorMessage = message
        }
    }

}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            completion(nil)
            return
        }

        completion(data)
    }
}

struct LiveCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
#endif
