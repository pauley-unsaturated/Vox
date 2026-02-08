//
//  AtomicScopeBuffer.swift
//  VoxExtension
//
//  Lock-free SPSC ring buffer for audio thread → display thread data transfer.
//  Single-producer (audio thread), single-consumer (render/display thread).
//  Uses Swift 6 Synchronization.Atomic for lock-free, allocation-free operation.
//
//  Overwrite-oldest strategy: when buffer is full, writer advances the read
//  index so old data is discarded and new data always gets written.
//

import Synchronization

/// Lock-free single-producer, single-consumer ring buffer for real-time audio → UI data transfer.
///
/// The audio thread calls `write` methods (lock-free, no allocations, no ObjC runtime).
/// The display/render thread calls `read`/`drainInto` methods.
///
/// Uses overwrite-oldest strategy: if the buffer is full, the writer overwrites
/// the oldest unread data by advancing the read index.
@available(macOS 15.0, *)
@available(macOS 15.0, *)
public final class AtomicScopeBuffer<T>: @unchecked Sendable {
    
    /// Number of usable slots in the ring buffer.
    public let capacity: Int
    
    /// Backing storage — allocated once at init, never reallocated.
    private let buffer: UnsafeMutablePointer<T>
    
    /// Monotonically increasing write position (wraps via modulo).
    /// Written by producer, read by consumer.
    private let _writeHead = Atomic<Int>(0)
    
    /// Monotonically increasing read position (wraps via modulo).
    /// Written by consumer (and by producer during overwrite-oldest).
    private let _readHead = Atomic<Int>(0)
    
    /// Create a ring buffer with the given capacity.
    /// - Parameter capacity: Number of elements the buffer can hold. Defaults to 4096.
    public init(capacity: Int = 4096) {
        precondition(capacity > 0, "AtomicScopeBuffer capacity must be > 0")
        self.capacity = capacity
        self.buffer = .allocate(capacity: capacity)
        self.buffer.initialize(repeating: unsafeBitCast((0 as Int), to: T.self), count: 0)
        // Note: we don't initialize all slots — they'll be written before read.
    }
    
    deinit {
        buffer.deallocate()
    }
    
    // MARK: - Producer API (audio thread — must be lock-free, allocation-free)
    
    /// Write a single value into the ring buffer.
    /// If the buffer is full, the oldest unread value is discarded (overwrite-oldest).
    /// - Parameter value: The value to write.
    @inline(__always)
    public func write(_ value: T) {
        let w = _writeHead.load(ordering: .relaxed)
        let r = _readHead.load(ordering: .acquiring)
        
        // If full, advance read head (discard oldest)
        if w &- r >= capacity {
            _readHead.store(r &+ 1, ordering: .releasing)
        }
        
        buffer[w % capacity] = value
        _writeHead.store(w &+ 1, ordering: .releasing)
    }
    
    /// Write multiple values from a buffer pointer.
    /// Uses overwrite-oldest strategy for any overflow.
    /// - Parameters:
    ///   - source: Pointer to source data.
    ///   - count: Number of elements to write.
    @inline(__always)
    public func write(from source: UnsafePointer<T>, count: Int) {
        guard count > 0 else { return }
        
        let w = _writeHead.load(ordering: .relaxed)
        let r = _readHead.load(ordering: .acquiring)
        let available = capacity &- (w &- r)
        
        // If writing more than available space, advance read head
        if count > available {
            _readHead.store(r &+ (count &- available), ordering: .releasing)
        }
        
        // Write elements
        for i in 0..<count {
            buffer[(w &+ i) % capacity] = source[i]
        }
        _writeHead.store(w &+ count, ordering: .releasing)
    }
    
    // MARK: - Consumer API (render/display thread)
    
    /// Read up to `count` elements into the destination buffer.
    /// Returns the number of elements actually read.
    /// - Parameters:
    ///   - dest: Pointer to destination buffer (must have space for `count` elements).
    ///   - count: Maximum number of elements to read.
    /// - Returns: Number of elements actually read (0 if buffer is empty).
    @discardableResult
    public func read(into dest: UnsafeMutablePointer<T>, count: Int) -> Int {
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
    
    /// Drain available samples directly into a Metal buffer (or any mutable pointer).
    /// - Parameters:
    ///   - metalBuffer: Destination pointer.
    ///   - maxCount: Maximum number of elements to drain.
    /// - Returns: Number of elements drained.
    @discardableResult
    public func drainInto(_ metalBuffer: UnsafeMutablePointer<T>, maxCount: Int) -> Int {
        return read(into: metalBuffer, count: maxCount)
    }
    
    // MARK: - Diagnostics (not for audio thread)
    
    /// Number of elements available to read.
    public var availableToRead: Int {
        let w = _writeHead.load(ordering: .acquiring)
        let r = _readHead.load(ordering: .relaxed)
        return w &- r
    }
    
    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        return availableToRead == 0
    }
    
    /// Reset the buffer (not thread-safe — call only when neither thread is active).
    public func reset() {
        _writeHead.store(0, ordering: .relaxed)
        _readHead.store(0, ordering: .relaxed)
    }
}
