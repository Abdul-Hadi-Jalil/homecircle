import pytest

from app.core.exceptions import AppError
from app.services.invitation_codes import generate_code, hash_code, normalize_code


def test_invitation_codes_have_80_bits_of_randomness_and_normalize():
    codes = {generate_code() for _ in range(100)}
    assert len(codes) == 100
    for code in codes:
        assert len(normalize_code(code)) == 18
        assert normalize_code(code.lower().replace("-", " ")) == normalize_code(code)


def test_hash_is_keyed_and_format_independent():
    code = generate_code()
    assert hash_code(code, "a" * 32) == hash_code(code.lower().replace("-", ""), "a" * 32)
    assert hash_code(code, "a" * 32) != hash_code(code, "b" * 32)
    assert len(hash_code(code, "a" * 32)) == 64


@pytest.mark.parametrize("value", ["", "HC-123456", "HC-" + "I" * 16, "HC-" + "O" * 16])
def test_invalid_code_format_is_rejected(value):
    with pytest.raises(AppError) as error:
        normalize_code(value)
    assert error.value.status == 400
