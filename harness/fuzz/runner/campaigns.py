from __future__ import annotations

import hashlib
from dataclasses import dataclass


CAMPAIGN_CHOICES: tuple[str, ...] = (
    "none",
    "ram-symbol-bitflip",
    "reg-bitflip-window",
)


@dataclass(frozen=True)
class Campaign:
    name: str
    fault_mode: str
    fault_domain: str
    requires_injection: bool = False
    requires_fuzz_symbols: bool = False


CAMPAIGNS: dict[str, Campaign] = {
    "none": Campaign("none", "none", "none"),
    "ram-symbol-bitflip": Campaign(
        "ram-symbol-bitflip",
        "ram-symbol-bitflip",
        "ram",
        requires_injection=True,
        requires_fuzz_symbols=True,
    ),
    "reg-bitflip-window": Campaign(
        "reg-bitflip-window",
        "reg-bitflip-window",
        "register",
        requires_injection=True,
    ),
}


def campaign(name: str) -> Campaign:
    try:
        return CAMPAIGNS[name]
    except KeyError as exc:
        choices = ", ".join(CAMPAIGN_CHOICES)
        raise ValueError(f"unsupported campaign {name!r}; expected one of: {choices}") from exc


def derive_trial_seed(
    *,
    campaign_seed: int,
    trial_id: int,
    technique: str,
    implementation: str,
    campaign_name: str,
) -> int:
    payload = (
        f"{campaign_seed:016x}:{trial_id}:{technique}:"
        f"{implementation}:{campaign_name}"
    ).encode("utf-8")
    digest = hashlib.blake2b(payload, digest_size=8, person=b"ft-single").digest()
    seed = int.from_bytes(digest, "little")
    return seed or 0x9E3779B97F4A7C15
