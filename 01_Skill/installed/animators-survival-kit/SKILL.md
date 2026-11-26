---
name: animators-survival-kit
description: Use when designing or reviewing character animation — walk cycles, run cycles, dialogue/lip sync, acting and body language, animation timing and weight, or any animation that feels "off" but can't pinpoint why. Also triggers when the user asks about "animation principles", "squash and stretch", "anticipation", "staging", "follow through", "slow in slow out", "arcs", "secondary action", "timing animation", "exaggeration", "appeal", "walk cycle", "lip sync", "dialogue animation", "Richard Williams", or "Animator's Survival Kit".
metadata:
  version: 1.0.0
---

# The Animator's Survival Kit -- Professional Workflow

Based on Richard Williams《The Animator's Survival Kit》(Faber & Faber, Expanded Edition) -- three-time Oscar winner, animation director of Who Framed Roger Rabbit.

Core principle: **All animation is "change" — one shape becoming another shape at a specific rhythm.** 3D animation has not escaped 2D principles. Bones, IK, and motion matching are tools. Squash and stretch, anticipation, and follow-through are the source of quality. Knowing how to operate software does not equal knowing how to animate.

---

## Decision Flowchart

```
Animation Feels Wrong (But You Can't Pinpoint Why)
        │
        ▼
┌─ Diagnose: which principle is violated? ───────────────────┐
│                                                             │
│  1. SQUASH & STRETCH                                        │
│     Q: Does volume stay constant during deformation?        │
│     Sx: Character hits ground → no squash → feels weightless│
│                                                             │
│  2. ANTICIPATION                                            │
│     Q: Does audience know what's about to happen?           │
│     Sx: Action starts with no prep → viewer misses it       │
│                                                             │
│  3. STAGING                                                 │
│     Q: Is silhouette readable at a glance?                  │
│     Sx: Pose unclear from main camera angle → confusion     │
│                                                             │
│  4. STRAIGHT AHEAD vs POSE-TO-POSE                          │
│     Q: Solid structure OR organic flow — which is missing?  │
│     Sx: Feels too rigid (need SA) / floating proportions    │
│          (need P2P as scaffold)                             │
│                                                             │
│  5. FOLLOW THROUGH & OVERLAPPING                            │
│     Q: Do parts stop at different times?                    │
│     Sx: Everything stops simultaneously → looks robotic     │
│                                                             │
│  6. SLOW IN & SLOW OUT                                      │
│     Q: Does motion accelerate/decelerate naturally?         │
│     Sx: Constant speed → mechanical, not biological         │
│                                                             │
│  7. ARCS                                                    │
│     Q: Do joints trace curved paths?                        │
│     Sx: Linear trajectory → betrays it's CG immediately     │
│                                                             │
│  8. SECONDARY ACTION                                        │
│     Q: Do supporting motions support (not overwhelm)?       │
│     Sx: Secondary stronger than primary → audience confused │
│                                                             │
│  9. TIMING                                                  │
│     Q: Does speed communicate weight and emotion?           │
│     Sx: Same timing for light AND heavy → weight invisible  │
│                                                             │
│  10. EXAGGERATION                                           │
│      Q: Is the essence of the action AMPLIFIED?             │
│      Sx: Faithful to reference but reads flat on screen     │
│                                                             │
│  11. SOLID DRAWING (3D: SOLID POSING)                       │
│      Q: Does the pose work from EVERY angle?                │
│      Sx: Pose looks good from front, broken from side       │
│                                                             │
│  12. APPEAL                                                 │
│      Q: Is the character watchable?                         │
│      Sx: Technically correct but emotionally vacant         │
│                                                             │
└────────────────────────────────────────────────────────────┘
        │
        ▼
┌─ Apply the principle ──────────────────────────────────────┐
│                                                             │
│  For each violated principle, the fix:                      │
│                                                             │
│  Squash & Stretch: bone scale on impact + volume compensation│
│  Anticipation:   add reverse motion (size ∝ action size)   │
│  Staging:        rotate camera; adjust silhouette; simplify │
│  Follow Through: stagger stop times per joint chain         │
│  Slow In/Out:    weighted tangents; more keys at extremes   │
│  Arcs:           check graph editor; every joint = smooth curve│
│  Secondary:      reduce secondary intensity to ≤ 50% primary│
│  Timing:         MORE frames = heavier/slower/sadder        │
│                  FEWER frames = lighter/faster/excited      │
│  Exaggeration:   push 10-20% past reference; stop at "feels right"│
│  Solid Posing:   orbit camera around pose; check all angles │
│  Appeal:         clear line of action; readable silhouette  │
│                                                             │
└────────────────────────────────────────────────────────────┘
        │
        ▼
┌─ Check timing and spacing ─────────────────────────────────┐
│                                                             │
│  TIMING (number of frames between keys):                    │
│  - Weight: heavy → slow (more frames)                       │
│  - Emotion: sad → slow; excited → fast                      │
│  - Readability: fast action needs anticipation to be read   │
│                                                             │
│  SPACING (distribution of in-between frames):               │
│  - Even spacing = constant velocity = mechanical            │
│  - Clustered at ends = slow-in slow-out = natural           │
│  - Clustered in middle = fast start/stop = snappy/robotic   │
│                                                             │
│  In 3D: check the graph editor — NOT just the viewport.     │
│  Flat curve sections = constant speed = wrong.              │
│  Smooth S-curves = acceleration + deceleration = right.     │
│                                                             │
└────────────────────────────────────────────────────────────┘
        │
        ▼
┌─ Validate with playblast ──────────────────────────────────┐
│                                                             │
│  Export a real-time playback at target frame rate.          │
│  DO NOT trust the viewport scrub. DO NOT trust stepped.     │
│  Playblast reveals timing issues invisible at edit time.    │
│                                                             │
│  Check:                                                     │
│  - Is weight readable? (who is heavy, who is light?)        │
│  - Is anticipation visible? (can you predict the action?)   │
│  - Is silhouette clear? (squint: can you still read it?)    │
│  - Are arcs smooth? (no corners in the motion path)         │
│  - Does emotion read without sound? (mute test)             │
│                                                             │
└────────────────────────────────────────────────────────────┘
        │
        ▼
┌─ Iterate ──────────────────────────────────────────────────┐
│                                                             │
│  Animation is not "animate once, move on."                  │
│  Loop: diagnose → adjust → playblast → evaluate → repeat.  │
│                                                             │
│  Williams' rule: "If you think it's right, push it 10% more│
│  — that's usually where it actually becomes right."         │
│                                                             │
│  Most problems resolve in 2-3 iterations of adjusting       │
│  timing (more/fewer frames) and spacing (in-between curves).│
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## When to Use This Skill

| Trigger | Diagnosis | Fix |
|---------|-----------|-----|
| Character feels weightless / floaty | Missing squash & stretch; timing too fast for implied mass | Add bone scale on impact; more frames for heavy characters |
| Action happens too fast for viewer to process | No anticipation; timing too compressed | Add reverse motion before main action; 8-12 frames of anticipation for large moves |
| "Looks like a robot" | No arcs; no follow-through; even spacing | Check all joint paths in graph editor → smooth curves; stagger limb stop order; cluster keyframes at extremes |
| Pose unclear / ambiguous | Bad staging; silhouette unreadable | Rotate character to face camera (or 3/4); check silhouette by squinting |
| Lip sync feels mechanical | Animating every phoneme; mouth moves before body | Animate jaw open/close first; then 4-6 key mouth shapes; body leads mouth by 2-4 frames |
| Animation matches reference but looks boring | No exaggeration; reference is starting point, not endpoint | Push pose extremes 10-20% further; deepen anticipation; extend follow-through |
| Walk cycle just moves legs | Walk is full-body: no hip sway, no arm swing, no head bob | Add: hip lateral shift, counter-arm swing, vertical head oscillation, shoulder rotation |
| Dialogue scene: character stands still while talking | Body language precedes and accompanies speech | Add body gestures 2-4 frames BEFORE corresponding words; eye darts between thoughts |
| "Something's off but I can't name it" | Likely timing or anticipation (90% of cases) | Run through 12-principle diagnostic checklist systematically |

---

## Workflow Checklist

### Phase 1: Pre-Animation Planning

- [ ] 1.1 Defined what the character is feeling (emotion drives motion)
- [ ] 1.2 Identified the key storytelling pose (the one image that sells the shot)
- [ ] 1.3 Determined weight of character and any carried objects
- [ ] 1.4 Set frame rate and key frame count target
- [ ] 1.5 Gathered reference footage (do not animate from imagination alone)

### Phase 2: Blocking (Pose-to-Pose)

- [ ] 2.1 Key storytelling poses placed first (extremes)
- [ ] 2.2 Anticipation pose precedes every major action (size proportional to action)
- [ ] 2.3 Contact poses defined for locomotion (heel strike, passing, etc.)
- [ ] 2.4 Each pose verified from ALL camera angles (solid posing)
- [ ] 2.5 Silhouette readable at thumbnail size (staging check)
- [ ] 2.6 Line of action clear through spine for every key pose
- [ ] 2.7 Timing tested with only key poses (stepped mode) — does it read?

### Phase 3: Breakdown and In-Between

- [ ] 3.1 Breakdown poses added (define arc path midpoints)
- [ ] 3.2 All trajectories drawn as arcs — no straight-line motion paths
- [ ] 3.3 Spacing verified: keys clustered at extremes (slow-in/out); sparse in middle
- [ ] 3.4 Graph editor checked: flat sections = error; S-curves = correct
- [ ] 3.5 Follow-through: hair/cloth/tail continue moving after body stops; stagger stop order

### Phase 4: Detail Pass

- [ ] 4.1 Squash & stretch applied at impact moments; volume conserved
- [ ] 4.2 Secondary action added: intensity ≤ 50% of primary action
- [ ] 4.3 Overlapping action: adjacent body parts offset by 1-3 frames
- [ ] 4.4 Eye direction leads head turn; head turn leads body turn
- [ ] 4.5 Blinks placed at thought transitions (every 2-4 seconds naturally)

### Phase 5: Dialogue / Lip Sync (if applicable)

- [ ] 5.1 Jaw open/close animated first (largest, most important movement)
- [ ] 5.2 Mouth shapes reduced to 4-6 key phonemes (A, E, I, O, U, M/B/P/F)
- [ ] 5.3 Body gesture anticipation starts 2-4 frames BEFORE the associated word
- [ ] 5.4 Eye darts and brow movements placed at thought/emotion changes
- [ ] 5.5 Silent playback test: does emotion read without sound?

### Phase 6: Validation

- [ ] 6.1 Playblast exported at target frame rate (never trust viewport scrub)
- [ ] 6.2 Squint test: silhouette readable? action clear?
- [ ] 6.3 Mute test (dialogue): emotion, intent, weight all readable without audio
- [ ] 6.4 Frame-by-frame review: no popping, no broken arcs, no volume loss
- [ ] 6.5 Compare to reference: exaggeration pushed sufficiently past reality?
- [ ] 6.6 12-principle audit: every principle at least considered; violations are intentional

---

## Anti-Pattern Table

| Anti-Pattern | Why It Is Wrong | Correct Approach |
|--------------|----------------|------------------|
| "3D doesn't need squash & stretch" | Without squash, impacts have no weight. Character feels like rigid plastic | Bone scale on impact frames; compensate orthogonal axes to preserve volume |
| "Reference looks perfect, copy it exactly" | Reference is a record of reality, not a designed performance. Faithful copy = flat on screen | Reference is a starting point. Exaggerate 10-20% past reality. Stop when it "feels right" |
| "Just animate legs for a walk cycle" | Walk is whole-body: hip sway, arm counter-swing, spine twist, head bob. Legs alone = Terminator | Full-body walk: hips → spine → shoulders → arms → head. All parts move; none are static |
| "More blend frames fix a rough transition" | Longer blend masks the symptom, not the root cause (mismatched poses, wrong arc, bad spacing) | Fix the underlying motion: align exit/entry poses, smooth arc paths, correct spacing. Then adjust blend duration |
| "Animate every phoneme for lip sync" | Mouth becomes a seizure of 40 shapes per second. Impossible to read, unnatural | Animate jaw open/close first. Reduce to 4-6 key mouth shapes. Body leads, mouth follows |
| "Dialogue: body stays still until the line starts" | Body reacts BEFORE speech. Thought → body → mouth → sound. This order is non-negotiable | Gesture starts 2-4 frames BEFORE corresponding word. Eye shift marks thought change BEFORE speaking |
| "All parts stop at the same time" | Real bodies don't stop monolithically. Simultaneous stop = mechanical, CG, dead | Stagger stop: main body stops first, then arms, then head, then hair/cloth. Overlap creates life |
| "Constant speed between keys" | No living creature moves at constant speed. Even spacing = robotic = immersion-breaking | Cluster keys at extremes (slow-in/out). S-curves in graph editor. Weight lands where frames are concentrated |
| "The graph editor is clean, so the animation is good" | Clean curves can produce bad motion. The VIEWPORT is the truth; the graph editor is a diagnostic tool | Always verify in viewport playblast. The graph being clean is necessary but not sufficient |

---

## Code Reference: Principles Expressed in Code

### Squash & Stretch: Volume-Preserving Scale

```cpp
// Apply squash & stretch while preserving volume
// When squashing along X (getting shorter), expand Y and Z proportionally
FVector ComputeSquashStretch(const FVector& BaseScale, float SquashAmount, EAxis::Type SquashAxis)
{
    // SquashAmount: 0 = full rest, 1 = maximum squash/stretch
    // Negative = squash (compress), positive = stretch (extend)

    FVector Result = BaseScale;
    const float VolumePreservationFactor = 1.0f / FMath::Sqrt(FMath::Abs(1.0f + SquashAmount));

    switch (SquashAxis)
    {
    case EAxis::Y: // vertical squash (landing)
        Result.Y = BaseScale.Y * (1.0f + SquashAmount); // compress or extend along Y
        Result.X = BaseScale.X * VolumePreservationFactor; // expand/contract X
        Result.Z = BaseScale.Z * VolumePreservationFactor; // expand/contract Z
        break;
    // ... similar for X and Z axes
    }

    return Result;
}

