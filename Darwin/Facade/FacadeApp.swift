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
        dismissSettingsWindow()
        hideTitleBar()
    }

    func dismissSettingsWindow() {
        if let window = NSApplication.shared.windows.first(where: { window in
            window.identifier?.rawValue.starts(with: "config") ?? false
        }) {
            window.close()
        }
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
                InitView(isWaitingOnCamera: false)
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
            }
        )

        WindowGroup("Configuration", id: "config") {
            SettingsView()
                .environmentObject(cameraFilter)
                .environmentObject(devices)
        }
        .defaultSize(width: 702, height: 540)
        .windowResizability(.contentMinSize)

    }

    init() {
        let devices = Devices()

        self._devices = StateObject(wrappedValue: devices)
        self._cameraFilter = StateObject(
            wrappedValue: CameraFilter(availableOutputDevices: devices))
    }
}
