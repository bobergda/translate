import os
import requests

# Konfiguracja w kodzie (bez parametrów CLI).
TEXT_TO_TRANSLATE = (
    "Kamilek od zawsze chcial byc programista i marzyl, ze bedzie pisal kod szybciej niz kompilator "
    "zdazy sie zorientowac, co wlasnie sie stalo. Niestety rzeczywistosc byla brutalna: kazdy jego "
    "program konczyl sie bledem, a debugger plakal cicho w katku. Kamilek probowal wszystkiego — "
    "tutoriali na YouTube, kursow online, a nawet kopiowania kodu z internetu, ale nic nie dzialalo "
    "tak jak powinno. "
    "W pewnym momencie stwierdzil, ze skoro komputer go nie kocha, to moze kamien bedzie bardziej "
    "wyrozumial. I tak porzucil klawiature na rzecz dluta, zostajac mistrzem kamieniarskim. "
    "Dzis Kamilek tworzy przepiekne rzezby z kamienia, ktore nie rzucaja wyjatkow, nie maja bugow "
    "i nigdy nie wymagaja aktualizacji do nowszej wersji."
)

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
TIMEOUT_SECONDS = 120

system_prompt = """
You are a funny but still understandable translator.

Goal:
- Translate Polish to English, but make it playful by sprinkling MANY languages.

Rules:
- Sprinkle MANY short words or very short phrases from at least EIGHT other languages.
- Aim for 2–3 foreign words per sentence when possible.
- Output only the translated text.
"""

payload = {
    "model": "translategemma:4b",
    "stream": False,
    "messages": [
        {"role": "system", "content": system_prompt.strip()},
        {"role": "user", "content": TEXT_TO_TRANSLATE},
    ],
    "options": {
        # Trochę więcej "beka", ale nadal kontrola:
        "temperature": 1.05,
        "top_p": 0.97,
        "top_k": 80,
        "repeat_penalty": 1.1,
        "num_predict": 1024
    }
}

print(
    f"Wysyłanie zapytania do Ollama (model: {payload['model']}), "
    f"tłumaczenie z polskiego na angielski temp: {payload['options']['temperature']}..."
)
print(TEXT_TO_TRANSLATE)
print()

resp = requests.post(f"{OLLAMA_HOST}/api/chat", json=payload, timeout=TIMEOUT_SECONDS)
resp.raise_for_status()

data = resp.json()
print("===  Odpowiedź Ollama  ===")
print(data["message"]["content"])
