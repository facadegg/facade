//
//  CameraFilter.swift
//  Facade
//
//  Created by Shukant Pal on 4/29/23.
//

import AVFoundation
import Foundation

class FaceSwapTarget: ObservableObject {
    let name: String
    let builtin: Bool

    @Published var downloadProgress: Double = 0
    @Published private(set) var downloaded: Bool
    @Published private(set) var downloading: Bool = false
    private var _downloadObservation: NSKeyValueObservation?

    init(name: String) {
        let fileManager = FileManager.default
        let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "gg.facade")!
        let documentsDirectory = containerURL.appendingPathComponent("Library/Models")
        let faceSwapModelURL = documentsDirectory.appendingPathComponent(
            "\(name.replacingOccurrences(of: " ", with: "_")).mlmodel")

        self.name = name
        self.builtin = true
        self.downloaded = fileManager.fileExists(atPath: faceSwapModelURL.path)
    }

    deinit {
        _downloadObservation?.invalidate()
    }

    func download() {
        if self.downloading { return }

        self.downloading = true

        let filename = name.replacingOccurrences(of: " ", with: "_")
        let url = URL(
            string:
                "https://cdn.facade.gg/\(filename)/\(filename).mlmodel"
        )!

        print("Downloading \(url)")

        let task = URLSession.shared.downloadTask(with: url) { (localURL, response, error) in
            defer {
                DispatchQueue.main.async {
                    self.downloading = false
                }
            }

            guard let localURL = localURL, error == nil else {
                print("Download error:", error?.localizedDescription ?? "unknown")
                return
            }

            // Move downloaded file to the destination directory
            do {
                let fileManager = FileManager.default
                let containerURL = fileManager.containerURL(
                    forSecurityApplicationGroupIdentifier: "gg.facade")!
                let documentsDirectory = containerURL.appendingPathComponent("Library/Models")
                let faceSwapModelURL = documentsDirectory.appendingPathComponent(
                    "\(self.name.replacingOccurrences(of: " ", with: "_")).mlmodel")

                try fileManager.createDirectory(
                    at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
                try fileManager.moveItem(at: localURL, to: faceSwapModelURL)
                print("Downloaded \(self.name) successfully.")
                
                DispatchQueue.main.async {
                    self.downloaded = true
                }
            } catch {
                print("Download error:", error.localizedDescription)
            }
        }

        task.resume()

        _downloadObservation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                print("Downloaded \(url) \(progress.fractionCompleted * 100)%")
                self.downloadProgress = progress.fractionCompleted
            }
        }
    }
}

class CameraFilterProperties: ObservableObject {
    let input: Device?
    let output: Device
    let faceSwapTarget: FaceSwapTarget

    @Published private var process: Process?

    init(input: Device?, output: Device, faceSwapTarget: FaceSwapTarget) {
        self.input = input
        self.output = output
        self.faceSwapTarget = faceSwapTarget
        self.process = nil
    }

    var isRunning: Bool {
        return self.process != nil
    }

    func start() {
        if self.process != nil { return }

        let fileManager = FileManager.default
        let bundledResourcesDirectory =
            Bundle.main.bundlePath + "/Contents/MacOS/Lens.app/Contents/Resources"
        let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "gg.facade")!
        let documentsDirectory = containerURL.appendingPathComponent("Library/Models")

        let centerFaceModelURL = documentsDirectory.appendingPathComponent("CenterFace.mlmodel")
        let faceMeshModelURL = documentsDirectory.appendingPathComponent("FaceMesh.mlmodel")
        let faceCompositorURL = documentsDirectory.appendingPathComponent(
            "face_compositor.metallib")
        let faceSwapModelURL = documentsDirectory.appendingPathComponent(
            "\(self.faceSwapTarget.name.replacingOccurrences(of: " ", with: "_")).mlmodel")

