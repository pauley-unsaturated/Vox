import Testing
import VoxCore

// ═══════════════════════════════════════════════════════════════════════════
// Phase 6: Modulation Matrix Tests
// ═══════════════════════════════════════════════════════════════════════════

@Suite("Modulation Matrix Tests")
struct ModulationMatrixTests {
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - 6.1 Matrix Data Structure Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Matrix initializes with correct dimensions")
    func testMatrixDimensions() {
        // Use enum COUNT values to verify dimensions
        #expect(ModSource.COUNT.rawValue == 12, "Should have 12 sources")
        #expect(ModDest.COUNT.rawValue == 12, "Should have 12 destinations")
        // 12 × 12 = 144 total routes
    }
    
    @Test("Routes initialize with default values")
    func testDefaultRouteValues() {
        var matrix = ModulationMatrix()
        
        #expect(matrix.getAmount(ModSource.Env1, ModDest.Pitch) == 0.0, "Default amount should be 0")
        #expect(matrix.isEnabled(ModSource.Env1, ModDest.Pitch) == true, "Default enabled should be true")
        #expect(matrix.getCurve(ModSource.Env1, ModDest.Pitch) == ModCurve.Linear, "Default curve should be Linear")
        #expect(matrix.hasVia(ModSource.Env1, ModDest.Pitch) == false, "Default via should be none")
    }
    
