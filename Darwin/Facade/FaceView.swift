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

struct FaceOverlays: ViewModifier {
    func body(content: Content) -> some View {
        content
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
            .frame(minWidth: 540, minHeight: 360)
    }
}

struct FaceView: View {
    @EnvironmentObject var devices: Devices
    @EnvironmentObject var filter: CameraFilter
    @State var capture: CameraCapture?
    @State var isReady = false

    var body: some View {
        HStack {
            if isReady, let capture = self.capture {
                VStack {
                    if capture.deviceFailed {
                        Text("Failed to capture video from your camera")
                    } else {
                        CameraView(captureSession: capture.captureSession)
                    }
                }
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
            } else {
                InitView(isWaitingOnCamera: capture != nil)
            }
        }
        .onAppear {
            setupCapture()?.startSession()

            guard let window = NSApplication.shared.windows.first else {
                assertionFailure()
                return
            }

            var defaultSize = window.contentRect(forFrameRect: window.frame)
            defaultSize.size.width = 720
            defaultSize.size.height = 540
            window.setFrame(
                window.frameRect(forContentRect: defaultSize), display: true)
            isReady = true
        }
        .onDisappear {
            capture?.stopSession()
        }
        .onChange(of: filter.previewDevice) { _ in
            capture = setupCapture()
        }
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
