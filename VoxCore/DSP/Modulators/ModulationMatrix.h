//
//  ModulationMatrix.h
//  VoxCore
//
//  Phase 6: 12×12 Modulation Matrix
//  Flexible routing between any source and destination
//  with curve shaping and via modulation support.
//

#pragma once

#ifdef __cplusplus

#include <array>
#include <cmath>
#include <algorithm>
#include <string>
#include <unordered_map>

// ═══════════════════════════════════════════════════════════════════════════
// Modulation Sources (12)
// ═══════════════════════════════════════════════════════════════════════════

enum class ModSource : int {
    Env1 = 0,       // Amplitude envelope
    Env2,           // Modulation envelope
    LFO1,           // Per-voice LFO
    LFO2,           // Global LFO
    Drift,          // Ultra-slow drift
    Chaos,          // Lorenz/Henon chaos
    StepSeq,        // Formant step sequencer
    Velocity,       // Note velocity
    Aftertouch,     // Channel/poly aftertouch
    ModWheel,       // CC1 mod wheel
    NoteNum,        // MIDI note number (scaled)
    Random,         // Per-note random
    COUNT
};

constexpr int kModSourceCount = static_cast<int>(ModSource::COUNT);

// ═══════════════════════════════════════════════════════════════════════════
// Modulation Destinations (12)
// ═══════════════════════════════════════════════════════════════════════════

enum class ModDest : int {
    Pitch = 0,      // Pitch in semitones
    F1,             // Formant 1 frequency
    F2,             // Formant 2 frequency
    VowelMorph,     // Vowel interpolation
    DutyCycle,      // Pulsaret duty cycle
    GrainDensity,   // Grain density (async mode)
    CloudScatter,   // Stochastic scatter amount
    Pan,            // Stereo position
    Amp,            // Amplitude
    LFO1Rate,       // LFO1 rate modulation
    LFO2Rate,       // LFO2 rate modulation
    ChaosRate,      // Chaos generator rate
    COUNT
};

constexpr int kModDestCount = static_cast<int>(ModDest::COUNT);

// ═══════════════════════════════════════════════════════════════════════════
// Curve Types for Amount Shaping
// ═══════════════════════════════════════════════════════════════════════════

enum class ModCurve : int {
    Linear = 0,     // y = x
    Exponential,    // y = x² (compressed low end)
    Logarithmic,    // y = sqrt(x) (expanded low end)
    SCurve,         // Sigmoid (soft knee at extremes)
    COUNT
};

// ═══════════════════════════════════════════════════════════════════════════
// Single Route in the Matrix
// ═══════════════════════════════════════════════════════════════════════════

struct ModRoute {
    double amount = 0.0;        // -1.0 to +1.0 (-100% to +100%)
    bool enabled = true;        // Quick bypass without losing amount
    ModCurve curve = ModCurve::Linear;
    ModSource via = ModSource::COUNT;  // COUNT = no via (direct)
    