// Usage: on landing impact
// SquashAmount = -0.3  →  character compresses vertically, widens horizontally
// SquashAmount = +0.2  →  character stretches during jump ascent
```

### Timing: Frame-to-Weight Mapping

```cpp
// Timing communicates weight through frame count
// MORE frames = heavier, slower, sadder
// FEWER frames = lighter, faster, more energetic

struct FTimingProfile
{
    int32 AnticipationFrames;
    int32 ActionFrames;
    int32 FollowThroughFrames;
    int32 RecoveryFrames;
};

FTimingProfile GetTimingForWeight(float CharacterMass_Kg)
{
    FTimingProfile Profile;

    if (CharacterMass_Kg < 10.0f) // light: insect, small creature
    {
        Profile = { 3, 3, 4, 3 };   // 13 frames @24fps ≈ 0.5s — snappy
    }
    else if (CharacterMass_Kg < 50.0f) // medium: human child
    {
        Profile = { 6, 4, 6, 6 };     // 22 frames ≈ 0.9s
    }
    else if (CharacterMass_Kg < 120.0f) // heavy: adult human
    {
        Profile = { 10, 6, 10, 8 };    // 34 frames ≈ 1.4s
    }
    else // very heavy: giant, mech
    {
        Profile = { 16, 12, 16, 14 };  // 58 frames ≈ 2.4s — ponderous
    }

    return Profile;
}

