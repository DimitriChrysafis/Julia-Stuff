#include <metal_stdlib>
using namespace metal;

struct JPr {
    float2 c;
    int mxi;
    float cli;
    int wid;
    int hgt;
    int ofx;
    int ofy;
};

kernel void juliaSetKernel(
    texture2d<float, access::write> out [[texture(0)]],
    constant JPr &prm [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Map pixel coordinates to the complex plane (range: [-2, 2])
    float x = ((float(gid.x + prm.ofx) / float(prm.wid)) * 4.0) - 2.0;
    float y = ((float(gid.y + prm.ofy) / float(prm.hgt)) * 4.0) - 2.0;
    
    float2 z = float2(x, y);
    int itr = 0;
    
    // iterate until we either exceed the max iterations or the magnitude escapes
    while (itr < prm.mxi && length(z) < 2.0) {
        z = float2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + prm.c;
        itr++;
    }
    
    // normalize iteration count and compute RGB values using sine functions for color snot
    float nrm = float(itr) / float(prm.mxi);
    float r = clamp(2.5 * abs(sin(nrm * 6.28318 * 3.0)), 0.0, 1.0);
    float g = clamp(2.5 * abs(sin(nrm * 6.28318 * 5.0)), 0.0, 1.0);
    float b = clamp(2.5 * abs(sin(nrm * 6.28318 * 7.0)), 0.0, 1.0);
    
    float4 col = float4(clamp(r, 0.0, 1.0),
                        clamp(g, 0.0, 1.0),
                        clamp(b, 0.0, 1.0),
                        1.0);
    
    out.write(col, gid);
}
