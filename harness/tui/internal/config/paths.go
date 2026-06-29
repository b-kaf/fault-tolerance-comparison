package config

import (
	"fmt"
	"os"
	"path/filepath"
)

// FindRepoRoot walks up from start looking for a .git entry, mirroring
// support.find_repo_root. The Python version walked up from __file__; the Go
// binary can live anywhere (go run builds into a temp dir), so callers pass
// the working directory.
func FindRepoRoot(start string) (string, error) {
	path, err := filepath.Abs(start)
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(path, ".git")); err == nil {
			return path, nil
		}
		parent := filepath.Dir(path)
		if parent == path {
			return "", fmt.Errorf("could not find repo root (no .git ancestor) from %s", start)
		}
		path = parent
	}
}

// HarnessOutputDir is where `zig build harness` / `zig build fuzz-harness`
// place the ELFs.
func HarnessOutputDir(repoRoot string) string {
	return filepath.Join(repoRoot, "zig-out", "harness")
}

// E2EElfPath infers the e2e harness ELF path from technique + language + target
// suffix (e.g. "m4", "rv32"), matching build.zig's output naming.
func E2EElfPath(repoRoot, technique, language, suffix string) string {
	name := fmt.Sprintf("%s-harness-%s-%s.elf", technique, language, suffix)
	return filepath.Join(HarnessOutputDir(repoRoot), name)
}

// FuzzElfPath infers the fuzz harness ELF path from technique + language + target
// suffix (e.g. "m4", "rv32"), matching build.zig's output naming.
func FuzzElfPath(repoRoot, technique, language, suffix string) string {
	name := fmt.Sprintf("%s-fuzz-harness-%s-%s.elf", technique, language, suffix)
	return filepath.Join(HarnessOutputDir(repoRoot), name)
}