    @Test("Route amount can be set and retrieved")
    func testRouteAmount() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        #expect(matrix.getAmount(ModSource.LFO1, ModDest.Pitch) == 0.5)
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, -0.75)
        #expect(matrix.getAmount(ModSource.LFO1, ModDest.Pitch) == -0.75)
    }
    
    @Test("Route amount is clamped to valid range")
    func testAmountClamping() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.Env1, ModDest.Amp, 2.0)
        #expect(matrix.getAmount(ModSource.Env1, ModDest.Amp) == 1.0, "Should clamp to +1.0")
        
        matrix.setAmount(ModSource.Env1, ModDest.Amp, -3.0)
        #expect(matrix.getAmount(ModSource.Env1, ModDest.Amp) == -1.0, "Should clamp to -1.0")
    }
    
    @Test("Route enabled flag works")
    func testRouteEnabled() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        #expect(matrix.isEnabled(ModSource.LFO1, ModDest.Pitch) == true, "Should be enabled by default")
        
        matrix.setEnabled(ModSource.LFO1, ModDest.Pitch, false)
        #expect(matrix.isEnabled(ModSource.LFO1, ModDest.Pitch) == false, "Should be disabled")
        
        // Amount should be preserved
        #expect(matrix.getAmount(ModSource.LFO1, ModDest.Pitch) == 0.5, "Amount preserved when disabled")
    }
    
    @Test("Route curve type can be set")
    func testRouteCurve() {
        var matrix = ModulationMatrix()
        
        matrix.setCurve(ModSource.Chaos, ModDest.DutyCycle, ModCurve.Exponential)
        #expect(matrix.getCurve(ModSource.Chaos, ModDest.DutyCycle) == ModCurve.Exponential)
        
        matrix.setCurve(ModSource.Chaos, ModDest.DutyCycle, ModCurve.SCurve)
        #expect(matrix.getCurve(ModSource.Chaos, ModDest.DutyCycle) == ModCurve.SCurve)
    }
    
    @Test("Route via modulation can be set")
    func testRouteVia() {
        var matrix = ModulationMatrix()
        
        matrix.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.ModWheel)
        #expect(matrix.getVia(ModSource.LFO1, ModDest.Pitch) == ModSource.ModWheel)
        #expect(matrix.hasVia(ModSource.LFO1, ModDest.Pitch) == true)
        
        // Clear via by setting to COUNT
        matrix.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.COUNT)
        #expect(matrix.hasVia(ModSource.LFO1, ModDest.Pitch) == false)
    }
    
    @Test("Multiple routes can be configured independently")
    func testMultipleRoutes() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.3)
        matrix.setAmount(ModSource.LFO2, ModDest.Pitch, -0.2)
        matrix.setAmount(ModSource.Env1, ModDest.Amp, 1.0)
        matrix.setAmount(ModSource.Chaos, ModDest.Pan, 0.5)
        
        #expect(matrix.getAmount(ModSource.LFO1, ModDest.Pitch) == 0.3)
        #expect(matrix.getAmount(ModSource.LFO2, ModDest.Pitch) == -0.2)
        #expect(matrix.getAmount(ModSource.Env1, ModDest.Amp) == 1.0)
        #expect(matrix.getAmount(ModSource.Chaos, ModDest.Pan) == 0.5)
        
        // Unset routes should still be 0
        #expect(matrix.getAmount(ModSource.Drift, ModDest.F1) == 0.0)
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - 6.2 Matrix Routing Engine Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Single source routes to destination correctly")
    func testSingleSourceRouting() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        matrix.setSourceValue(ModSource.LFO1, 1.0)  // Full LFO output
        
        let pitchMod = matrix.getModulationValue(ModDest.Pitch)
        #expect(Swift.abs(pitchMod - 0.5) < 0.001, "Pitch mod should be 0.5")
    }
    
    @Test("Multiple sources sum correctly")
    func testMultipleSourceSum() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.3)
        matrix.setAmount(ModSource.LFO2, ModDest.Pitch, 0.2)
        matrix.setAmount(ModSource.Env2, ModDest.Pitch, 0.1)
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        matrix.setSourceValue(ModSource.LFO2, 1.0)
        matrix.setSourceValue(ModSource.Env2, 1.0)
        
        let pitchMod = matrix.getModulationValue(ModDest.Pitch)
        #expect(Swift.abs(pitchMod - 0.6) < 0.001, "Sum should be 0.3 + 0.2 + 0.1 = 0.6")
    }
    
    @Test("Negative amounts work correctly")
    func testNegativeAmounts() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        matrix.setAmount(ModSource.LFO2, ModDest.Pitch, -0.3)
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        matrix.setSourceValue(ModSource.LFO2, 1.0)
        
        let pitchMod = matrix.getModulationValue(ModDest.Pitch)
        #expect(Swift.abs(pitchMod - 0.2) < 0.001, "Should be 0.5 - 0.3 = 0.2")
    }
    
    @Test("Disabled routes are skipped")
    func testDisabledRoutesSkipped() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        matrix.setAmount(ModSource.LFO2, ModDest.Pitch, 0.3)
        matrix.setEnabled(ModSource.LFO2, ModDest.Pitch, false)
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        matrix.setSourceValue(ModSource.LFO2, 1.0)
        
        let pitchMod = matrix.getModulationValue(ModDest.Pitch)
        #expect(Swift.abs(pitchMod - 0.5) < 0.001, "Should only use LFO1 (0.5)")
    }
    
    @Test("Bipolar source values work correctly")
    func testBipolarSourceValues() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        #expect(matrix.getModulationValue(ModDest.Pitch) == 0.5)
        
        matrix.setSourceValue(ModSource.LFO1, -1.0)
        #expect(matrix.getModulationValue(ModDest.Pitch) == -0.5)
        
        matrix.setSourceValue(ModSource.LFO1, 0.0)
        #expect(matrix.getModulationValue(ModDest.Pitch) == 0.0)
    }
    
    @Test("All 12 sources can be used")
    func testAllSources() {
        var matrix = ModulationMatrix()
        
        let sources: [ModSource] = [.Env1, .Env2, .LFO1, .LFO2, .Drift, .Chaos,
                                     .StepSeq, .Velocity, .Aftertouch, .ModWheel, .NoteNum, .Random]
        
        for (i, src) in sources.enumerated() {
            matrix.setAmount(src, ModDest.Pitch, Double(i + 1) * 0.01)
            matrix.setSourceValue(src, 1.0)
        }
        
        let expectedSum = (1...12).reduce(0.0) { $0 + Double($1) * 0.01 }  // 0.78
        let pitchMod = matrix.getModulationValue(ModDest.Pitch)
        #expect(Swift.abs(pitchMod - expectedSum) < 0.001, "All sources should sum correctly")
    }
    
    @Test("All 12 destinations can be modulated")
    func testAllDestinations() {
        var matrix = ModulationMatrix()
        
        let destinations: [ModDest] = [.Pitch, .F1, .F2, .VowelMorph, .DutyCycle, .GrainDensity,
                                        .CloudScatter, .Pan, .Amp, .LFO1Rate, .LFO2Rate, .ChaosRate]
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        
        for (i, dst) in destinations.enumerated() {
            let amount = Double(i + 1) * 0.05
            matrix.setAmount(ModSource.LFO1, dst, amount)
            let mod = matrix.getModulationValue(dst)
            #expect(Swift.abs(mod - amount) < 0.001, "Destination \(i) should work")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - 6.3 Curve Types Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Exponential curve compresses low values")
    func testExponentialCurve() {
        let low = ModulationMatrix.applyCurve(0.2, ModCurve.Exponential)
        let mid = ModulationMatrix.applyCurve(0.5, ModCurve.Exponential)
        let high = ModulationMatrix.applyCurve(0.8, ModCurve.Exponential)
        
        #expect(low < 0.2, "Exponential should compress low values")
        #expect(Swift.abs(mid - 0.25) < 0.01, "0.5² = 0.25")
        #expect(Swift.abs(high - 0.64) < 0.01, "0.8² = 0.64")
    }
    
    @Test("Logarithmic curve expands low values")
    func testLogarithmicCurve() {
        let low = ModulationMatrix.applyCurve(0.04, ModCurve.Logarithmic)
        let mid = ModulationMatrix.applyCurve(0.25, ModCurve.Logarithmic)
        let high = ModulationMatrix.applyCurve(0.81, ModCurve.Logarithmic)
        
        #expect(Swift.abs(low - 0.2) < 0.01, "sqrt(0.04) = 0.2")
        #expect(Swift.abs(mid - 0.5) < 0.01, "sqrt(0.25) = 0.5")
        #expect(Swift.abs(high - 0.9) < 0.01, "sqrt(0.81) = 0.9")
    }
    
    @Test("S-Curve has soft knees at extremes")
    func testSCurve() {
        let veryLow = ModulationMatrix.applyCurve(0.1, ModCurve.SCurve)
        let mid = ModulationMatrix.applyCurve(0.5, ModCurve.SCurve)
        let veryHigh = ModulationMatrix.applyCurve(0.9, ModCurve.SCurve)
        
        #expect(Swift.abs(mid - 0.5) < 0.01, "S-curve should pass through 0.5")
        #expect(veryLow < 0.1, "S-curve should be below input at low values")
        #expect(veryHigh > 0.9, "S-curve should be above input at high values")
    }
    
    @Test("Curves work with bipolar values")
    func testBipolarCurves() {
        let negExp = ModulationMatrix.applyCurve(-0.5, ModCurve.Exponential)
        #expect(Swift.abs(negExp - (-0.25)) < 0.01, "Negative should be shaped and stay negative")
        
        let negLog = ModulationMatrix.applyCurve(-0.25, ModCurve.Logarithmic)
        #expect(Swift.abs(negLog - (-0.5)) < 0.01, "Negative sqrt(0.25) = -0.5")
    }
    
    @Test("Curve applies to source before amount scaling")
    func testCurveAppliesBeforeAmount() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        matrix.setCurve(ModSource.LFO1, ModDest.Pitch, ModCurve.Exponential)
        matrix.setSourceValue(ModSource.LFO1, 0.5)
        
        let result = matrix.getModulationValue(ModDest.Pitch)
        #expect(Swift.abs(result - 0.125) < 0.001, "0.25 × 0.5 = 0.125")
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - 6.4 Via Modulation Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Via modulation scales route amount")
    func testViaModulationScales() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 1.0)
        matrix.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.ModWheel)
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        
        matrix.setSourceValue(ModSource.ModWheel, 0.0)
        #expect(matrix.getModulationValue(ModDest.Pitch) == 0.0, "Via=0 should block modulation")
        
        matrix.setSourceValue(ModSource.ModWheel, 0.5)
        #expect(Swift.abs(matrix.getModulationValue(ModDest.Pitch) - 0.5) < 0.001, "Via=0.5 should halve")
        
        matrix.setSourceValue(ModSource.ModWheel, 1.0)
        #expect(Swift.abs(matrix.getModulationValue(ModDest.Pitch) - 1.0) < 0.001, "Via=1.0 should pass full")
    }
    
    @Test("Via uses absolute value")
    func testViaUsesAbsoluteValue() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 1.0)
        matrix.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.LFO2)
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        matrix.setSourceValue(ModSource.LFO2, -1.0)
        
        #expect(Swift.abs(matrix.getModulationValue(ModDest.Pitch) - 1.0) < 0.001)
    }
    
    @Test("Via combined with curve")
    func testViaCombinedWithCurve() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 1.0)
        matrix.setCurve(ModSource.LFO1, ModDest.Pitch, ModCurve.Exponential)
        matrix.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.ModWheel)
        
        matrix.setSourceValue(ModSource.LFO1, 0.5)
        matrix.setSourceValue(ModSource.ModWheel, 0.5)
        
        #expect(Swift.abs(matrix.getModulationValue(ModDest.Pitch) - 0.125) < 0.001)
    }
    
    @Test("Multiple routes with different vias")
    func testMultipleVias() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        matrix.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.ModWheel)
        
        matrix.setAmount(ModSource.LFO2, ModDest.Pitch, 0.3)
        
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        matrix.setSourceValue(ModSource.LFO2, 1.0)
        matrix.setSourceValue(ModSource.ModWheel, 0.5)
        
        #expect(Swift.abs(matrix.getModulationValue(ModDest.Pitch) - 0.55) < 0.001)
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - 6.5 Matrix Preset Save/Load Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Serialize and deserialize round-trip")
    func testSerializeRoundTrip() {
        var matrix1 = ModulationMatrix()
        
        matrix1.setAmount(ModSource.LFO1, ModDest.Pitch, 0.75)
        matrix1.setCurve(ModSource.LFO1, ModDest.Pitch, ModCurve.Exponential)
        matrix1.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.ModWheel)
        
        matrix1.setAmount(ModSource.Chaos, ModDest.Pan, -0.5)
        matrix1.setCurve(ModSource.Chaos, ModDest.Pan, ModCurve.SCurve)
        matrix1.setEnabled(ModSource.Chaos, ModDest.Pan, false)
        
        let serialized = matrix1.serialize()
        
        var matrix2 = ModulationMatrix()
        matrix2.deserialize(serialized)
        
        #expect(Swift.abs(matrix2.getAmount(ModSource.LFO1, ModDest.Pitch) - 0.75) < 0.001)
        #expect(matrix2.getCurve(ModSource.LFO1, ModDest.Pitch) == ModCurve.Exponential)
        #expect(matrix2.getVia(ModSource.LFO1, ModDest.Pitch) == ModSource.ModWheel)
        
        #expect(Swift.abs(matrix2.getAmount(ModSource.Chaos, ModDest.Pan) - (-0.5)) < 0.001)
        #expect(matrix2.getCurve(ModSource.Chaos, ModDest.Pan) == ModCurve.SCurve)
        #expect(matrix2.isEnabled(ModSource.Chaos, ModDest.Pan) == false)
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Utility Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("getActiveRouteCount works")
    func testActiveRouteCount() {
        var matrix = ModulationMatrix()
        
        #expect(matrix.getActiveRouteCount() == 0, "Fresh matrix has no active routes")
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        #expect(matrix.getActiveRouteCount() == 1)
        
        matrix.setAmount(ModSource.Chaos, ModDest.Pan, 0.3)
        #expect(matrix.getActiveRouteCount() == 2)
        
        matrix.setEnabled(ModSource.Chaos, ModDest.Pan, false)
        #expect(matrix.getActiveRouteCount() == 1, "Disabled route not counted")
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.0)
        #expect(matrix.getActiveRouteCount() == 0, "Zero amount not counted")
    }
    
    @Test("hasActiveRoutesTo works")
    func testHasActiveRoutesTo() {
        var matrix = ModulationMatrix()
        
        #expect(matrix.hasActiveRoutesTo(ModDest.Pitch) == false)
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        #expect(matrix.hasActiveRoutesTo(ModDest.Pitch) == true)
        #expect(matrix.hasActiveRoutesTo(ModDest.F1) == false)
    }
    
    @Test("hasActiveRoutesFrom works")
    func testHasActiveRoutesFrom() {
        var matrix = ModulationMatrix()
        
        #expect(matrix.hasActiveRoutesFrom(ModSource.LFO1) == false)
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        #expect(matrix.hasActiveRoutesFrom(ModSource.LFO1) == true)
        #expect(matrix.hasActiveRoutesFrom(ModSource.LFO2) == false)
    }
    
    @Test("reset clears all routes and source values")
    func testReset() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        matrix.setCurve(ModSource.LFO1, ModDest.Pitch, ModCurve.Exponential)
        matrix.setVia(ModSource.LFO1, ModDest.Pitch, ModSource.ModWheel)
        matrix.setSourceValue(ModSource.LFO1, 1.0)
        
        matrix.reset()
        
        #expect(matrix.getAmount(ModSource.LFO1, ModDest.Pitch) == 0.0)
        #expect(matrix.getCurve(ModSource.LFO1, ModDest.Pitch) == ModCurve.Linear)
        #expect(matrix.hasVia(ModSource.LFO1, ModDest.Pitch) == false)
        #expect(matrix.getSourceValue(ModSource.LFO1) == 0.0)
    }
    
    @Test("clearAllRoutes preserves structure but clears amounts")
    func testClearAllRoutes() {
        var matrix = ModulationMatrix()
        
        matrix.setAmount(ModSource.LFO1, ModDest.Pitch, 0.5)
        matrix.setCurve(ModSource.LFO1, ModDest.Pitch, ModCurve.Exponential)
        matrix.setEnabled(ModSource.Env1, ModDest.Amp, false)
        
        matrix.clearAllRoutes()
        
        #expect(matrix.getAmount(ModSource.LFO1, ModDest.Pitch) == 0.0)
        #expect(matrix.getCurve(ModSource.LFO1, ModDest.Pitch) == ModCurve.Linear)
        #expect(matrix.isEnabled(ModSource.LFO1, ModDest.Pitch) == true)
        #expect(matrix.isEnabled(ModSource.Env1, ModDest.Amp) == true)
    }
    
    @Test("Enum name helpers return valid strings")
    func testEnumNameHelpers() {
        if let name = ModulationMatrix.getSourceName(ModSource.Velocity) {
            #expect(String(cString: name) == "Velocity")
        }
        if let name = ModulationMatrix.getSourceName(ModSource.LFO1) {
            #expect(String(cString: name) == "LFO1")
        }
        
        if let name = ModulationMatrix.getDestName(ModDest.Pitch) {
            #expect(String(cString: name) == "Pitch")
        }
        if let name = ModulationMatrix.getDestName(ModDest.CloudScatter) {
            #expect(String(cString: name) == "CloudScatter")
        }
        
        if let name = ModulationMatrix.getCurveName(ModCurve.SCurve) {
            #expect(String(cString: name) == "S-Curve")
        }
    }
}