// Emotional timing overlay
float GetEmotionalSpeedMultiplier(const FString& Emotion)
{
    if (Emotion == "excited" || Emotion == "angry" || Emotion == "panicked")
        return 0.7f;  // faster
    if (Emotion == "sad" || Emotion == "tired" || Emotion == "thoughtful")
        return 1.4f;  // slower
    return 1.0f;       // neutral
}
```

### Arcs: Joint Trajectory Validation

```cpp
// Validate that a joint's motion follows an arc, not a straight line
// Real joints move in arcs; linear motion looks robotic

bool IsMotionArced(const TArray<FVector>& PositionSamples, float ArcTolerance)
{
    if (PositionSamples.Num() < 3) return true; // not enough data

    for (int32 i = 1; i < PositionSamples.Num() - 1; ++i)
    {
        const FVector A = PositionSamples[i - 1];
        const FVector B = PositionSamples[i];
        const FVector C = PositionSamples[i + 1];

        // Distance from B to line AC — if near zero, motion is linear (bad)
        const FVector AC = C - A;
        const FVector AB = B - A;
        const float Proj = FVector::DotProduct(AB, AC.GetSafeNormal());
        const FVector ClosestPointOnAC = A + AC.GetSafeNormal() * Proj;
        const float Deviation = FVector::Dist(B, ClosestPointOnAC);

        if (Deviation < ArcTolerance)
        {
            UE_LOG(LogAnimation, Warning,
                TEXT("Joint moving linearly at frame %d — arc deviation: %.3f"), i, Deviation);
            return false; // too linear — needs arc adjustment
        }
    }
    return true;
}
```

### Walk Cycle: Full-Body Formula

```cpp
// Walk cycle is not just legs — it's a whole-body coordinated event
struct FWalkCycleParams
{
    // Timing
    float CycleDuration_Seconds = 1.0f;     // one full stride
    int32 FramesPerCycle = 24;              // at 24fps

