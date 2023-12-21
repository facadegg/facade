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
        view.message +=
            "Oops! It seems like you have an old version of Facade installed. Please remove that and try again."
        view.error = true
        return OSSystemExtensionRequest.ReplacementAction.cancel
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        view.message =
            "Facade needs your permission to install system software.\n\nIn System Settings > Privacy & Security > Security, unblock Facade from loading system software."
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        view.message = "Oops! \(error.localizedDescription)."
        view.error = true
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        view.message =
            "The system software has been installed. Please close this window and restart Facade to continue."
        view.error = false

        self.view.devices.needsRestart = true
    }
}

struct SetupView: View {
    @EnvironmentObject var devices: Devices
    @State var delegate: SetupDelegate?
    @State var error = false
    @State var message =
        "Thanks for trying out Facade!\n\nFacade is a programmable virtual camera for macOS. Please continue to install its system software."

    var body: some View {
        VStack {
            IconView()
                .frame(maxWidth: 96, maxHeight: 48)
                .padding(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 0))
            Text("Get Started")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            Text(message)
                .foregroundColor(error ? Color.red : Color.primary)
                .padding(EdgeInsets(top: 0, leading: 24, bottom: 16, trailing: 24))
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: { [self] in
                if self.devices.needsRestart {
                    NSApplication.shared.terminate(nil)
                } else {
                    OSSystemExtensionManager.shared.submitRequest(newRequest())
                }
            }) {
                Text(self.devices.needsRestart ? "Close" : self.error ? "Try again" : "Install")
            }
            .buttonStyle(.borderedProminent)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))
        }
        .frame(width: 360, height: 320)
        .padding(8)
    }

    func newRequest() -> OSSystemExtensionRequest {
        let identifier = "gg.facade.Facade.Camera"
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
            .environmentObject(Devices(installed: false))
            .presentedWindowStyle(.hiddenTitleBar)
    }
}
