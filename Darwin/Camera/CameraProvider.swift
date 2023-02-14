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

let stateProperty = CMIOExtensionProperty(rawValue: "4cc_fsta_glob_0000")

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
        return [.providerName, .providerManufacturer, magicProperty, stateProperty]
	}
	
	func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
		let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])

        if properties.contains(.providerName) {
            providerProperties.name = "Facade"
        }
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = "Paal Maxima"
        }
        if properties.contains(magicProperty) {
            providerProperties.setPropertyState(CMIOExtensionPropertyState(value: NSData(bytes: magicValue.utf8String,
                                                                           length: magicValue.length + 1)),
                                                forProperty: magicProperty)
        }
        if properties.contains(stateProperty) {
            let stateValue = export().xmlString as NSString
            providerProperties.setPropertyState(CMIOExtensionPropertyState(value: NSData(bytes: stateValue.utf8String,
                                                                                         length: stateValue.length + 1)),
                                                                           forProperty: stateProperty)
        }

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

    func export() -> XMLDocument {
        let facade = XMLElement(name: "facade")
        let apiVersion = XMLElement(name: "apiVersion", stringValue: "v1")
        let devices = XMLElement(name: "devices")

        for source in deviceSources {
            devices.insertChild(source.export(), at: devices.childCount)
        }
        
        facade.insertChild(apiVersion, at: 0)
        facade.insertChild(devices, at: 1)

        return XMLDocument(rootElement: facade)
    }

}
