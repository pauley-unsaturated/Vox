//
//  VoiceConstellationPointTests.swift
//  VoxCoreTests
//
//  Tests for VoiceConstellationPoint data structure and AtomicScopeBuffer integration.
//

import Testing
@testable import VoxExtension

@Suite("Voice Constellation Point Tests")
struct VoiceConstellationPointTests {

    // MARK: - Data Structure Tests

    @Test("Default initialization has zeroed fields")
    func testDefaultInit() {
        let point = VoiceConstellationPoint()
        #expect(point.pitch == 0)
        #expect(point.amplitude == 0)
        #expect(point.active == 0)
        #expect(point.voiceIndex == 0)
        #expect(point.pan == 0)
        #expect(point.detuneCents == 0)
    }

    @Test("Custom initialization stores all fields")
    func testCustomInit() {
        let point = VoiceConstellationPoint(
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
        #expect(MemoryLayout<VoiceConstellationPoint>.stride == 32)
        #expect(MemoryLayout<VoiceConstellationPoint>.size <= 32)
    }

    // MARK: - AtomicScopeBuffer Integration Tests

    @Test("Can write and read VoiceConstellationPoint through AtomicScopeBuffer")
    func testRingBufferRoundtrip() {
        let buffer = AtomicScopeBuffer<VoiceConstellationPoint>(capacity: 16)

        let point = VoiceConstellationPoint(
            pitch: 72, amplitude: 0.6, active: 1.0,
            voiceIndex: 5, pan: 0.3, detuneCents: -7.0
        )
        buffer.write(point)

        #expect(buffer.availableToRead == 1)

        let dest = UnsafeMutablePointer<VoiceConstellationPoint>.allocate(capacity: 1)
        defer { dest.deallocate() }

        let count = buffer.read(into: dest, count: 1)
        #expect(count == 1)
        #expect(dest.pointee.pitch == 72)
        #expect(dest.pointee.amplitude == 0.6)
        #expect(dest.pointee.active == 1.0)
        #expect(dest.pointee.voiceIndex == 5)
    }

    @Test("Can batch write 8 voice snapshots")
    func testBatchWrite() {
        let buffer = AtomicScopeBuffer<VoiceConstellationPoint>(capacity: 16)

        var voices: [VoiceConstellationPoint] = (0..<8).map { i in
            VoiceConstellationPoint(
                pitch: Float(60 + i * 4),
                amplitude: Float(i) / 7.0,
                active: i % 2 == 0 ? 1.0 : 0.0,
                voiceIndex: Float(i)
            )
        }

        voices.withUnsafeBufferPointer { ptr in
            buffer.write(from: ptr.baseAddress!, count: 8)
        }

        #expect(buffer.availableToRead == 8)

        let dest = UnsafeMutablePointer<VoiceConstellationPoint>.allocate(capacity: 8)
        defer { dest.deallocate() }

        let count = buffer.drainInto(dest, maxCount: 8)
        #expect(count == 8)
        #expect(dest[0].voiceIndex == 0)
        #expect(dest[7].voiceIndex == 7)
        #expect(dest[3].active == 0.0) // odd index = inactive
        #expect(dest[4].active == 1.0) // even index = active
    }

    @Test("Overwrite-oldest works for continuous voice snapshots")
    func testOverwriteOldest() {
        // Small buffer so we can test overwrite
        let buffer = AtomicScopeBuffer<VoiceConstellationPoint>(capacity: 8)

        // Write 16 points (overflows)
        for i in 0..<16 {
            buffer.write(VoiceConstellationPoint(
                pitch: Float(i),
                amplitude: 0.5,
                active: 1.0,
                voiceIndex: Float(i % 8)
            ))
        }

        // Should have last 8 points
        let dest = UnsafeMutablePointer<VoiceConstellationPoint>.allocate(capacity: 8)
        defer { dest.deallocate() }

        let count = buffer.drainInto(dest, maxCount: 8)
        #expect(count == 8)
        #expect(dest[0].pitch == 8)  // oldest surviving
        #expect(dest[7].pitch == 15) // newest
    }
}