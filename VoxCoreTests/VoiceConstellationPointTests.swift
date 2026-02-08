//
//  VoiceConstellationPointTests.swift
//  VoxCoreTests
//
//  Tests for VoiceConstellationPoint data structure layout.
//  AtomicScopeBuffer integration is tested in AtomicScopeBufferTests.
//

import Testing

/// Mirror of VoxExtension.VoiceConstellationPoint for testing layout.
/// Must match the layout in VoiceConstellationPoint.swift exactly.
struct TestVoiceConstellationPoint: BitwiseCopyable {
    var pitch: Float = 0
    var amplitude: Float = 0
    var active: Float = 0
    var voiceIndex: Float = 0
    var pan: Float = 0
    var detuneCents: Float = 0
    var _pad0: Float = 0
    var _pad1: Float = 0
}

@Suite("Voice Constellation Point Tests")
struct VoiceConstellationPointTests {

    @Test("Default initialization has zeroed fields")
    func testDefaultInit() {
        let point = TestVoiceConstellationPoint()
        #expect(point.pitch == 0)
        #expect(point.amplitude == 0)
        #expect(point.active == 0)
        #expect(point.voiceIndex == 0)
        #expect(point.pan == 0)
        #expect(point.detuneCents == 0)
    }

    @Test("Custom initialization stores all fields")
    func testCustomInit() {
        let point = TestVoiceConstellationPoint(
            pitch: 60,
            amplitude: 0.8,
            active: 1.0,
            voiceIndex: 3,
            pan: -0.5,
            detuneCents: 12.5
        )
        #expect(point.pitch == 60)
        #expect(point.amplitude == 0.8)
        #expect(point.active == 1.0)
        #expect(point.voiceIndex == 3)
        #expect(point.pan == -0.5)
        #expect(point.detuneCents == 12.5)
    }

    @Test("Struct has expected memory layout for Metal compatibility")
    func testMemoryLayout() {
        // 8 floats = 32 bytes stride
        #expect(MemoryLayout<TestVoiceConstellationPoint>.stride == 32)
        #expect(MemoryLayout<TestVoiceConstellationPoint>.size <= 32)
    }
}
