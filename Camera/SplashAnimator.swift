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
    private let _context: CGContext

    private let _cellDiameter: Int
    private let _cellRows: Int
    private let _cellColumns: Int
    private let _paddingX: Int
    private let _paddingY: Int

    private var _t: Double // from 0 to 2

    init(width: Int, height: Int) {
        _context = CGContext(data: nil,
                             width: width,
                             height: height,
                             bitsPerComponent: 8,
                             bytesPerRow: width * 4,
                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        _cellDiameter = max(width, height) > 720 ? 96 : 48
        _cellRows = height / _cellDiameter
        _cellColumns = width / _cellDiameter
        _paddingX = (width - _cellColumns * _cellDiameter) / 2
        _paddingY = (height - _cellRows * _cellDiameter) / 2

        _t = 0
    }

    func nextFrame() -> UnsafeMutableRawPointer? {
        _t = (_t + 0.005).truncatingRemainder(dividingBy: 2)

        _context.clear(CGRect(x: 0, y: 0, width: _context.width, height: _context.height))
        _context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)

        let lerp = abs(_t - 1.0)
        let cubicLerp = lerp * lerp * (3.0 - 2.0 * lerp)
        let gravityX = Double(_context.width) * cubicLerp
        let gravityY = Double(_context.height) / 2.0
        let gravityRange = Double(min(_context.width, _context.height)) / 2.0

        for row in 0..<_cellRows {
            for column in 0..<_cellColumns {
                let x = Double(_paddingX + column * _cellDiameter)
                let y = Double(_paddingY + row * _cellDiameter)
                let distanceSquared = pow(gravityX - CGFloat(x), 2) + pow(gravityY - CGFloat(y), 2)
                let dotDiameterLerp = Double(distanceSquared) / pow(gravityRange, 2)
                let dotDiameterLerpClamped = max(min(dotDiameterLerp, 1), 0)
                let dotDiameter = 3.0 * Double(_cellDiameter) / 4.0 -
                            1.0 * dotDiameterLerpClamped * Double(_cellDiameter) / 4.0 // b/w 1/2 and 3/4th of cell diameter
                let dotPadding = (Double(_cellDiameter) - dotDiameter) / Double(2)

                _context.fillEllipse(in: CGRect(x: x + dotPadding,
                                                y: y + dotPadding,
                                                width: dotDiameter,
                                                height: dotDiameter))
            }
        }

        return _context.data
    }
}
