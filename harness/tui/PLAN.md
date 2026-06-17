# Harness TUI — Plan

Replace `harness/e2e/injector/` (562 LOC Python) and `harness/fuzz/runner/` (652 LOC Python across 7 files), plus the shared `harness_shared` package (498 LOC), with a single Go TUI built on bubbletea / bubbles / lipgloss.

Decisions already locked in (from the architecture questions):

- **Full port** — no Python at runtime. Single static Go binary.
- **One TUI, mode toggle** — top-level switch between E2E Injector and Fuzz Runner.
- **Run-to-completion UX** — progress bar + spinner during the run, results table populates from the in-memory rows after the run finishes. No streaming row updates.
- **GDB/MI via `github.com/cyrus-and/gdb`** — no hand-rolled MI parser. A thin wrapper adds the timeout behaviour pygdbmi gave us (see §3).
- **Headless mode ships** — dedicated `e2e` / `fuzz` subcommands (kong-based CLI) drive each engine without the TUI, preserving the Python CLIs' exit codes (e2e: exit 1 if the final row has `failures != 0`, exit 2 on usage/run errors) and the stdout-CSV default for CI. A bare `harness-tui` (no subcommand) opens the TUI.
- **Rebuild from the TUI** — a `[Rebuild]` action runs `zig build harness` / `zig build fuzz-harness` for the current mode, output surfaced in the status area. The devenv scripts ran this before every campaign; without it a stale ELF is a silent footgun (the CLIs only check the file exists).
- **Export on demand** — a TUI run never touches the disk; results stay in memory until the `[Export]` action opens a prompt pre-filled with an auto-named path (`results/{mode}-{technique}-{language}-{campaign}-{timestamp}.csv`), which the user accepts or edits before writing. Headless writes the CSV itself, keeping stdout when `--csv` is omitted (CLI parity).

---

## 1. Scope of what gets ported

### 1.1 From `harness/e2e/injector/`

- `main.py` (562 LOC) — argparse, env loading, technique/campaign dispatch tables, fault chooser callables, the per-iteration QEMU+GDB loop, row construction.
- `injector/gdbmi.py` (195 LOC) — pygdbmi wrapper. Reimplemented as a thin wrapper around `cyrus-and/gdb` (timeouts, stop-wait channel, `read_u32`/`write_u32` helpers).
- The hard-coded constants (`FAULT_*`, `CONTROL_PHASE_COMMIT`, the four `*_CAMPAIGNS` tables, the four `*_MIXED_ORDER` rotations, the `*_SAMPLE_CHOICES` tuples).

### 1.2 From `harness/fuzz/runner/`

- `main.py` (274 LOC) — argparse, env loading, manifest write per trial, QEMU+plugin spawn, done-flag polling, raw-result parse, classify, row emit.
- `campaigns.py` (65 LOC) — `Campaign` dataclass, the three campaign specs, `derive_trial_seed` (Blake2b, `digest_size=8`, `person=b"ft-single"`, little-endian u64, zero fallback `0x9E3779B97F4A7C15` — see the Blake2b dependency note in §3).
- `classification.py` (77 LOC) — 9-way trial classifier. Port 1:1 and reuse `classification_test.py` cases as Go table tests for parity.
- `manifest.py` (58 LOC) — manifest text format (`key=value` lines, `sym.NAME=0xADDR:0xSIZE`).
- `runner.py` (94 LOC) — QEMU subprocess + 5s done-flag poll loop + `ProcessResult`.
- `symbols.py` (104 LOC) — `llvm-nm` output parsing. **Replace with `debug/elf` from the Go stdlib** so we drop the `llvm-nm` external dep entirely.

### 1.3 From `harness/common/python/harness_shared/`

