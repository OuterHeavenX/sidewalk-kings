# Mobile and touch controls

The browser build is meant to be playable on a phone, not merely to load on one.

---

## Layout

```
┌─────────────────────────────────────────────┐
│ Lv 3                 ⏸               $240   │
│ ████████████                                │
│ ██████                                      │
│                                             │
│                    (game)                   │
│                                             │
│                                    ● special│
│                              ● heavy        │
│      ╭───╮                        ● light   │
│      │ ● │                     ● jump       │
│      ╰───╯                  ● grab          │
└─────────────────────────────────────────────┘
```

- **Virtual stick, lower left.** Anywhere on the left half of the screen starts it, so
  there is no need to find a fixed pad. Pushing to the edge is running.
- **Five action buttons on an arc, lower right**, positioned so a thumb sweeps between
  them: jump, light, heavy, special, grab.
- **Pause at top centre**, clear of the vitals on the left and the money on the right.

The whole cluster scales with viewport height and every button is clamped inside the
screen, so an unusual aspect ratio cannot push a control off the edge.

---

## Multitouch

Each control tracks its **own touch index**, which is what makes moving and attacking at
the same time work:

```gdscript
var _stick_touch: int = -1          # which finger owns the stick
var _button_touch: Dictionary = {}  # touch index -> action name
```

`_touch_down` claims an index for whichever button was hit, or for the stick. `_touch_move`
only moves the stick if the index matches. `_touch_up` releases just that one control.

A single shared pointer would make the game unplayable: every attack would drop movement.

Button presses are injected as `InputEventAction`, so touch, keyboard and gamepad all reach
exactly the same code in `Player`. There is no separate touch input path to keep in sync.

The stick reads through `TouchControls.move_vector`, a static field, so `Player` does not
have to look the node up.

---

## The sliding stick

If a drag goes beyond the stick's radius, the origin follows the finger instead of pinning
at the rim:

```gdscript
if mag > r:
    _stick_origin = p - delta.normalized() * r
```

Without this, a thumb that drifts during a long walk ends up fighting the deadzone. With
it, the stick stays under the thumb.

---

## Safe areas

Notches, rounded corners and home indicators are handled in `_safe_insets()`.

`DisplayServer.get_display_safe_area()` reports **screen** coordinates, and on desktop
describes the whole monitor. Trusting it there produced negative padding that pushed the
controls off screen. It is now only used when:

- the platform actually has cutouts (`mobile`, `web_android`, `web_ios`), **and**
- the reported rect fits inside the window,

and the resulting insets are clamped to at most 20% of the viewport.

The HTML shell contributes the other half: `viewport-fit=cover` on the viewport meta plus
`env(safe-area-inset-*)` so the canvas reaches the screen edges while the controls stay
inside the usable area.

---

## When the controls appear

Touch controls show up automatically the first time a touch event arrives, and on any
platform that reports a touchscreen. They hide during menus, shops and the pause screen,
and reappear during gameplay and dialogue so a conversation can still be advanced by
tapping.

They can also be forced on or off from **Pause → Settings**, which is useful for testing on
a desktop browser and for touchscreen laptops where autodetection is ambiguous.

---

## Preventing the browser from interfering

Handled in `web/shell.html`:

| Problem | Fix |
|---|---|
| Pinch-zoom during a fight | `user-scalable=no`, `gesturestart/change/end` prevented |
| Double-tap zoom | `touch-action: none` on body and canvas |
| Long-press context menu | `contextmenu` prevented |
| Pull-to-refresh | `overscroll-behavior: none` |
| Page scrolling on arrows or space | `keydown` prevented for those keys |
| Text selection on drag | `user-select: none` |
| Blue tap highlight | `-webkit-tap-highlight-color: transparent` |
| Canvas resizing as the URL bar hides | `resize`, `orientationchange` and `visualViewport` listeners re-sync the drawing buffer |

---

## Screen sizes

The game renders at 480×270 and stretches with `canvas_items` + `expand`. Wider screens see
more of the street rather than black bars, and taller ones see more sky and pavement.

| Device | Result |
|---|---|
| 16:9 desktop | Reference framing |
| 16:10 desktop | Slightly more vertical view |
| 4:3 | Narrower view, fully playable |
| Tablet landscape | Comfortable, controls near the corners |
| Tablet portrait | Playable; the street is narrower and the controls scale down |
| Phone landscape | The intended mobile experience |
| Phone portrait | Playable but cramped; landscape is much better |

Landscape is preferred, and `window/handheld/orientation` requests it, but portrait is not
broken.

---

## Performance on mobile

- Compatibility renderer (WebGL 2), which is the right target for phone browsers.
- No shaders beyond default canvas material.
- Particles are short-lived sprite strips that free themselves, not `GPUParticles`.
- Enemy counts are capped per encounter by `EncounterData.max_active`, typically three or
  four.
- Ground tiles are plain `Sprite2D` regions from one atlas, built once per area.

---

## Not yet done

- No haptics. `Input.vibrate_handheld()` on hit would help and is not wired up.
- Button positions are fixed. A left-handed layout option would be worth adding.
- Touch input has been verified through the browser's touch emulation and the mobile
  layout path, not on a physical phone.