    // Check if route is active
    bool isActive() const {
        return enabled && amount != 0.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// Modulation Matrix (12×12)
// ═══════════════════════════════════════════════════════════════════════════

class ModulationMatrix {
public:
    static constexpr int kSourceCount = kModSourceCount;
    static constexpr int kDestCount = kModDestCount;
    static constexpr int kTotalRoutes = kSourceCount * kDestCount;
    
    ModulationMatrix() {
        reset();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Route Access
    // ═══════════════════════════════════════════════════════════════
    
    // Get route by source and destination
    ModRoute& getRoute(ModSource src, ModDest dst) {
        return mRoutes[routeIndex(src, dst)];
    }
    
    const ModRoute& getRoute(ModSource src, ModDest dst) const {
        return mRoutes[routeIndex(src, dst)];
    }
    
    // Get route by flat index (for iteration)
    ModRoute& getRouteByIndex(int index) {
        return mRoutes[std::clamp(index, 0, kTotalRoutes - 1)];
    }
    
    const ModRoute& getRouteByIndex(int index) const {
        return mRoutes[std::clamp(index, 0, kTotalRoutes - 1)];
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Route Configuration
    // ═══════════════════════════════════════════════════════════════
    
    // Set route amount (-1.0 to +1.0, i.e., -100% to +100%)
    void setAmount(ModSource src, ModDest dst, double amount) {
        mRoutes[routeIndex(src, dst)].amount = std::clamp(amount, -1.0, 1.0);
    }
    
    double getAmount(ModSource src, ModDest dst) const {
        return mRoutes[routeIndex(src, dst)].amount;
    }
    
    // Enable/disable route (preserves amount)
    void setEnabled(ModSource src, ModDest dst, bool enabled) {
        mRoutes[routeIndex(src, dst)].enabled = enabled;
    }
    
    bool isEnabled(ModSource src, ModDest dst) const {
        return mRoutes[routeIndex(src, dst)].enabled;
    }
    
    // Set curve type
    void setCurve(ModSource src, ModDest dst, ModCurve curve) {
        mRoutes[routeIndex(src, dst)].curve = curve;
    }
    
    ModCurve getCurve(ModSource src, ModDest dst) const {
        return mRoutes[routeIndex(src, dst)].curve;
    }
    
    // Set via modulator (ModSource::COUNT = no via)
    void setVia(ModSource src, ModDest dst, ModSource via) {
        mRoutes[routeIndex(src, dst)].via = via;
    }
    
    ModSource getVia(ModSource src, ModDest dst) const {
        return mRoutes[routeIndex(src, dst)].via;
    }
    
    // Check if route has via modulation
    bool hasVia(ModSource src, ModDest dst) const {
        return mRoutes[routeIndex(src, dst)].via != ModSource::COUNT;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Curve Functions
    // ═══════════════════════════════════════════════════════════════
    
    // Apply curve to a value in [-1, 1] range
    static double applyCurve(double value, ModCurve curve) {
        // Handle bipolar input: apply curve to magnitude, preserve sign
        double sign = value >= 0.0 ? 1.0 : -1.0;
        double magnitude = std::abs(value);
        double shaped;
        
        switch (curve) {
            case ModCurve::Exponential:
                // Compress low end: y = x²
                shaped = magnitude * magnitude;
                break;
                
            case ModCurve::Logarithmic:
                // Expand low end: y = sqrt(x)
                shaped = std::sqrt(magnitude);
                break;
                
            case ModCurve::SCurve:
                // Sigmoid-like S-curve: smooth at both ends
                // Using smoothstep: 3x² - 2x³
                shaped = magnitude * magnitude * (3.0 - 2.0 * magnitude);
                break;
                
            case ModCurve::Linear:
            default:
                shaped = magnitude;
                break;
        }
        
        return sign * shaped;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Source Value Storage (updated each process cycle)
    // ═══════════════════════════════════════════════════════════════
    
    // Set source value (called by the engine before computing destinations)
    void setSourceValue(ModSource src, double value) {
        mSourceValues[static_cast<int>(src)] = value;
    }
    
    double getSourceValue(ModSource src) const {
        return mSourceValues[static_cast<int>(src)];
    }
    
    // Set all source values at once
    void setSourceValues(const std::array<double, kSourceCount>& values) {
        mSourceValues = values;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Modulation Computation
    // ═══════════════════════════════════════════════════════════════
    
    // Get summed modulation for a destination
    // Call this after setting all source values
    double getModulationValue(ModDest dst) const {
        double sum = 0.0;
        int dstIdx = static_cast<int>(dst);
        
        for (int srcIdx = 0; srcIdx < kSourceCount; ++srcIdx) {
            const ModRoute& route = mRoutes[srcIdx * kDestCount + dstIdx];
            
            if (!route.isActive()) {
                continue;
            }
            
            // Get source value
            double sourceValue = mSourceValues[srcIdx];
            
            // Apply curve shaping
            double shaped = applyCurve(sourceValue, route.curve);
            
            // Apply via modulation if present
            double amount = route.amount;
            if (route.via != ModSource::COUNT) {
                double viaValue = mSourceValues[static_cast<int>(route.via)];
                // Via scales the amount: 0 = no modulation, 1 = full amount
                // Typically via sources are unipolar (0-1), but we handle bipolar too
                amount *= std::abs(viaValue);
            }
            
            // Accumulate
            sum += shaped * amount;
        }
        
        return sum;
    }
    
    // Get all destination values at once
    std::array<double, kDestCount> getAllDestinationValues() const {
        std::array<double, kDestCount> values;
        for (int i = 0; i < kDestCount; ++i) {
            values[i] = getModulationValue(static_cast<ModDest>(i));
        }
        return values;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Reset / Initialize
    // ═══════════════════════════════════════════════════════════════
    
    void reset() {
        for (auto& route : mRoutes) {
            route = ModRoute();
        }
        for (auto& val : mSourceValues) {
            val = 0.0;
        }
    }
    
    // Clear all routes but keep structure
    void clearAllRoutes() {
        for (auto& route : mRoutes) {
            route.amount = 0.0;
            route.enabled = true;
            route.curve = ModCurve::Linear;
            route.via = ModSource::COUNT;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Preset Save/Load (Phase 6.5)
    // ═══════════════════════════════════════════════════════════════
    
    // Serialize to a flat structure for AU state
    struct SerializedRoute {
        int source;
        int dest;
        double amount;
        bool enabled;
        int curve;
        int via;  // -1 = no via
    };
    
    std::array<SerializedRoute, kTotalRoutes> serialize() const {
        std::array<SerializedRoute, kTotalRoutes> result;
        
        for (int srcIdx = 0; srcIdx < kSourceCount; ++srcIdx) {
            for (int dstIdx = 0; dstIdx < kDestCount; ++dstIdx) {
                int idx = srcIdx * kDestCount + dstIdx;
                const ModRoute& route = mRoutes[idx];
                
                result[idx] = {
                    srcIdx,
                    dstIdx,
                    route.amount,
                    route.enabled,
                    static_cast<int>(route.curve),
                    route.via == ModSource::COUNT ? -1 : static_cast<int>(route.via)
                };
            }
        }
        
        return result;
    }
    
    void deserialize(const std::array<SerializedRoute, kTotalRoutes>& data) {
        for (const auto& sr : data) {
            if (sr.source >= 0 && sr.source < kSourceCount &&
                sr.dest >= 0 && sr.dest < kDestCount) {
                
                int idx = sr.source * kDestCount + sr.dest;
                mRoutes[idx].amount = std::clamp(sr.amount, -1.0, 1.0);
                mRoutes[idx].enabled = sr.enabled;
                mRoutes[idx].curve = static_cast<ModCurve>(
                    std::clamp(sr.curve, 0, static_cast<int>(ModCurve::COUNT) - 1));
                mRoutes[idx].via = sr.via < 0 ? ModSource::COUNT :
                    static_cast<ModSource>(std::clamp(sr.via, 0, kSourceCount - 1));
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Utility
    // ═══════════════════════════════════════════════════════════════
    
    // Get number of active routes
    int getActiveRouteCount() const {
        int count = 0;
        for (const auto& route : mRoutes) {
            if (route.isActive()) {
                ++count;
            }
        }
        return count;
    }
    
    // Check if any routes are active for a destination
    bool hasActiveRoutesTo(ModDest dst) const {
        int dstIdx = static_cast<int>(dst);
        for (int srcIdx = 0; srcIdx < kSourceCount; ++srcIdx) {
            if (mRoutes[srcIdx * kDestCount + dstIdx].isActive()) {
                return true;
            }
        }
        return false;
    }
    
    // Check if any routes are active from a source
    bool hasActiveRoutesFrom(ModSource src) const {
        int srcIdx = static_cast<int>(src);
        for (int dstIdx = 0; dstIdx < kDestCount; ++dstIdx) {
            if (mRoutes[srcIdx * kDestCount + dstIdx].isActive()) {
                return true;
            }
        }
        return false;
    }
    
    // Static helpers for enum names (useful for UI/debugging)
    static const char* getSourceName(ModSource src) {
        static const char* names[] = {
            "Env1", "Env2", "LFO1", "LFO2", "Drift", "Chaos",
            "StepSeq", "Velocity", "Aftertouch", "ModWheel", "NoteNum", "Random"
        };
        int idx = static_cast<int>(src);
        return (idx >= 0 && idx < kSourceCount) ? names[idx] : "Unknown";
    }
    
    static const char* getDestName(ModDest dst) {
        static const char* names[] = {
            "Pitch", "F1", "F2", "VowelMorph", "DutyCycle", "GrainDensity",
            "CloudScatter", "Pan", "Amp", "LFO1Rate", "LFO2Rate", "ChaosRate"
        };
        int idx = static_cast<int>(dst);
        return (idx >= 0 && idx < kDestCount) ? names[idx] : "Unknown";
    }
    
    static const char* getCurveName(ModCurve curve) {
        static const char* names[] = {
            "Linear", "Exponential", "Logarithmic", "S-Curve"
        };
        int idx = static_cast<int>(curve);
        return (idx >= 0 && idx < static_cast<int>(ModCurve::COUNT)) ? names[idx] : "Unknown";
    }
    
private:
    // Flat index for 2D access
    static int routeIndex(ModSource src, ModDest dst) {
        return static_cast<int>(src) * kDestCount + static_cast<int>(dst);
    }
    
    // Storage
    std::array<ModRoute, kTotalRoutes> mRoutes;
    std::array<double, kSourceCount> mSourceValues{};
};

#endif // __cplusplus
