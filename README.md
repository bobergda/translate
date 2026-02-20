# translate

Repo zawiera trzy wersje lokalnego tlumacza:

- wersje Python + Ollama (obecne skrypty w katalogu glownym),
- wersje Apple (iPhone + macOS) oparta o `SwiftUI` + `llama.cpp`,
- druga wersje Apple (macOS) oparta o `SwiftUI` + `Core ML` + ANE.

## Start (Python + Ollama)

```bash
./start.sh install
./start.sh download translategemma:4b
./start.sh run
```

## Wersja Apple (iPhone + macOS, `llama.cpp`)

Pełny opis, model i kroki uruchomienia znajdziesz tutaj:

- `apple_local_translator/README.md`

To jest główny punkt wejścia, jeśli chcesz lokalne odpalanie modelu na iPhonie lub macOS.

## Wersja Apple Core ML (macOS + ANE)

Osobna appka macOS pod modele `Core ML` znajdziesz tutaj:

- `apple_local_translator_coreml/README.md`
