from __future__ import annotations

import unittest

from classification import ClassificationInput, classify_trial


def base(**overrides: object) -> dict[str, object]:
    facts: dict[str, object] = {
        "harness_done": 1,
        "harness_detected": 0,
        "harness_corrected": 0,
        "harness_safe_state": 0,
        "harness_output": 7,
        "harness_expected": 7,
        "injected": 1,
        "instruction_budget_exhausted": 0,
    }
    facts.update(overrides)
    return facts


class ClassificationTests(unittest.TestCase):
    def classify(self, facts: dict[str, object], **kwargs: object) -> str:
        return classify_trial(
            ClassificationInput(
                facts=facts,
                process_status=str(kwargs.get("process_status", "completed")),
                timeout=bool(kwargs.get("timeout", False)),
                requires_injection=bool(
                    kwargs.get("requires_injection", False)),
            )
        )

    def test_timeout_maps_to_hang(self) -> None:
        self.assertEqual("hang", self.classify({}, timeout=True))

    def test_budget_maps_to_hang(self) -> None:
        self.assertEqual("hang", self.classify(
            base(instruction_budget_exhausted=1)))

    def test_abnormal_exit_before_done_maps_to_crash(self) -> None:
        self.assertEqual("crash", self.classify({}, process_status="exit:1"))

    def test_wrong_output_without_detection_maps_to_sdc(self) -> None:
        self.assertEqual("sdc", self.classify(base(harness_output=8)))

    def test_detected_valid_recovery_maps_to_corrected(self) -> None:
        self.assertEqual(
            "corrected",
            self.classify(base(harness_detected=1, harness_corrected=1)),
        )

    def test_detected_non_commit_maps_to_fail_safe(self) -> None:
        self.assertEqual(
            "fail_safe",
            self.classify(
                base(harness_detected=1, harness_safe_state=1, harness_output=0)),
        )

    def test_matching_output_without_detection_maps_to_passed(self) -> None:
        self.assertEqual("passed", self.classify(base()))

    def test_missing_required_fact_maps_to_invalid(self) -> None:
        facts = base()
        del facts["harness_expected"]
        self.assertEqual("invalid_trial", self.classify(facts))

    def test_correction_without_detection_is_invalid(self) -> None:
        self.assertEqual("invalid_trial", self.classify(
            base(harness_corrected=1)))

    def test_required_injection_without_injection_is_invalid(self) -> None:
        self.assertEqual(
            "invalid_trial",
            self.classify(base(injected=0), requires_injection=True),
        )


if __name__ == "__main__":
    unittest.main()
