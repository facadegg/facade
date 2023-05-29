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
    @EnvironmentObject var store: Devices

    @State var editMode = false
    @State var explicitlySelectedDeviceUID: UUID?

    var body: some View {
        HStack {
            DevicesList(
                devices: store.devices,
                editMode: $editMode,
                selectedDeviceUID: $explicitlySelectedDeviceUID
            )
            .sheet(isPresented: $editMode) {
                editMode = false
            } content: {
                DeviceEditorSheet(
                    device: explicitlySelectedDeviceUID != nil
                        ? store.devices.first(where: { $0.uid == explicitlySelectedDeviceUID })
                        : nil,
                    editMode: $editMode)
            }

            if let selection = selectedDevice() {
                DeviceDetails(
                    device: selection,
                    editMode: $editMode,
                    selectedDeviceUID: $explicitlySelectedDeviceUID)
            } else {
                SetupView()
            }
        }
    }

    func selectedDevice() -> Device? {
        print("Devices count \(store.devices.count)")
        var selection = store.devices.count > 0 ? store.devices[0] : Optional.none

        if let selectedUID = explicitlySelectedDeviceUID {
            selection = store.devices.first(where: { $0.uid == selectedUID })
        }

        return selection
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView().environmentObject(
            Devices(devices: [
                Device(
                    type: facade_device_type_video,
                    uid: UUID(),
                    name: "Flashy Pan",
                    width: 800,
                    height: 600,
                    frameRate: 60),
                Device(
                    type: facade_device_type_video,
                    uid: UUID(),
                    name: "My Deepfake",
                    width: 800,
                    height: 600,
                    frameRate: 60),
                Device(
                    type: facade_device_type_video,
                    uid: UUID(),
                    name: "Mr. Biden",
                    width: 800,
                    height: 600,
                    frameRate: 60),
            ])
        )
        .environmentObject(CameraFilter(availableOutputDevices: Devices()))
    }
}

struct DevicesList: View {
    let devices: [Device]

    @Binding var editMode: Bool
    @Binding var selectedDeviceUID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedDeviceUID) {
                Text("Cameras")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(devices, id: \.uid) { wk in
                    Text(wk.name).tag(wk)
                }
            }

            List {
                HStack {
                    Spacer()

                    Button(action: {
                        editMode = true
                        selectedDeviceUID = Optional.none
                    }) {
                        Image(systemName: "plus")
                            .frame(width: 8, height: 8)
                    }

                    Button(action: {
                        if let uuidString = selectedDeviceUID?.uuidString {
                            DispatchQueue.global().async {
                                uuidString.cString(using: .utf8)?.withUnsafeBytes({ uidBytes in
                                    facade_delete_device(
                                        uidBytes.bindMemory(to: Int8.self).baseAddress)
                                    return
                                })
                            }
                        }

                        editMode = false
                        selectedDeviceUID = Optional.none
                    }) {
                        Image(systemName: "minus")
                            .frame(width: 8, height: 8)
                    }

                    Spacer()
                }
                .padding(0)
            }
            .padding(0)
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
    @Binding var editMode: Bool
    @Binding var selectedDeviceUID: UUID?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
            }
            Text("\(device.name)")
                .bold()

            HStack {
                Spacer()
                Button("Edit") {
                    editMode = true
                    selectedDeviceUID = device.uid
                }
            }

            if capture.deviceFailed {
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

    init(device: Device, editMode: Binding<Bool>, selectedDeviceUID: Binding<UUID?>) {
        self.device = device

        _capture = State(initialValue: CameraCapture(uniqueID: device.uid.uuidString))
        _editMode = editMode
        _selectedDeviceUID = selectedDeviceUID

        capture.checkAuthorization()
    }

    func getProperties() -> [KeyValue] {
        return [
            KeyValue(name: "Device UID", value: device.uid.uuidString),
            KeyValue(name: "Name", value: device.name),
            KeyValue(name: "Width", value: String(device.width)),
            KeyValue(name: "Height", value: String(device.height)),
            KeyValue(name: "Frame Rate", value: String(device.frameRate)),
        ]
    }
}

struct DeviceEditorSheet: View {
    var device: Device?

    @Binding var editMode: Bool

    @State var name: String
    @State var width: String
    @State var height: String
    @State var frameRate: String

    var body: some View {
        VStack {
            Text(device != Optional.none ? "Edit device" : "Create new device")
                .bold()

            Spacer()

            Form {
                TextField(text: $name, label: { Text("Name:") }).disabled(device != nil)
                TextField(text: $width, label: { Text("Width: ") })
                TextField(text: $height, label: { Text("Height: ") })
                TextField(text: $frameRate, label: { Text("Frame Rate:") })
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    editMode = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Done") {
                    editMode = false

                    DispatchQueue.global().async { () in
                        name.cString(using: .utf8)?.withUnsafeBytes({
                            (nameBytes: UnsafeRawBufferPointer) -> Void in
                            var info = facade_device_info(
                                next: nil,
                                type: facade_device_type_video,
                                uid: nil,
                                name: nameBytes.bindMemory(to: Int8.self).baseAddress,
                                width: UInt32(self.width) ?? 1920,
                                height: UInt32(self.height) ?? 1080,
                                frame_rate: UInt32(self.frameRate) ?? 60)

                            print(info)

                            if let device = self.device {
                                info.name = nil

                                device.uid.uuidString.cString(using: .utf8)?
                                    .withUnsafeBufferPointer({ uidBytes in
                                        print(
                                            "facade_edit_device: \(facade_edit_device(uidBytes.baseAddress, &info))"
                                        )
                                    })
                            } else {
                                print("facade_create_device: \(facade_create_device(&info))")
                            }
                        })
                        return
                    }
                }
                .backgroundStyle(.blue)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 240, height: 180)
        .padding()
    }

    init(device: Device?, editMode: Binding<Bool>) {
        if let initialDevice = device {
            _name = State(initialValue: initialDevice.name)
            _width = State(initialValue: String(initialDevice.width))
            _height = State(initialValue: String(initialDevice.height))
            _frameRate = State(initialValue: String(initialDevice.frameRate))
        } else {
            _name = State(initialValue: "My Camera")
            _width = State(initialValue: String(1920))
            _height = State(initialValue: String(1080))
            _frameRate = State(initialValue: String(60))
        }

        _editMode = editMode
        self.device = device
    }
}

struct DeviceEditorSheet_Previews: PreviewProvider {
    static var previews: some View {
        PreviewSheet()
    }

    struct PreviewSheet: View {
        var body: some View {
            DeviceEditorSheet(device: Optional.none, editMode: Binding.constant(true))
        }
    }
}
