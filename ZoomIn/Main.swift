import Metal
import MetalKit
import CoreGraphics
import Foundation

let width = 6000
let height = 6000
let folder = "frames"
let frames = 300
let zoom = Float(3.0)
let factor = Float(0.97)
let iters: Int32 = 50334500
let limit: Int32 = 100303
let count = 1

struct JP {
    var coef: SIMD2<Float>
    var iter: Int32
    var intensity: Float
    var width: Int32
    var height: Int32
    var zcen: SIMD2<Float>
    var scale: Float
}

func lib(dev: MTLDevice) -> MTLLibrary {
    let url = URL(fileURLWithPath: "julia.metal")
    let code = try! String(contentsOf: url, encoding: .utf8)
    let opt = MTLCompileOptions()
    opt.mathMode = .fast
    opt.languageVersion = .version3_0
    return try! dev.makeLibrary(source: code, options: opt)
}

func texs(dev: MTLDevice, n: Int) -> [MTLTexture] {
    let desc = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: width,
        height: height,
        mipmapped: false
    )
    desc.usage = [.shaderWrite, .shaderRead]
    return (0..<n).compactMap { _ in dev.makeTexture(descriptor: desc) }
}

func save(_ tex: MTLTexture, url: URL) {
    let region = MTLRegionMake2D(0, 0, tex.width, tex.height)
    let bpr = 4 * tex.width
    var data = [UInt8](repeating: 0, count: bpr * tex.height)
    tex.getBytes(&data, bytesPerRow: bpr, from: region, mipmapLevel: 0)
    
    squeue.async {
        let ctx = CGContext(data: &data,
                            width: width,
                            height: height,
                            bitsPerComponent: 8,
                            bytesPerRow: bpr,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let img = ctx.makeImage()!
        let rep = NSBitmapImageRep(cgImage: img)
        rep.size = NSSize(width: width, height: height)
        let png = rep.representation(using: .png, properties: [:])!
        try! png.write(to: url)
    }
}

let squeue = DispatchQueue(label: "com.julia.saving", qos: .userInitiated, attributes: .concurrent)
let sync = DispatchSemaphore(value: count)

let dev = MTLCreateSystemDefaultDevice()!
let mtllib = lib(dev: dev)
let initfn = mtllib.makeFunction(name: "initKernel")!
let renderfn = mtllib.makeFunction(name: "renderKernel")!

let initps = try! dev.makeComputePipelineState(function: initfn)
let renderps = try! dev.makeComputePipelineState(function: renderfn)

let cmdqueue = dev.makeCommandQueue()!
var textures = texs(dev: dev, n: count)

let parbuf = dev.makeBuffer(length: MemoryLayout<JP>.stride, options: .storageModeShared)!

let group = MTLSize(width: 32, height: 32, depth: 1)
let grid = MTLSize(
    width: (width + 31) / 32,
    height: (height + 31) / 32,
    depth: 1
)

let itersize = width * height * MemoryLayout<Int32>.stride
let iterbuf = dev.makeBuffer(length: itersize, options: .storageModeShared)!

var initparam = JP(
    coef: SIMD2<Float>(-0.8, 0.156),
    iter: iters,
    intensity: 1.0,
    width: Int32(width),
    height: Int32(height),
    zcen: SIMD2<Float>(0.0, 0.0),
    scale: zoom
)

let cmdinit = cmdqueue.makeCommandBuffer()!
let encinit = cmdinit.makeComputeCommandEncoder()!
encinit.setComputePipelineState(initps)
encinit.setTexture(textures[0], index: 0)
encinit.setBuffer(iterbuf, offset: 0, index: 1)

let initbuf = dev.makeBuffer(bytes: &initparam, length: MemoryLayout<JP>.stride, options: [])!
encinit.setBuffer(initbuf, offset: 0, index: 0)
encinit.dispatchThreadgroups(grid, threadsPerThreadgroup: group)
encinit.endEncoding()
cmdinit.commit()
cmdinit.waitUntilCompleted()

let iterptr = iterbuf.contents().bindMemory(to: Int32.self, capacity: width * height)
let iterarr = Array(UnsafeBufferPointer(start: iterptr, count: width * height))

let maxval = iterarr.max()!
let maxidx = iterarr.firstIndex(of: maxval)!
let xpos = maxidx % width
let ypos = maxidx / width
let xcen = initparam.zcen.x + (Float(xpos) / Float(width) * 2 - 1) * zoom
let ycen = initparam.zcen.y + (Float(ypos) / Float(height) * 2 - 1) * zoom
let zcen = SIMD2<Float>(xcen, ycen)
print("Computed optimal zoom center: \(zcen)")

try! FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

let start = Date()

for frame in 0..<frames {
    sync.wait()
    
    let texindex = frame % count
    let tex = textures[texindex]
    let url = URL(fileURLWithPath: "\(folder)/frame_\(String(format: "%05d", frame)).png")
    
    let curzoom = zoom * pow(factor, Float(frame))
    let logs = log(1 + Float(frame) / 100)
    let iterval = min(Float(limit), Float(iters) * (1 + logs))
    
    var param = JP(
        coef: SIMD2<Float>(-0.8, 0.156),
        iter: Int32(iterval),
        intensity: 1.0 - (Float(frame) / Float(frames)) * 0.5,
        width: Int32(width),
        height: Int32(height),
        zcen: zcen,
        scale: curzoom
    )
    
    parbuf.contents().copyMemory(from: &param, byteCount: MemoryLayout<JP>.stride)
    
    let cmd = cmdqueue.makeCommandBuffer()!
    let enc = cmd.makeComputeCommandEncoder()!
    enc.setComputePipelineState(renderps)
    enc.setTexture(tex, index: 0)
    enc.setBuffer(parbuf, offset: 0, index: 0)
    enc.dispatchThreadgroups(grid, threadsPerThreadgroup: group)
    enc.endEncoding()
    
    cmd.addCompletedHandler { _ in
        save(tex, url: url)
        sync.signal()
    }
    
    cmd.commit()
    print("born to life frame #\(frame + 1)/\(frames) [Zoom: \(zoom / curzoom)x]")
}

for _ in 0..<count {
    sync.wait()
    sync.signal()
}

let end = Date()
let elapsed = end.timeIntervalSince(start)
print("DONE MF directory: \(folder)")
print("Total time: \(elapsed)")
