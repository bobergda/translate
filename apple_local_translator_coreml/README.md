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

## TranslateGemma 4B (download + konwersja do Core ML)

### 1) Pobierz checkpoint HF (format konwertowalny)

```bash
cd apple_local_translator_coreml
./download_translategemma_4b_hf_checkpoint.sh
```

Skrypt ma zaszyty model:
- `https://huggingface.co/google/translategemma-4b-it`

Domyslnie pobierze pliki do:
- `~/Downloads/translategemma-4b-it-hf`

Uwaga:
- skrypt pobiera checkpoint `Transformers/safetensors`,
- appka z tego katalogu wymaga artefaktu `Core ML` (`.mlpackage/.mlmodel/.mlmodelc`),
- pobrany format jest baza do konwersji na Core ML.

### 2) Konwersja na Core ML

```bash
cd apple_local_translator_coreml
./convert_translategemma_4b_to_coreml.sh
```

Domyslny output:
- `~/Downloads/translategemma-4b-it-coreml/Model.mlpackage`

Jesli chcesz podac inne sciezki:

```bash
./convert_translategemma_4b_to_coreml.sh \
  ~/Downloads/translategemma-4b-it-hf \
  ~/Downloads/translategemma-4b-it-coreml/Model.mlpackage
```

## Uzycie

1. Kliknij `Importuj model Core ML` i wybierz model.
2. Wpisz tekst po polsku.
3. Kliknij `Przetlumacz przez Core ML`.

Model i inferencja sa lokalne (on-device).
