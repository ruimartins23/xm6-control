#!/usr/bin/env swift
// Builds an .iconset from the hero photo in Resources, for iconutil to turn into
// AppIcon.icns. Run via Scripts/build_app.sh, which handles the iconutil step.
//
// The photo is expected to have a transparent background. It is trimmed to its
// opaque bounds first, so the headphones fill the icon instead of floating inside
// whatever margin the original image happened to have.

import AppKit

let resources = "Sources/XM6Control/Resources"
let photoPath = "\(resources)/headphones.png"
let outputSet = ".build/AppIcon.iconset"

guard let photo = NSImage(contentsOfFile: photoPath),
      let cg = photo.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("no photo at \(photoPath)\n".data(using: .utf8)!)
    exit(1)
}

// MARK: - Trim to opaque bounds

let width = cg.width
let height = cg.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

var minX = width, minY = height, maxX = -1, maxY = -1
for y in 0..<height {
    for x in 0..<width {
        // Ignore near-transparent edge pixels so antialiasing doesn't defeat the trim.
        if pixels[(y * width + x) * 4 + 3] > 12 {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
}
guard maxX >= minX, maxY >= minY else {
    FileHandle.standardError.write("photo is fully transparent\n".data(using: .utf8)!)
    exit(1)
}

// CGImage cropping is in the image's own top-left coordinate space, which matches
// the buffer we just scanned.
let cropped = cg.cropping(to: CGRect(
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1
))!

// MARK: - Render each size

/// Fraction of the canvas the artwork occupies. macOS app icons leave a margin;
/// filling the square edge to edge makes the icon look oversized next to others.
let inset: CGFloat = 0.86

// Drawn through an explicit CGContext rather than NSImage.lockFocus: on a Retina
// display lockFocus renders at the screen's 2x backing scale, so every slice came
// out twice the size iconutil was told it was.
func render(side: Int) -> Data {
    let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high

    let box = CGFloat(side) * inset
    let scale = min(box / CGFloat(cropped.width), box / CGFloat(cropped.height))
    let drawWidth = CGFloat(cropped.width) * scale
    let drawHeight = CGFloat(cropped.height) * scale
    context.draw(cropped, in: CGRect(
        x: (CGFloat(side) - drawWidth) / 2,
        y: (CGFloat(side) - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
    ))

    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.removeItem(atPath: outputSet)
try FileManager.default.createDirectory(atPath: outputSet, withIntermediateDirectories: true)

// The set of names and sizes iconutil expects for a complete icon.
let variants: [(name: String, side: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    try render(side: variant.side).write(to: URL(fileURLWithPath: "\(outputSet)/\(variant.name).png"))
}

print("==> Icon set written from headphones.png (trimmed \(width)x\(height) to \(cropped.width)x\(cropped.height))")
