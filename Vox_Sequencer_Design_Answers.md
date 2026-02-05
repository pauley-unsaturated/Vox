1. Transport Synchronization - Major Gap

I think the deal here is that there needs to be a "sequence enabled" mode, and a "sequence running" mode.  Enabling the sequence causes the arp / sequence to start(and sync to the beat clock) when the transport starts. The "sequence running" mode should always turn off when the transport stops. One can click the "play" button on the sequencer to start the transport.  We don't want our instrument to appear to be sending stuck notes.  Arp should stop when transport stops, even if there are notes that haven't been turned off, although I think the note-off might be sent automatically when that happens, so maybe there's nothing to be done there to get the correct functionality. 

2. Song Position Calculation

Good point: when the transport starts we need to calculate this just like we do for the LFO. Is this actually some more fundamental building block?
Maybe we can design a ramp component that we use to index into the LFO function, and then of course we do some low-pass filter on the output of the LFO 
as we currently do. This ramp calculator can operate in free run and tempo-sync mode, and in both cases it will need to have a phase parameter and it will need to
reset when we receive a transport start event. Likewise, the ramp calculated by this component would be used to index into the sequence.  This would help
standardize the mechanism of our low-frequency signals like a step sequence and an LFO, and make testing easier and making new things that need to ramp via song
position easier to build (the phase for the new feature has already been solved by this module we need to build).


3. Recording Mode

Recording mode should be a step-wise affair just like in the SH-101.  When in recording mode, each note-on causes a new note to be appended to the end of the
sequence when in record mode. We should have a velocity value for "normal" notes, and another for "accent" notes.  I suppose this could be either two parameters
surfaced as knobs or sliders in the UI of the performance section.  To skip a step, we need a "rest" button, and to tie a step, we need a "tie" button. 

An example for inputting via keyboard would then be: 
- Press Record
- Hit "C2" on MIDI controller [step 1]
- Hit "E2" on MIDI controller [step 2]
- Hit Rest button             [step 3]
- Hit "B3" on MIDI controller [step 4]
- Hit Tie button              [step 5]
- Hit "B5" on MIDI controller [step 5]
- Hit "E2" on MIDI controller [step 6]
- Hit "A1" on MIDI controller [step 7]
- Hit Rest button             [step 8]
- Press Record to end recording

This would result in an 8 step sequence, with two rests (step 3, step 8) and one tied note from B3 (step 4) to B5 (step 5)

At the beginning, hitting the record button resets the pattern to 0 steps.  Each note or rest increases the step length by one.
This is a pretty intuitive method of entering notes, closely matching the SH-101 and Pro-One.

4. Latch Parameter Duplication

Yep, latch should only be in one place. In the MODE section makes sense.

5. Step Grid in ARP Mode

We should make the step grid look disabled, and disable interaction with the UI elements in there when we are in ARP mode.


6. MIDI Output / Export - Not Addressed

Yeah, this is tough. Let's put a pin in this one and come back to it later. Do we have a backlog?  Put it in TODO.md under low priority.


7. 
