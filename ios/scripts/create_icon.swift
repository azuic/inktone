import AppKit

// Four ink strokes on dotted sketch paper. iOS applies its own outer mask.
// Use an explicit opaque bitmap so output stays exactly 1024 pixels on Retina Macs.
let side = 1024
// AppKit needs a four-channel drawing surface. Flatten to opaque RGB for export.
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create the icon drawing context")
}
NSGraphicsContext.current = context
let referenceSide: CGFloat = 614
let scale = CGFloat(side) / referenceSide

func fill(_ rect: CGRect, rgb: UInt32, radius: CGFloat = 0) {
    NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
            green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: 1).setFill()
    let target = CGRect(x: rect.minX * scale, y: (referenceSide - rect.maxY) * scale,
                        width: rect.width * scale, height: rect.height * scale)
    NSBezierPath(roundedRect: target, xRadius: radius * scale, yRadius: radius * scale).fill()
}

fill(CGRect(x: 0, y: 0, width: referenceSide, height: referenceSide), rgb: 0xf4f5f7)
for row in 0..<18 {
    for column in 0..<17 {
        fill(CGRect(x: 18.5 + CGFloat(column) * 36, y: 15.5 + CGFloat(row) * 34.1,
                    width: 3, height: 3), rgb: 0xc4c8cf, radius: 0.25)
    }
}

// Square the sketch by extending the paper and centering the strokes as a group.
// Keep the original unequal lengths and the darker overprinted intersections.
let pink = CGRect(x: 188, y: 109, width: 24, height: 360)
let blue = CGRect(x: 333, y: 123, width: 24, height: 381)
let yellow = CGRect(x: 94, y: 221.5, width: 438, height: 23)
let orange = CGRect(x: 83, y: 350, width: 397, height: 23)
fill(pink, rgb: 0xe75aa0, radius: 12)
fill(blue, rgb: 0x3ca8da, radius: 12)
fill(yellow, rgb: 0xeabf20, radius: 11.5)
fill(orange, rgb: 0xe8633a, radius: 11.5)
fill(pink.intersection(yellow), rgb: 0xdd4514)
fill(blue.intersection(yellow), rgb: 0x39831c)
fill(pink.intersection(orange), rgb: 0xdc2425)
fill(blue.intersection(orange), rgb: 0x3a4433)
NSGraphicsContext.restoreGraphicsState()
let opaque = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                              bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
let source = bitmap.bitmapData!
let destination = opaque.bitmapData!
for y in 0..<side {
    for x in 0..<side {
        let input = y * bitmap.bytesPerRow + x * 4
        let output = y * opaque.bytesPerRow + x * 3
        destination[output] = source[input]
        destination[output + 1] = source[input + 1]
        destination[output + 2] = source[input + 2]
    }
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try opaque.representation(using: .png, properties: [:])!.write(to: output)
