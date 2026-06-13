package e2e

// chooseTMRFault mirrors choose_tmr_fault: a named campaign uses its chooser,
// anything else rotates through the mixed order by iteration.
func chooseTMRFault(campaign string, iteration, expected uint32) fault {
	if chooser, ok := tmrCampaigns[campaign]; ok {
		return chooser(expected)
	}
	key := tmrMixedOrder[(iteration-1)%uint32(len(tmrMixedOrder))]
	return tmrCampaigns[key](expected)
}

func chooseCheckpointFault(campaign string, iteration uint32) fault {
	if entry, ok := checkpointCampaigns[campaign]; ok {
		return entry
	}
	key := checkpointMixedOrder[(iteration-1)%uint32(len(checkpointMixedOrder))]
	return checkpointCampaigns[key]
}

func chooseRecoveryBlockFault(campaign string, iteration uint32) fault {
	if entry, ok := recoveryBlockCampaigns[campaign]; ok {
		return entry
	}
	key := recoveryBlockMixedOrder[(iteration-1)%uint32(len(recoveryBlockMixedOrder))]
	return recoveryBlockCampaigns[key]
}

func chooseControlFlowFault(campaign string, iteration uint32) fault {
	if entry, ok := controlFlowCampaigns[campaign]; ok {
		return entry
	}
	key := controlFlowMixedOrder[(iteration-1)%uint32(len(controlFlowMixedOrder))]
	return controlFlowCampaigns[key]
}
