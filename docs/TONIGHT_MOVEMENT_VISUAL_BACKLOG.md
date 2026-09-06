# Floorball Movement and Visual Improvement Backlog

## Reference target

Motion reference:

- [Floorball slap-shot tutorial](https://youtu.be/vcMT9so5-u8?si=PLduLUQNmD1NdSBI)
- [Floorball slap-shot short 1](https://youtube.com/shorts/hQLCAbZpyHA?si=C5HkqpqbMVjVcGDf)
- [Floorball slap-shot short 2](https://youtube.com/shorts/B09dUFoAXwU?si=8fXZvwwdYDaz6k3t)

The animation target is readable, stylised biomechanics rather than literal realism. Gameplay remains responsive and authoritative; animation presents the simulation without delaying input.

## P0 — Player movement and animation

### Slap shot

- Replace the single stick orbit with authored phases: ready, load, backswing, plant, drive, contact, follow-through, and recovery.
- Begin from a wider, lower athletic stance with knees and hips flexed.
- Transfer weight onto the rear leg during the load, then decisively onto the lead leg through contact.
- Rotate hips first, chest second, arms third, and the stick last; avoid moving the body as one rigid unit.
- Keep the blade low and behind the player during the backswing instead of lifting or passing through the torso.
- Keep the upper hand as the stable hinge while the lower hand stays fixed about 30% down the shaft and drives through contact.
- Maintain visible hand contact for every phase, including online-replicated poses.
- Add a short forward plant/step before contact and preserve momentum after release.
- Put contact slightly ahead of the lead foot, with the torso leaning into the shot.
- Continue into a broad wraparound follow-through; do not snap immediately back to idle.
- Add anticipation and contact accents without delaying release: brief compression, faster contact interval, slower settle.
- Drive the animation from normalized charge and action phase so host, guest, AI, and replay show the same pose.

### Locomotion

- Replace discrete directional clips with smooth 2D blending and phase-matched transitions.
- Add start, acceleration, hard stop, turn-in-place, planted turn, and direction-change poses.
- Add separate possession locomotion: lower stance, shorter steps, stick and ball protected to one side.
- Add genuine backpedal and side-shuffle movement while watching the ball.
- Add speed-dependent body lean and foot planting without sliding.
- Keep facing independent from travel direction, with upper-body ball tracking layered over locomotion.
- Add contextual sprint/dash anticipation, push-off, stride, and recovery.
- Add lightweight idle variation so teammates do not look synchronized.

### Ball and stick actions

- Add wrist-shot, push-pass, charged pass, receive/cushion, poke-check, steal attempt, and possession-protection poses.
- Animate the blade cupping the ball while dribbling rather than keeping a perfectly rigid offset.
- Match predicted and authoritative contact frames to one named animation event.
- Add flinch/stumble reactions for contested possession without removing control for too long.

## P1 — Character rig and models

- Replace rigid arm sections with properly skinned upper-arm/forearm deformation.
- Add elbow pole controls and reliable two-bone IK suited to Godot 4.7.
- Add pelvis, clavicle, and foot controls needed for weight transfer and planted shots.
- Author Lamb and Pirate hand shapes that wrap around the shaft rather than spherical placeholders.
- Preserve the shared skeleton, animation names, editable `.blend` sources, and mobile bone budget.
- Add animation export validation for root motion, contact markers, loop continuity, and hand-to-stick error.

## P1 — Gameplay readability and feedback

- Add a small floor shadow/contact accent under the planted lead foot during shots.
- Add a fast, tapered 2D blade-sweep arc and a brief ball-contact flash.
- Add subtle camera impulse at contact, scaled by charge; avoid disruptive shake.
- Make charge direction and power readable without covering the blade or ball.
- Add distinct pass, shot, steal, receive, and goal audio cues with positional attenuation.
- Add shot-speed-dependent ball trail, net reaction, and post/board impact feedback.

## P2 — Match presentation

- Improve camera anticipation so it frames shooter, ball, target goal, and likely passing lane.
- Add short goal reaction poses, scorer celebration, teammate response, and opponent disappointment.
- Improve substitutions between controlled players with a deliberate camera/ring handoff.
- Add contextual goalkeeper ready, lateral set, pickup, and recovery animation while preserving the current shot-through gameplay rule.
- Add crowd/bench/environment motion only after player silhouettes remain clear on phones.

## Performance and online constraints

- Target 60 FPS with a 30 FPS fallback on web/mobile.
- Reuse shared animation resources and materials; avoid per-player high-cost state.
- Replicate compact action phase, charge, handedness, and contact event—not bone transforms.
- Predict the local action immediately, timestamp contact, and reconcile outcomes without rewinding the visible swing.
- Interpolate remote action phase while never smoothing across the contact event.

## Delivery order

1. Slap-shot phase curve and lower-body weight transfer.
2. Hip/chest/arm sequencing and planted forward step.
3. Stable hand IK and low blade path through the complete action.
4. Follow-through, recovery, contact event, and visual/audio accents.
5. Locomotion transition quality and foot planting.
6. Possession locomotion, receiving, passing, and checking actions.
7. Rig/model deformation improvements in Blender, with saved sources.
8. Camera, reactions, match presentation, and final mobile profiling.

## Progress

- [x] Added deterministic load, drive, contact, follow-through, and recovery body-pose curves without changing authoritative contact timing.
- [x] Added rear-leg load, crouch, hip-before-chest rotation, lead-leg plant, forward weight transfer, and recovery to the runtime skeleton.
- [ ] Tune the complete pose sequence from close-up real-device captures.
- [x] Replace angle-derived presentation state with an explicitly replicated action timeline for host, guest, AI, shots, and charged passes.
- [x] Replace discrete directional animation switching with continuous 2D blending and subtle per-player locomotion pace variation.
- [x] Add speed- and acceleration-responsive lean plus brief stance compression for planted starts, braking, and direction changes.
- [x] Add possession-aware locomotion with an eased lower stance, bent hips/legs, and shorter-looking protective steps while the ball stays anchored to the blade pocket.
- [x] Replace reversed running with authored bent-knee backpedal recovery steps and planted hip/knee side-shuffles; regenerate and save both character `.blend` sources and GLB exports.
- [x] Add a speed-aware planted pivot response so low-speed facing changes shift the hips and body instead of rotating the character like a rigid pawn.
- [x] Give each squad slot a deterministic locomotion phase offset, in addition to pace variation, so teammates do not start or idle in synchronized lockstep.
- [x] Add deterministic slap anticipation/contact accents and a speed-triggered dash push-off/recovery pose without delaying authoritative ball contact.
- [x] Add a repeatable fixed-camera renderer capture for loaded, contact, follow-through, and recovered slap-shot visual QA.
- [x] Add and run a repeatable 12-player animation CPU benchmark; current headless median is about 0.25 ms and p95 remains under 2.3 ms with all hand IK enabled on the development machine.
- [x] Replace rigid single-bone sleeves with mobile-friendly upper-arm/forearm blended skinning, then regenerate, save, validate, and visually inspect both character sources and exports.
- [x] Replace spherical grip placeholders with shaft-aligned capsule palms and curved finger bands, merged into one draw surface per hand for mobile/web.
- [x] Add clavicle controls to the shared skeleton, parent both arm chains correctly, and drive the shoulders through load, contact, follow-through, and recovery.
- [x] Lock both hands to stable shaft grips through the swing and deepen the backswing to 90 degrees.
- [x] Replace pointed dark shoe lasts with rounded, team-coloured footwear that remains visible without creating back spikes in the broadcast view.
- [x] Give all five field players on each team deterministic, restrained differences in jersey shade, body/head proportion, and Lamb wool or Pirate hat treatment.
- [x] Keep charged passes on one continuous compact load-to-contact curve for solo, host, remote-host, and guest-predicted actions instead of snapping back to neutral on release.

## Acceptance checks

- At full charge, the rear leg carries the load, the blade is behind and near the floor, and both hands touch the shaft.
- At contact, the lead foot is planted, hips have led the chest, and the ball releases ahead of the body.
- Follow-through remains visible long enough to read at normal gameplay camera distance.
- Solo, host, guest, AI, and replay show equivalent action phase and facing.
- No stick/hand/torso intersections occur at ready, full backswing, contact, or follow-through.
- The full 6v6 scene stays inside the existing mobile model and frame-time budgets.
