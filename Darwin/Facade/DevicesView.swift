//
//  DevicesView.swift
//  Facade
//
//  Created by Shukant Pal on 1/22/23.
//  Copyright © 2023 Paal Maxima. All rights reserved.
//

import AVFoundation
import SwiftUI

struct DevicesView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = NavigationSplitViewVisibility.all
    
    @EnvironmentObject var store: Devices
    @State var explicitlySelectedDevice: Device?
    
    var body: some View {
        HStack {
            DevicesList(devices: store.devices,
                        selectedDevice: $explicitlySelectedDevice)
            
            if let selection = selectedDevice() {
                DeviceDetails(device: selection)
            } else {
                SetupView()
            }
        }
    }

    func selectedDevice() -> Optional<Device> {
        var selection = store.devices.count > 0 ? store.devices[0] : Optional.none
        
        if let explicitSelection = explicitlySelectedDevice {
            selection = explicitSelection
        }
        
        return selection
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView().environmentObject(Devices(devices: [
            Device(type: facade_device_type_video,
                   uid: UUID(),
                   name: "Flashy Pan",
                   width: 800,
                   height: 600,
                   frameRate: 60),
            Device(type: facade_device_type_video,
                   uid: UUID(),
                   name: "My Deepfake",
                   width: 800,
                   height: 600,
                   frameRate: 60),
            Device(type: facade_device_type_video,
                   uid: UUID(),
                   name: "Mr. Biden",
                   width: 800,
                   height: 600,
                   frameRate: 60)
        ]))
    }
}

struct DevicesList: View {
    let devices: [Device]
    @Binding var selectedDevice: Device?
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedDevice) {
                Text("Cameras")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(devices) { wk in
                    Text(wk.name).tag(wk)
                }
            }
            
            List {
                HStack {
                    Button(action: {
                        
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        
                    }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
            .frame(height: 48)
        }
        .frame(width: 140)
        .listStyle(.sidebar)
    }
}

struct Person: Identifiable {
    let givenName: String
    let familyName: String
    let emailAddress: String
    let id = UUID()

    var fullName: String { givenName + " " + familyName }
}

struct KeyValue: Identifiable {
    let name: String
    let value: String
    
    var id: String { name }
}

struct DeviceDetails: View {
    let device: Device
    @State var capture: CameraCapture
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
            }
            Text("\(device.name)")
                .bold()
            
            if (capture.deviceFailed) {
                Text("Device Failed")
            } else {
                CameraView(captureSession: capture.captureSession)
            }
            
            Table(getProperties()) {
                TableColumn("Properties", value: \.name)
                TableColumn("Value", value: \.value)
            }
            .frame(maxHeight: 160)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    init(device: Device) {
        self.device = device
        _capture = State(initialValue: CameraCapture(uniqueID: device.uid.uuidString))
        
        capture.checkAuthorization()
    }
    
    func getProperties() -> [KeyValue] {
        return [
            KeyValue(name: "Device UID", value: device.uid.uuidString),
            KeyValue(name: "Name"      , value: device.name),
            KeyValue(name: "Width"     , value: String(device.width)),
            KeyValue(name: "Height"    , value: String(device.height)),
            KeyValue(name: "Frame Rate", value: String(device.frameRate))
        ]
    }
}
