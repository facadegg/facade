//
//  CameraStream.swift
//  Camera
//
//  Created by Shukant Pal on 1/29/23.
//

import CoreMediaIO
import Foundation
import os.log

protocol CameraStreamHandler {
    func startStreaming() -> Void
    func stopStreaming() -> Void
    func startStreamingFromSink(client: CMIOExtensionClient) -> Void
    func stopStreamingFromSink() -> Void
}

class CameraStreamSource: NSObject, CMIOExtensionStreamSource {
    private(set) var stream: CMIOExtensionStream!
    
    private let _handler: CameraStreamHandler
    public var format: CMIOExtensionStreamFormat
    
    init(localizedName: String, streamFormat: CMIOExtensionStreamFormat, handler: CameraStreamHandler) {
        
        self.format = streamFormat
        self._handler = handler
        
        super.init()
        
        self.stream = CMIOExtensionStream(localizedName: localizedName,
                                          streamID: UUID(),
                                          direction: .source,
                                          clockType: .hostTime,
                                          source: self)
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return []
    }
    
    var formats: [CMIOExtensionStreamFormat] {
        return [format]
    }
    
    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        return CMIOExtensionStreamProperties(dictionary: [:])
    }
    
    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        // No operation
    }
    
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        return true
    }
    
    func startStream() throws {
        _handler.startStreaming()
    }
    
    func stopStream() throws {
        _handler.stopStreaming()
    }
}

class CameraStreamSink: NSObject, CMIOExtensionStreamSource {
    private(set) var stream: CMIOExtensionStream!
    
    private var _client: CMIOExtensionClient?
    public var format: CMIOExtensionStreamFormat
    private let _handler: CameraStreamHandler
    private var _started: Bool
    
    init(localizedName: String, streamFormat: CMIOExtensionStreamFormat, handler: CameraStreamHandler) {
        self._client = nil
        self.format = streamFormat
        self._handler = handler
        self._started = false
        
        super.init()
        
        self.stream = CMIOExtensionStream(localizedName: localizedName,
                                          streamID: UUID(),
                                          direction: .sink,
                                          clockType: .hostTime,
                                          source: self)
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return []
    }
    
    var formats: [CMIOExtensionStreamFormat] {
        return [format]
    }
    
    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        return CMIOExtensionStreamProperties(dictionary: [:])
    }
    
    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        // No operation
    }
    
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        if !_started {
            _client = client
            return true
        }
        
        return false
    }
    
    func startStream() throws {
        if let client = _client {
            _handler.startStreamingFromSink(client: client)
        }
    }
    
    func stopStream() throws {
        _handler.stopStreamingFromSink()
    }
}
