# Floorball Frenzy 3D — Godot Port Plan

## Product direction

Floorball Frenzy 3D should feel like a toy-sports broadcast: fast, readable, physical, and slightly chaotic. The match remains a compact 1v1 arcade game, but the rink becomes a miniature arena viewed from above and from one long side.

The port is not a literal recreation of the Phaser scene. It preserves the proven rules and feel, then rebuilds the presentation and code boundaries for Godot.

### Experience goals

- A player understands the rink, teams, ball, and attacking direction at a glance.
- Movement, dribbling, shooting, dashing, and rebounds feel responsive before visual polish is added.
- Real ball height matters: lifted shots visibly rise, clear sticks and players, strike the goal frame, and land.
- Matches feel exciting through anticipation, impact, and celebration rather than visual clutter.
- The game remains suitable for landscape mobile play and later online multiplayer.

## Visual concept: tabletop arena broadcast

Use a stylised miniature-sports look rather than realism. Players have chunky proportions and oversized floorball sticks. The rink has clean geometry, strong team colours, and a dark surrounding arena that makes the playing surface read clearly.

### Camera

Start with a perspective camera above one long side of the rink:

- Look toward the rink centre at roughly a 35–45 degree downward angle.
- Rotate around the vertical axis roughly 8–15 degrees off the rink's long axis so depth is visible without making the goals hard to read.
- Keep both goals visible for the first prototype; use a mild dynamic zoom only after gameplay is proven.
- Use a narrow-to-medium field of view (about 35–45 degrees) to create a miniature-diorama feel and reduce perspective distortion.
- Place near-side boards below the players on screen or fade/cut them so they never obscure play.
- Keep screen-space team orientation stable: red attacks right and blue attacks left.

The first camera test should compare three presets using the same greybox rink:

1. **Broadcast** — balanced height and side angle; recommended default.
2. **Toy box** — higher angle and narrower FOV; maximum tactical readability.
3. **Action** — lower and closer; more dramatic, but likely too occluded for the full match.

### Art language

- Rounded, chunky, low-poly silhouettes with subtle outlines or rim lighting.
- Pale sport-court floor, white boards, dark arena surround, saturated red/blue teams.
- Orange perforated floorball large enough to track on a phone screen.
- Soft baked-looking lighting plus strong contact shadows beneath players and ball.
- Sparse audience silhouettes, banners, score lights, and bench props outside the rink.
- Effects communicate mechanics: dash streak, charge arc, perfect-shot flash, ball trail, impact burst, and short goal celebration.

Avoid detailed realistic human characters in the first pass. Capsule-based players with expressive lean, stick motion, and squash/stretch will prove the game faster and read better at this camera distance.

## Gameplay model

### Preserve from the current game

- 1v1 matches and five-goal win condition.
- Fixed 60 Hz gameplay simulation.
- Acceleration, maximum speed, friction, and soft player collisions.
- Aim smoothing and a stick interaction point.
- Possession assist and side-to-side dribble motion.
- Hold/release charged shot with lift.
- Perfect-shot, one-touch, dash/steal, heat, En Fuego, scoop, bolt, and parry concepts.
- Local player-versus-AI mode before online play.
- Host-authoritative networking as the eventual online model.

### Change for 3D

- Use metres, not pixels. The rink's gameplay plane is Godot XZ; Y is height.
- Make the ball a true 3D state (`position`, `velocity`) but keep player movement planar.
- Treat player and ball simulation as game code with explicit collision tests, rather than relying entirely on nondeterministic rigid-body behaviour.
- Use Godot collision shapes for queries and presentation support, while authoritative movement and ball response remain controlled by the simulation.
- Give goal frames, boards, rounded corners, and ball height explicit collision rules.
- Separate simulation transforms from smoothed visual transforms so networking can be added without rewriting presentation.

## Platform and deployment strategy

Treat web support as a first-class constraint from the beginning, not a later port.

- Use **GDScript**, not C#. Godot 4 C# projects cannot currently export to the web, while GDScript supports web, Android, iOS, and desktop from one project.
- Use Godot's **Compatibility renderer**. Godot 4 web exports require WebGL 2.0 and do not support the Forward+ or Mobile renderers.
- Make a **single-threaded web export** the default browser build. It has fewer hosting requirements and better compatibility with macOS, iOS, itch.io, and web game portals.
- Offer the browser version as a **Progressive Web App** so it can be installed to a phone home screen and cached for offline startup after its first load.
- Produce native Android and iOS builds from the same project when store distribution or better performance is worthwhile. Native mobile exports will outperform the browser build.
- Keep assets, shaders, particles, lights, and post-processing within a mobile-WebGL budget from the greybox phase onward.

