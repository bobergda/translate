# Lokalny translator macOS (SwiftUI + Core ML + ANE)

Ten katalog zawiera druga appke, niezalezna od wersji `llama.cpp`.

Wersja tutaj:
- dziala tylko na `macOS`,
- laduje model `Core ML` (`.mlpackage`, `.mlmodel`, `.mlmodelc`),
- uzywa `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine` (preferencja ANE).

## Wymagania modelu

Aplikacja obsluguje modele `text -> text`:
- przynajmniej jedno wejscie typu `String`,
- przynajmniej jedno wyjscie typu `String`.

Przy ladowaniu appka wypisuje wykryty schemat wejsc/wyjsc i pokazuje,
ktore pola zostaly automatycznie uzupelnione.

## Uruchomienie

1. Wygeneruj projekt:

```bash
cd apple_local_translator_coreml
xcodegen generate
```

2. Otworz `LocalTranslatorCoreMLMac.xcodeproj` w Xcode.
3. Zbuduj i uruchom target `LocalTranslatorCoreMLMac`.

## TranslateGemma 4B (Core ML)

Skrypt pomocniczy pod `TranslateGemma 4B`:

```bash
cd apple_local_translator_coreml
MODEL_URL="https://twoj-adres/TranslateGemma-4B-IT.mlpackage.zip" \
./download_translategemma_4b_coreml.sh
```

Domyslnie model zapisze sie jako:
- `~/Downloads/TranslateGemma-4B-IT.mlpackage`

Nastepnie wybierz go w appce przez `Importuj model Core ML`.

Uwaga:
- skrypt oczekuje gotowego artefaktu Core ML (`.mlpackage/.mlmodel/.mlmodelc`),
- oficjalny `google/translategemma-4b-it` nie jest sam w sobie artefaktem Core ML.

## Uzycie

1. Kliknij `Importuj model Core ML` i wybierz model.
2. Wpisz tekst po polsku.
3. Kliknij `Przetlumacz przez Core ML`.

Model i inferencja sa lokalne (on-device).
