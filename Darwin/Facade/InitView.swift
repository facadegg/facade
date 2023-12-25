//
//  InitView.swift
//  Facade
//
//  Created by Shukant Pal on 12/25/23.
//

import Foundation
import SwiftUI

struct InitView: View {
    let isWaitingOnCamera: Bool
    
    var body: some View {
        VStack(alignment: .center) {
            IconView()
                .frame(maxWidth: 96, maxHeight: 48)
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text(isWaitingOnCamera ? "One more moment..." : "Bringing out the Facade...")
                .padding()
            Spacer()
        }
        .padding(48)
        .frame(width: 360, height: 320)
    }
}
