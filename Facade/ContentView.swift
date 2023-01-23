//
//  ContentView.swift
//  Facade
//
//  Created by Shukant Pal on 1/22/23.
//  Copyright © 2023 Paal Maxima. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem({
                    Label("General", systemImage: "gear")
                }).tag(0)
            
            DevicesView()
                .tabItem({
                    Label("Devices", image: "default")
                })
        }
        .padding(20)
        .frame(width: 500, height: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
