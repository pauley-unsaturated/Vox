//
//  ChaosAttractorTests.swift
//  VoxCoreTests
//
//  Tests for ChaosPoint and AtomicScopeBuffer<ChaosPoint> data flow.
//

import Testing
import Synchronization

// Minimal AtomicScopeBuffer duplicate for testing (same as AtomicScopeBufferTests).
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

// Local ChaosPoint for testing (mirrors VoxExtension's ChaosPoint)
private struct ChaosPoint {
    var x: Float
    var y: Float
    var age: Float
    
    init(x: Float = 0, y: Float = 0, age: Float = 0) {
        self.x = x
        self.y = y
        self.age = age
    }
}

@Suite("ChaosPoint Data Flow")
struct ChaosAttractorTests {
    
    @Test("ChaosPoint struct layout is correct size")
    func chaosPointSize() {
        #expect(MemoryLayout<ChaosPoint>.size == 12) // 3 x Float32
        #expect(MemoryLayout<ChaosPoint>.stride == 12)
    }
    
    @Test("Ring buffer writes and drains ChaosPoints")
    func chaosPointRingBuffer() {
        let buffer = AtomicScopeBuffer<ChaosPoint>(capacity: 256)
        
        // Write some attractor points
        for i in 0..<100 {
            let t = Float(i) / 100.0
            buffer.write(ChaosPoint(x: sin(t * .pi * 2), y: cos(t * .pi * 2)))
        }
        
        #expect(buffer.availableToRead == 100)
        
        // Drain
        let dest = UnsafeMutablePointer<ChaosPoint>.allocate(capacity: 256)
        defer { dest.deallocate() }
        let count = buffer.drainInto(dest, maxCount: 256)
        
        #expect(count == 100)
        // First point should be near (sin(0), cos(0)) = (0, 1)
        #expect(abs(dest[0].x) < 0.01)
        #expect(abs(dest[0].y - 1.0) < 0.01)
    }
    
    @Test("Overwrite-oldest preserves newest ChaosPoints")
    func overwriteOldest() {
        let buffer = AtomicScopeBuffer<ChaosPoint>(capacity: 64)
        
        // Write 100 points into capacity-64 buffer
        for i in 0..<100 {
            buffer.write(ChaosPoint(x: Float(i), y: Float(i) * 2))
        }
        
        // Should have 64 readable (oldest discarded)
        #expect(buffer.availableToRead == 64)
        
        let dest = UnsafeMutablePointer<ChaosPoint>.allocate(capacity: 64)
        defer { dest.deallocate() }
        let count = buffer.drainInto(dest, maxCount: 64)
        
        #expect(count == 64)
        // First readable should be point 36 (100 - 64)
        #expect(dest[0].x == 36.0)
        #expect(dest[0].y == 72.0)
    }
    
    @Test("Lorenz attractor stays bounded")
    func lorenzBounded() {
        // Simple Lorenz integration check — values should not diverge
        var lx = 0.1, ly = 0.0, lz = 0.0
        let sigma = 10.0, rho = 28.0, beta = 8.0 / 3.0
        let dt = 0.005
        
        for _ in 0..<10000 {
            let dx = sigma * (ly - lx)
            let dy = lx * (rho - lz) - ly
            let dz = lx * ly - beta * lz
            lx += dt * dx
            ly += dt * dy
            lz += dt * dz
        }
        
        // Lorenz attractor is bounded: |x|,|y| < ~25, |z| < ~50
        #expect(abs(lx) < 30)
        #expect(abs(ly) < 30)
        #expect(abs(lz) < 55)
    }
    
    @Test("Concurrent write and drain does not crash")
    func concurrentAccess() async {
        let buffer = AtomicScopeBuffer<ChaosPoint>(capacity: 1024)
        let dest = UnsafeMutablePointer<ChaosPoint>.allocate(capacity: 512)
        defer { dest.deallocate() }
        
        // Writer task
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<5000 {
                    buffer.write(ChaosPoint(x: Float(i), y: Float(i)))
                }
            }
            group.addTask {
                var totalDrained = 0
                for _ in 0..<100 {
                    totalDrained += buffer.drainInto(dest, maxCount: 512)
                    try? await Task.sleep(nanoseconds: 100_000)
                }
                // Should have drained some points
                #expect(totalDrained > 0)
            }
        }
    }
}
