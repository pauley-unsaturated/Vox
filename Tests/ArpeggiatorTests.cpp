#include <gtest/gtest.h>
#include "../Source/DSP/Performance/Arpeggiator.h"

class ArpeggiatorTest : public ::testing::Test {
protected:
    const float sampleRate = 44100.0f;
};

// Test basic arpeggiator functionality
TEST_F(ArpeggiatorTest, BasicFunctionality) {
    Arpeggiator arp(sampleRate);
    
    // Default values
    EXPECT_FALSE(arp.isEnabled());
    EXPECT_EQ(arp.getMode(), Arpeggiator::UP);
    EXPECT_EQ(arp.getOctaveRange(), 1);
    
    // Enable arpeggiator
    arp.setEnabled(true);
    EXPECT_TRUE(arp.isEnabled());
    
    // Without notes, getNextNote should return -1
    EXPECT_EQ(arp.getNextNote(), -1);
    
    // Add notes
    arp.noteOn(60); // Middle C
    arp.noteOn(64); // E
    arp.noteOn(67); // G
    
    // Get notes for a while
    int previousNote = -1;
    bool foundDifferentNotes = false;
    
    for (int i = 0; i < sampleRate * 0.5f; i++) {
        int currentNote = arp.getNextNote();
        if (currentNote != -1 && previousNote != -1 && currentNote != previousNote) {
            foundDifferentNotes = true;
            break;
        }
        previousNote = currentNote;
    }
    
    // Should have found different notes
    EXPECT_TRUE(foundDifferentNotes);
}

// Test arpeggiator modes
TEST_F(ArpeggiatorTest, Modes) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    
    // Add notes in ascending order
    arp.noteOn(60); // C
    arp.noteOn(64); // E
    arp.noteOn(67); // G
    
    // Test UP mode
    arp.setMode(Arpeggiator::UP);
    int notesUp[10];
    for (int i = 0; i < 10; i++) {
        notesUp[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: C, E, G, C, E, G, ...
    EXPECT_EQ(notesUp[0], 60);
    EXPECT_EQ(notesUp[1], 64);
    EXPECT_EQ(notesUp[2], 67);
    EXPECT_EQ(notesUp[3], 60);
    
    // Test DOWN mode
    arp.setMode(Arpeggiator::DOWN);
    arp.reset();
    int notesDown[10];
    for (int i = 0; i < 10; i++) {
        notesDown[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: G, E, C, G, E, C, ...
    EXPECT_EQ(notesDown[0], 67);
    EXPECT_EQ(notesDown[1], 64);
    EXPECT_EQ(notesDown[2], 60);
    EXPECT_EQ(notesDown[3], 67);
}

// Test octave range
TEST_F(ArpeggiatorTest, OctaveRange) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    arp.setMode(Arpeggiator::UP);
    
    // Add a note
    arp.noteOn(60); // Middle C
    
    // Test with 1 octave range (default)
    arp.setOctaveRange(1);
    int notes1Oct[10];
    for (int i = 0; i < 10; i++) {
        notes1Oct[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: C, C, C, ... (only one note in one octave)
    EXPECT_EQ(notes1Oct[0], 60);
    EXPECT_EQ(notes1Oct[1], 60);
    
    // Test with 2 octave range
    arp.setOctaveRange(2);
    arp.reset();
    int notes2Oct[10];
    for (int i = 0; i < 10; i++) {
        notes2Oct[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: C, C+12, C, C+12, ... (one note in two octaves)
    EXPECT_EQ(notes2Oct[0], 60);   // C4
    EXPECT_EQ(notes2Oct[1], 60+12); // C5
    EXPECT_EQ(notes2Oct[2], 60);   // C4
}

// Test note removal
TEST_F(ArpeggiatorTest, NoteRemoval) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    arp.setMode(Arpeggiator::UP);
    
    // Add notes
    arp.noteOn(60); // C
    arp.noteOn(64); // E
    arp.noteOn(67); // G
    
    // Check that we get all three notes
    bool foundC = false, foundE = false, foundG = false;
    for (int i = 0; i < sampleRate * 1.0f; i++) {
        int note = arp.getNextNote();
        if (note == 60) foundC = true;
        if (note == 64) foundE = true;
        if (note == 67) foundG = true;
    }
    
    EXPECT_TRUE(foundC && foundE && foundG);
    
    // Remove one note
    arp.noteOff(64); // Remove E
    
    // Reset flags
    foundC = foundE = foundG = false;
    
    // Check that we only get C and G now
    for (int i = 0; i < sampleRate * 1.0f; i++) {
        int note = arp.getNextNote();
        if (note == 60) foundC = true;
        if (note == 64) foundE = true;
        if (note == 67) foundG = true;
    }
    
    EXPECT_TRUE(foundC);
    EXPECT_FALSE(foundE); // E should not be found
    EXPECT_TRUE(foundG);
}

// Test transpose functionality
TEST_F(ArpeggiatorTest, Transpose) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    
    // Add a note
    arp.noteOn(60); // Middle C
    
    // Get the note without transpose
    int noteBeforeTranspose = arp.getNextNote();
    EXPECT_EQ(noteBeforeTranspose, 60);
    
    // Apply transpose
    arp.transposePattern(5); // Up a perfect fourth
    
    // Get the note after transpose
    int noteAfterTranspose = arp.getNextNote();
    EXPECT_EQ(noteAfterTranspose, 65); // 60 + 5 = 65
    
    // Reset transpose
    arp.transposePattern(0);
    
    // Get the note after reset
    int noteAfterReset = arp.getNextNote();
    EXPECT_EQ(noteAfterReset, 60);
}