//
//  Devices.swift
//  Facade
//
//  Created by Shukant Pal on 2/20/23.
//

import Foundation

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
        hasher.combine(uid)
    }
}

class Devices: ObservableObject {
    @Published var installed = false
    @Published var devices: [Device] = []
    
    private var initializing = false
    private var loading = false
    
    init() {
        checkInstall()
    }
    
    init(devices: [Device]) {
        self.installed = true
        self.devices = devices
    }
    
    func checkInstall() {
        if (!didInit) {
            initializing = true
            
            DispatchQueue.global().async {
                didInit = (facade_init() == facade_error_none)
                
                DispatchQueue.main.async {
                    self.initializing = false
                    self.installed = didInit
                    
                    self.load()
                }
            }
        }
    }
    
    func load() {
        if (!installed) {
            self.devices = []
            return
        }
        if loading {
            return
        }
        
        loading = true
        
        DispatchQueue.global().async {
            var state: UnsafeMutablePointer<facade_state>? = nil
            facade_read_state(&state)
            
            var listedDevices: [Device] = []
            
            if let data = state?.pointee {
                if var device = data.devices {
                    repeat {
                        let uuid = UUID(uuidString: String(cString: device.pointee.uid))
                        if let uid = uuid {
                            listedDevices.append(Device(type: device.pointee.type,
                                                        uid: uid,
                                                        name: String(cString: device.pointee.name),
                                                        width: UInt32(device.pointee.width),
                                                        height: UInt32(device.pointee.height),
                                                        frameRate: UInt32(device.pointee.frame_rate)))
                        }
                        
                        device = device.pointee.next
                    } while (device != data.devices)
                }
            }
            
            DispatchQueue.main.async {
                self.devices = listedDevices
                self.loading = false
            }
        }
    }
}
