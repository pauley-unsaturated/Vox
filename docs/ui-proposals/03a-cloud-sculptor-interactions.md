# Cloud Sculptor — Interaction Design

## Toolkit (5 tools)

### 🧲 Magnet
- **Click + hold**: Create gravitational attractor at cursor position
- **Drag**: Sweep grains into clusters
- **Scroll**: Adjust strength (force falloff is inverse-square)
- **Double-click**: Anchor magnet permanently at position
- **Click anchored magnet**: Remove it
- **Sonic effect**: Creates formant focus points, concentrates spectral energy

### 🐝 Flock
- **Drag lasso**: Select grains to form a flock
- **Drag flock leader (first selected)**: Swarm follows with organic lag
- **Boid rules**: Cohesion (stay together), separation (don't collide), alignment (match neighbor velocity)
- **Scroll on flock**: Adjust cohesion strength (tight swarm ↔ loose cloud)
- **Drag one flock near another**: Flocks can merge at boundaries
- **Sonic effect**: Voices that move together with natural spread, choir-like

### 🔥 Heat
- **Paint (click + drag)**: Apply temperature to regions
- **Hot zones**: Grains move faster, more erratic (brownian motion, stochastic)
- **Cold zones**: Grains freeze in place (deterministic, static)
- Temperature diffuses slowly to neighboring regions over time
- **Option + paint**: Cool mode (paint cold instead of hot)
- **Sonic effect**: Spatial control over chaos vs order, localized randomness

### 🪐 Grain Planet
- **Click**: Place a gravitational body (starts at low mass)
- **Scroll / drag up-down**: Increase/decrease mass
- **Low mass**: Gentle stable circular orbits — effectively a vortex
- **Medium mass**: Tight elliptical orbits, accretion disk forms
- **High mass**: Grains spiral in and get consumed at center (amplitude spike → silence)
- **Option + drag**: Set spin direction (clockwise/counter-clockwise)
- **Multiple planets**: Create Lagrange points where grains hover between gravitational fields
- Planets can have different masses — a solar system of sound
- **Double-click**: Remove planet
- **Sonic effect**: Orbital = rhythmic pitch/formant modulation, accretion = crescendo builds, consumption = dramatic silence

### 💫 Grain Emitter
- **Click**: Place an emitter source
- **Drag from emitter**: Set spray direction and spread angle
- **Scroll**: Adjust emission rate (trickle ↔ firehose)
- **Shift + scroll**: Adjust grain velocity (slow drift ↔ fast jets)
- Configurable per-emitter: rate, spread angle, initial velocity, grain lifetime
- Aim at a Planet for orbital injection
- Aim two emitters at each other for grain collisions
- **Sonic effect**: Continuous grain generation, density control, rhythmic if pulsed

## Modifier Keys (work with all tools)
- **Shift**: Constrain to horizontal/vertical axis
- **Option**: Invert tool (e.g., magnet becomes repulsor, heat becomes cold)
- **Cmd**: Temporal mode (affect grain timing/rhythm instead of position)
- **Scroll wheel**: Tool-specific parameter (strength, radius, rate, etc.)

## Meta Interactions
- **Right-click any placed tool**: Parameter popup (strength, radius, decay, lifetime)
- **Shake/swipe gesture**: Scatter all grains (chaos burst)
- **Spacebar**: Pause grain physics (audio continues, positions freeze for precision editing)

## Visual Design
- Tool palette as vertical strip on left side or floating toolbar
- Active tool highlighted with corresponding color/icon
- Placed tools shown as subtle glyphs on the canvas (magnet icon, planet ring, emitter nozzle)
- Grain cloud rendered via existing `GrainCloudRenderer` (Metal, ice blue → deep blue particles)
- Tool influence zones shown as translucent colored overlays

## Grain Visual Properties
- **Position X**: Time offset / phase
- **Position Y**: Formant position / pitch
- **Size**: Amplitude (louder = bigger)
- **Color/brightness**: Age (new = bright, dying = dim)
- **Trail**: Recent movement path (fading)

## Physics
- Simple 2D particle physics, updated per-frame on GPU (Metal compute shader)
- Each grain has: position, velocity, mass (uniform), lifetime
- Force accumulation from all active tools (magnet, planet, vortex, heat noise)
- Flock behavior via spatial hash for neighbor lookup
- Grain-grain collision optional (expensive, toggle-able)
- Boundary: grains that leave canvas wrap or bounce
