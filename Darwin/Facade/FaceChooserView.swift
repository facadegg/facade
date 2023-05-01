//
//  FaceChooserView.swift
//  Facade
//
//  Created by Shukant Pal on 4/29/23.
//

import SwiftUI

struct FaceChooserView: View {
    @EnvironmentObject var filter: CameraFilter
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 10) {
                ForEach(filter.availableFaceSwapTargets, id: \.name) { target in
                    Button {
                        filter.run(faceSwapTarget: target)
                    } label: {
                        VStack {
                            Image(target.name)
                                .frame(width: 86, height: 126)
                                .aspectRatio(contentMode: .fit)
                            Text(target.name)
                        }
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 29, trailing: 0))
                }
            }
            .padding(32)
        }
        .background(.secondary.opacity(0.1))
    }
}

struct FaceChooserView_Previews: PreviewProvider {
    static var previews: some View {
        FaceChooserView()
            .environmentObject(CameraFilter(availableOutputDevices: Devices()))
            .frame(width: 600, height: 200)
    }
}
