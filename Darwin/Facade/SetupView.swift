//
//  SetupView.swift
//  Facade
//
//  Created by Shukant Pal on 1/29/23.
//

import Foundation
import SwiftUI
import SystemExtensions

class SetupDelegate: NSObject, OSSystemExtensionRequestDelegate {
    var view: SetupView

    init(view: SetupView) {
        self.view = view
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        view.message += "Facade is already installed. Please uninstall it first."
        view.error = true
        return OSSystemExtensionRequest.ReplacementAction.cancel
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        view.message = "Please allow System Extension in Settings > Privacy & Security"
        view.error = true
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        view.message = error.localizedDescription
        view.error = true
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        view.message = "Awesome, now you can create virtual devices in Facade!"
        view.error = false
        view.devices.checkInstall()
    }
}

struct SetupView: View {
    @EnvironmentObject var devices: Devices
    @State var delegate: SetupDelegate?
    @State var error = false
    @State var message = "Facade needs permission to create virtual devices"

    var body: some View {
        VStack {
            Button(action: { [self] in
                OSSystemExtensionManager.shared.submitRequest(newRequest())
            }) {
                Text("Install System Extension")
            }

            Text(message)
                .foregroundColor(error ? Color.red : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
    }

    func newRequest() -> OSSystemExtensionRequest {
        let identifier = "video.facade.Facade.Camera"
        let activationRequest = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: identifier, queue: .main)

        if delegate == nil {
            delegate = SetupDelegate(view: self)
        }

        activationRequest.delegate = delegate

        return activationRequest
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView()
    }
}
