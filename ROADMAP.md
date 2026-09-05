# Floorball Frenzy Quality Roadmap

## Objective

Build a polished sports-game vertical slice around one locally controlled player, one remote player, the ball, and a complete possession-to-slap-shot sequence. Once that experience remains responsive and visually stable under realistic network conditions, extend the same systems across the full 6v6 match.

The target is the responsiveness, readability, movement quality, and presentation discipline of a FIFA-style sports game, while retaining a scope and performance budget appropriate for a Godot web/mobile title.

## Principles

- The host remains authoritative for scoring, possession, collisions, and shot results.
- Solo, host, and guest players run the same movement simulation.
- Local input reacts immediately; networking validates and corrects the result afterward.
- Gameplay simulation drives animation. Animated bones never determine authoritative player position.
- Ball possession is explicit replicated state rather than something inferred from intermittent ball positions.
- Authoritative simulation state, replicated network state, and smoothed visual state remain separate.
- Optimise for a stable 60 FPS on supported phones and browsers, with a reduced-quality 30 FPS fallback for lower-end devices.

## Milestone 1: Diagnostics and repeatable measurement

Add enough instrumentation and test infrastructure to distinguish input delay, simulation error, network delay, reconciliation, rendering stutter, and animation lag.

### Work

- Add an optional developer HUD showing FPS, frame time, RTT, jitter, packet loss, snapshot age/rate, input acknowledgement, player prediction error, ball prediction error, and direct-versus-relayed connection status.
- Add repeatable simulated network conditions for local testing: 50/100/150/250 ms RTT, 1-5% loss, jitter, and packet reordering.
- Record short input and state traces so identical movement sequences can be replayed.
- Establish a fixed simulation tick and clearly separate simulation, network, and visual state.
- Capture baseline measurements before changing movement or reconciliation.

### Exit criteria

- Guest problems can be reproduced locally without two physical devices.
- Visible corrections have measurable causes and magnitudes.
- The same input trace produces equivalent simulation results at different render frame rates.

## Milestone 2: Shared, responsive player simulation

Replace divergent host and guest movement paths with one command-driven simulation.

### Work

- Introduce a `PlayerCommand` containing movement, aim/facing, shoot, pass, switch, dash, sequence, and simulation tick.
- Feed offline, host, and guest input through the same movement step.
- Remove the guest's simplified constant-speed position prediction.
- Separate movement direction from facing direction.
- Add fast initial response, controlled acceleration, sharper braking, speed-sensitive turns, low-speed pivots, backpedalling, strafing, and contextual possession movement.
- Add mobile dead zones and response curves.
- Buffer short-lived pass, switch, and shoot inputs.
- Preserve limited steering during shot charge and recovery.

### Exit criteria

- Local input-to-motion response occurs within one rendered frame.
- Solo, host, and guest handling use identical rules and feel materially equivalent.
- Full-speed reversals remain responsive without looking instantaneous or weightless.
- Movement remains stable at 30 and 60 FPS.

## Milestone 3: Guest prediction and reconciliation

Make the guest locally responsive while retaining host authority.

### Player prediction

- Assign every simulation step a monotonically increasing tick.
- Send guest commands with tick and sequence identifiers.
- Have the host acknowledge the last command it actually simulated.
- Include the authoritative player state for that acknowledged tick in snapshots.
- On receipt, restore the authoritative state, discard acknowledged commands, replay outstanding commands through the shared simulation, and visually blend only the resulting correction.
- Ignore negligible errors, blend small errors, and snap only genuinely invalid large errors.
- Timestamp and briefly buffer remote actors for interpolation.
- Extrapolate across short packet gaps, then decelerate rather than drifting indefinitely.
- Replicate facing and action state as well as position and velocity.

### Exit criteria

- Ordinary local corrections remain below approximately 20-30 cm.
- The guest does not routinely snap backward.
- Remote players remain smooth without excessive visual delay.
- The match remains playable at 150 ms RTT with 2% packet loss and moderate jitter.

## Milestone 4: Ball, possession, pass, and hit prediction

Represent ball ownership and actions explicitly so the guest does not chase delayed ball coordinates.

### State model

Use explicit ball states:

- `LOOSE`
- `POSSESSED`
- `PASSING`
- `SHOT`
- `DEAD`
- `FACEOFF`

Replicate the state, owning actor, possession generation ID, position, velocity, release tick, action/event ID, and intended pass recipient when applicable.

### Work

- While possessed, attach the ball locally to the replicated owner's blade socket. Treat ball-position snapshots as safety corrections.
- Start locally initiated passes and shots at the predicted contact frame without waiting for a host round trip.
- Have the host validate and acknowledge the same action/event ID.
- Reconcile accepted trajectories gently and return rejected actions cleanly to authoritative possession.
- Prevent stale possessed-ball snapshots from affecting a loose, passed, or shot ball.
- Predict local stick contact immediately and send charge, direction, origin, and contact tick.
- Validate hits against a short host-side history of player, blade, and ball transforms.
- Use lag-compensated stick sweeps rather than a current-frame distance check.
- Add explicit possession-acquired and possession-rejected events.
- Apply a short visual possession lease while guest pickup validation is pending.
- Keep scoring fully host-authoritative while allowing immediate predicted goal presentation.

### Exit criteria

- Guest pickups appear immediate and remain stable when confirmed.
- Passes and shots visibly begin locally.
- The ball does not jump between blade sockets and stale network positions.
- Guest slap contact behaves consistently at 150 ms RTT and 2% packet loss.
- Predicted goals display immediately and reconcile cleanly with host confirmation.

## Later milestones

After milestones 1-4 meet their quality gates:

1. Build a shared humanoid skeleton and authored locomotion/slap-shot animation set.
2. Integrate locomotion blend spaces, action states, upper-body layers, and hand IK through `AnimationTree`.
3. Improve broadcast camera behaviour, lighting, materials, effects, audio, and player readability.
4. Profile and optimise skeletons, animation resources, materials, effects, and packet budgets for web/mobile.

## Validation matrix

Every networking milestone should be exercised against this minimum matrix:

| Scenario | RTT | Loss | Jitter | Expected result |
| --- | ---: | ---: | ---: | --- |
| Local baseline | 0 ms | 0% | 0 ms | Identical solo/host/guest simulation traces |
| Good connection | 50 ms | 0% | 5 ms | Corrections are effectively invisible |
| Typical remote connection | 100 ms | 1% | 15 ms | Responsive movement and stable possession |
| Quality gate | 150 ms | 2% | 30 ms | Fully playable with no routine snaps or ball jumps |
| Degraded connection | 250 ms | 5% | 60 ms | Degradation is understandable and recoverable |

## Delivery order

1. Diagnostics and baseline capture.
2. Shared command and simulation path.
3. Local handling vertical slice.
4. Guest command replay and correction policy.
5. Explicit ball/possession state and action events.
6. Predicted pickup, pass, shot, and goal presentation.
7. Rigged-player and animation vertical slice.
8. Full-team migration and presentation polish.
