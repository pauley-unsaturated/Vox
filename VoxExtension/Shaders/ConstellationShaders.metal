//
//  ConstellationShaders.metal
//  VoxExtension
//
//  Metal shaders for voice constellation circular display.
//  Renders 8 voice positions in a ring with glow/bloom based on amplitude.
//

#include <metal_stdlib>
using namespace metal;

/// Per-voice data from the CPU.
struct ConstellationPointIn {
    float pitch;        // MIDI note (0-127)
    float amplitude;    // 0..1
    float active;       // 0 or 1
    float voiceIndex;   // 0..7
    float pan;          // -1..1
    float detuneCents;  // cents offset
    float _pad0;
    float _pad1;
};

struct ConstellationVertexOut {
    float4 position [[position]];
    float4 color;
    float  pointSize [[point_size]];
};

/// Per-frame uniforms.
struct ConstellationUniforms {
    float voiceCount;    // number of voices (8)
    float aspectRatio;   // width / height
    float time;          // animation time for subtle pulsing
    float padding;
};

// Helper: soft glow circle in fragment shader
float glowCircle(float2 pointCoord, float radius, float softness) {
    float dist = length(pointCoord - float2(0.5));
    return 1.0 - smoothstep(radius - softness, radius + softness, dist);
}

vertex ConstellationVertexOut constellation_vertex(
    const device ConstellationPointIn* voices [[buffer(0)]],
    constant ConstellationUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    ConstellationVertexOut out;

    ConstellationPointIn v = voices[vid];

    // Arrange voices in a circle: angle based on voice index
    float angle = (v.voiceIndex / max(uniforms.voiceCount, 1.0)) * 2.0 * M_PI_F - M_PI_F / 2.0;

    // Base radius of the ring
    float baseRadius = 0.55;

    // Amplitude pushes outward slightly (breathing effect)
    float radius = baseRadius + v.amplitude * 0.12;

    // Detune creates slight angular wobble
    float detuneWobble = v.detuneCents * 0.0002;

    float x = cos(angle + detuneWobble) * radius;
    float y = sin(angle + detuneWobble) * radius;

    // Aspect correction
    if (uniforms.aspectRatio > 1.0) {
        x /= uniforms.aspectRatio;
    } else {
        y *= uniforms.aspectRatio;
    }

    out.position = float4(x, y, 0.0, 1.0);

    // Color: active voices glow warm (gold/amber), inactive are cool dim (blue-gray)
    float activity = v.active * v.amplitude;

    // Subtle pulsing for active voices
    float pulse = 1.0 + 0.15 * sin(uniforms.time * 3.0 + v.voiceIndex * 0.8);

    float3 activeColor = float3(1.0, 0.75, 0.3);   // warm gold
    float3 dimColor = float3(0.2, 0.3, 0.5);        // cool blue-gray
    float3 color = mix(dimColor, activeColor, activity) * pulse;

    float alpha = mix(0.25, 1.0, activity);
    out.color = float4(color * alpha, alpha);

    // Point size: active voices are much larger
    float baseSize = mix(6.0, 28.0, activity);
    out.pointSize = baseSize * pulse;

    return out;
}

fragment float4 constellation_fragment(
    ConstellationVertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Soft circular glow
    float dist = length(pointCoord - float2(0.5));

    // Inner bright core
    float core = 1.0 - smoothstep(0.0, 0.15, dist);
    // Outer soft glow
    float glow = 1.0 - smoothstep(0.1, 0.5, dist);

    float intensity = core * 0.8 + glow * 0.4;

    return float4(in.color.rgb * intensity, in.color.a * intensity);
}

// --- Ring outline pass ---

struct RingVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex RingVertexOut constellation_ring_vertex(
    constant ConstellationUniforms& uniforms [[buffer(0)]],
    uint vid [[vertex_id]]
) {
    RingVertexOut out;

    // 128 segments for smooth circle
    float segments = 128.0;
    float angle = (float(vid) / segments) * 2.0 * M_PI_F;

    float radius = 0.55;
    float x = cos(angle) * radius;
    float y = sin(angle) * radius;

    if (uniforms.aspectRatio > 1.0) {
        x /= uniforms.aspectRatio;
    } else {
        y *= uniforms.aspectRatio;
    }

    out.position = float4(x, y, 0.0, 1.0);
    out.color = float4(0.15, 0.25, 0.4, 0.3); // subtle blue ring

    return out;
}

fragment float4 constellation_ring_fragment(RingVertexOut in [[stage_in]]) {
    return in.color;
}