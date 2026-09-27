import AppKit

// Draws the app icon (a sheet of paper with a few lines) as a 1024px PNG.
let output = CommandLine.arguments[1]
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185).fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.20, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 250, y: 640, width: 330, height: 56), xRadius: 28, yRadius: 28).fill()

NSColor(calibratedWhite: 0.78, alpha: 1).setFill()
for (index, width) in [524.0, 460, 524, 300].enumerated() {
    let y = 530 - CGFloat(index) * 100
    NSBezierPath(roundedRect: NSRect(x: 250, y: y, width: width, height: 40), xRadius: 20, yRadius: 20).fill()
}
image.unlockFocus()

let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
