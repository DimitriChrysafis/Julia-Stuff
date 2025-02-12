// i ran this through an obfuscator lol. it sucks
#include <metal_stdlib>
using namespace metal;
constant float E=4.0; constant float S=0.3; constant float3 F=float3(25.0,30.0,35.0); constant float3 O=float3(0.7,0.5,0.9);
struct J{float2 a; int b; float c; int d; int e; float2 f; float g;};
kernel void i(texture2d<float,access::write> o, device int *b, constant J &j, uint2 t){
float x = j.f.x+(((float(t.x)/float(j.d))*2.0-1.0)*j.g); float y = j.f.y+(((float(t.y)/float(j.e))*2.0-1.0)*j.g); float2 z = float2(x,y); int n = 0;
while(n<j.b && dot(z,z)<E){ z = float2(z.x*z.x-z.y*z.y,2.0*z.x*z.y)+j.a; n++; }
b[t.y*j.d+t.x] = n; float u = (n==j.b?0.0:log(float(n))/log(float(j.b)));
float r = 0.5+0.5*cos(3.0+u*F.x+O.x*sin(u*15.0)); float g = 0.5+0.5*sin(2.0+u*F.y+O.y*cos(u*22.0)); float p = 0.5+0.5*cos(1.0+u*F.z+O.z*sin(u*30.0));
o.write(float4(r,g,p,1.0)*j.c,t);
}
kernel void r(texture2d<float,access::write> o, constant J &j, uint2 t){
float x = j.f.x+(((float(t.x)/float(j.d))*2.0-1.0)*j.g); float y = j.f.y+(((float(t.y)/float(j.e))*2.0-1.0)*j.g); float2 z = float2(x,y); int n = 0; float a, b;
while(n<j.b){ a = z.x*z.x; b = z.y*z.y; if(a+b>E) break; z = float2(a-b,2.0*z.x*z.y)+j.a; n++; }
float u = (n==j.b?0.0:log(float(n))/log(float(j.b)));
float3 c = 0.5+0.5*cos(float3(3.0,2.5,1.5)*2.0+float3(u)*F+sin(float3(u)*float3(15.0,20.0,25.0)));
o.write(float4(c*j.c,1.0),t);
}
