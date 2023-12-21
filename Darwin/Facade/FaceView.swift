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
            if let capture = self.capture {
                if capture.deviceFailed {
                    Text("Device failed!")
                } else {
                    CameraView(captureSession: capture.captureSession)
                        .padding(EdgeInsets(top: -56.0, leading: 0, bottom: 0, trailing: 0))
                        .overlay(alignment: .topLeading) {
                            FaceChooserView()
                                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))  // clips faces under toolbar
                                .background(.black.opacity(0.5))
                                .background(.ultraThinMaterial)
                                .frame(width: 226)
                        }
                }
            } else {
                Text("No input device selected")

                if let i = filter.previewDevice {
                    Text(i)
                }
            }
        }
        .padding(0)
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
        .frame(minWidth: 540, minHeight: 360)
    }

    func setupCapture() -> CameraCapture? {
        if capture?.uniqueID != filter.previewDevice {
            capture?.stopSession()
            capture = nil

            if let previewDevice = filter.previewDevice {
                print("Creating capture on  \(previewDevice)")
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
    @StateObject static var devices = Devices()

    static var previews: some View {
        FaceView()
            .environmentObject(CameraFilter(availableOutputDevices: devices))
            .environmentObject(devices)
            .frame(width: 1080, height: 720)
            .toolbar {
                Color.clear
            }
    }
}
