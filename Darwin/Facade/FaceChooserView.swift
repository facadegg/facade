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

private struct FaceTextAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context.height * 1.2
    }
}

struct FaceChooserView: View {
    @EnvironmentObject var filter: CameraFilter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Faces")
                    .foregroundStyle(.secondary)
                    .fontWeight(.bold)
                    .padding(EdgeInsets(top: 0, leading: 2, bottom: 8, trailing: 0))

                LazyVGrid(
                    columns: [GridItem(.fixed(86), spacing: 18), GridItem(.fixed(86))], spacing: 18
                ) {
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
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 86, height: 126)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(FaceDownloadOverlay(faceSwapTarget: target))
                                    .overlay(alignment: .bottom) {
                                        LinearGradient(
                                            gradient: Gradient(colors: [.black, .black, .clear]),
                                            startPoint: .bottom, endPoint: .top
                                        )
                                        .frame(width: 86, height: target.name.count > 10 ? 48 : 32)
                                        .mask(
                                            UnevenRoundedRectangle(
                                                cornerRadii: .init(
                                                    bottomLeading: 8, bottomTrailing: 8)
                                            )
                                            .fill(.black.opacity(0.67))
                                        )
                                    }
                                    .overlay(alignment: .bottom) {
                                        Text(target.name)
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 86, maxWidth: 86)
                                            .padding(4)
                                    }
                            }
                            .frame(
                                minWidth: 0, maxWidth: .infinity, minHeight: 0,
                                maxHeight: .infinity,
                                alignment: .top
                            )
                        }
                        .frame(
                            minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity,
                            alignment: .top
                        )
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
        }
    }
}

struct FaceChooserView_Previews: PreviewProvider {
    static var previews: some View {
        FaceChooserView()
            .environmentObject(CameraFilter(availableOutputDevices: Devices(installed: false)))
            .frame(width: 228, height: 600)
            .previewLayout(.fixed(width: 228, height: 600))
            .toolbar {
                Color.clear
            }
    }
}
