# /// script
# requires-python = ">=3.13"
# dependencies = ["pytest>=8"]
# ///
"""Tests for vendor_sweep.py against a fake repo root. Run: uv run test_vendor_sweep.py"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))

from vendor_sweep import Sweep  # noqa: E402


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


@pytest.fixture
def root(tmp_path: Path) -> Path:
    write(tmp_path / "phony/pyproject.toml", """
[project]
dependencies = ["twilio>=9", "savi-pybase", "phony-core", "data-lake-schema"]
[dependency-groups]
dev = ["pytest", {include-group = "lint"}]
""")
    write(tmp_path / "phony/src/settings.py", """
class TwilioConfig(BaseModel):
    account_sid: str
    api_key_secret: SecretStr

class Other:
    name: str
""")
    write(tmp_path / "data-lake/package.json", json.dumps({"dependencies": {"@savi/ui": "1", "posthog-js": "1"},
                                                           "devDependencies": {"@types/node": "1"}}))
    write(tmp_path / "infra/main.tf", 'terraform { required_providers { aws = { source = "hashicorp/aws" } } }')
    write(tmp_path / "phony/.worktrees/x/pyproject.toml", '[project]\ndependencies = ["ghost"]\n')
    write(tmp_path / "phony/node_modules/y/package.json", json.dumps({"dependencies": {"ghost-js": "1"}}))
    return tmp_path


def test_sweep(root: Path) -> None:
    sweep = Sweep("savi")
    sweep.scan(root)
    out = sweep.as_json()
    assert out["packages"] == {"posthog-js": ["data-lake"], "pytest": ["phony"], "twilio": ["phony"]}
    assert out["terraform_providers"] == {"hashicorp/aws": ["infra"]}
    assert out["key_settings"] == {"TwilioConfig": ["phony"]}


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-q"]))
