import re


def clean_tag_text(raw_text: str, keep_alphanumeric_only: bool = True) -> str:
    """
    Cleans raw OCR output by removing extraneous whitespace and invalid characters.
    
    Args:
        raw_text: Raw string returned by OCR.
        keep_alphanumeric_only: If True, keeps only letters, digits, and hyphens.
        
    Returns:
        Cleaned, uppercase string.
    """
    if not raw_text:
        return ""

    text = raw_text.strip().upper()

    if keep_alphanumeric_only:
        # Keep alphanumeric and hyphens/dots
        text = re.sub(r"[^A-Z0-9\-\.]", "", text)

    return text.strip()


def is_valid_tag(text: str, min_length: int = 2, max_length: int = 15) -> bool:
    """
    Checks whether the extracted text resembles a plausible ear tag number.
    """
    if not text:
        return False
    clean = clean_tag_text(text)
    if len(clean) < min_length or len(clean) > max_length:
        return False
    # At least one digit or letter
    return bool(re.search(r"[A-Z0-9]", clean))