    // Vertical motion
    float HipVerticalRange = 4.0f;          // total up-down (cm)
    float HipLowestAt = 0.25f;              // fraction of cycle (contact → weight absorption)
    float HipHighestAt = 0.75f;             // passing position

    // Lateral hip sway
    float HipSwayRange = 3.0f;              // left-right shift (cm)
    // Hip shifts toward the WEIGHT-BEARING leg

    // Counter-arm swing
    float ArmSwingRangeDeg = 25.0f;         // forward-back swing
    // Left arm forward = right leg forward (opposite phase)

    // Shoulder/chest rotation
    float ShoulderRotationDeg = 8.0f;       // opposite to hip rotation
    // Shoulders rotate opposite to hips for balance

    // Head bob
    float HeadBobRange = 2.0f;              // smaller than hip (damped by spine)

    // Contact poses
    float HeelStrikeAt = 0.0f;              // front heel contacts ground
    float FootFlatAt = 0.15f;               // foot fully planted
    float ToeOffAt = 0.60f;                 // back toe leaves ground
};

// Personality variants
FWalkCycleParams GetWalkPersonality(const FString& Personality)
{
    FWalkCycleParams P;

    if (Personality == "confident")
    {
        P.HipVerticalRange = 6.0f;   // more bounce
        P.ArmSwingRangeDeg = 35.0f;  // bigger arm swing
        P.CycleDuration_Seconds = 0.8f; // faster pace
    }
    else if (Personality == "sneaky")
    {
        P.HipVerticalRange = 1.5f;   // almost no bounce
        P.HipSwayRange = 2.0f;       // narrower stance
        P.ArmSwingRangeDeg = 10.0f;
        P.CycleDuration_Seconds = 1.5f; // slow, deliberate
    }
    else if (Personality == "tired")
    {
        P.HipVerticalRange = 2.0f;
        P.ArmSwingRangeDeg = 8.0f;   // almost no arm swing
        P.HeadBobRange = 1.0f;       // head hangs low
        P.CycleDuration_Seconds = 1.3f;
    }
    else if (Personality == "elderly")
    {
        P.HipVerticalRange = 1.0f;   // very little vertical motion
        P.ArmSwingRangeDeg = 15.0f;
        P.CycleDuration_Seconds = 1.6f; // slow walking
        P.HeelStrikeAt = 0.0f;       // feet stay closer to ground
        P.ToeOffAt = 0.55f;          // less push-off
    }

    return P;
}
```

---

## Red Flags -- STOP and Re-evaluate

- **"Something's off but I can't name it"**: Run the 12-principle diagnostic checklist systematically. In 90% of cases the culprit is timing (wrong speed for implied weight/emotion) or anticipation (missing or undersized). Check these TWO first before anything else.
- **"3D doesn't need squash & stretch"**: Bones don't squash by default, so characters have no weight on impact. Bone scale is a legitimate animation tool. Squash on landings, stretch on takeoffs. Always compensate orthogonal axes for volume.
- **"The action is correct but looks like a robot"**: No arcs. Every joint trajectory MUST be a smooth curve — check the graph editor. Linear sections between keys = mechanical motion. Also check follow-through: parts stopping simultaneously = dead giveaway.
- **"The walk cycle just moves the legs"**: Walking is a full-body event from heel to crown. Hip lateral sway, arm counter-swing, shoulder rotation, spinal twist, vertical head bob — EVERYTHING moves. A walk cycle where only legs animate is a broken walk cycle.
- **"I animated every phoneme — the mouth matches the waveform"**: Matching every phoneme makes the mouth convulse at 30Hz. It looks unnatural because real speech does not articulate every phoneme visibly. Jaw open/close first, then 4-6 key shapes only.
- **"Body stays still until the dialogue starts"**: Thought precedes action precedes speech. Body gesture starts 2-4 frames BEFORE the spoken word. An eye dart marks a thought change before the mouth opens. This order is biologically wired, not a style choice.
- **"Reference looks perfect — I copied it exactly"**: Reference records reality. Animation DESIGNES an amplified reality for screen readability. Copy exactly = flat and underwhelming. Push 10-20% past reference. Stop when it "feels right" — usually a bit further than you first think.
- **"Anticipation is small because the action is small"**: Anticipation size scales with action size, but even small actions need visible preparation. An eye blink anticipates a head turn. A breath anticipates a word. If you can't see it, it might as well not be there.
- **"The staging looks fine from the default view"**: Players see characters from gameplay cameras — not the animation workspace angle. Test staging from ALL possible in-game angles. A pose that reads from front may be a silhouette blob from side.

**All of this means: animation software is just the tool. The 12 principles are the human compiler of quality. Software won't tell you the arc is broken, the anticipation is too small, or the timing communicates the wrong weight. Only your eye — trained by these principles — can do that.**
