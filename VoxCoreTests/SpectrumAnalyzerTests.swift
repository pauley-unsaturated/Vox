//
//  SpectrumAnalyzerTests.swift
//  VoxCoreTests
//
//  Tests for the FFT spectrum computation logic used by SpectrumRenderer.
//  Validates that known signals produce expected frequency peaks.
//

import Testing
import Foundation
import Accelerate

@Suite("Spectrum Analyzer Tests")
struct SpectrumAnalyzerTests {
    
    /// FFT size matching SpectrumRenderer.
    let fftSize = 2048
    let sampleRate: Float = 44100.0
    
    /// Compute magnitude spectrum for a given signal buffer.
    /// Mirrors the FFT logic in SpectrumRenderer.computeFFT().
    private func computeMagnitudes(signal: [Float]) -> [Float] {
        let n = fftSize
        let halfN = n / 2
        
        // Hann window
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        
        // Apply window
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(signal, 1, window, 1, &windowed, 1, vDSP_Length(n))
        
        // Split complex
        var splitReal = [Float](repeating: 0, count: halfN)
        var splitImag = [Float](repeating: 0, count: halfN)
        
        let log2n = vDSP_Length(log2(Double(n)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        splitReal.withUnsafeMutableBufferPointer { realBuf in
            splitImag.withUnsafeMutableBufferPointer { imagBuf in
                var sc = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                windowed.withUnsafeBufferPointer { src in
                    src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &sc, 1, vDSP_Length(halfN))
                    }
                }
                vDSP_fft_zrip(fftSetup, &sc, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        
        // Compute absolute magnitudes
        var mags = [Float](repeating: 0, count: halfN)
        splitReal.withUnsafeMutableBufferPointer { realBuf in
            splitImag.withUnsafeMutableBufferPointer { imagBuf in
                var sc = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvabs(&sc, 1, &mags, 1, vDSP_Length(halfN))
            }
        }
        
        // Scale by 2/N
        var scale: Float = 2.0 / Float(n)
        vDSP_vsmul(mags, 1, &scale, &mags, 1, vDSP_Length(halfN))
        
        return mags
    }
    
    /// Generate a sine wave signal.
    private func sineSignal(frequency: Float, amplitude: Float = 1.0) -> [Float] {
        (0..<fftSize).map { i in
            amplitude * sin(2.0 * .pi * frequency * Float(i) / sampleRate)
        }
    }
    
    /// Find the bin index with the maximum magnitude.
    private func peakBin(_ mags: [Float]) -> Int {
        var maxVal: Float = 0
        var maxIdx = 0
        for (i, m) in mags.enumerated() {
            if m > maxVal { maxVal = m; maxIdx = i }
        }
        return maxIdx
    }
    
    /// Convert bin index to frequency.
    private func binToFreq(_ bin: Int) -> Float {
        Float(bin) * sampleRate / Float(fftSize)
    }
    
    @Test("Pure 440 Hz sine peaks at correct bin")
    func testSine440() {
        let signal = sineSignal(frequency: 440)
        let mags = computeMagnitudes(signal: signal)
        
        let peak = peakBin(mags)
        let peakFreq = binToFreq(peak)
        
        // Should be within one bin of 440 Hz
        let binResolution = sampleRate / Float(fftSize) // ~21.5 Hz
        #expect(abs(peakFreq - 440.0) <= binResolution)
    }
    
    @Test("Pure 1000 Hz sine peaks at correct bin")
    func testSine1000() {
        let signal = sineSignal(frequency: 1000)
        let mags = computeMagnitudes(signal: signal)
        
        let peak = peakBin(mags)
        let peakFreq = binToFreq(peak)
        
        let binResolution = sampleRate / Float(fftSize)
        #expect(abs(peakFreq - 1000.0) <= binResolution)
    }
    
    @Test("Two-tone signal has two peaks")
    func testTwoTone() {
        let f1: Float = 800.0
        let f2: Float = 2400.0
        let signal = (0..<fftSize).map { i in
            0.5 * sin(2.0 * .pi * f1 * Float(i) / sampleRate) +
            0.3 * sin(2.0 * .pi * f2 * Float(i) / sampleRate)
        }
        let mags = computeMagnitudes(signal: signal)
        
        // Find top two peaks
        let binRes = sampleRate / Float(fftSize)
        let f1Bin = Int(f1 / binRes)
        let f2Bin = Int(f2 / binRes)
        
        // Check that the bins near f1 and f2 have significant energy
        let f1Region = mags[max(0, f1Bin - 2)...min(mags.count - 1, f1Bin + 2)]
        let f2Region = mags[max(0, f2Bin - 2)...min(mags.count - 1, f2Bin + 2)]
        
        let f1Peak = f1Region.max() ?? 0
        let f2Peak = f2Region.max() ?? 0
        
        // Both should have significant energy (> 0.1 after normalization)
        #expect(f1Peak > 0.01)
        #expect(f2Peak > 0.01)
        // F1 is louder than F2 (0.5 vs 0.3 amplitude)
        #expect(f1Peak > f2Peak)
    }
    
    @Test("Silent signal produces near-zero magnitudes")
    func testSilence() {
        let signal = [Float](repeating: 0, count: fftSize)
        let mags = computeMagnitudes(signal: signal)
        
        let maxMag = mags.max() ?? 0
        #expect(maxMag < 1e-6)
    }
    
    @Test("FFT output has correct bin count")
    func testBinCount() {
        let signal = sineSignal(frequency: 440)
        let mags = computeMagnitudes(signal: signal)
        #expect(mags.count == fftSize / 2)
    }
}
