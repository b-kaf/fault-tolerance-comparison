from __future__ import annotations

from dataclasses import dataclass


CAMPAIGN_CHOICES: tuple[str, ...] = (
    "none",
    "abi-none",
    "abi-mixed",
    "ram-symbol-bitflip",
    "reg-bitflip-window",
)


@dataclass(frozen=True)
class Campaign:
    name: str
    requires_fuzz_symbols: bool = False


CAMPAIGNS: dict[str, Campaign] = {
    "none": Campaign("none"),
    "abi-none": Campaign("abi-none"),
    "abi-mixed": Campaign("abi-mixed"),
    "ram-symbol-bitflip": Campaign(
        "ram-symbol-bitflip",
        requires_fuzz_symbols=True,
    ),
    "reg-bitflip-window": Campaign("reg-bitflip-window"),
}


def campaign(name: str) -> Campaign:
    try:
        return CAMPAIGNS[name]
    except KeyError as exc:
        choices = ", ".join(CAMPAIGN_CHOICES)
        raise ValueError(f"unsupported campaign {name!r}; expected one of: {choices}") from exc
