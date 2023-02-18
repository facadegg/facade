//
//  DevicesView.swift
//  Facade
//
//  Created by Shukant Pal on 1/22/23.
//  Copyright © 2023 Paal Maxima. All rights reserved.
//

import SwiftUI

struct DevicesView: View {
    @State private var devices: Array<String> = [
    ]
    @State private var columnVisibility: NavigationSplitViewVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationView {
                VStack {
                    List {
                        Text("Cameras")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ForEach(devices, id: \.self) { wk in
                            Text(wk)
                        }
                    }
                    Spacer()
                    HStack {
                        Button(action: {
                            
                        }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            
                        }) {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .padding(8)
                }
            }
        } detail: {
            VStack {
                Form {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "circle.square")
                                .resizable(capInsets: EdgeInsets(), resizingMode: .stretch)
                                .frame(width: 50, height: 50)
                        }
                        
                        Text("Facade Camera")
                            .fontWeight(.bold)
                        
                        LabeledContent("Dimensions") {
                            Menu("1920 x 1080") {
                                Button("1920 x 1080", action: {})
                                Button("1280 x 720", action: {})
                                Button("800 x 600", action: {})
                            }
                            .frame(width: 120)
                        }
                    }
                }
                .padding(20)
                
                Spacer()
                
                SetupView()
            }
            .frame(maxWidth: .infinity)
            .padding(0)
        }
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
    }
}
