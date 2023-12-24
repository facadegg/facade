//
//  CameraView.swift
//  Facade
//
//  Created by Shukant Pal on 2/20/23.
//

import AVFoundation
import SwiftUI

class PlayerView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var fill: Bool

    init(captureSession: AVCaptureSession, fill: Bool) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.fill = fill

        super.init(frame: .zero)

        setupLayer()
    }

    func setupLayer() {
        previewLayer?.frame = self.frame
        previewLayer?.contentsGravity = fill ? .resizeAspectFill : .resizeAspect
        previewLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        previewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer?.backgroundColor = .black

        if let connection = previewLayer?.connection, connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }

        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct CameraView: NSViewRepresentable {
    typealias NSViewType = PlayerView

    let captureSession: AVCaptureSession
    let fill: Bool

    init(captureSession: AVCaptureSession, fill: Bool) {
        self.captureSession = captureSession
        self.fill = fill
    }
    
    init(captureSession: AVCaptureSession) {
        self.init(captureSession: captureSession, fill: true)
    }

    func makeNSView(context: Context) -> PlayerView {
        return PlayerView(captureSession: captureSession, fill: fill)
    }

    func updateNSView(_ nsView: PlayerView, context: Context) {}
}
