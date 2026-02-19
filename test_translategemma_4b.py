#!/usr/bin/env python3
"""Prosty test tłumaczenia przez Ollama (tekst -> tekst)."""

import argparse
import json
import os
import socket
import sys
import urllib.error
import urllib.request


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Simple Ollama translation test")
    parser.add_argument("--text", default="To jest prosty test tłumaczenia.", help="Tekst do przetłumaczenia")
    parser.add_argument("--source", default="pl", help="Kod języka źródłowego, np. pl")
    parser.add_argument("--target", default="en", help="Kod języka docelowego, np. en lub de-DE")
    parser.add_argument("--model", default="translategemma:4b", help="Model Ollama, np. translategemma:4b")
    parser.add_argument("--max-new-tokens", type=int, default=128, help="Maksymalna liczba nowych tokenów")
    parser.add_argument(
        "--host",
        default=os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434"),
        help="Adres serwera Ollama, np. http://127.0.0.1:11434",
    )
    parser.add_argument("--timeout", type=int, default=120, help="Timeout zapytania HTTP w sekundach")
    return parser.parse_args()


def _build_prompt(source: str, target: str, text: str) -> str:
    return (
        f"Przetłumacz poniższy tekst z języka '{source}' na '{target}'. "
        "Zwróć wyłącznie tłumaczenie, bez komentarzy i dodatkowych wyjaśnień.\n\n"
        f"Tekst:\n{text}"
    )


def _call_ollama(host: str, payload: dict, timeout: int) -> dict:
    url = f"{host.rstrip('/')}/api/chat"
    request = urllib.request.Request(
        url=url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    args = _parse_args()

    payload = {
        "model": args.model,
        "stream": False,
        "messages": [
            {
                "role": "system",
                "content": "Jesteś profesjonalnym tłumaczem. Odpowiadaj samym tłumaczeniem.",
            },
            {
                "role": "user",
                "content": _build_prompt(args.source, args.target, args.text),
            },
        ],
        "options": {
            "temperature": 0,
            "num_predict": args.max_new_tokens,
        },
    }

    try:
        data = _call_ollama(args.host, payload, args.timeout)
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace").strip()
        print(f"Błąd HTTP z Ollama API: {exc.code}", file=sys.stderr)
        if details:
            print(f"Szczegóły: {details}", file=sys.stderr)
        if exc.code == 404:
            print(
                f"Model '{args.model}' nie został znaleziony. Uruchom: ./start.sh download {args.model}",
                file=sys.stderr,
            )
        return 1
    except (urllib.error.URLError, socket.timeout, TimeoutError) as exc:
        print(f"Nie można połączyć się z Ollama pod adresem {args.host}: {exc}", file=sys.stderr)
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

    print(translated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
