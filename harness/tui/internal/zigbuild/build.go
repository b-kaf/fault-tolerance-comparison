// Package zigbuild runs the `zig build` steps that produce the harness ELFs,
// replacing the `zig build harness` / `zig build fuzz-harness` calls the old
// devenv scripts ran before every campaign.
package zigbuild

import (
	"bufio"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Target is a `zig build` step name.
type Target string

const (
	TargetE2E  Target = "harness"
	TargetFuzz Target = "fuzz-harness"
)

// TargetForMode maps a TUI mode ("e2e"/"fuzz") to its zig build step.
func TargetForMode(mode string) Target {
	if mode == "fuzz" {
		return TargetFuzz
	}
	return TargetE2E
}

// Run executes `zig build <target>` from repoRoot, invoking onLine for each
// line of combined stdout/stderr. Cancelling ctx kills the build.
func Run(ctx context.Context, repoRoot string, target Target, onLine func(string)) error {
	cmd := exec.CommandContext(ctx, "zig", "build", string(target))
	cmd.Dir = repoRoot

	pipe, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	cmd.Stderr = cmd.Stdout // merge stderr into the same pipe

	if err := cmd.Start(); err != nil {
		return err
	}

	scanner := bufio.NewScanner(pipe)
	for scanner.Scan() {
		if onLine != nil {
			onLine(scanner.Text())
		}
	}
	return cmd.Wait()
}

// sourceExtensions are the harness source file kinds that, when newer than a
// built ELF, mean the ELF is stale.
var sourceExtensions = map[string]bool{
	".zig": true,
	".c":   true,
	".h":   true,
	".s":   true,
	".ld":  true,
}

// IsELFStale reports whether any harness source file is newer than the ELF, a
// heuristic used to warn before a run. A missing ELF counts as stale. Errors
// walking the tree are treated as "not stale" — the warning is best-effort.
func IsELFStale(repoRoot, elfPath string) bool {
	info, err := os.Stat(elfPath)
	if err != nil {
		return true // missing or unreadable: needs a build
	}
	elfTime := info.ModTime()

	stale := false
	harnessDir := filepath.Join(repoRoot, "harness")
	_ = filepath.WalkDir(harnessDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if !sourceExtensions[strings.ToLower(filepath.Ext(path))] {
			return nil
		}
		if fi, err := d.Info(); err == nil && fi.ModTime().After(elfTime) {
			stale = true
		}
		return nil
	})
	return stale
}
