//
//  CameraCapture.swift
//  Facade
//
//  Created by Shukant Pal on 2/20/23.
//

import AVFoundation
import Combine
import Foundation

class CameraCapture: ObservableObject {
    @Published var isGranted: Bool = false
    @Published var deviceFailed: Bool = false
    
    var captureSession: AVCaptureSession!
    private var cancellables = Set<AnyCancellable>()
    let uniqueID: String

    init(uniqueID: String) {
        self.uniqueID = uniqueID
        captureSession = AVCaptureSession()
        setupBindings()
    }

    func setupBindings() {
        $isGranted
            .sink { [weak self] isGranted in
                if isGranted {
                    self?.prepareCamera()
                } else {
                    self?.stopSession()
                }
            }
            .store(in: &cancellables)
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: // The user has previously granted access to the camera.
                self.isGranted = true

            case .notDetermined: // The user has not yet been asked for camera access.
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    if granted {
                        DispatchQueue.main.async {
                            self?.isGranted = granted
                        }
                    }
                }

            case .denied: // The user has previously denied access.
                self.isGranted = false
                return

            case .restricted: // The user can't grant access due to restrictions.
                self.isGranted = false
                return
        @unknown default:
            fatalError()
        }
    }

    func startSession() {
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }

    func prepareCamera() {
        captureSession.sessionPreset = .high

        if let device = AVCaptureDevice.default(for: .video) {
            print("Started session")
            startSessionForDevice(device)
        } else {
            print("Device not found")
            deviceFailed = true
        }
    }

    func startSessionForDevice(_ device: AVCaptureDevice) {
        do {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified)
            let devices = discoverySession.devices
            
            print(devices)

            if let captureDevice = devices.first(where: { $0.uniqueID == uniqueID }) {
                // Use the captureDevice
                let input = try AVCaptureDeviceInput(device: captureDevice)
                addInput(input)
                startSession()
                deviceFailed = false
            } else {
                print("Device not found for some reason!")
                deviceFailed = true
            }
        }
        catch {
            print("Something went wrong - ", error.localizedDescription)
        }
    }

    func addInput(_ input: AVCaptureInput) {
        guard captureSession.canAddInput(input) == true else {
            return
        }
        captureSession.addInput(input)
    }
}
