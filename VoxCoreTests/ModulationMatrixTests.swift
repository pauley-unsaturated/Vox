//
//  ModulationMatrixTests.swift
//  VoxCoreTests
//
//  Tests for the 12×12 Modulation Matrix
//  Note: Full testing requires proper C++/Swift bridging
//

import Testing
@testable import VoxCore

@Suite("Modulation Matrix Tests")
struct ModulationMatrixTests {
    
    @Test("ModulationMatrix can be instantiated")
    func testInstantiation() {
        // Just verify we can create the object
        let matrix = ModulationMatrix()
        #expect(matrix != nil, "Should be able to create ModulationMatrix")
    }
    
    @Test("ModSource enum has 12 values")
    func testModSourceCount() {
        // ModSource should have COUNT = 12
        #expect(ModSource.COUNT.rawValue == 12, "Should have 12 mod sources")
    }
    
    @Test("ModDest enum has 12 values")
    func testModDestCount() {
        // ModDest should have COUNT = 12
        #expect(ModDest.COUNT.rawValue == 12, "Should have 12 mod destinations")
    }
    
    @Test("ModCurve enum has 4 values")
    func testModCurveCount() {
        #expect(ModCurve.COUNT.rawValue == 4, "Should have 4 curve types")
    }
}
