//
//  DriftTimelineTests.swift
//  VoxCoreTests
//
//  Unit tests for DriftTimeline history buffer logic.
//  Tests the scrolling history buffer that accumulates and shifts drift data.
//

import Testing
import Synchronization

// Standalone history buffer matching DriftTimelineRenderer's logic,
// extracted for testability (the renderer itself needs Metal).
private struct DriftHistoryBuffer {
    let capacity: Int
    private(set) var data: [Float]
    private(set) var count: Int = 0
    
    init(capacity: Int) {
        self.capacity = capacity
        self.data = [Float](repeating: 0.0, count: capacity)
    }
    
    /// Append a new value, shifting history left.
    mutating func append(_ value: Float) {
        // Shift left
        for i in 0..<(capacity - 1) {
            data[i] = data[i + 1]
        }
        data[capacity - 1] = value
        if count < capacity {
            count += 1
        }
    }
    
    /// Append the average of multiple values as one history point.
    mutating func appendAverage(_ values: [Float]) {
        guard !values.isEmpty else { return }
        let sum = values.reduce(0, +)
        append(sum / Float(values.count))
    }
    
    /// Get the visible portion of history (most recent `count` values).
    var visibleData: [Float] {
        let start = capacity - count
        return Array(data[start..<capacity])
    }
}

@Suite("DriftTimeline History Buffer Tests")
struct DriftTimelineHistoryTests {
    
    @Test("Empty history has zero count")
    func testEmptyHistory() {
        let history = DriftHistoryBuffer(capacity: 8)
        #expect(history.count == 0)
        #expect(history.visibleData.isEmpty)
    }
    
    @Test("Appending fills history progressively")
    func testProgressiveFill() {
        var history = DriftHistoryBuffer(capacity: 4)
        
        history.append(0.1)
        #expect(history.count == 1)
        #expect(history.visibleData == [0.1])
        
        history.append(0.2)
        #expect(history.count == 2)
        #expect(history.visibleData == [0.1, 0.2])
        
        history.append(0.3)
        history.append(0.4)
        #expect(history.count == 4)
        #expect(history.visibleData == [0.1, 0.2, 0.3, 0.4])
    }
    
    @Test("History shifts left when full")
    func testShiftLeft() {
        var history = DriftHistoryBuffer(capacity: 4)
        
        history.append(1.0)
        history.append(2.0)
        history.append(3.0)
        history.append(4.0)
        history.append(5.0) // should push out 1.0
        
        #expect(history.count == 4)
        #expect(history.visibleData == [2.0, 3.0, 4.0, 5.0])
    }
    
    @Test("Continuous shifting maintains correct order")
    func testContinuousShift() {
        var history = DriftHistoryBuffer(capacity: 3)
        
        for i in 0..<10 {
            history.append(Float(i))
        }
        
        // Should have last 3 values: 7, 8, 9
        #expect(history.count == 3)
        #expect(history.visibleData == [7.0, 8.0, 9.0])
    }
    
    @Test("Average append downsamples correctly")
    func testAverageAppend() {
        var history = DriftHistoryBuffer(capacity: 4)
        
        history.appendAverage([0.0, 0.5, 1.0]) // avg = 0.5
        #expect(history.count == 1)
        
        let val = history.visibleData[0]
        #expect(abs(val - 0.5) < 0.001)
    }
    
    @Test("Average append with empty array does nothing")
    func testAverageAppendEmpty() {
        var history = DriftHistoryBuffer(capacity: 4)
        history.appendAverage([])
        #expect(history.count == 0)
    }
    
    @Test("Data stays in -1..1 range for clamped input")
    func testBoundedValues() {
        var history = DriftHistoryBuffer(capacity: 8)
        
        let values: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0, -0.8, 0.3, -0.1]
        for v in values {
            history.append(v)
        }
        
        for v in history.visibleData {
            #expect(v >= -1.0 && v <= 1.0)
        }
    }
    
    @Test("Ring buffer to history integration pattern")
    func testRingBufferDrainPattern() {
        // Simulate the pattern: ring buffer produces, history consumes
        // Using the local AtomicScopeBuffer duplicate from AtomicScopeBufferTests
        let ringBuf = LocalAtomicScopeBuffer<Float>(capacity: 256)
        var history = DriftHistoryBuffer(capacity: 4)
        
        // Simulate 3 frames, each with some drift samples
        // Frame 1: write some values, drain and average
        ringBuf.write(0.1)
        ringBuf.write(0.2)
        ringBuf.write(0.3)
        
        let staging = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        defer { staging.deallocate() }
        
        let count1 = ringBuf.read(into: staging, count: 256)
        var frame1Values: [Float] = []
        for i in 0..<count1 { frame1Values.append(staging[i]) }
        history.appendAverage(frame1Values)
        
        #expect(history.count == 1)
        #expect(abs(history.visibleData[0] - 0.2) < 0.001) // avg of 0.1, 0.2, 0.3
        
        // Frame 2
        ringBuf.write(0.5)
        ringBuf.write(0.7)
        let count2 = ringBuf.read(into: staging, count: 256)
        var frame2Values: [Float] = []
        for i in 0..<count2 { frame2Values.append(staging[i]) }
        history.appendAverage(frame2Values)
        
        #expect(history.count == 2)
        #expect(abs(history.visibleData[1] - 0.6) < 0.001) // avg of 0.5, 0.7
    }
}

// Minimal ring buffer for testing (same as in AtomicScopeBufferTests)
private final class LocalAtomicScopeBuffer<T>: @unchecked Sendable {
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
    
    func write(_ value: T) {
        let w = _writeHead.load(ordering: .relaxed)
        let r = _readHead.load(ordering: .acquiring)
        if w &- r >= capacity {
            _readHead.store(r &+ 1, ordering: .releasing)
        }
        buffer[w % capacity] = value
        _writeHead.store(w &+ 1, ordering: .releasing)
    }
    
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
}