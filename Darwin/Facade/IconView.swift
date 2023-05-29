//
//  IconView.swift
//  Facade
//
//  Created by Shukant Pal on 5/29/23.
//

import SwiftUI

struct IconView: View {
    var body: some View {
        VStack {
            IconShape()
                .fill(.foreground)
                .aspectRatio(CGSize(width: 844, height: 693), contentMode: .fill)
        }
    }
}

struct IconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        path.move(to: CGPoint(x: 0.85977 * w, y: 0.3394 * h))
        path.addCurve(
            to: CGPoint(x: 0.61583 * w, y: 0.32148 * h),
            control1: CGPoint(x: 0.84869 * w, y: 0.32229 * h),
            control2: CGPoint(x: 0.78788 * w, y: 0.24601 * h))
        path.addCurve(
            to: CGPoint(x: 0.49932 * w, y: 0.37221 * h),
            control1: CGPoint(x: 0.58228 * w, y: 0.34262 * h),
            control2: CGPoint(x: 0.52527 * w, y: 0.37523 * h))
        path.addCurve(
            to: CGPoint(x: 0.38297 * w, y: 0.32148 * h),
            control1: CGPoint(x: 0.47304 * w, y: 0.37502 * h),
            control2: CGPoint(x: 0.41636 * w, y: 0.34262 * h))
        path.addCurve(
            to: CGPoint(x: 0.13887 * w, y: 0.3394 * h),
            control1: CGPoint(x: 0.2111 * w, y: 0.24621 * h),
            control2: CGPoint(x: 0.15028 * w, y: 0.32189 * h))
        path.addCurve(
            to: CGPoint(x: 0.3253 * w, y: 0.68761 * h),
            control1: CGPoint(x: 0.12307 * w, y: 0.52922 * h),
            control2: CGPoint(x: 0.19711 * w, y: 0.79181 * h))
        path.addCurve(
            to: CGPoint(x: 0.41817 * w, y: 0.62098 * h),
            control1: CGPoint(x: 0.35521 * w, y: 0.66345 * h),
            control2: CGPoint(x: 0.38628 * w, y: 0.64091 * h))
        path.addCurve(
            to: CGPoint(x: 0.5803 * w, y: 0.62098 * h),
            control1: CGPoint(x: 0.46974 * w, y: 0.58858 * h),
            control2: CGPoint(x: 0.52874 * w, y: 0.58858 * h))
        path.addCurve(
            to: CGPoint(x: 0.67335 * w, y: 0.68761 * h),
            control1: CGPoint(x: 0.6122 * w, y: 0.64091 * h),
            control2: CGPoint(x: 0.64343 * w, y: 0.66325 * h))
        path.addCurve(
            to: CGPoint(x: 0.85977 * w, y: 0.3394 * h),
            control1: CGPoint(x: 0.79912 * w, y: 0.78986 * h),
            control2: CGPoint(x: 0.87658 * w, y: 0.53945 * h))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.33686 * w, y: 0.561 * h))
        path.addCurve(
            to: CGPoint(x: 0.24018 * w, y: 0.48653 * h),
            control1: CGPoint(x: 0.28332 * w, y: 0.561 * h),
            control2: CGPoint(x: 0.24018 * w, y: 0.48653 * h))
        path.addCurve(
            to: CGPoint(x: 0.33686 * w, y: 0.41186 * h),
            control1: CGPoint(x: 0.24018 * w, y: 0.48653 * h),
            control2: CGPoint(x: 0.28332 * w, y: 0.41186 * h))
        path.addCurve(
            to: CGPoint(x: 0.43354 * w, y: 0.48653 * h),
            control1: CGPoint(x: 0.39025 * w, y: 0.41186 * h),
            control2: CGPoint(x: 0.43354 * w, y: 0.48653 * h))
        path.addCurve(
            to: CGPoint(x: 0.33686 * w, y: 0.561 * h),
            control1: CGPoint(x: 0.43354 * w, y: 0.48653 * h),
            control2: CGPoint(x: 0.39025 * w, y: 0.561 * h))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.66194 * w, y: 0.561 * h))
        path.addCurve(
            to: CGPoint(x: 0.56526 * w, y: 0.48653 * h),
            control1: CGPoint(x: 0.6084 * w, y: 0.561 * h),
            control2: CGPoint(x: 0.56526 * w, y: 0.48653 * h))
        path.addCurve(
            to: CGPoint(x: 0.66194 * w, y: 0.41186 * h),
            control1: CGPoint(x: 0.56526 * w, y: 0.48653 * h),
            control2: CGPoint(x: 0.6084 * w, y: 0.41186 * h))
        path.addCurve(
            to: CGPoint(x: 0.75862 * w, y: 0.48653 * h),
            control1: CGPoint(x: 0.71532 * w, y: 0.41186 * h),
            control2: CGPoint(x: 0.75862 * w, y: 0.48653 * h))
        path.addCurve(
            to: CGPoint(x: 0.66194 * w, y: 0.561 * h),
            control1: CGPoint(x: 0.75862 * w, y: 0.48653 * h),
            control2: CGPoint(x: 0.71532 * w, y: 0.561 * h))
        path.closeSubpath()
        return path
    }
}

struct IconView_Previews: PreviewProvider {
    static var previews: some View {
        IconView()
    }
}
