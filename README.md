# FPGA Digital Piano

Top-level entity: `piano_top` (Quartus project `piano.qpf`, DE1-SoC 5CSEMA5F31C6).

## Folder layout

| Folder | Contents |
|---|---|
| `rtl/` | Our design: `piano_top`, `note_control`, `tone_generator`, `vga_controller`, `piano_renderer`, `demo_player` |
| `ip/`  | Course audio IP copied from Audio_Demo (`Audio_Controller`, `avconf`, …) — don't edit |
| `sim/` | Testbenches + reference screenshots (`frame_mi.png`, `frame_sol.png`) |

## Block diagram (data flow)

```
SW[6:0] ──┐
          ├─ key_down[6:0] ─► note_control ─ active_note[2:0] ─┬─► tone_generator ─► Audio_Controller ─► codec
demo_player (SW9) ┘                                           ├─► piano_renderer ◄─ x,y ─ vga_controller ─► VGA
                                                               └─► HEX0 / LEDR
```

## Interface contract (don't change without telling each other)

- `key_down[6:0]`: level signal, 1 = key held. bit0 = Do (C4) … bit6 = Si (B4).
  Milestone 2's PS/2 decoder only has to produce this bus and replace `sw_keys` in `piano_top`.
- `active_note[2:0]`: 0 = silent, 1..7 = Do..Si. Newest pressed key wins; releasing it falls back to the lowest key still held.
- Notes: Do 261.63, Re 293.66, Mi 329.63, Fa 349.23, Sol 392.00, La 440.00, Si 493.88 Hz (square wave).

## Board controls (Milestone 1)

| Input/Output | Function |
|---|---|
| KEY[0] | reset |
| SW[0]..SW[6] | hold Do..Si |
| SW[9] | demo mode: plays "Twinkle Twinkle Little Star" (42 notes, 120 BPM) and loops; ignores SW[6:0] |
| LEDR[6:0] | keys held · LEDR[9:7] = active note number |
| HEX0 | note letter C d E F G A b, `-` when silent |

## Simulation status (Icarus Verilog, already passing)

- `tb_note_control.v` — press/release/overlap/fallback/reset: **PASS**
- `tb_tone_generator.v` — measured half-periods match all 7 notes exactly: **PASS**
- `tb_vga_frame.v` — 800 px/line, 525 lines/frame, 96 px h-sync, 640×480 visible, dumps `frame.ppm`: **PASS**

ModelSim: create a project with `rtl/*.v` + the testbench, run `vsim tb_note_control` → `run -all`.

## Milestone 1 board test checklist (teammate)

1. Compile `piano.qpf`, program `output_files/piano.sof`.
2. VGA: screen matches `sim/frame_mi.png` layout with no key lit after reset.
3. SW0..SW6 one at a time: correct key lights in its colour, bar appears above it, HEX0 shows the letter, tone pitch rises Do→Si.
4. Overlap: hold SW2, then SW5 → La plays; drop SW5 → back to Mi.
5. All switches off → silence, no key lit, HEX0 `-`.
6. SW9 on → Twinkle Twinkle Little Star plays (and loops); highlights track the sound.
7. Press KEY[0] during playback → resets to silence.
Record a short video of steps 3 and 6 for the milestone check-off.
