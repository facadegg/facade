//
//  FaceView.swift
//  Facade
//
//  Created by Shukant Pal on 4/29/23.
//

import SwiftUI

struct FaceView: View {
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
                    
                    if let i = filter.inputDevice {
                        Text(i)
                    }
                }
            }
            .padding(EdgeInsets(top: 8, leading: 204, bottom: 16, trailing: 204))
            
            FaceChooserView()
        }
        .onAppear {
            setupCapture()
            capture?.startSession()
        }
        .onDisappear {
            capture?.stopSession()
        }
        .onChange(of: filter.inputDevice) { _ in
            setupCapture()
        }
    }
    
    func setupCapture() {
        if capture?.uniqueID != filter.inputDevice {
            capture?.stopSession()

            if let inputDevice = filter.inputDevice {
                print("Creating capture on \(inputDevice)")
                capture = CameraCapture(uniqueID: inputDevice)
                capture?.checkAuthorization()
            } else {
                capture = nil
            }
        }
    }
}

struct FaceView_Previews: PreviewProvider {
    static var previews: some View {
        FaceView()
            .environmentObject(CameraFilter(availableOutputDevices: Devices()))
            .frame(width: 800, height: 600)
    }
}