- `support.py` (76 LOC) — `find_repo_root`, `qemu_mps2_an386_command`, `terminate_process`, `positive_int`, `parse_u64`.
- `result_format.py` (422 LOC) — **the load-bearing one.** All CSV column orderings, the per-technique field maps, `_FAULT_NAMES`, `_STAGE_NAMES`, `_TMR_STATUS_NAMES`, etc., plus `write_e2e_result_csv`, `open_fuzz_result_csv`, `format_fuzz_result_row`. Names and column order must match the existing CSVs so downstream analysis isn't broken. **Not ported (dead code):** `rewrite_e2e_result_csv` has no callers, and the `_E2E_PLUGIN_FIELDS` branch in `_selected_e2e_fields` only triggers on rows with `seed`/`fault_mode` keys, which the e2e injector never sets. Drop both; in Go the dict-presence field discovery collapses to fixed per-technique column lists.
  - Formatting parity details for the golden-CSV diffs: seeds are written `0x%016x`, `timeout` as `0`/`1`, everything else decimal; `format_fuzz_result_row` lets unknown fact keys pass through but `DictWriter(extrasaction="ignore")` drops them — `encoding/csv` has no equivalent, so the Go writer must project rows onto the field list explicitly.

### 1.4 Devenv glue

- `devenv.nix` currently defines `harness-campaign` and `harness-fuzz-campaign` scripts that `uv run` the Python CLIs. Replace both with a single `harness-tui` script that builds the Go binary (or runs `go run`) and exec's it. The QEMU plugin path (`QEMU_FT_FUZZ_PLUGIN=${qemuFtFuzzPlugin}/lib/qemu-ft-fuzz.so`) still needs to be wired in.
- Drop `pkgs.uv` and `pkgs.llvmPackages.bintools` from `devenv.nix` once the Python CLIs are gone (`llvm-objdump` is still used by `harness-asm`, so keep the bintools package). Verify before removing.

---

## 2. Module layout

```
harness/tui/
  go.mod
  go.sum
  cmd/
    harness-tui/
      main.go                 # entry: parses flags, starts bubbletea program
  internal/
    config/
      config.go               # env loading (.env files), defaults, RunConfig
      paths.go                # repo root discovery, ELF path inference
    elf/
      symbols.go              # debug/elf-based symbol table + text-range
    qemu/
      qemu.go                 # mps2-an386 command builder, process lifecycle
    gdbmi/
      client.go               # cyrus-and/gdb wrapper: timeouts, stop-wait, read/write u32
      breakpoints.go          # per-technique breakpoint installer
    zigbuild/
      build.go                # runs `zig build harness|fuzz-harness`, streams output
    e2e/
      campaigns.go            # FAULT_* constants, per-technique campaign tables
      fault.go                # campaign → (fault_target, fault_value) chooser
      engine.go               # per-iteration loop: continue, read, choose, write, continue, read
      row.go                  # per-technique row dict construction
    fuzz/
      campaigns.go            # Campaign struct, the three specs, derive_trial_seed
      manifest.go             # write_manifest mirror
      runner.go               # QEMU+plugin per-trial loop, done-flag poll
      classify.go             # classify_trial port
      classify_test.go        # Go table tests mirroring classification_test.py
    result/
      e2e_csv.go              # write_e2e_result_csv mirror (per-technique columns)
      fuzz_csv.go             # 31-column fuzz schema
      names.go                # _FAULT_NAMES, _STAGE_NAMES, status maps
    tui/
      model.go                # bubbletea top-level model (mode, sub-models)
      mode.go                 # E2E ↔ Fuzz toggle pane
      form_e2e.go             # bubbles textinput/select for E2E config
      form_fuzz.go            # bubbles textinput/select for fuzz config
      actions.go              # Start / Stop / Rebuild / Export / Clear bar
      results.go              # bubbles/table for results
      styles.go               # lipgloss styles, layout primitives
      progress.go             # bubbles/progress for run-in-flight feedback
      keymap.go               # key bindings
```

Module path: `github.com/b-kaf/fault-tolerance-comparison/harness/tui` (matches the git remote).

---

## 3. Dependencies

