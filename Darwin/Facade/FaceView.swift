//
//  FaceView.swift
//  Facade
//
//  Created by Shukant Pal on 4/29/23.
//

import SwiftUI

struct FaceOverlayBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.black.opacity(0.67))
            .background(.ultraThinMaterial)
    }
}

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
                            FaceStatusView()
                                .padding(EdgeInsets(top: -8, leading: 240, bottom: 0, trailing: 0))
                        }
                        .overlay(alignment: .topLeading) {
                            FaceChooserView()
                                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))  // clips faces under toolbar
                                .frame(width: 226)
                                .modifier(FaceOverlayBackground())
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
            capture = setupCapture()
        }
        .frame(minWidth: 540, minHeight: 360)
    }

    func setupCapture() -> CameraCapture? {
        if capture?.uniqueID != filter.previewDevice {
            capture?.stopSession()
            capture = nil

            if let previewDevice = filter.previewDevice {
                print("Creating capture on  \(previewDevice)")
                capture = CameraCapture(uniqueID: previewDevice)
                capture?.checkAuthorization()
            }
        }

        return capture
    }
}

struct FaceStatusView: View {
    @EnvironmentObject var filter: CameraFilter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            if let previewDeviceName = self.filter.previewDeviceName {
                HStack {
                    Image(systemName: "camera.fill")
                    Text(previewDeviceName)
                }
                .padding(8)
                .frame(height: 32)
                .modifier(FaceOverlayBackground())
                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 8, height: 8)))
            }

            Button(
                action: {
                    openWindow(id: "config")
                },
                label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white)
                        .padding(8)
                        .contentShape(RoundedRectangle(cornerSize: CGSize(width: 8, height: 8)))
                }
            )
            .buttonStyle(.plain)
            .modifier(FaceOverlayBackground())
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 8, height: 8)))
        }
        .foregroundStyle(.white)
    }
}

struct FaceView_Previews: PreviewProvider {
    @StateObject static var devices = Devices()

    static var previews: some View {
        FaceView()
            .environmentObject(CameraFilter(availableOutputDevices: devices))
            .environmentObject(devices)
            .frame(width: 1080, height: 720)
            .previewDisplayName("Facade")
            .toolbar {
                Color.clear
            }
    }
}
