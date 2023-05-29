//
//  FaceChooserView.swift
//  Facade
//
//  Created by Shukant Pal on 4/29/23.
//

import SwiftUI

struct FaceDownloadProgressArc: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5

        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: 360 * progress - 90)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false)
        path.addLine(to: center)
        path.addLine(to: CGPoint(x: rect.midX, y: 0))

        return path
    }
}

struct FaceDownloadOverlay: View {
    @ObservedObject var faceSwapTarget: FaceSwapTarget

    var body: some View {
        if faceSwapTarget.downloaded {
            EmptyView()
        } else {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 30, height: 30)
                    .opacity(0.67)

                if faceSwapTarget.downloading {
                    FaceDownloadProgressArc(progress: faceSwapTarget.downloadProgress)
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                        .opacity(0.67)
                }

                AnyView(
                    Image(systemName: "arrow.down")
                        .foregroundColor(faceSwapTarget.downloading ? .accentColor : .white)
                        .padding())
            }
        }
    }
}

struct FaceChooserView: View {
    @EnvironmentObject var filter: CameraFilter

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 10) {
                ForEach(filter.availableFaceSwapTargets, id: \.name) { target in
                    Button {
                        if target.downloaded {
                            filter.run(faceSwapTarget: target)
                        } else {
                            target.download()
                        }
                    } label: {
                        VStack {
                            Image(target.name)
                                .frame(width: 86, height: 126)
                                .aspectRatio(contentMode: .fit)
                            Text(target.name)
                        }
                        .overlay(
                            FaceDownloadOverlay(faceSwapTarget: target)
                        )
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 29, trailing: 0))
                    .frame(
                        minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity,
                        alignment: .top
                    )
                    .buttonStyle(.borderless)
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
            .frame(width: 902, height: 400)
    }
}
