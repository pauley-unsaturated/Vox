//
//  SpectrumShaders.metal
//  VoxExtension
//
//  Vertex and fragment shaders for the formant spectrum display.
//  Renders FFT magnitude bins as filled bars with F1/F2 frequency markers.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Spectrum Bars

struct SpectrumVertexOut {
    float4 position [[position]];
    float4 color;
};

/// Uniform data for the spectrum display.
struct SpectrumUniforms {
    float binCount;       // number of FFT bins to display
    float maxFrequency;   // Nyquist frequency (sampleRate / 2)
    float f1Frequency;    // Formant 1 frequency in Hz (0 = no marker)
    float f2Frequency;    // Formant 2 frequency in Hz (0 = no marker)
};

/// Vertex shader for spectrum bars.
/// Each bin is drawn as a quad (2 triangles = 6 vertices per bin).
/// Buffer 0: array of floats (magnitude per bin, 0..1 normalized)
/// Buffer 1: SpectrumUniforms
vertex SpectrumVertexOut spectrum_vertex(
    const device float* magnitudes [[buffer(0)]],
    constant SpectrumUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    SpectrumVertexOut out;
    
    uint binIndex = vid / 6;
    uint vertexInQuad = vid % 6;
    
    float totalBins = uniforms.binCount;
    float barWidth = 2.0 / totalBins;
    float leftX = (float(binIndex) / totalBins) * 2.0 - 1.0;
    float rightX = leftX + barWidth * 0.85; // slight gap between bars
    
    float magnitude = magnitudes[binIndex];
    float topY = magnitude * 2.0 - 1.0; // map 0..1 to -1..1
    float bottomY = -1.0;
    
    // Quad vertices: two triangles
    // Triangle 1: bottom-left, top-left, top-right
    // Triangle 2: bottom-left, top-right, bottom-right
    float2 positions[6] = {
        float2(leftX,  bottomY),  // 0: bottom-left
        float2(leftX,  topY),     // 1: top-left
        float2(rightX, topY),     // 2: top-right
        float2(leftX,  bottomY),  // 3: bottom-left
        float2(rightX, topY),     // 4: top-right
        float2(rightX, bottomY),  // 5: bottom-right
    };
    
    out.position = float4(positions[vertexInQuad], 0.0, 1.0);
    
    // Color gradient: teal at bottom → bright cyan at top
    float t = (magnitude > 0.001) ? (positions[vertexInQuad].y + 1.0) / 2.0 : 0.0;
    out.color = float4(0.05 + 0.15 * t, 0.4 + 0.6 * t, 0.5 + 0.5 * t, 0.85);
    
    return out;
}

fragment float4 spectrum_fragment(SpectrumVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Formant Markers (F1/F2 vertical lines)

struct MarkerVertexOut {
    float4 position [[position]];
    float4 color;
};

/// Vertex shader for formant frequency marker lines.
/// Draws thin vertical lines at F1 and F2 positions.
/// vid 0-3: F1 line (2 triangles forming thin quad), vid 4-7: F2 line
vertex MarkerVertexOut marker_vertex(
    constant SpectrumUniforms& uniforms [[buffer(0)]],
    uint vid [[vertex_id]]
) {
    MarkerVertexOut out;
    
    uint markerIndex = vid / 6;  // 0 = F1, 1 = F2
    uint vertexInQuad = vid % 6;
    
    float freq = (markerIndex == 0) ? uniforms.f1Frequency : uniforms.f2Frequency;
    float halfWidth = 0.003; // thin line
    
    // Map frequency to x position: freq / maxFrequency * 2.0 - 1.0
    float centerX = (freq / uniforms.maxFrequency) * 2.0 - 1.0;
    
    float2 positions[6] = {
        float2(centerX - halfWidth, -1.0),
        float2(centerX - halfWidth,  1.0),
        float2(centerX + halfWidth,  1.0),
        float2(centerX - halfWidth, -1.0),
        float2(centerX + halfWidth,  1.0),
        float2(centerX + halfWidth, -1.0),
    };
    
    out.position = float4(positions[vertexInQuad], 0.0, 1.0);
    
    // F1 = orange/amber, F2 = magenta/pink
    if (markerIndex == 0) {
        out.color = float4(1.0, 0.6, 0.1, 0.9);  // amber
    } else {
        out.color = float4(1.0, 0.3, 0.7, 0.9);  // magenta
    }
    
    return out;
}

fragment float4 marker_fragment(MarkerVertexOut in [[stage_in]]) {
    return in.color;
}
