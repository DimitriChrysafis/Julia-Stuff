import Metal
import MetalKit
import CoreGraphics
import Foundation



/*
 THIS IS MEANT TO CUZ U CANT  RENDER A FULL IMAGE OF 20000 by 20000 IN SWIFT IT SEGMENTS IT THEN U USE SOME OTHER  TO COMBINE IT.
 
 These magic numbers define our tile size,
 image dimensions
*/
let TSZ = 5000
let WDT = 20000
let HGT = 20000
let OUT = "Julia"

/*
I know, more boilerplate—just roll with it.
*/
struct JPr {
    var c: SIMD2<Float>
    var mxi: Int32
    var cli: Float       // Some client value (not really used, but here for kicks)
    var wid: Int32
    var hgt: Int32
    var ofx: Int32
    var ofy: Int32       // Y offset for the current tile
}

/*

 I stole this from stack overflow. This will try to create one
 if it doesn’t exist. Seriously, file management is fun, right?
*/
let fil = FileManager.default
try? fil.createDirectory(atPath: OUT, withIntermediateDirectories: true)


/*
 

 It’s a bridge between Metal and CoreGraphics. Womp womp
*/
func savTex(_ tex: MTLTexture, to fnm: String) {
    let url = URL(fileURLWithPath: OUT).appendingPathComponent(fnm)
    let region = MTLRegionMake2D(0, 0, tex.width, tex.height)
    let bytesPerRow = 4 * tex.width
    var data = [UInt8](repeating: 0, count: bytesPerRow * tex.height)
    
    tex.getBytes(&data, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
    
    // RAW TEXTTURE DATA RAHHH
    guard let context = CGContext(data: &data,
                                  width: tex.width,
                                  height: tex.height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo.rawValue) else {
        return
    }
    
    guard let cgImage = context.makeImage() else { return }
    
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: tex.width, height: tex.height))
    
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData) else {
        return
    }
    
    let pngData = bitmapRep.representation(using: .png, properties: [:])
    try? pngData?.write(to: url)
}



let dev = MTLCreateSystemDefaultDevice()!
let lib = try! dev.makeLibrary(source: mco, options: nil)
guard let fun = lib.makeFunction(name: "juliaSetKernel") else {
    fatalError("Couldn't find the 'juliaSetKernel' function.")
}

/*

PROCCESSS THE WHOLE THING
*/
for ty in stride(from: 0, to: HGT, by: TSZ) {
    for tx in stride(from: 0, to: WDT, by: TSZ) {
        let w = min(TSZ, WDT - tx)
        let h = min(TSZ, HGT - ty)
        

        let tds = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                           width: w,
                                                           height: h,
                                                           mipmapped: false)
        tds.usage = [.shaderWrite, .shaderRead]
        guard let tex = dev.makeTexture(descriptor: tds) else {
            fatalError("kys")
        }
        
        // Set up the parameters for our Julia set computation
        let prm = JPr(
            c: SIMD2<Float>(-0.8, 0.156), // Julia constant (because why not?)
            mxi: 10000,                   // Maximum iterations (try not to overdo it)
            cli: 1.0,
            wid: Int32(WDT),
            hgt: Int32(HGT),
            ofx: Int32(tx),
            ofy: Int32(ty)
        )
        
    // the rest of the code is just gpu garbage
        let buf = cmd.makeCommandBuffer()!
        let enc = buf.makeComputeCommandEncoder()!
        
        enc.setComputePipelineState(pip)
        enc.setTexture(tex, index: 0)
        
        let pbf = dev.makeBuffer(bytes: [prm],
                                  length: MemoryLayout<JPr>.stride,
                                  options: [])!
        enc.setBuffer(pbf, offset: 0, index: 0)
        
        let tpg = MTLSize(width: w, height: h, depth: 1)
        let ttg = MTLSize(width: 16, height: 16, depth: 1)
        enc.dispatchThreads(tpg, threadsPerThreadgroup: ttg)
        
        enc.endEncoding()
        buf.commit()
        buf.waitUntilCompleted()
        
        let fnm = "tile_\(tx)_\(ty).png"
        savTex(tex, to: fnm)
    }
}
