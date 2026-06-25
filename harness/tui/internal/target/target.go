// Package target describes each supported emulation target (ISA + QEMU board)
// in one place, so the rest of the harness runner stays ISA-agnostic. ARM
// Cortex-M4 (mps2-an386) is the default; RISC-V rv32 (virt) is the second
// target. It is a leaf package (no internal imports) to avoid import cycles.
package target

import (
	"fmt"
	"strings"
)

// Profile captures everything ISA/board-specific the runner needs: how to
// launch QEMU, which ELF suffix names the firmware, how to talk to the GDB
// stub, and which general-purpose registers the fuzz plugin may target.
type Profile struct {
	Name         string   // short id, e.g. "m4", "rv32"
	ELFSuffix    string   // firmware filename suffix (matches build.zig output)
	QemuBinary   string   // qemu-system-arm | qemu-system-riscv32
	Machine      string   // -M value: mps2-an386 | virt
	CPU          string   // -cpu value: cortex-m4 | rv32
	ExtraQemu    []string // extra QEMU args (riscv virt needs -bios none)
	GdbArch      string   // gdb "set architecture" value (e2e path)
	EntrySymbols []string // candidate entry symbols for TextRange bounding
	GPRegisters  []string // GP registers the reg-bitflip mode may flip
}

// profiles is the registry of supported targets.
var profiles = map[string]Profile{
	"m4": {
		Name:         "m4",
		ELFSuffix:    "m4",
		QemuBinary:   "qemu-system-arm",
		Machine:      "mps2-an386",
		CPU:          "cortex-m4",
		GdbArch:      "armv7e-m",
		EntrySymbols: []string{"_start", "Reset_Handler"},
		// ARM general registers r0-r12 (excludes sp/lr/pc).
		GPRegisters: []string{
			"r0", "r1", "r2", "r3", "r4", "r5", "r6",
			"r7", "r8", "r9", "r10", "r11", "r12",
		},
	},
	"rv32": {
		Name:         "rv32",
		ELFSuffix:    "rv32",
		QemuBinary:   "qemu-system-riscv32",
		Machine:      "virt",
		CPU:          "rv32",
		ExtraQemu:    []string{"-bios", "none"},
		GdbArch:      "riscv:rv32",
		EntrySymbols: []string{"_start"},
		// RISC-V writable integer registers worth faulting: ra, the temporaries,
		// argument and saved registers. Excludes the hardwired x0 (zero) and the
		// pointer registers sp/gp/tp/fp whose corruption is uninformative.
		GPRegisters: []string{
			"ra", "t0", "t1", "t2",
			"a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
			"s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
			"t3", "t4", "t5", "t6",
		},
	},
}

// Names lists the supported target ids (for CLI enums / TUI selects).
var Names = []string{"m4", "rv32"}

// Default is the target used when none is specified.
const Default = "m4"

// Get returns the profile for a target id.
func Get(name string) (Profile, error) {
	p, ok := profiles[name]
	if !ok {
		return Profile{}, fmt.Errorf("unknown target %q; expected one of: %s",
			name, strings.Join(Names, ", "))
	}
	return p, nil
}
