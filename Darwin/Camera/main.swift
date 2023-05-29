//
//  main.swift
//  Camera
//
//  Created by Shukant Pal on 1/22/23.
//

import CoreMediaIO
import Foundation
import os.log

let scribe = OSLog(subsystem: "com.paalmaxima.Facade.Camera", category: "Camera")

os_log("com.paalmaxima.Facade.Camera is initializing.", log: scribe, type: .error)
let providerSource = CameraProviderSource(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

_ = providerSource.createDevice(localizedName: "Facade")

CFRunLoopRun()
os_log("com.paalmaxima.Facade.Camera has initialized.", log: scribe, type: .info)
