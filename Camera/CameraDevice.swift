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

let magicProperty = CMIOExtensionProperty(rawValue: "4cc_fmag_glob_0000")
let magicValue = "Facade by Paal Maxima" as NSString

let nameProperty = CMIOExtensionProperty(rawValue: "4cc_fnam_glob_0000")
let dimensionsProperty = CMIOExtensionProperty(rawValue: "4cc_fdim_glob_000")
let frameRateProperty = CMIOExtensionProperty(rawValue: "4cc_frat_glob_000")

class CameraDeviceSource: NSObject, CMIOExtensionDeviceSource, CameraStreamHandler {
    private(set) var device: CMIOExtensionDevice!

    private var bufferAuxAttributes: NSDictionary!
    private var bufferPool: CVPixelBufferPool!
    private var formatDescription: CMFormatDescription!
    private var frameRate: UInt32 = 60
    private var height: UInt32 = 1080
    private var lastScheduledOutput = CMSampleTimingInfo()
    private let logger: Logger
    private var width: UInt32 = 1920

    private var frameTimer: DispatchSourceTimer?
    private let frameQueue = DispatchQueue(label: "frameQueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: .global(qos: .userInteractive))

    private var streamCounter: UInt32 = 0
    private var streamFromSink: Bool = false
    private var streamFakeSplash: SplashAnimator!
    private var streamSource: CameraStreamSource!
    private var streamSink: CameraStreamSink!
    
    init(localizedName: String) {
        let deviceID = UUID() // replace this with your device UUID
        self.logger = Logger(subsystem: "com.paalmaxima.Facade.Camera", category: "CameraDeviceSource@\(deviceID)")
        super.init()

        self.device = CMIOExtensionDevice(localizedName: localizedName, deviceID: deviceID, legacyDeviceID: nil, source: self)
        setDeviceFormat(width: 1920, height: 1080, frameRate: 60, withStreams: false)
        streamFakeSplash = SplashAnimator(width: Int(self.width), height: Int(self.height))

        let streamFormat = CMIOExtensionStreamFormat.init(formatDescription: formatDescription,
                                                          maxFrameDuration: CMTime(value: 1, timescale: Int32(frameRate)),
                                                          minFrameDuration: CMTime(value: 1, timescale: Int32(frameRate)),
                                                          validFrameDurations: nil)
        streamSource = CameraStreamSource(localizedName: "Facade Source", streamFormat: streamFormat, handler: self)
        streamSink = CameraStreamSink(localizedName: "Facade Sink", streamFormat: streamFormat, handler: self)

        do {
            try device.addStream(streamSource.stream)
            try device.addStream(streamSink.stream)
        } catch let error {
            fatalError("Failed to add stream: \(error.localizedDescription)")
        }
    }

    var availableProperties: Set<CMIOExtensionProperty> {
        return [.deviceTransportType, .deviceModel, magicProperty, nameProperty, dimensionsProperty]
    }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])

        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            deviceProperties.model = "Facade"
        }
        if properties.contains(magicProperty) {
            deviceProperties.setPropertyState(CMIOExtensionPropertyState(value: NSData(bytes: magicValue.utf8String,
                                                                                       length: magicValue.length + 1)),
                                              forProperty: magicProperty)
        }
        if properties.contains(nameProperty) {
            deviceProperties.setPropertyState(CMIOExtensionPropertyState(value: device.localizedName as NSString),
                                              forProperty: nameProperty)
        }
        if properties.contains(dimensionsProperty) {
            deviceProperties.setPropertyState(CMIOExtensionPropertyState(value: "1920x1080" as NSString),
                                              forProperty: dimensionsProperty)
        }
        
        return deviceProperties
    }
    
    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        let resetDeviceFormat = false
        var newWidth = self.width, newHeight = self.height, newFrameRate = self.frameRate
        
        if let dimensions = deviceProperties.propertiesDictionary[dimensionsProperty] {
            if let values = dimensions.value?.components(separatedBy: "x") {
                if values.count == 2, let width = UInt32(values[0]), let height = UInt32(values[1]) {
                    if width > 0 && height > 0 && width <= 8192 && height <= 8192 {
                        newWidth = width
                        newHeight = height
                    }
                }
            }
        }

        if let frameRatePropertyState = deviceProperties.propertiesDictionary[frameRateProperty] {
            if let frameRateValue = frameRatePropertyState.value?.uint32Value {
                if frameRateValue >= 1 && frameRateValue <= 120 {
                    newFrameRate = frameRateValue
                }
            }
        }

        if newWidth != self.width || newHeight != self.height || newFrameRate != self.frameRate {
            setDeviceFormat(width: newWidth, height: newHeight, frameRate: newFrameRate)
        }
    }

    private func setDeviceFormat(width: UInt32, height: UInt32, frameRate: UInt32, withStreams: Bool = true) {
        logger.info("Reformat device to \(width)x\(height) at \(frameRate) FPS")
        self.width = width
        self.height = height
        self.frameRate = frameRate

        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                       codecType: kCVPixelFormatType_32BGRA,
                                       width: Int32(width),
                                       height: Int32(height),
                                       extensions: nil,
                                       formatDescriptionOut: &formatDescription)
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: Int32(width),
            kCVPixelBufferHeightKey: Int32(height),
            kCVPixelBufferPixelFormatTypeKey: formatDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferPoolAllocationThresholdKey: 64
        ]
        bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &bufferPool)

        if withStreams { setStreamFormat() }
    }

    private func setStreamFormat() {
        let streamFormat = CMIOExtensionStreamFormat.init(formatDescription: formatDescription,
                                                          maxFrameDuration: CMTime(value: 1, timescale: Int32(frameRate)),
                                                          minFrameDuration: CMTime(value: 1, timescale: Int32(frameRate)),
                                                          validFrameDurations: nil)
        streamSource.format = streamFormat
        streamSink.format = streamFormat

        streamFakeSplash = SplashAnimator(width: Int(self.width), height: Int(self.height))
    }

    func startStreaming() {
        guard let _ = bufferPool else {
            return
        }
        
        streamCounter += 1
        frameTimer = DispatchSource.makeTimerSource(flags: .strict, queue: frameQueue)
        frameTimer!.schedule(deadline: .now(), repeating: Double(1) / Double(kFrameRate), leeway: .seconds(0))
        
        frameTimer!.setEventHandler {
            if self.streamFromSink {
                return
            }
            
            var err: OSStatus = 0
            let now = CMClockGetTime(CMClockGetHostTimeClock())
            
            var pixelBuffer: CVPixelBuffer?
            err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self.bufferPool, self.bufferAuxAttributes, &pixelBuffer)
            if err != 0 {
                os_log(.error, "out of pixel buffers \(err)")
            }
            
            if let pixelBuffer = pixelBuffer {
                CVPixelBufferLockBaseAddress(pixelBuffer, [])

                let bufferPtr = CVPixelBufferGetBaseAddress(pixelBuffer)!
                let bufferByteSize = CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)

                memcpy(bufferPtr, self.streamFakeSplash.nextFrame(), bufferByteSize)
                os_log(.info, "painted \(CVPixelBufferGetBytesPerRow(pixelBuffer))")

                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                
                var sbuf: CMSampleBuffer!
                var timingInfo = CMSampleTimingInfo()
                timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self.formatDescription, sampleTiming: &timingInfo, sampleBufferOut: &sbuf)
                if err == 0 {
                    self.streamSource.stream.send(sbuf, discontinuity: [], hostTimeInNanoseconds: UInt64(timingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                }
                os_log(.info, "video time \(timingInfo.presentationTimeStamp.seconds) now \(now.seconds) err \(err)")
            }
        }
        
        frameTimer!.setCancelHandler {
        }
        
        frameTimer!.resume()
    }

    func stopStreaming() {
        if streamCounter > 1 {
            streamCounter -= 1
        }
        else {
            streamCounter = 0
            if let timer = frameTimer {
                timer.cancel()
                frameTimer = nil
            }
        }
    }

    func copyFromSinkToSource(client: CMIOExtensionClient) {
        self.streamSink.stream.consumeSampleBuffer(from: client) { buffer, sequenceNumber, discontinuity, hasMoreSamples, error in

            if let buffer = buffer {
                self.lastScheduledOutput.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                let scheduledOutputTimestampNanos =
                        UInt64(self.lastScheduledOutput.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
                let scheduledOutput = CMIOExtensionScheduledOutput(sequenceNumber: sequenceNumber,
                                                                   hostTimeInNanoseconds: scheduledOutputTimestampNanos)

                if self.streamCounter > 0 {
                    os_log(.info, "Sending sink to source")
                    self.streamSource.stream.send(buffer,
                                                   discontinuity: discontinuity,
                                                   hostTimeInNanoseconds: scheduledOutputTimestampNanos)
                }
    
                self.streamSink.stream.notifyScheduledOutputChanged(scheduledOutput)
            }

            if self.streamFromSink {
                self.copyFromSinkToSource(client: client)
            }
        }
    }

    func startStreamingFromSink(client: CMIOExtensionClient) {
        streamFromSink = true
        copyFromSinkToSource(client: client)
    }

    func stopStreamingFromSink() {
        streamFromSink = false
    }
}
