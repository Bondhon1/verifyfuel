import base64
import binascii
import json
import os
import re
from urllib import error, request

from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account

from app.core.config import settings


class GoogleVisionOcrService:
    _bengali_to_english = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")

    @classmethod
    def is_configured(cls) -> bool:
        has_service_account_json = bool(settings.GOOGLE_APPLICATION_CREDENTIALS_JSON)
        has_service_account = bool(settings.GOOGLE_APPLICATION_CREDENTIALS)
        has_api_key = bool(settings.GOOGLE_VISION_API_KEY)
        return has_service_account_json or has_service_account or has_api_key

    @classmethod
    def scan_plate(cls, image_base64: str) -> dict:
        if not cls.is_configured():
            raise RuntimeError("Google Vision OCR is not configured.")

        cleaned_content = cls._clean_base64(image_base64)
        raw_text = cls._call_google_vision(cleaned_content)
        plate_number = cls.extract_plate_number(raw_text)

        return {
            "plate_number": plate_number,
            "raw_text": raw_text,
            "provider": "google_vision",
            "is_configured": True,
        }

    @classmethod
    def _clean_base64(cls, image_base64: str) -> str:
        value = image_base64.strip()
        if not value:
            raise ValueError("image_base64 is required")

        if ";base64," in value:
            value = value.split(";base64,", 1)[1]

        try:
            base64.b64decode(value, validate=True)
        except binascii.Error as exc:
            raise ValueError("Invalid base64 image payload") from exc

        return value

    @classmethod
    def _call_google_vision(cls, image_base64: str) -> str:
        endpoint = "https://vision.googleapis.com/v1/images:annotate"
        payload = {
            "requests": [
                {
                    "image": {"content": image_base64},
                    "features": [{"type": "DOCUMENT_TEXT_DETECTION", "maxResults": 1}],
                    "imageContext": {"languageHints": ["bn", "en"]},
                }
            ]
        }

        headers = {"Content-Type": "application/json"}
        credentials_json = settings.GOOGLE_APPLICATION_CREDENTIALS_JSON
        credentials_path = settings.GOOGLE_APPLICATION_CREDENTIALS

        if credentials_json:
            try:
                credentials_info = json.loads(credentials_json)
            except json.JSONDecodeError as exc:
                raise RuntimeError(
                    "GOOGLE_APPLICATION_CREDENTIALS_JSON is not valid JSON"
                ) from exc

            credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=["https://www.googleapis.com/auth/cloud-platform"],
            )
            credentials.refresh(GoogleAuthRequest())
            headers["Authorization"] = f"Bearer {credentials.token}"
        elif credentials_path:
            if not os.path.exists(credentials_path):
                raise RuntimeError(
                    "GOOGLE_APPLICATION_CREDENTIALS path does not exist"
                )

            credentials = service_account.Credentials.from_service_account_file(
                credentials_path,
                scopes=["https://www.googleapis.com/auth/cloud-platform"],
            )
            credentials.refresh(GoogleAuthRequest())
            headers["Authorization"] = f"Bearer {credentials.token}"
        elif settings.GOOGLE_VISION_API_KEY:
            endpoint = f"{endpoint}?key={settings.GOOGLE_VISION_API_KEY}"
        else:
            raise RuntimeError(
                "Google Vision is not configured. Set GOOGLE_APPLICATION_CREDENTIALS_JSON, GOOGLE_APPLICATION_CREDENTIALS, or GOOGLE_VISION_API_KEY."
            )

        req = request.Request(
            endpoint,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )

        try:
            with request.urlopen(req, timeout=25) as response:
                body = response.read().decode("utf-8")
        except error.HTTPError as exc:
            response_body = exc.read().decode("utf-8", errors="ignore")
            raise RuntimeError(
                f"Google Vision request failed ({exc.code}): {response_body}"
            ) from exc
        except error.URLError as exc:
            raise RuntimeError(f"Google Vision connection failed: {exc.reason}") from exc

        parsed = json.loads(body)
        first = (parsed.get("responses") or [{}])[0]

        if first.get("error"):
            message = first["error"].get("message", "Unknown Vision API error")
            raise RuntimeError(f"Google Vision error: {message}")

        full_text = (first.get("fullTextAnnotation") or {}).get("text", "").strip()
        if full_text:
            return full_text

        annotations = first.get("textAnnotations") or []
        if annotations:
            return (annotations[0].get("description") or "").strip()

        return ""

    @classmethod
    def extract_plate_number(cls, raw_text: str) -> str:
        if not raw_text:
            return ""

        normalized = raw_text.translate(cls._bengali_to_english).upper()
        normalized = (
            normalized.replace("—", "-")
            .replace("–", "-")
            .replace("−", "-")
            .replace("_", "-")
        )

        lines = [re.sub(r"\s+", " ", line).strip() for line in normalized.splitlines()]
        lines = [line for line in lines if line]

        strict = re.compile(r"\b(\d{2,3})\s*-\s*(\d{3,4})\b")
        for line in lines:
            match = strict.search(line)
            if match:
                return f"{match.group(1)}-{match.group(2)}"

        compact = re.compile(r"\b(\d{5,7})\b")
        for line in lines:
            match = compact.search(line)
            if match:
                digits = match.group(1)
                if len(digits) in (5, 6, 7):
                    return f"{digits[:2]}-{digits[2:]}"

        noisy = re.compile(r"[^0-9-]")
        for line in lines:
            candidate = noisy.sub("", line)
            candidate = re.sub(r"-+", "-", candidate).strip("-")
            match = strict.search(candidate)
            if match:
                return f"{match.group(1)}-{match.group(2)}"

        return ""
