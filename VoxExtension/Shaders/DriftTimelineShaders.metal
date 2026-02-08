//
//  DriftTimelineShaders.metal
//  VoxExtension
//
//  Vertex and fragment shaders for the drift timeline display.
//  Renders a scrolling horizontal timeline of drift parameter values
//  with gradient fill underneath the line.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Drift Timeline Fill (gradient area under the curve)

struct DriftTimelineVertexOut {
    float4 position [[position]];
    float4 color;
    float  normalizedY; // 0 at bottom, 1 at line
};

/// Uniform data for the drift timeline.
struct DriftTimelineUniforms {
    float sampleCount;    // number of history samples to draw
    float lineWidth;      // unused for now
    float timeScale;      // seconds of history visible (e.g., 4.0)
    float padding;
};

/// Vertex shader for the filled area under the drift curve.
/// Each sample generates a quad (2 triangles = 6 vertices) from the baseline to the value.
/// Buffer 0: array of floats (drift values, -1..1)
/// Buffer 1: DriftTimelineUniforms
vertex DriftTimelineVertexOut drift_fill_vertex(
    const device float* samples [[buffer(0)]],
    constant DriftTimelineUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    DriftTimelineVertexOut out;

    uint sampleIndex = vid / 6;
    uint vertexInQuad = vid % 6;

    float totalSamples = max(uniforms.sampleCount - 1.0, 1.0);

    // Two adjacent sample columns form a quad
    float x0 = (float(sampleIndex) / totalSamples) * 2.0 - 1.0;
    float x1 = (float(sampleIndex + 1) / totalSamples) * 2.0 - 1.0;

    float val0 = samples[min(sampleIndex, uint(uniforms.sampleCount - 1))];
    float val1 = samples[min(sampleIndex + 1, uint(uniforms.sampleCount - 1))];

    // Baseline at y = 0 (center), values map -1..1 to clip space
    float baseY = 0.0;

    // Quad: two triangles connecting adjacent samples to baseline
    float2 positions[6] = {
        float2(x0, baseY),  // 0: base-left
        float2(x0, val0),   // 1: top-left
        float2(x1, val1),   // 2: top-right
        float2(x0, baseY),  // 3: base-left
        float2(x1, val1),   // 4: top-right
        float2(x1, baseY),  // 5: base-right
    };

    float normalizedY[6] = {
        0.0, 1.0, 1.0,
        0.0, 1.0, 0.0
    };

    out.position = float4(positions[vertexInQuad], 0.0, 1.0);
    out.normalizedY = normalizedY[vertexInQuad];

    // Determine if above or below baseline for coloring
    float avgVal = (val0 + val1) * 0.5;
    float absVal = abs(avgVal);

    // Gradient: deep teal at baseline → bright cyan at extremes
    float intensity = 0.3 + 0.7 * absVal;
    if (avgVal >= 0.0) {
        // Positive: teal/cyan
        out.color = float4(0.05 * intensity, 0.6 * intensity, 0.7 * intensity, 0.4 * out.normalizedY);
    } else {
        // Negative: deep blue/purple
        out.color = float4(0.15 * intensity, 0.2 * intensity, 0.7 * intensity, 0.4 * out.normalizedY);
    }

    return out;
}

fragment float4 drift_fill_fragment(DriftTimelineVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Drift Timeline Line (the actual curve on top)

struct DriftLineVertexOut {
    float4 position [[position]];
    float4 color;
};

/// Vertex shader for the drift line itself (line strip).
/// Buffer 0: array of floats (drift values, -1..1)
/// Buffer 1: DriftTimelineUniforms
vertex DriftLineVertexOut drift_line_vertex(
    const device float* samples [[buffer(0)]],
    constant DriftTimelineUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    DriftLineVertexOut out;

    float x = (float(vid) / max(uniforms.sampleCount - 1.0, 1.0)) * 2.0 - 1.0;
    float y = samples[vid];

    out.position = float4(x, y, 0.0, 1.0);

    // Bright line color: cyan with value-dependent intensity
    float absY = abs(y);
    float intensity = 0.6 + 0.4 * absY;
    out.color = float4(0.2 * intensity, 0.9 * intensity, 1.0 * intensity, 1.0);

    return out;
}

fragment float4 drift_line_fragment(DriftLineVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Center Line (subtle baseline reference)

struct CenterLineVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex CenterLineVertexOut drift_center_vertex(uint vid [[vertex_id]]) {
    CenterLineVertexOut out;
    // Just two points: left and right at y=0
    float x = (vid == 0) ? -1.0 : 1.0;
    out.position = float4(x, 0.0, 0.0, 1.0);
    out.color = float4(1.0, 1.0, 1.0, 0.15); // subtle white
    return out;
}

fragment float4 drift_center_fragment(CenterLineVertexOut in [[stage_in]]) {
    return in.color;
}