package gdbmi

// Breakpoints holds the two hardware breakpoint numbers each technique drives:
// the injection point reached before a fault is written, and the observation
// point reached after the target acts on it.
type Breakpoints struct {
	Inject  string
	Observe string
}

// injectionSymbols maps a technique to its (inject, observe) injection-point
// symbols, mirroring the four install_*_breakpoints methods in gdbmi.py.
var injectionSymbols = map[string][2]string{
	"tmr": {
		"harness_injection_point_after_init",
		"harness_injection_point_after_read",
	},
	"checkpoint": {
		"harness_injection_point_after_mutation",
		"harness_injection_point_after_commit",
	},
	"recovery-block": {
		"harness_injection_point_before_recovery",
		"harness_injection_point_after_recovery",
	},
	"control-flow": {
		"harness_injection_point_before_control_flow",
		"harness_injection_point_after_control_flow",
	},
}

// InstallBreakpoints installs the inject/observe hardware breakpoints for a
// technique.
func (c *Client) InstallBreakpoints(technique string) (Breakpoints, error) {
	symbols, ok := injectionSymbols[technique]
	if !ok {
		return Breakpoints{}, &unknownTechniqueError{technique}
	}
	inject, err := c.InsertHardwareBreakpoint(symbols[0])
	if err != nil {
		return Breakpoints{}, err
	}
	observe, err := c.InsertHardwareBreakpoint(symbols[1])
	if err != nil {
		return Breakpoints{}, err
	}
	return Breakpoints{Inject: inject, Observe: observe}, nil
}

type unknownTechniqueError struct{ technique string }

func (e *unknownTechniqueError) Error() string {
	return "unknown technique: " + e.technique
}
