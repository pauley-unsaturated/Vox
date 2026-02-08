//
//  AtomicScopeBufferTests.swift
//  VoxCoreTests
//
//  Unit tests for AtomicScopeBuffer: SPSC lock-free ring buffer.
//

import Testing
import Synchronization

// We duplicate a minimal version of AtomicScopeBuffer here for testing,
// because VoxCoreTests links VoxCore (C++ framework) not VoxExtension.
// The real implementation is in VoxExtension/Swift/DSP/AtomicScopeBuffer.swift.

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
    
    @inline(__always)
    func write(from source: UnsafePointer<T>, count: Int) {
        guard count > 0 else { return }
        let w = _writeHead.load(ordering: .relaxed)
        let r = _readHead.load(ordering: .acquiring)
        let available = capacity &- (w &- r)
        if count > available {
            _readHead.store(r &+ (count &- available), ordering: .releasing)
        }
        for i in 0..<count {
            buffer[(w &+ i) % capacity] = source[i]
        }
        _writeHead.store(w &+ count, ordering: .releasing)
    }
    
    @discardableResult
    func read(into dest: UnsafeMutablePointer<T>, count: Int) -> Int {
        let w = _writeHead.load(ordering: .acquiring)
        let r = _readHead.load(ordering: .relaxed)
        let readable = min(w &- r, count)
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
    
    var isEmpty: Bool { availableToRead == 0 }
    
    func reset() {
        _writeHead.store(0, ordering: .relaxed)
        _readHead.store(0, ordering: .relaxed)
    }
}

// MARK: - Tests

@Suite("AtomicScopeBuffer Tests")
struct AtomicScopeBufferTests {
    
    @Test("Empty buffer returns 0 on read")
    func testEmptyRead() {
        let buf = AtomicScopeBuffer<Float>(capacity: 64)
        let dest = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { dest.deallocate() }
        
        let count = buf.read(into: dest, count: 64)
        #expect(count == 0)
        #expect(buf.isEmpty)
    }
    
    @Test("Write and read single values")
    func testSingleWriteRead() {
        let buf = AtomicScopeBuffer<Float>(capacity: 64)
        
        buf.write(0.5)
        buf.write(-0.25)
        buf.write(1.0)
        
        #expect(buf.availableToRead == 3)
        
        let dest = UnsafeMutablePointer<Float>.allocate(capacity: 3)
        defer { dest.deallocate() }
        
        let count = buf.read(into: dest, count: 3)
        #expect(count == 3)
        #expect(dest[0] == 0.5)
        #expect(dest[1] == -0.25)
        #expect(dest[2] == 1.0)
        #expect(buf.isEmpty)
    }
    
    @Test("Write from pointer, read back correctly")
    func testBulkWriteRead() {
        let buf = AtomicScopeBuffer<Float>(capacity: 256)
        
        var source: [Float] = (0..<100).map { Float($0) / 100.0 }
        source.withUnsafeBufferPointer { ptr in
            buf.write(from: ptr.baseAddress!, count: 100)
        }
        
        #expect(buf.availableToRead == 100)
        
        let dest = UnsafeMutablePointer<Float>.allocate(capacity: 100)
        defer { dest.deallocate() }
        
        let count = buf.read(into: dest, count: 100)
        #expect(count == 100)
        
        for i in 0..<100 {
            #expect(dest[i] == Float(i) / 100.0)
        }
    }
    
    @Test("Partial read returns only available samples")
    func testPartialRead() {
        let buf = AtomicScopeBuffer<Float>(capacity: 64)
        
        buf.write(1.0)
        buf.write(2.0)
        
        let dest = UnsafeMutablePointer<Float>.allocate(capacity: 10)
        defer { dest.deallocate() }
        
        let count = buf.read(into: dest, count: 10)
        #expect(count == 2)
        #expect(dest[0] == 1.0)
        #expect(dest[1] == 2.0)
    }
    
    @Test("Overwrite-oldest: writing beyond capacity discards old data")
    func testOverwriteOldest() {
        let buf = AtomicScopeBuffer<Float>(capacity: 4)
        
        buf.write(1.0)
        buf.write(2.0)
        buf.write(3.0)
        buf.write(4.0)
        buf.write(5.0)
        buf.write(6.0)
        
        #expect(buf.availableToRead == 4)
        
        let dest = UnsafeMutablePointer<Float>.allocate(capacity: 4)
        defer { dest.deallocate() }
        
        let count = buf.read(into: dest, count: 4)
        #expect(count == 4)
        #expect(dest[0] == 3.0)
        #expect(dest[1] == 4.0)
        #expect(dest[2] == 5.0)
        #expect(dest[3] == 6.0)
    }
    
    @Test("Bulk write overwrite-oldest")
    func testBulkOverwriteOldest() {
        let buf = AtomicScopeBuffer<Float>(capacity: 4)
        
        var source: [Float] = [1, 2, 3, 4]
        source.withUnsafeBufferPointer { buf.write(from: $0.baseAddress!, count: 4) }
        
        var source2: [Float] = [5, 6, 7]
        source2.withUnsafeBufferPointer { buf.write(from: $0.baseAddress!, count: 3) }
        
        let dest = UnsafeMutablePointer<Float>.allocate(capacity: 4)
        defer { dest.deallocate() }
        
        let count = buf.read(into: dest, count: 4)
        #expect(count == 4)
        #expect(dest[0] == 4.0)
        #expect(dest[1] == 5.0)
        #expect(dest[2] == 6.0)
        #expect(dest[3] == 7.0)
    }
    
    @Test("Correct behavior across index wrap-around")
    func testWrapAround() {
        let buf = AtomicScopeBuffer<Float>(capacity: 4)
        let dest = UnsafeMutablePointer<Float>.allocate(capacity: 4)
        defer { dest.deallocate() }
        
        for cycle in 0..<10 {
            let base = Float(cycle * 4)
            buf.write(base + 1)
            buf.write(base + 2)
            buf.write(base + 3)
            buf.write(base + 4)
            
            let count = buf.read(into: dest, count: 4)
            #expect(count == 4)
            #expect(dest[0] == base + 1)
            #expect(dest[1] == base + 2)
            #expect(dest[2] == base + 3)
            #expect(dest[3] == base + 4)
        }
    }
    
    @Test("Reset clears the buffer")
    func testReset() {
        let buf = AtomicScopeBuffer<Float>(capacity: 64)
        buf.write(1.0)
        buf.write(2.0)
        #expect(buf.availableToRead == 2)
        
        buf.reset()
        #expect(buf.isEmpty)
        #expect(buf.availableToRead == 0)
    }
    
    @Test("Concurrent producer/consumer stress test")
    func testConcurrentStress() async {
        let buf = AtomicScopeBuffer<Float>(capacity: 1024)
        let totalWrites = 100_000
        
        let producerTask = Task.detached {
            for i in 0..<totalWrites {
                buf.write(Float(i))
            }
        }
        
        let consumerTask = Task.detached {
            let dest = UnsafeMutablePointer<Float>.allocate(capacity: 512)
            defer { dest.deallocate() }
            var lastValue: Float = -1
            var totalRead = 0
            
            while totalRead < totalWrites {
                let count = buf.read(into: dest, count: 512)
                for i in 0..<count {
                    if dest[i] > lastValue {
                        lastValue = dest[i]
                    }
                }
                totalRead += count
                if count == 0 {
                    try? await Task.sleep(for: .microseconds(10))
                }
            }
        }
        
        await producerTask.value
        try? await Task.sleep(for: .milliseconds(100))
        consumerTask.cancel()
    }
}
