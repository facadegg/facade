//
//  DefaultStream.swift
//  Camera
//
//  Created by Shukant Pal on 1/29/23.
//

import CoreGraphics
import CoreText
import Foundation

class SplashAnimator {
    private let context: CGContext

    private let cellDiameter: Int
    private let cellRows: Int
    private let cellColumns: Int
    private let paddingX: Int
    private let paddingY: Int

    private var t: Double  // from 0 to 2

    init(width: Int, height: Int) {
        context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

        cellDiameter = max(width, height) > 720 ? 96 : 48
        cellRows = height / cellDiameter
        cellColumns = width / cellDiameter
        paddingX = (width - cellColumns * cellDiameter) / 2
        paddingY = (height - cellRows * cellDiameter) / 2

        t = 0
    }

    func nextFrame() -> UnsafeMutableRawPointer? {
        t = (t + 0.005).truncatingRemainder(dividingBy: 2)

        context.clear(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)

        let lerp = abs(t - 1.0)
        let cubicLerp = lerp * lerp * (3.0 - 2.0 * lerp)
        let gravityX = Double(context.width) * cubicLerp
        let gravityY = Double(context.height) / 2.0
        let gravityRange = Double(min(context.width, context.height)) / 2.0

        for row in 0..<cellRows {
            for column in 0..<cellColumns {
                let x = Double(paddingX + column * cellDiameter)
                let y = Double(paddingY + row * cellDiameter)
                let distanceSquared = pow(gravityX - CGFloat(x), 2) + pow(gravityY - CGFloat(y), 2)
                let dotDiameterLerp = Double(distanceSquared) / pow(gravityRange, 2)
                let dotDiameterLerpClamped = max(min(dotDiameterLerp, 1), 0)
                let dotDiameter =
                    3.0 * Double(cellDiameter) / 4.0 - 1.0 * dotDiameterLerpClamped
                    * Double(cellDiameter)
                    / 4.0  // b/w 1/2 and 3/4th of cell diameter
                let dotPadding = (Double(cellDiameter) - dotDiameter) / Double(2)

                context.fillEllipse(
                    in: CGRect(
                        x: x + dotPadding,
                        y: y + dotPadding,
                        width: dotDiameter,
                        height: dotDiameter))
            }
        }

        return context.data
    }
}
