//
//  FacadeApp.swift
//  Facade
//
//  Created by Shukant Pal on 1/22/23.
//  Copyright © 2023 Paal Maxima. All rights reserved.
//

import SwiftUI

@main
struct FacadeApp: App {
    @StateObject var devices: Devices = Devices()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(devices)
        }
        .windowResizability(WindowResizability.contentSize)
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
