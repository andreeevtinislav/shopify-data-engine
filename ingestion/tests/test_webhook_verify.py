import base64
import hashlib
import hmac

from shopify_engine.webhook.verify import verify_shopify_hmac

SECRET = "test-webhook-secret"
BODY = b'{"id": 12345, "name": "#1001"}'


def _sign(body: bytes, secret: str) -> str:
    digest = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).digest()
    return base64.b64encode(digest).decode("utf-8")


def test_accepts_valid_signature():
    header = _sign(BODY, SECRET)
    assert verify_shopify_hmac(BODY, header, SECRET) is True


def test_rejects_tampered_body():
    header = _sign(BODY, SECRET)
    tampered = BODY.replace(b"1001", b"9999")
    assert verify_shopify_hmac(tampered, header, SECRET) is False


def test_rejects_wrong_secret():
    header = _sign(BODY, "a-different-secret")
    assert verify_shopify_hmac(BODY, header, SECRET) is False


def test_rejects_missing_header():
    assert verify_shopify_hmac(BODY, None, SECRET) is False


def test_rejects_empty_header():
    assert verify_shopify_hmac(BODY, "", SECRET) is False