The easiest initial release path is a static web export deployed over HTTPS. The export produces an HTML entry point plus WebAssembly and data files, so it can be hosted by a normal static host. Native packages can be added without changing gameplay architecture.

### Platform quality targets

| Target | Role | Initial target |
|---|---|---|
| Mobile browser/PWA | Instant shareable version | 60 fps on a representative mid-range phone; graceful 30 fps fallback |
| Android native | Best Android experience | 60 fps, Play Store-ready AAB later |
| iOS native | Best iPhone/iPad experience | 60 fps; exported and signed on macOS |
| Desktop browser | Development and easy sharing | 60 fps at 1280x720 and 1920x1080 |

Browser-specific constraints must be tested early: audio requires an initial user gesture, inactive tabs pause processing, persistent local storage depends on browser policy, and mobile Safari deserves its own test pass. WebRTC is available in Godot web exports, so the intended peer-to-peer multiplayer architecture remains viable, but tab suspension and reconnection need explicit handling.

## Godot architecture

The existing Godot 4.7 project is a suitable base, but it should be converted from its empty C# shell to GDScript before gameplay implementation begins. Typed GDScript keeps the simulation data explicit while preserving all intended export targets.

```text
res://
  assets/
    audio/
    materials/
    models/
    textures/
  scenes/
    app/Main.tscn
    match/Match.tscn
    rink/Rink.tscn
    actors/Player.tscn
    actors/Ball.tscn
    props/Goal.tscn
    ui/MatchHud.tscn
  scripts/
    simulation/
      match_simulation.gd
      simulation_constants.gd
      player_simulation.gd
      ball_simulation.gd
      collision_solver.gd
      input_frame.gd
      match_state.gd
    presentation/
      match_presenter.gd
      player_presenter.gd
      ball_presenter.gd
      broadcast_camera.gd
    gameplay/
      local_input_source.gd
      simple_ai_input_source.gd
      match_flow.gd
    tests/
```

### Scene responsibilities

- `Main`: application boot and mode selection.
- `Match`: owns match flow, simulation clock, input sources, presenters, camera, and HUD.
- `Rink`: visual mesh plus authored collision/layout data.
- `Player`: visuals, animation, stick, shadow, and effects; it does not decide gameplay state.
- `Ball`: mesh, shadow, trail, and impact effects; it reads simulation state.
- `MatchSimulation`: pure fixed-step state transition that can be tested without loading a scene.

### Coordinate conversion

The Phaser rink is approximately 37.9 m by 18.6 m, already based on 28 pixels per metre. Port constants by converting pixels to metres, then retune feel in-engine:

- Player radius: about 0.71 m.
- Ball radius: visual size may be exaggerated; collision radius starts near 0.12 m rather than the old pixel-derived 0.36 m.
- Stick reach: about 1.7 m from player centre.
- Goal-line inset: 3 m.
- Rounded corner radius: 1.5 m.

Do not blindly convert velocity constants. Establish a reference traversal time (for example, centre to goal in about 1.2–1.5 seconds at full speed) and tune acceleration, dash, and shot speed around that target.

## Port map

| Phaser/TypeScript | Godot/GDScript destination | Approach |
|---|---|---|
| `types/game.ts` | `MatchState`, `InputFrame` | Port first; keep data-only |
| `physics/constants.ts` | `SimulationConstants` | Convert to metres and seconds |
| `playerPhysics.ts` | `PlayerSimulation` | Direct behavioural port, then retune |
| `ballPhysics.ts` | `BallSimulation` | Replace pseudo-Z with true Y height |
| `collision.ts` | `CollisionSolver` | Explicit planar/height-aware solver |
| `shooting.ts` | `ShotSystem` or simulation methods | Preserve charge/perfect-shot rules |
| `simpleAI.ts` | `SimpleAiInputSource` | Port after local controls |
| `GameScene.ts` | Multiple match/presenter/UI classes | Do not port the monolith |
| `OnlineGameScene.ts` | Later network session layer | Defer until local vertical slice is fun |
| `VirtualJoystick`/`ActionButtons` | Godot `Control` scenes | Add after desktop input feels right |

