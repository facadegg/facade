//
//  CameraDevice.swift
//  Camera
//
//  Created by Shukant Pal on 1/27/23.
//

import CoreMediaIO
import CoreGraphics
import Foundation
import os.log

class CameraDeviceSource: NSObject, CMIOExtensionDeviceSource, CameraStreamHandler {
    private(set) var device: CMIOExtensionDevice!
    private var _defaultStream: SplashAnimator!
    private var _streamSource: CameraStreamSource!
    private var _streamSink: CameraStreamSink!
    private var _streamingCounter: UInt32 = 0
    private var _streamingFromSink: Bool = false
    private var _lastScheduledOutputTimingInfo = CMSampleTimingInfo()
    private var _timer: DispatchSourceTimer?
    private let _timerQueue = DispatchQueue(label: "timerQueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: .global(qos: .userInteractive))
    private var _videoDescription: CMFormatDescription!
    private var _bufferPool: CVPixelBufferPool!
    private var _bufferAuxAttributes: NSDictionary!
    private var _whiteStripeStartRow: UInt32 = 0
    private var _whiteStripeIsAscending: Bool = false
    
    init(localizedName: String) {
        
        super.init()
        let deviceID = UUID() // replace this with your device UUID
        self.device = CMIOExtensionDevice(localizedName: localizedName, deviceID: deviceID, legacyDeviceID: nil, source: self)
        
        let dims = CMVideoDimensions(width: 1920, height: 1080)
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA, width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferPoolAllocationThresholdKey: 64
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        let videoStreamFormat = CMIOExtensionStreamFormat.init(formatDescription: _videoDescription, maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), validFrameDurations: nil)
        _bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]

        _defaultStream = SplashAnimator(width: 1920, height: 1080)
        
        let videoID = UUID() // replace this with your video UUID
        _streamSource = CameraStreamSource(localizedName: "Facade Source", streamID: videoID, streamFormat: videoStreamFormat, handler: self)
        _streamSink = CameraStreamSink(localizedName: "Facade Sink", streamFormat: videoStreamFormat, handler: self)
        
        do {
            try device.addStream(_streamSource.stream)
        } catch let error {
            fatalError("Failed to add stream: \(error.localizedDescription)")
        }
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return [.deviceTransportType, .deviceModel]
    }
    
    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            deviceProperties.model = "SampleCapture Model"
        }
        
        return deviceProperties
    }
    
    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        // Handle settable properties here.
    }
    
    func startStreaming() {
        guard let _ = _bufferPool else {
            return
        }
        
        _streamingCounter += 1
        _timer = DispatchSource.makeTimerSource(flags: .strict, queue: _timerQueue)
        _timer!.schedule(deadline: .now(), repeating: Double(1) / Double(kFrameRate), leeway: .seconds(0))
        
        _timer!.setEventHandler {
            
            var err: OSStatus = 0
            let now = CMClockGetTime(CMClockGetHostTimeClock())
            
            var pixelBuffer: CVPixelBuffer?
            err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &pixelBuffer)
            if err != 0 {
                os_log(.error, "out of pixel buffers \(err)")
            }
            
            if let pixelBuffer = pixelBuffer {
                CVPixelBufferLockBaseAddress(pixelBuffer, [])

                let bufferPtr = CVPixelBufferGetBaseAddress(pixelBuffer)!
                let bufferByteSize = CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)

                memcpy(bufferPtr, self._defaultStream.nextFrame(), bufferByteSize)
                os_log(.info, "painted \(CVPixelBufferGetBytesPerRow(pixelBuffer))")

                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                
                var sbuf: CMSampleBuffer!
                var timingInfo = CMSampleTimingInfo()
                timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self._videoDescription, sampleTiming: &timingInfo, sampleBufferOut: &sbuf)
                if err == 0 {
                    self._streamSource.stream.send(sbuf, discontinuity: [], hostTimeInNanoseconds: UInt64(timingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                }
                os_log(.info, "video time \(timingInfo.presentationTimeStamp.seconds) now \(now.seconds) err \(err)")
            }
        }
        
        _timer!.setCancelHandler {
        }
        
        _timer!.resume()
    }

    func stopStreaming() {
        if _streamingCounter > 1 {
            _streamingCounter -= 1
        }
        else {
            _streamingCounter = 0
            if let timer = _timer {
                timer.cancel()
                _timer = nil
            }
        }
    }

    func copyFromSinkToSource(client: CMIOExtensionClient) {
        self._streamSink.stream.consumeSampleBuffer(from: client) { buffer, sequenceNumber, discontinuity, hasMoreSamples, error in

            if let buffer = buffer {
                self._lastScheduledOutputTimingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                let scheduledOutputTimestampNanos =
                        UInt64(self._lastScheduledOutputTimingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
                let scheduledOutput = CMIOExtensionScheduledOutput(sequenceNumber: sequenceNumber,
                                                                   hostTimeInNanoseconds: scheduledOutputTimestampNanos)

                if self._streamingCounter > 0 {
                    self._streamSource.stream.send(buffer,
                                                   discontinuity: discontinuity,
                                                   hostTimeInNanoseconds: scheduledOutputTimestampNanos)
                }
    
                self._streamSink.stream.notifyScheduledOutputChanged(scheduledOutput)
            }

            if self._streamingFromSink {
                self.copyFromSinkToSource(client: client)
            }
        }
    }

    func startStreamingFromSink(client: CMIOExtensionClient) {
        _streamingFromSink = true
        copyFromSinkToSource(client: client)
    }

    func stopStreamingFromSink() {
        _streamingFromSink = false
    }
}
