//
//  main.swift
//  Camera
//
//  Created by Shukant Pal on 1/22/23.
//

import Foundation
import CoreMediaIO

let providerSource = CameraProviderSource(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