## Delivery phases

### Phase 0 — visual and scale proof

Build one greybox scene containing the rink, boards, two capsule players, sticks, ball, goals, lighting, and the three camera presets.

Success criteria:

- Entire playable rink is understandable at 1280x720 and a representative phone resolution.
- The ball remains visible everywhere, including along the near boards.
- Goals and attacking directions are unambiguous.
- One chosen camera becomes the locked baseline for the vertical slice.
- The same scene runs in a local mobile-browser web export using the Compatibility renderer.

### Phase 1 — playable local vertical slice

Implement fixed-step simulation, one human player, simple AI, planar movement, dribbling, charged lifted shots, walls, goals, scoring, and resets. Use primitive art and keyboard/gamepad input.

Success criteria:

- A complete first-to-five match is playable without editor intervention.
- Movement and aiming are independent enough for intentional shots.
- Ball lift, landing, goal height, boards, and goal frame behave consistently.
- Pure simulation tests cover movement, wall/corner response, shot release, and scoring.

### Phase 2 — game feel and identity

Add authored player models, animation, stick poses, shadows, trails, hit effects, camera impulses, audio, crowd reactions, HUD, replay-like goal beat, and the signature mechanics in small increments.

Prioritise feedback in this order:

1. Contact and shot timing.
2. Ball readability and height.
3. Dash and possession state.
4. Scoring celebration.
5. Heat and special-shot states.

### Phase 3 — mobile controls, deployment, and performance

Add landscape touch controls, safe-area-aware UI, quality settings, PWA configuration, repeatable web export, and mobile profiling. Target a stable 60 fps; reduce shadow count, particles, transparent surfaces, and crowd detail before compromising gameplay readability. Validate Android and iOS native exports from the same project.

### Phase 4 — online play

Port signaling and WebRTC only after the local simulation state and input schema stabilise. Retain host authority, input sequence numbers, interpolation buffers, and visual smoothing. Decide export targets before committing to a Godot WebRTC transport implementation; web, desktop, and mobile have different constraints.

## First implementation backlog

Each item should leave the project runnable and be committed separately.

1. Add repository guidance, ignore rules, and a minimal `Main.tscn` that boots cleanly.
2. Add the greybox rink at real-world scale with floor, rounded boards, markings, and goals.
3. Add camera presets and a debug switch; select the baseline using desktop and phone screenshots.
4. Add data-only match state and constants with unit tests.
5. Add fixed-step player movement and one capsule presenter.
6. Add second player, planar player collision, and keyboard/gamepad input mapping.
7. Add ball flight, gravity, floor bounce, wall/corner collision, and shadow.
8. Add stick aim, control range, dribble assist, and shot charging/release.
9. Add goal-frame collision, scoring, round reset, and first-to-five flow.
10. Port the simple AI and complete a local match.
11. Add HUD and three essential feedback effects: shot, dash, and goal.
12. Playtest and retune traversal, possession, shot speed, lift, camera, and ball visibility before porting extra mechanics.

## Early decisions and risks

- **Target platforms:** web/PWA, Android, and iOS are first-class targets. GDScript and the Compatibility renderer are required baselines.
- **Mobile browser performance:** Godot WebAssembly is slower than native mobile builds. Maintain low/medium quality profiles and test physical phones continuously.
- **Rendering limits:** Forward+ features cannot be used on web. Art direction must work under WebGL 2.0 and Compatibility rendering.
- **Camera occlusion:** the near boards and near-side player can hide the ball. Solve this in the greybox phase with board treatment, camera height, and ball indicators.
- **Physics determinism:** using `RigidBody3D` as the authority would make prediction and reconciliation harder. Keep an explicit simulation state.
- **Scope:** do not port menus, lobby, tutorial, PWA behaviours, or every special mechanic before the local match is fun.
- **Readability:** physically accurate floorball scale can make the ball and stick too small. Visual scale may be exaggerated independently from collision scale.

## Recommended first milestone

The first milestone is a **greybox camera-and-feel prototype**, not a menu or a networking spike. It should answer the riskiest question: does Floorball Frenzy remain readable and exciting from the elevated side perspective?

Deliverable: a runnable Godot scene where one capsule player can move and aim around a complete rink, with a visible ball and instant switching among the three camera presets. This creates the foundation for the simulation port without committing to final art.
