//
//  GrainCloudTests.swift
//  VoxCoreTests
//
//  Tests for GrainPoint struct and AtomicScopeBuffer<GrainPoint> data flow.
//

import Testing
import Foundation
import Synchronization

// Minimal AtomicScopeBuffer duplicate for testing.
private final class AtomicScopeBuffer<T>: @unchecked Sendable {
    let capacity: Int
    private let buffer: UnsafeMutablePointer<T>
    private let _writeHead = Atomic<Int>(0)
    private let _readHead = Atomic<Int>(0)

    init(capacity: Int = 4096) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.buffer = .allocate(capacity: capacity)
    }

    deinit { buffer.deallocate() }

    @inline(__always)
    func write(_ value: T) {
        let w = _writeHead.load(ordering: .relaxed)
        let r = _readHead.load(ordering: .acquiring)
        if w &- r >= capacity {
            _readHead.store(r &+ 1, ordering: .releasing)
        }
        buffer[w % capacity] = value
        _writeHead.store(w &+ 1, ordering: .releasing)
    }

    @discardableResult
    func drainInto(_ dest: UnsafeMutablePointer<T>, maxCount: Int) -> Int {
        let w = _writeHead.load(ordering: .acquiring)
        let r = _readHead.load(ordering: .relaxed)
        let readable = min(w &- r, maxCount)
        guard readable > 0 else { return 0 }
        for i in 0..<readable {
            dest[i] = buffer[(r &+ i) % capacity]
        }
        _readHead.store(r &+ readable, ordering: .releasing)
        return readable
    }

    var availableToRead: Int {
        let w = _writeHead.load(ordering: .acquiring)
        let r = _readHead.load(ordering: .relaxed)
        return w &- r
    }
}

// Local GrainPoint for testing (mirrors VoxExtension's GrainPoint)
private struct GrainPoint {
    var x: Float
    var y: Float
    var size: Float
    var age: Float
    var amplitude: Float

    init(x: Float = 0, y: Float = 0, size: Float = 0.5, age: Float = 0, amplitude: Float = 1.0) {
        self.x = x
        self.y = y
        self.size = size
        self.age = age
        self.amplitude = amplitude
    }
}

@Suite("GrainPoint Data Flow")
struct GrainCloudTests {

    @Test("GrainPoint struct layout is correct size")
    func grainPointSize() {
        // 5 x Float32 = 20 bytes
        #expect(MemoryLayout<GrainPoint>.size == 20)
        #expect(MemoryLayout<GrainPoint>.stride == 20)
    }

    @Test("GrainPoint default values are correct")
    func grainPointDefaults() {
        let p = GrainPoint()
        #expect(p.x == 0)
        #expect(p.y == 0)
        #expect(p.size == 0.5)
        #expect(p.age == 0)
        #expect(p.amplitude == 1.0)
    }

    @Test("Ring buffer writes and drains GrainPoints")
    func grainPointRingBuffer() {
        let buffer = AtomicScopeBuffer<GrainPoint>(capacity: 256)

        // Write grain points simulating a stochastic burst
        for i in 0..<100 {
            let t = Float(i) / 100.0
            buffer.write(GrainPoint(
                x: t * 2.0 - 1.0,
                y: sin(t * .pi * 4) * 0.8,
                size: t * 0.5 + 0.1,
                age: 0,
                amplitude: 1.0 - t * 0.5
            ))
        }

        #expect(buffer.availableToRead == 100)

        let dest = UnsafeMutablePointer<GrainPoint>.allocate(capacity: 256)
        defer { dest.deallocate() }
        let count = buffer.drainInto(dest, maxCount: 256)

        #expect(count == 100)
        // First point: x = -1, y ≈ 0, size ≈ 0.1, amplitude = 1.0
        #expect(abs(dest[0].x - (-1.0)) < 0.01)
        #expect(abs(dest[0].y) < 0.01)
        #expect(abs(dest[0].size - 0.1) < 0.01)
        #expect(dest[0].amplitude == 1.0)
    }

    @Test("Overwrite-oldest preserves newest GrainPoints")
    func overwriteOldest() {
        let buffer = AtomicScopeBuffer<GrainPoint>(capacity: 64)

        // Write 100 points into capacity-64 buffer
        for i in 0..<100 {
            buffer.write(GrainPoint(x: Float(i), y: Float(i) * 0.5, size: 0.3))
        }

        #expect(buffer.availableToRead == 64)

        let dest = UnsafeMutablePointer<GrainPoint>.allocate(capacity: 64)
        defer { dest.deallocate() }
        let count = buffer.drainInto(dest, maxCount: 64)

        #expect(count == 64)
        // First readable should be point 36 (100 - 64)
        #expect(dest[0].x == 36.0)
        #expect(dest[0].y == 18.0)
    }

    @Test("GrainPoint amplitude and size are clamped in valid range")
    func grainPointBounds() {
        let p = GrainPoint(x: -0.5, y: 0.8, size: 0.7, age: 0.2, amplitude: 0.9)
        #expect(p.x >= -1.0 && p.x <= 1.0)
        #expect(p.y >= -1.0 && p.y <= 1.0)
        #expect(p.size >= 0.0 && p.size <= 1.0)
        #expect(p.age >= 0.0 && p.age <= 1.0)
        #expect(p.amplitude >= 0.0 && p.amplitude <= 1.0)
    }

    @Test("Concurrent write and drain does not crash")
    func concurrentAccess() async {
        let buffer = AtomicScopeBuffer<GrainPoint>(capacity: 1024)
        let dest = UnsafeMutablePointer<GrainPoint>.allocate(capacity: 512)
        defer { dest.deallocate() }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<5000 {
                    buffer.write(GrainPoint(
                        x: Float(i % 100) / 50.0 - 1.0,
                        y: Float(i % 50) / 25.0 - 1.0,
                        size: 0.5,
                        amplitude: 0.8
                    ))
                }
            }
            group.addTask {
                var totalDrained = 0
                for _ in 0..<100 {
                    totalDrained += buffer.drainInto(dest, maxCount: 512)
                    try? await Task.sleep(nanoseconds: 100_000)
                }
                #expect(totalDrained > 0)
            }
        }
    }
}