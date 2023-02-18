//
//  GeneralSettingsView.swift
//  Facade
//
//  Created by Shukant Pal on 1/22/23.
//  Copyright © 2023 Paal Maxima. All rights reserved.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("virtualizeCamera")
    private var virtualizeCamera = false
    @AppStorage("virtualizeMicrophone")
    private var virtualizeMicrophone = false
    @AppStorage("virtualizeSpeaker")
    private var virtualizeSpeaker = false
    @AppStorage("requireSocketAuthorization")
    private var requireSocketAuthorization = true
    
    var body: some View {
        Form {
            LabeledContent("Virtualization: ") {
                VStack(alignment: HorizontalAlignment.leading) {
                    Toggle("Camera", isOn: $virtualizeCamera)
                    Toggle("Microphone (coming soon)",
                           isOn: $virtualizeMicrophone).disabled(true)
                    
                    Toggle("Speaker (coming soon)", isOn: $virtualizeSpeaker)
                        .disabled(true)
                    Button(action: {
                        
                    }) {
                        Text("Enable all")
                    }
                }
            }
            LabeledContent("Security: ") {
                VStack(alignment: HorizontalAlignment.leading) {
                    Toggle("Require socket authorization", isOn: $requireSocketAuthorization)
                }
            }
        }
    }
}
