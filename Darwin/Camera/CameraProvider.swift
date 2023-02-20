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
    private let logger: Logger
    
    init(clientQueue: DispatchQueue?) {
        self.logger = Logger(subsystem: "com.paalmaxima.Facade.Camera", category: "CameraProviderSource")
        
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
        if let state = providerProperties.propertiesDictionary[stateProperty] {
            if let stateData = state.value as? NSData {
                logger.debug("Importing state from client")
                let str = String(data: stateData as Data, encoding: .utf8)
                logger.debug("\(str!, privacy: .public)")
                
                do {
                    importFromXML(try XMLDocument(data: stateData.subdata(with: NSRange(location: 0, length: stateData.length - 1)) as Data))
                } catch {
                    logger.error("Failed parsing XML from state: \(error)")
                }
            } else {
                logger.error("Failed to extract data from state")
            }

            do {
                let changedProperties = try self.providerProperties(forProperties: [stateProperty])
                self.provider.notifyPropertiesChanged(changedProperties.propertiesDictionary)
                logger.info("notified property changed")
            } catch {
                logger.error("CameraProviderSource: notifyPropertiesChanged threw an error")
            }
        }
    }
    
    func createDevice(localizedName: String = "Facade") -> CameraDeviceSource {
        logger.debug("Creating device '\(localizedName, privacy: .public)'")
        
        let deviceSource = CameraDeviceSource(localizedName: localizedName)
        
        do {
            try provider.addDevice(deviceSource.device)
        } catch let error {
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
        
        deviceSources.insert(deviceSource)
        
        return deviceSource
    }
    
    func destroyDevice(deviceSource: CameraDeviceSource) {
        logger.debug("Destroying device '\(deviceSource.device.localizedName)'")
        
        do {
            try provider.removeDevice(deviceSource.device)
        } catch let error {
            fatalError("Failed to remove device: \(error.localizedDescription)")
        }
        
        deviceSources.remove(deviceSource)
    }
    
    func importFromXML(_ document: XMLDocument) {
        guard let facade = document.rootElement() else { return }
        guard let facadeName = facade.name, facadeName == "facade" else {
            logger.warning("importFromXML: <facade> not found at document root")
            return
        }
        
        let apiVersions = facade.elements(forName: "apiVersion")
        guard apiVersions.count == 1 else {
            logger.warning("importFromXML: <apiVersion> declaration is not present or is duplicated")
            return
        }
        guard let apiVersion = apiVersions[0].stringValue else {
            logger.warning("importFromXML: <apiVersion> does not contain a valid version string")
            return
        }
        guard apiVersion == "v1" else {
            logger.warning("importFromXML: \(apiVersion) specified in <apiVersion> is not supported")
            return
        }
        
        let deviceLists = facade.elements(forName: "devices")
        guard deviceLists.count == 1 else {
            logger.warning("importFromXML: <devices> must be present exactly once")
            return
        }
        
        let devices = deviceLists[0]
        let videos = devices.elements(forName: "video")
        var videosDeleted: Set<CameraDeviceSource> = Set(deviceSources)
        
        guard videos.count <= 4 else {
            logger.warning("importFromXML: <devices> can have a maximum of 4 videos devices")
            return
        }
        
        for (videoIndex, video) in videos.enumerated() {
            let id = video.elements(forName: "id")
            let name = video.elements(forName: "name")
            let width = video.elements(forName: "width")
            let height = video.elements(forName: "height")
            let frameRate = video.elements(forName: "frameRate")
            
            guard id.count <= 1 && name.count <= 1 &&
                    width.count <= 1 && height.count <= 1 && frameRate.count <= 1 else {
                logger.warning("importFromXML: Malformed <device> at index \(videoIndex)")
                continue
            }
            guard name.count == 1 && width.count == 1 &&
                    height.count == 1 && frameRate.count == 1 else {
                logger.warning("importFromXML: Missing name, width, height, or frameRate at <video> \(videoIndex)")
                continue
            }
            
            guard let nameValue = name[0].stringValue,
                  let widthValue = UInt32(width[0].stringValue ?? ""),
                  let heightValue = UInt32(height[0].stringValue ?? ""),
                  let frameRateValue = UInt32(frameRate[0].stringValue ?? "") else {
                logger.warning("importFromXML: Missing property values at <video> \(videoIndex)")
                continue
            }
            
            guard widthValue >= 16 && widthValue <= 8192 else {
                logger.warning("importFromXML: <width> out of bounds [16ox, 8192px] at <video> \(videoIndex)")
                continue
            }
            guard heightValue >= 16 && heightValue <= 8192 else {
                logger.warning("importFromXML: <height> out of bounds [16px, 8192px] at <video> \(videoIndex)")
                continue
            }
            guard frameRateValue >= 10 && frameRateValue <= 120 else {
                logger.warning("importFromXML: <frameRate> out of bounds [10FPS, 120FPS] at <video> \(videoIndex)")
                continue
            }
            
            let idValue = id.count == 1 ? id[0].stringValue : nil
            
            if let idValue = idValue {
                guard let modifiedDevice = deviceSources.first(where: {
                    $0.device.deviceID.uuidString == idValue
                }) else {
                    logger.warning("importFromXML: Unknown device identifier \(idValue)")
                    continue
                }
                
                // Note: We cannot modify the localizedName of the device.
                
                if widthValue != modifiedDevice.width ||
                    heightValue != modifiedDevice.height ||
                    frameRateValue != modifiedDevice.frameRate {
                    modifiedDevice.setDeviceFormat(width: widthValue,
                                                   height: heightValue,
                                                   frameRate: frameRateValue)
                }
                
                videosDeleted.remove(modifiedDevice)
            } else {
                let createdDevice = createDevice(localizedName: nameValue)
                createdDevice.setDeviceFormat(width: widthValue,
                                              height: heightValue,
                                              frameRate: frameRateValue)
            }
        }
        
        for video in videosDeleted {
            destroyDevice(deviceSource: video)
        }
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
