import re


def normalize_indian_mobile(value: str | None) -> str | None:
    """Return an Indian mobile in canonical 10-digit form, or None."""
    if not value:
        return None

    digits = re.sub(r"\D", "", value)
    if digits.startswith("0091") and len(digits) == 14:
        digits = digits[4:]
    elif digits.startswith("91") and len(digits) == 12:
        digits = digits[2:]
    elif digits.startswith("0") and len(digits) == 11:
        digits = digits[1:]

    if len(digits) != 10 or digits[0] not in "6789":
        return None
    return digits


def indian_mobile_variants(value: str | None) -> tuple[str, ...]:
    mobile = normalize_indian_mobile(value)
    if mobile is None:
        return ()
    return (mobile, f"+91{mobile}", f"91{mobile}", f"0{mobile}")
