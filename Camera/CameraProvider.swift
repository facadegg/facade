//
//  CameraProvider.swift
//  Camera
//
//  Created by Shukant Pal on 1/22/23.
//

import Foundation
import CoreMediaIO
import IOKit.audio
import os.log

let kWhiteStripeHeight: Int = 10
let kFrameRate: Int = 60

class CameraProviderSource: NSObject, CMIOExtensionProviderSource {
	private(set) var provider: CMIOExtensionProvider!
    private var deviceSources: Set<CameraDeviceSource> = []
		
	init(clientQueue: DispatchQueue?) {
		super.init()

        deviceSources = []
		provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
	}

	func connect(to client: CMIOExtensionClient) throws {
		// Handle client connect
	}
	
	func disconnect(from client: CMIOExtensionClient) {
		// Handle client disconnect
	}

    var availableProperties: Set<CMIOExtensionProperty> {
        return [.providerName, .providerManufacturer]
	}
	
	func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
		let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])

        if properties.contains(.providerName) { providerProperties.name = "Facade" }
        if properties.contains(.providerManufacturer) { providerProperties.manufacturer = "Paal Maxima" }

        return providerProperties
	}

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        // No operation
	}

    func createDevice() {
        let deviceSource = CameraDeviceSource(localizedName: "Facade")

        do {
            try provider.addDevice(deviceSource.device)
        } catch let error {
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
        
        deviceSources.insert(deviceSource)
    }

    func destroyDevice(deviceSource: CameraDeviceSource) {
        do {
            try provider.removeDevice(deviceSource.device)
        } catch let error {
            fatalError("Failed to remove device: \(error.localizedDescription)")
        }

        deviceSources.remove(deviceSource)
    }
}
