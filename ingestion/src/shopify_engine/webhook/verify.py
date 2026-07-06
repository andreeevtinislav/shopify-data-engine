import base64
import hashlib
import hmac


def verify_shopify_hmac(raw_body: bytes, hmac_header: str | None, secret: str) -> bool:
    """Verifies Shopify's X-Shopify-Hmac-Sha256 header against the raw request body.

    Must be called on the exact bytes Shopify sent, before any JSON parsing —
    re-serializing the parsed body can change whitespace/key order and break
    verification even for a genuine, unmodified payload.
    """
    if not hmac_header:
        return False

    digest = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).digest()
    expected = base64.b64encode(digest).decode("utf-8")
    return hmac.compare_digest(expected, hmac_header)
