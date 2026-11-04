"""Invitation bearer secrets are generated once and stored only as keyed hashes."""

import hashlib
import hmac
import re
import secrets

from app.core.exceptions import AppError

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def normalize_code(value: str) -> str:
    normalized = re.sub(r"[\s-]", "", value).upper()
    if not re.fullmatch(r"HC[A-HJ-NP-Z2-9]{16}", normalized):
        raise AppError(400, "invalid_invitation", "This invitation is not available.")
    return normalized


def generate_code() -> str:
    value = "".join(secrets.choice(ALPHABET) for _ in range(16))
    return "HC-" + "-".join(value[index : index + 4] for index in range(0, 16, 4))


def hash_code(code: str, pepper: str) -> str:
    return hmac.new(pepper.encode(), normalize_code(code).encode(), hashlib.sha256).hexdigest()
