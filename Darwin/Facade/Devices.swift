//
//  Devices.swift
//  Facade
//
//  Created by Shukant Pal on 2/20/23.
//

import Foundation
import os.log

let logger = OSLog(subsystem: "gg.facade.Facade", category: "Camera")
var didInit = false

struct Device: Identifiable, Hashable {
    let type: facade_device_type
    let uid: UUID
    let name: String
    let width: UInt32
    let height: UInt32
    let frameRate: UInt32

    var id: UUID { uid }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type.rawValue)
        hasher.combine(uid)
        hasher.combine(name)
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(frameRate)
    }
}

class Devices: ObservableObject {
    @Published var installed = false
    @Published var devices: [Device] = []
    @Published var needsRestart = false
    @Published var needsInitializing = true

    private var initializing = false
    private var loading = false

    init() {
        openSession()
    }

    init(devices: [Device]) {
        self.installed = true
        self.devices = devices
    }

    init(installed: Bool) {
        self.installed = installed

        if installed {
            openSession()
        } else {
            self.needsInitializing = false
        }
    }

    deinit {
        facade_on_state_changed(nil, nil)
    }

    func openSession() {
        if !didInit {
            initializing = true

            DispatchQueue.global().async {
                didInit = (facade_init() == facade_error_none)

                if didInit {
                    os_log("facade_init successfully returned", log: logger, type: .info)
                    facade_on_state_changed(
                        { context in
                            print("facade_on_state_changed")
                            if let devices = context {
                                Unmanaged<Devices>.fromOpaque(devices).takeUnretainedValue().load()
                            }
                        },
                        Unmanaged.passUnretained(self).toOpaque())
                } else {
                    os_log(
                        "facade_init returned with facade_not_installed", log: logger, type: .error)
                }

                DispatchQueue.main.async {
                    self.needsInitializing = false
                    self.initializing = false
                    self.installed = didInit

                    self.load()
                }
            }
        } else {
            self.load()
        }
    }

    private func load() {
        if !installed {
            self.devices = []
            return
        }
        if loading {
            return
        }

        loading = true

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            var state: UnsafeMutablePointer<facade_state>? = nil
            facade_read_state(&state)

            var listedDevices: [Device] = []

            if let data = state?.pointee {
                if var device = data.devices {
                    repeat {
                        let uuid = UUID(uuidString: String(cString: device.pointee.uid))
                        if let uid = uuid {
                            listedDevices.append(
                                Device(
                                    type: device.pointee.type,
                                    uid: uid,
                                    name: String(cString: device.pointee.name),
                                    width: UInt32(device.pointee.width),
                                    height: UInt32(device.pointee.height),
                                    frameRate: UInt32(device.pointee.frame_rate)))
                        }

                        device = device.pointee.next
                    } while device != data.devices
                }

                facade_dispose_state(&state)
            }

            listedDevices = listedDevices.sorted(by: { $0.name < $1.name })

            print("New list \(listedDevices.count)")

            DispatchQueue.main.async {
                self.needsInitializing = false
                self.devices = listedDevices
                self.loading = false
            }
        }
    }
}