        if !fileManager.fileExists(atPath: faceSwapModelURL.path) {
            print("No model found at \(faceSwapModelURL)")
            return
        }
        if !fileManager.fileExists(atPath: centerFaceModelURL.path) {
            try! fileManager.copyItem(
                at: URL(fileURLWithPath: bundledResourcesDirectory + "/CenterFace.mlmodel"),
                to: centerFaceModelURL)

        }
        if !fileManager.fileExists(atPath: faceMeshModelURL.path) {
            try! fileManager.copyItem(
                at: URL(fileURLWithPath: bundledResourcesDirectory + "/FaceMesh.mlmodel"),
                to: faceMeshModelURL)

        }
        if !fileManager.fileExists(atPath: faceCompositorURL.path) {
            try! fileManager.copyItem(
                at: URL(fileURLWithPath: bundledResourcesDirectory + "/face_compositor.metallib"),
                to: faceCompositorURL)

        }

        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let arguments = [
            "--dst",
            output.uid.uuidString,
            "--frame-rate",
            "30",
            "--face-swap-model",
            faceSwapModelURL.path,
            "--root-dir",
            documentsDirectory.path,
        ]

        self.process = task

        task.launchPath = Bundle.main.bundlePath + "/Contents/MacOS/Lens.app/Contents/MacOS/Lens"
        task.arguments = arguments
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        task.terminationHandler = { _ in
            print(
                "\(self.faceSwapTarget.name) terminated: \(task.terminationReason.rawValue) with exit status \(task.terminationStatus)"
            )
        }

        task.launch()

        print(arguments.joined(separator: " "))
        print("Launched filter for \(faceSwapTarget.name)")

        let stdoutFileHandle = stdoutPipe.fileHandleForReading
        let stderrFileHandle = stderrPipe.fileHandleForReading
        let queue = DispatchQueue(label: "gg.facade.Facade.Lens")

        stdoutFileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                if !string.isEmpty {
                    queue.async {
                        print(
                            "\(self.faceSwapTarget.name): \(string.replacingOccurrences(of: "\n", with: ""))"
                        )
                    }
                }
            }
        }

        stderrFileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                if !string.isEmpty {
                    queue.async {
                        print(
                            "\(self.faceSwapTarget.name): \(string.replacingOccurrences(of: "\n", with: ""))"
                        )
                    }
                }
            }
        }
    }

    func stop() {
        if let task = process {
            task.terminate()
            self.process = nil
        }
    }
}

class CameraFilter: ObservableObject {

    @Published private(set) var availableFaceSwapTargets = [
        FaceSwapTarget(name: "Bryan Greynolds"),
        FaceSwapTarget(name: "David Kovalniy"),
        FaceSwapTarget(name: "Ewon Spice"),
        FaceSwapTarget(name: "Kim Jarrey"),
        FaceSwapTarget(name: "Tim Chrys"),
        FaceSwapTarget(name: "Tim Norland"),
        FaceSwapTarget(name: "Zahar Lupin"),
    ]

    @Published private(set) var properties: CameraFilterProperties? = nil
    private let devices: Devices

    init(availableOutputDevices devices: Devices) {
        self.devices = devices
    }

    var inputDevice: Device? {
        if let defaultDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: AVMediaType.video,
            position: .unspecified)
        {
            return Device(type: facade_device_type_video,
                          uid: UUID(uuidString: defaultDevice.uniqueID) ?? UUID(),
                          name: defaultDevice.localizedName,
                          width: 0,
                          height: 0,
                          frameRate: 0)
        }

        return nil
    }

    var previewDevice: String? {
        if let properties = self.properties {
            if properties.isRunning {
                return properties.output.uid.uuidString
            }
        }

        return inputDevice?.uid.uuidString
    }
    
    var previewDeviceName: String? {
        if let properties = self.properties {
            if properties.isRunning {
                return properties.output.name
            }
        }

        return inputDevice?.name
    }

    func run(faceSwapTarget: FaceSwapTarget) {
        if let properties = self.properties {
            properties.stop()
        }

        if let device = devices.devices.first {
            print("Starting filter")
            self.properties = CameraFilterProperties(
                input: nil,
                output: device,
                faceSwapTarget: faceSwapTarget)
            self.properties?.start()
        } else {
            print("No device found")
        }
    }

    func resume() {
        self.properties?.start()
    }

    func pause() {
        self.properties?.stop()
    }
}
