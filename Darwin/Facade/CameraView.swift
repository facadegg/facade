//
//  CameraView.swift
//  Facade
//
//  Created by Shukant Pal on 2/20/23.
//

import AVFoundation
import SwiftUI

class PlayerView: NSView {
    var captureSession: AVCaptureSession
    var previewLayer: AVCaptureVideoPreviewLayer?
    var fill: Bool

    init(captureSession: AVCaptureSession, fill: Bool) {
        self.captureSession = captureSession
        self.fill = fill

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        super.init(frame: .zero)

        setupLayer()
    }

    func setupLayer() {
        if let previewLayer = previewLayer {
            previewLayer.frame = self.frame
            previewLayer.contentsGravity = fill ? .resizeAspectFill : .resizeAspect
            previewLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
            previewLayer.backgroundColor = .black

            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
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

    func updateNSView(_ nsView: PlayerView, context: Context) {
        if !captureSession.inputs.elementsEqual(nsView.captureSession.inputs) {
            nsView.captureSession = captureSession
            nsView.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            nsView.setupLayer()
        }
    }
}
