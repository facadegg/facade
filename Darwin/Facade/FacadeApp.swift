//
//  FacadeApp.swift
//  Facade
//
//  Created by Shukant Pal on 1/22/23.
//  Copyright © 2023 Paal Maxima. All rights reserved.
//

import SwiftUI

@main
struct FacadeApp: App {
    @StateObject var devices: Devices
    @StateObject var cameraFilter: CameraFilter

    var body: some Scene {
        WindowGroup {
            FaceView()
                .environmentObject(cameraFilter)
                .environmentObject(devices)
        }
        .defaultSize(width: 902, height: 728)
        .windowResizability(WindowResizability.contentSize)
        .windowStyle(HiddenTitleBarWindowStyle())
    }
    
    init() {
        let devices = Devices()
        
        self._devices = StateObject(wrappedValue: devices)
        self._cameraFilter = StateObject(wrappedValue: CameraFilter(availableOutputDevices: devices))
    }
}
