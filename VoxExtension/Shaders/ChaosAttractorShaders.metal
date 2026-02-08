//
//  ChaosAttractorShaders.metal
//  VoxExtension
//
//  Metal shaders for 2D chaos attractor phase-space visualization.
//  Renders ChaosPoint data as fading point trails.
//

#include <metal_stdlib>
using namespace metal;

/// Per-point data from the ring buffer.
struct ChaosPointIn {
    float x;    // attractor x coordinate (normalized -1..1)
    float y;    // attractor y coordinate (normalized -1..1)
    float age;  // 0 = newest, 1 = oldest (for trail fading)
};

struct ChaosVertexOut {
    float4 position [[position]];
    float4 color;
    float  pointSize [[point_size]];
};

/// Uniforms passed per-frame.
struct ChaosUniforms {
    float pointCount;    // total points being drawn
    float aspectRatio;   // width / height for correct scaling
    float trailLength;   // 0..1 controls fade curve
    float padding;
};

vertex ChaosVertexOut chaos_attractor_vertex(
    const device ChaosPointIn* points [[buffer(0)]],
    constant ChaosUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    ChaosVertexOut out;
    
    ChaosPointIn pt = points[vid];
    
    // Scale to clip space with aspect correction
    float x = pt.x;
    float y = pt.y;
    if (uniforms.aspectRatio > 1.0) {
        x /= uniforms.aspectRatio;
    } else {
        y *= uniforms.aspectRatio;
    }
    
    out.position = float4(x, y, 0.0, 1.0);
    
    // Age-based fading: newer points are brighter and larger
    float freshness = 1.0 - pt.age;  // 1 = newest, 0 = oldest
    float alpha = pow(freshness, 1.5) * 0.9 + 0.1;
    
    // Color: electric cyan → deep purple as points age
    float3 newColor = float3(0.2, 1.0, 0.95);   // cyan
    float3 oldColor = float3(0.6, 0.1, 0.9);     // purple
    float3 color = mix(oldColor, newColor, freshness);
    
    out.color = float4(color * alpha, alpha);
    
    // Point size: newer = larger
    out.pointSize = mix(1.0, 4.0, freshness);
    
    return out;
}

fragment float4 chaos_attractor_fragment(ChaosVertexOut in [[stage_in]]) {
    return in.color;
}
