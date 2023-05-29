//
//  FacadeApp.swift
//  Facade
//
//  Created by Shukant Pal on 1/22/23.
//  Copyright © 2023 Paal Maxima. All rights reserved.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        hideTitleBar()
    }

    func hideTitleBar() {
        guard let window = NSApplication.shared.windows.first else {
            assertionFailure()
            return
        }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

@main
struct FacadeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var devices: Devices
    @StateObject var cameraFilter: CameraFilter

    var body: some Scene {
        WindowGroup {
            if devices.needsInitializing {
                VStack(alignment: .center) {
                    IconView()
                        .frame(maxWidth: 96, maxHeight: 48)
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Bringing out the Facade...")
                        .padding()
                    Spacer()
                }
                .padding(48)
                .frame(width: 360, height: 320)
            } else if !devices.installed {
                SetupView()
                    .environmentObject(devices)
            } else {
                FaceView()
                    .environmentObject(cameraFilter)
                    .environmentObject(devices)

            }
        }
        .defaultSize(width: 902, height: 728)
        .windowResizability(.contentSize)
        .windowStyle(HiddenTitleBarWindowStyle())
        .onChange(
            of: devices.needsInitializing,
            perform: { needsInitializing in
                if needsInitializing { return }
                guard let window = NSApplication.shared.windows.first else {
                    assertionFailure()
                    return
                }
                window.standardWindowButton(.closeButton)?.isHidden = false
                window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                window.standardWindowButton(.zoomButton)?.isHidden = false
            })
    }

    init() {
        let devices = Devices()

        self._devices = StateObject(wrappedValue: devices)
        self._cameraFilter = StateObject(
            wrappedValue: CameraFilter(availableOutputDevices: devices))
    }
}
