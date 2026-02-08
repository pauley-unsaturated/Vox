//
//  GrainCloudShaders.metal
//  VoxExtension
//
//  Metal shaders for 2D grain cloud scatter plot visualization.
//  Renders GrainPoint data as fading, size-varying point particles
//  with additive blending for a glowing cloud effect.
//

#include <metal_stdlib>
using namespace metal;

/// Per-point data from the ring buffer.
struct GrainPointIn {
    float x;          // normalized position (-1..1)
    float y;          // normalized position (-1..1)
    float size;       // grain duration (0..1)
    float age;        // 0 = newest, 1 = oldest
    float amplitude;  // grain amplitude (0..1)
};

struct GrainVertexOut {
    float4 position [[position]];
    float4 color;
    float  pointSize [[point_size]];
};

/// Uniforms passed per-frame.
struct GrainCloudUniforms {
    float pointCount;    // total points being drawn
    float aspectRatio;   // width / height
    float time;          // animation time for subtle shimmer
    float padding;
};

vertex GrainVertexOut grain_cloud_vertex(
    const device GrainPointIn* points [[buffer(0)]],
    constant GrainCloudUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    GrainVertexOut out;

    GrainPointIn pt = points[vid];

    // Scale to clip space with aspect correction
    float x = pt.x;
    float y = pt.y;
    if (uniforms.aspectRatio > 1.0) {
        x /= uniforms.aspectRatio;
    } else {
        y *= uniforms.aspectRatio;
    }

    out.position = float4(x, y, 0.0, 1.0);

    // Age-based fading: newer grains are brighter
    float freshness = 1.0 - pt.age;  // 1 = newest, 0 = oldest
    float alpha = pow(freshness, 2.0) * pt.amplitude;

    // Color: ice blue (new) → deep blue (old), brightness from amplitude
    float3 newColor = float3(0.7, 0.85, 1.0);    // bright ice white-blue
    float3 oldColor = float3(0.15, 0.25, 0.6);    // deep blue
    float3 color = mix(oldColor, newColor, freshness);

    // Subtle shimmer based on vertex id and time
    float shimmer = 0.95 + 0.05 * sin(float(vid) * 1.7 + uniforms.time * 3.0);
    color *= shimmer;

    out.color = float4(color * alpha, alpha);

    // Point size: based on grain duration, modulated by freshness
    float baseSize = mix(1.5, 8.0, pt.size);
    out.pointSize = baseSize * mix(0.3, 1.0, freshness);

    return out;
}

fragment float4 grain_cloud_fragment(
    GrainVertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Soft circular falloff for each point
    float dist = length(pointCoord - float2(0.5));
    float softEdge = 1.0 - smoothstep(0.3, 0.5, dist);
    return in.color * softEdge;
}