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
                    .toolbar {
                        Color.clear
                    }
            }
        }
        .defaultSize(width: 1080, height: 720)
        .windowResizability(devices.needsInitializing ? .contentSize : .contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
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

                var defaultSize = window.contentRect(forFrameRect: window.frame)
                defaultSize.size.width = 1080
                defaultSize.size.height = 720
                window.setFrame(
                    window.frameRect(forContentRect: defaultSize), display: true, animate: true)
            })
    }

    init() {
        let devices = Devices()

        self._devices = StateObject(wrappedValue: devices)
        self._cameraFilter = StateObject(
            wrappedValue: CameraFilter(availableOutputDevices: devices))
    }
}