| Need | Choice | Notes |
|---|---|---|
| TUI runtime | `github.com/charmbracelet/bubbletea` | required |
| TUI widgets | `github.com/charmbracelet/bubbles` | textinput, table, progress, spinner, viewport, help |
| Styling | `github.com/charmbracelet/lipgloss` | required |
| GDB/MI | `github.com/cyrus-and/gdb` | Dormant since ~2022 but tiny, zero open issues, and the surface we need is stable: token-sequenced `Send`/`CheckedSend` matched to result records, notification callback for async `*stopped`. Use `NewCmd` (skips the pty path — our target is QEMU over TCP, no TTY needed). Wrapper covers the gaps: (1) `Send` has no timeout — wrap in goroutine + `select` with timer, kill the gdb process on expiry (reproduces pygdbmi's `connect_timeout`/`stop_timeout`); (2) no raw CLI commands — `set architecture armv7e-m` and the `write_u32` `set {unsigned int}&sym = val` both go through `-interpreter-exec console`, which is MI; (3) route `*stopped` notifications into a channel for `continue_until_breakpoint`'s stop-wait. |
| ELF parsing | `debug/elf` (stdlib) | Replaces the `llvm-nm` subprocess. |
| Blake2b | `github.com/dchest/blake2b` | **Not `x/crypto/blake2b`**: `derive_trial_seed` uses `digest_size=8` + `person=b"ft-single"`, and x/crypto doesn't expose personalization. Both are baked into the BLAKE2b parameter block, so truncating a 512-bit digest can't emulate it — x/crypto would silently produce different trial seeds for every fuzz trial. `dchest/blake2b` exposes `Config{Size, Person}`. Verify seed parity against Python in a unit test. |
| .env loading | `github.com/joho/godotenv` | Mirrors `python-dotenv` semantics (override=false). |
| Process control | `os/exec` + `syscall` | For SIGTERM-then-SIGKILL behaviour matching `terminate_process`. |

No third-party CSV lib — `encoding/csv` is fine.

---

## 4. TUI structure

Single column, three vertically-stacked panes, controlled by a global keymap.

```
┌─ Mode ───────────────────────────────────────────────────────┐
│  [ E2E Injector ]   Fuzz Runner       tab ⇄                  │
├─ Configuration ──────────────────────────────────────────────┤
│  Technique  : tmr            ▾                               │
│  Language   : zig            ▾                               │
│  Campaign   : mixed          ▾   ← choices reload on         │
│  Iterations : 20                   technique change          │
│  (Env)      HARNESS_E2E_GDB_PORT=1234  STOP_TIMEOUT=10.0     │
├─ Actions ────────────────────────────────────────────────────┤
│  [Start]  [Stop]  [Rebuild]  [Export]  [Clear]  [Quit]       │
│  status: running iteration 7 / 20   ▓▓▓▓▓▓▓░░░░░             │
├─ Results ────────────────────────────────────────────────────┤
│ iter│technique│campaign│result│stage_name│fault_name│value   │
│   1 │ tmr     │ mixed  │ pass │ after_read│ none     │0x...  │
│   2 │ tmr     │ mixed  │ fail │ after_read│ copy_a   │0x...  │
│   …                                                          │
└──────────────────────────────────────────────────────────────┘
```

Behavioural notes:

- **Mode pane**: arrow keys or `tab` flips mode. Switching mode discards the in-memory results table.
- **Configuration pane**: tab cycles inputs; enums use `bubbles/list` or a custom select; numeric inputs use `bubbles/textinput` with validators. The campaign choices list is **derived from the selected technique** in E2E mode, matching the validation matrix in the Python CLI. Defaults come from `.env`/env vars at startup.
- **Actions bar**: Start kicks off a goroutine that drives the engine; events are funneled to the bubbletea model via a channel (`tea.Cmd` returning messages). Stop sends cancellation. Rebuild runs the mode's `zig build` step (`harness` for E2E, `fuzz-harness` for fuzz) with stdout/stderr streamed into the status area; Start is disabled while a build is in flight. Export (enabled only when idle with results) opens a prompt pre-filled with an auto-named path; confirming writes the in-memory rows there, esc cancels. Clear empties the results table.
- **Progress**: `iteration X/N` (E2E) or `trial X/N` (fuzz). Final line: pass/fail counts (E2E) or result-class histogram (fuzz). Optional spinner while QEMU is starting/connecting.
- **Results pane**: `bubbles/table` with:
  - **E2E** columns vary by technique. Base columns always shown; technique-specific columns appended dynamically. The Python CSV format is the contract — column order matches `_FUZZ_CSV_FIELDS` / per-technique field lists in `result_format.py`.
  - **Fuzz** uses the fixed 31-column schema. **Caveat: `bubbles/table` has no native horizontal scrolling.** Ship a curated default column subset (trial_id, result_class, fault_mode, target_name, bit, process_status, elapsed_ms) with a key to toggle column pages; the full 31 columns always land in the CSV regardless.
  - Filtering by `result` / `result_class` is a stretch goal — leave a hook in the keymap but ship without it.

In the TUI, **Export is the only path to disk** — the engines no longer write CSVs (they return the collected rows), so a run leaves nothing on disk until you Export. The headless `e2e` / `fuzz` subcommands write the returned rows themselves. The engines still accumulate rows the same way internally, matching the Python behaviour: the fuzz runner collects one row per trial, and the e2e injector builds the full row sequence before the pass/failure deltas in `_clean_e2e_result_rows` are computed over it.

---

## 5. Concurrency model

The bubbletea model is single-threaded. The run engine is not. Pattern:

1. On `Start`, the model emits a `tea.Cmd` that:
   - Spawns a goroutine running the engine (E2E or Fuzz).
   - Returns a "subscription" `tea.Cmd` that reads from a buffered channel of `engineEvent`.
2. The engine emits events: `runStarted`, `iterationProgress{n, total}`, `iterationRow{row}`, `runFinished{summary, err}`.
3. The model updates progress UI on each event and appends to its internal `[]row` (even though the table isn't shown live, this lets `Export` work).
4. On finish, model rebuilds the bubbles/table model from `rows` and reveals the results pane.
5. Stop: model cancels the context the engine was created with; engine SIGTERMs the child QEMU/GDB processes. The engine still emits `runFinished` with the rows collected so far, so the table populates and Export works on partial runs — an improvement over the Python e2e injector, which discards all rows on abort.

This keeps the heavy lifting off the UI thread and gives a clean cancellation story.

---

## 6. Porting risks and how to manage them

| Risk | Plan |
|---|---|
| **GDB/MI client correctness** | `cyrus-and/gdb` owns the MI2 record parsing, but its parser still needs validating against our real traffic (`-break-insert` bkpt tuples, `*stopped` frames). Mitigation: capture `gdb --interpreter=mi2` transcripts from the existing Python flow (`script`) and replay them in wrapper unit tests. Also: `Send` has no timeout (wrapper adds one, see §3) and the library's record-reader goroutine panics on a read error — acceptable since that only fires on gdb dying mid-session, but recover it in the wrapper. |
| **Blake2b seed parity** | `derive_trial_seed` depends on BLAKE2b personalization (see §3). A wrong digest config silently changes every `trial_seed` and breaks reproducibility against historical runs. Mitigation: unit test pinning known (campaign_seed, trial_id, …) → seed pairs computed by the Python implementation. |
| **ELF parsing parity with `llvm-nm`** | `symbols.py` filters by NM kind letters (B/D/b/d for data, T/t for text-ish) and bounds .text via `__etext`/`_etext`/`__exidx_start` with a max-over-T/t fallback. `debug/elf` exposes section + symbol type/binding directly — equivalent but the predicates need translating. Add a parity test comparing the Go output against `llvm-nm` output on a representative ELF. |
| **CSV column drift** | Nothing in-repo consumes the CSVs (`research/` is papers only), but local notebooks/spreadsheets may. Mitigation: capture a "golden" CSV from each technique + the fuzz runner before starting, diff Go output against it during port (formatting details in §1.3). |
| **Classification logic correctness** | Port `classification_test.py`'s 10 cases to Go table tests verbatim — the cheapest safety net we have. The 9-way classifier has more edge interactions than 10 tests cover; add cases for the invalid-trial guards (`corrected` without `detected`, `corrected` with `output != expected`, `safe_state` without `detected`) while porting. |
| **QEMU + plugin process lifecycle on cancellation** | The Python code is careful with SIGTERM-then-wait-then-SIGKILL. The Go side needs the same; `os/exec` + a context with `CommandContext` gets us most of the way, but we may need `setpgid` to kill child trees. |
| **Devenv Nix integration** | The QEMU plugin is built by Nix; its path is injected via env var. The TUI binary needs the same `QEMU_FT_FUZZ_PLUGIN` env var, and the `harness-tui` devenv script needs to set it. |

---

## 7. Phasing

A suggested order — each phase is independently mergeable.

### Phase 1: skeleton
- `harness/tui/go.mod`, dependency pins, a `cmd/harness-tui/main.go` that prints "hello" and exits.
- `devenv.nix`: add a `harness-tui` script that runs `go run ./harness/tui/cmd/harness-tui`.

### Phase 2: shared core (no TUI yet)
- `internal/config/`, `internal/elf/`, `internal/qemu/`, `internal/result/`.
- A `cmd/harness-tui fuzz ...` headless subcommand that mimics the Python CLI exactly. This lets us validate the porting **before** building any UI.

### Phase 3: fuzz engine (no TUI)
- `internal/fuzz/` + the `fuzz` headless subcommand. Validate against the Python output on a fixed seed (CSVs should be byte-identical except for `elapsed_ms`).
- Port `classification_test.py` cases.

### Phase 4: e2e engine (no TUI)
- `internal/gdbmi/`, `internal/e2e/` + the `e2e` headless subcommand. Validate against the Python output for `none` and `clean-*` campaigns (deterministic) on a fixed iteration count.

### Phase 5: TUI shell
- `internal/tui/` model, mode pane, config pane, actions bar, progress. Wire Start to the engines from phases 3 & 4. Results pane still empty.
- `internal/zigbuild/` + the `[Rebuild]` action, with build output in the status area.

### Phase 6: results table
- `bubbles/table` with per-mode column sets. Populate from in-memory rows on `runFinished`.
- Export to user-specified path.

### Phase 7: cleanup
- Delete `harness/e2e/injector/`, `harness/fuzz/runner/`, `harness/common/python/`.
- Remove `pkgs.uv` (and review `llvmPackages.bintools`) from `devenv.nix`.
- Remove `harness-campaign` and `harness-fuzz-campaign` scripts.
- Update top-level `README.md` and `harness/README.md`.

---

## 8. Open questions for refinement

Resolved: headless mode ships (locked, see top); CSV auto-names under `results/` as the TUI Export default, stdout in headless (locked); module path is `github.com/b-kaf/fault-tolerance-comparison/harness/tui` (matches the git remote); nothing outside the two CLIs imports `harness_shared` (`research/` is papers only), so it gets deleted with the rest of the Python tree.

1. **Run history within a session**: queue multiple runs and compare? Or strictly one run at a time, replace results on Start? (My recommendation: one at a time for v1; add a "runs" pane later if needed.)
2. **Table column toggling / filtering**: ship v1 read-only with column pages, or add filter-by-result? (My recommendation: read-only v1.)
3. **Should we keep the Python tree on a branch** as a reference during the porting work, or just rely on git history? (My recommendation: rely on git.)
4. **`--config-file` support**: do we want to load a YAML/TOML config file in addition to .env + flags, so a saved campaign can be re-run? Could be a `[Save preset]` button in the TUI.

---

## 9. Out of scope (for now)

- Live row streaming during a run (decided against).
- Multi-host / distributed runs.
- Result diffing across runs.
- Re-running a single failed iteration / trial from the table.
- Replacing the `harness-asm` script in `devenv.nix` (that's a separate `llvm-objdump` invocation, unaffected).
