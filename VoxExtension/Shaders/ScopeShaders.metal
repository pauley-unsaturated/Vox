//
//  ScopeShaders.metal
//  VoxExtension
//
//  Vertex and fragment shaders for the real-time oscilloscope display.
//  Renders audio samples as a line strip in clip space.
//

#include <metal_stdlib>
using namespace metal;

struct ScopeVertexOut {
    float4 position [[position]];
    float4 color;
};

/// Uniform data passed per-frame.
struct ScopeUniforms {
    float sampleCount;  // number of samples being drawn
    float lineWidth;    // unused for now (line strip is 1px)
};

/// Vertex shader: maps (sample_index, amplitude) to clip space.
/// Buffer 0: array of floats (amplitudes, -1..1)
/// Buffer 1: ScopeUniforms
vertex ScopeVertexOut scope_vertex(
    const device float* samples [[buffer(0)]],
    constant ScopeUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    ScopeVertexOut out;
    
    // Map sample index to x in [-1, 1]
    float x = (float(vid) / max(uniforms.sampleCount - 1.0, 1.0)) * 2.0 - 1.0;
    
    // Amplitude is already -1..1
    float y = samples[vid];
    
    out.position = float4(x, y, 0.0, 1.0);
    
    // Neon green with amplitude-dependent intensity
    float intensity = 0.6 + 0.4 * abs(y);
    out.color = float4(0.1 * intensity, 1.0 * intensity, 0.3 * intensity, 1.0);
    
    return out;
}

/// Fragment shader: solid color pass-through.
fragment float4 scope_fragment(ScopeVertexOut in [[stage_in]]) {
    return in.color;
}
