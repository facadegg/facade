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
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "video.facade")!
        let documentsDirectory = containerURL.appendingPathComponent("Library/Models")
        let faceSwapModelURL = documentsDirectory.appendingPathComponent("\(name.replacingOccurrences(of: " ", with: "_")).mlmodel")

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
        let url = URL(string: "https://facade.nyc3.cdn.digitaloceanspaces.com/models/face-swap/\(filename)/\(filename).mlmodel")!
        
        print("Downloading \(url)")
        
        let task = URLSession.shared.downloadTask(with: url) { (localURL, response, error) in
            defer {
                DispatchQueue.main.async {
                    self.downloading = false
                    self.downloaded = true
                }
            }

            guard let localURL = localURL, error == nil else {
                print("Download error:", error?.localizedDescription ?? "unknown")
                return
            }

            // Move downloaded file to the destination directory
            do {
                let fileManager = FileManager.default
                let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "video.facade")!
                let documentsDirectory = containerURL.appendingPathComponent("Library/Models")
                let faceSwapModelURL = documentsDirectory.appendingPathComponent("\(self.name.replacingOccurrences(of: " ", with: "_")).mlmodel")
                
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
                try fileManager.moveItem(at: localURL, to: faceSwapModelURL)
                print("Downloaded \(self.name) successfully.")
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
};

class CameraFilterProperties: ObservableObject {
    let inputDevice: String?
    let outputDevice: String
    let faceSwapTarget: FaceSwapTarget
    
    @Published private var process: Process?
   
    init(inputDevice: String?, outputDevice: String, faceSwapTarget: FaceSwapTarget) {
        self.inputDevice = inputDevice
        self.outputDevice = outputDevice
        self.faceSwapTarget = faceSwapTarget
        self.process = nil
    }
    
    var isRunning: Bool {
        return self.process != nil
    }
    
    func start() {
        if self.process != nil { return }
        
        let fileManager = FileManager.default
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "video.facade")!
        let documentsDirectory = containerURL.appendingPathComponent("Library/Models")
        let faceSwapModelURL = documentsDirectory.appendingPathComponent("\(self.faceSwapTarget.name.replacingOccurrences(of: " ", with: "_")).mlmodel")

        if !fileManager.fileExists(atPath: faceSwapModelURL.path) {
            print("No model found at \(faceSwapModelURL)")
            return
        }
        
        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let arguments = [
            "--dst",
            outputDevice,
            "--frame-rate",
            "30",
            "--face-swap-model",
            faceSwapModelURL.path,
            "--root-dir",
            Bundle.main.bundlePath + "/Contents/MacOS/Lens.app/Contents/Resources"
        ]
        
        self.process = task
        
        task.launchPath = Bundle.main.bundlePath + "/Contents/MacOS/Lens.app/Contents/MacOS/Lens"
        task.arguments = arguments
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        task.terminationHandler = { _ in
            print("\(self.faceSwapTarget.name) terminated: \(task.terminationReason.rawValue) with exit status \(task.terminationStatus)")
        }
        
        task.launch()
        
        print(arguments.joined(separator: " "))
        print("Launched filter for \(faceSwapTarget.name)")
        
        let stdoutFileHandle = stdoutPipe.fileHandleForReading
        let stderrFileHandle = stderrPipe.fileHandleForReading
        let queue = DispatchQueue(label: "video.facade.Facade.Lens")

        stdoutFileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                if !string.isEmpty {
                    queue.async {
                        print("\(self.faceSwapTarget.name): \(string.replacingOccurrences(of: "\n", with: ""))")
                    }
                }
            }
        }

        stderrFileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                if !string.isEmpty {
                    queue.async {
                        print("\(self.faceSwapTarget.name): \(string.replacingOccurrences(of: "\n", with: ""))")
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
};

class CameraFilter: ObservableObject {
    
    @Published private(set) var availableFaceSwapTargets = [
        FaceSwapTarget(name: "Bryan Greynolds"),
        FaceSwapTarget(name: "David Kovalniy"),
        FaceSwapTarget(name: "Ewon Spice"),
        FaceSwapTarget(name: "Kim Jarrey"),
        FaceSwapTarget(name: "Tim Chrys"),
        FaceSwapTarget(name: "Tim Norland"),
        FaceSwapTarget(name: "Zahar Lupin")
    ]
    
    @Published var preferredInputDevice: String? = nil
    @Published private(set) var properties: CameraFilterProperties? = nil
    private let devices: Devices
    
    init(availableOutputDevices devices: Devices) {
        self.devices = devices
    }
   
    var inputDevice: String? {
        if let preferredInputDevice = self.preferredInputDevice {
            return preferredInputDevice
        }
        
        if let defaultDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: AVMediaType.video,
                                                       position: .unspecified) {
            return defaultDevice.uniqueID
        }
        
        return nil
    }
    
    var previewDevice: String? {
        if let properties = self.properties {
            if properties.isRunning {
                return properties.outputDevice
            }
        }

        return inputDevice
    }
    
    func run(faceSwapTarget: FaceSwapTarget) {
        if let properties = self.properties {
            properties.stop()
        }

        if let device = devices.devices.first {
            print("Starting filter")
            self.properties = CameraFilterProperties(inputDevice: nil,
                                                     outputDevice: device.uid.uuidString,
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