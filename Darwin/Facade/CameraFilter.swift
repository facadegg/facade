//
//  CameraFilter.swift
//  Facade
//
//  Created by Shukant Pal on 4/29/23.
//

import AVFoundation
import Foundation

struct FaceSwapTarget {
    let name: String
    let builtin: Bool = true
};

class CameraFilterProperties {
    let inputDevice: String?
    let outputDevice: String
    let faceSwapTarget: FaceSwapTarget
    
    private var process: Process?
   
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
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "dev.facade")!
        let documentsDirectory = containerURL.appendingPathComponent("Library/Models")
        let faceSwapModelURL = documentsDirectory.appendingPathComponent("\(self.faceSwapTarget.name.replacingOccurrences(of: " ", with: "_")).mlmodel")

        if !fileManager.fileExists(atPath: faceSwapModelURL.path) {
            print("No model found at \(faceSwapModelURL)")
            return
        }
        
        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        self.process = task
        
        task.launchPath = Bundle.main.bundlePath + "/Contents/MacOS/Lens.app/Contents/MacOS/Lens"
        task.arguments = [
            "--dst",
            outputDevice,
            "--frame-rate",
            "30",
            "--face-swap-model",
            faceSwapModelURL.path,
            "--root-dir",
            Bundle.main.bundlePath + "/Contents/Resources"
        ]
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        task.launch()
        
        let stdoutFileHandle = stdoutPipe.fileHandleForReading
        let stderrFileHandle = stderrPipe.fileHandleForReading
        let queue = DispatchQueue(label: "dev.facade.Facade.Lens")

        stdoutFileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                if !string.isEmpty {
                    queue.async {
                        print("\(self.faceSwapTarget.name): \(string)")
                    }
                }
            }
        }

        stderrFileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                if !string.isEmpty {
                    queue.async {
                        print("\(self.faceSwapTarget.name): \(string)")
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
    
    let availableFaceSwapTargets = [
        FaceSwapTarget(name: "Bryan Greynolds"),
        FaceSwapTarget(name: "David Kovalniy"),
        FaceSwapTarget(name: "Ewon Spice"),
        FaceSwapTarget(name: "Kim Jarrey"),
        FaceSwapTarget(name: "Tim Chrys"),
        FaceSwapTarget(name: "Tim Norland"),
        FaceSwapTarget(name: "Zahar Lupin")
    ]
    
    let preferredInputDevice: String? = nil
    private(set) var properties: CameraFilterProperties? = nil
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
            self.properties = CameraFilterProperties(inputDevice: nil,
                                                     outputDevice: device.uid.uuidString,
                                                     faceSwapTarget: faceSwapTarget)
            self.properties?.start()
        }
    }
    
    func resume() {
        self.properties?.start()
    }
    
    func pause() {
        self.properties?.stop()
    }
}
