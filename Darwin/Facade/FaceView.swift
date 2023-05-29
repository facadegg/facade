//
//  FaceView.swift
//  Facade
//
//  Created by Shukant Pal on 4/29/23.
//

import SwiftUI

struct FaceView: View {
    @EnvironmentObject var devices: Devices
    @EnvironmentObject var filter: CameraFilter
    @State var capture: CameraCapture?

    var body: some View {
        VStack {
            HStack {
                if let capture = self.capture {
                    if capture.deviceFailed {
                        Text("Device failed!")
                    } else {
                        CameraView(captureSession: capture.captureSession)
                            .frame(width: 493, height: 227)
                            .cornerRadius(12, antialiased: true)
                    }
                } else {
                    Text("No input device selected")

                    if let i = filter.previewDevice {
                        Text(i)
                    }
                }
            }
            .padding(EdgeInsets(top: 8, leading: 204, bottom: 16, trailing: 204))

            FaceChooserView()
        }
        .onAppear {
            setupCapture()?.startSession()
        }
        .onDisappear {
            capture?.stopSession()
        }
        .onChange(of: filter.previewDevice) { _ in
            if let previewDevice = filter.previewDevice {
                capture?.changeDevice(newUniqueID: previewDevice)
            } else {
                capture?.stopSession()
            }
        }
        .frame(minWidth: 902, minHeight: 728)
    }

    func setupCapture() -> CameraCapture? {
        if capture?.uniqueID != filter.previewDevice {
            capture?.stopSession()
            capture = nil

            if let previewDevice = filter.previewDevice {
                print("Creating capture on \(previewDevice)")
                capture = CameraCapture(uniqueID: filter.inputDevice!)
                capture?.checkAuthorization()
            } else {
                capture = nil
            }
        }

        return capture
    }
}

struct FaceView_Previews: PreviewProvider {
    static var previews: some View {
        FaceView()
            .environmentObject(CameraFilter(availableOutputDevices: Devices()))
            .frame(width: 800, height: 600)
    }
}
