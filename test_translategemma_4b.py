#!/usr/bin/env python3
"""Prosty test tłumaczenia przez Ollama (tekst -> tekst)."""

import json
import os
import socket
import sys
import urllib.error
import urllib.request

# Konfiguracja w kodzie (bez parametrów CLI).
TEXT_TO_TRANSLATE = "Kamilek chcial byc programista, ale nie mial talentu do kodowania. Zamiast tego, zostal mistrzem kamieniarskim i tworzy przepiekne rzezby z kamienia."
SOURCE_LANG = "pl"
TARGET_LANG = "en"
MODEL = "translategemma:4b"
MAX_NEW_TOKENS = 128
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
TIMEOUT_SECONDS = 120


def _call_ollama(payload: dict) -> dict:
    url = f"{OLLAMA_HOST.rstrip('/')}/api/chat"
    request = urllib.request.Request(
        url=url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    temperature = 0.5  # Ustawienie kreatywności (0.5 to 50% kreatywności)
    payload = {
        "model": MODEL,
        "stream": False,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a professional translator. "
                    f"Translate from {SOURCE_LANG} to {TARGET_LANG}."
                ),
            },
            {
                "role": "user",
                "content": TEXT_TO_TRANSLATE,
            },
        ],
        "options": {
            "temperature": temperature,
            "num_predict": MAX_NEW_TOKENS,
        },
    }

    try:
        print(f"Wysyłanie zapytania do Ollama (model: {MODEL}), tłumaczenie z {SOURCE_LANG} na {TARGET_LANG} temp: {temperature}...")
        print(f"{TEXT_TO_TRANSLATE}")
        data = _call_ollama(payload)
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace").strip()
        print(f"Błąd HTTP z Ollama API: {exc.code}", file=sys.stderr)
        if details:
            print(f"Szczegóły: {details}", file=sys.stderr)
        if exc.code == 404:
            print(
                f"Model '{MODEL}' nie został znaleziony. Uruchom: ./start.sh download {MODEL}",
                file=sys.stderr,
            )
        return 1
    except (urllib.error.URLError, socket.timeout, TimeoutError) as exc:
        print(f"Nie można połączyć się z Ollama pod adresem {OLLAMA_HOST}: {exc}", file=sys.stderr)
        print("Sprawdź, czy działa `ollama serve` i czy host jest poprawny.", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"Odpowiedź Ollama nie jest poprawnym JSON-em: {exc}", file=sys.stderr)
        return 1

    translated = (data.get("message") or {}).get("content", "").strip()
    if not translated:
        print("Ollama zwróciła pustą odpowiedź.", file=sys.stderr)
        print(f"Pełna odpowiedź: {json.dumps(data, ensure_ascii=False)}", file=sys.stderr)
        return 1
    
    print()
    print("===  Odpowiedź Ollama  ===")
    print(translated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
