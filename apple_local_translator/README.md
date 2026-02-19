# Lokalny translator na iPhone + macOS (SwiftUI + llama.cpp)

Ten folder zawiera kod "podobny" do Twojego `test_translategemma_4b.py`, ale przygotowany pod Apple:
- dziala lokalnie na urzadzeniu (bez API),
- jeden kod UI dla iPhone i macOS,
- model GGUF zoptymalizowany pod mobile (`Q4_K_M`).

## Co jest w srodku

- `SwiftUIApp/LibLlama.swift` - lokalny inference przez `llama.cpp`.
- `SwiftUIApp/TranslatorState.swift` - logika tlumaczenia i prompt.
- `SwiftUIApp/ContentView.swift` - UI (import modelu + tlumaczenie).
- `SwiftUIApp/LocalTranslatorApp.swift` - punkt startowy aplikacji.
- `download_model_for_iphone.sh` - pobiera model pod iPhone/macOS.

## 1) Model pod iPhone (lokalny)

Pobierz gotowy model `Q4_K_M`:

```bash
cd apple_local_translator
./download_model_for_iphone.sh
```

Domyslnie plik trafi do:
- `~/Downloads/gemma-3-1b-it-Q4_K_M.gguf`

## 2) Dodaj `llama.cpp` do projektu Xcode

Najprostsza droga:
1. Sklonuj `llama.cpp`.
2. Uruchom skrypt `./build-xcframework.sh` w katalogu repo.
3. Dodaj `build-apple/llama.xcframework` do projektu Xcode (`Frameworks, Libraries, and Embedded Content`).

Kod w tym folderze zaklada import:

```swift
import llama
```

## 3) Projekt iOS + macOS

1. W Xcode stworz nowy projekt `App` (SwiftUI).
2. Wlacz platformy: `iOS` i `macOS`.
3. Podmien domyslne pliki na te z katalogu `SwiftUIApp/`.
4. Zbuduj i uruchom.

## 4) Import modelu w appce

Po starcie appki kliknij:
- `Importuj GGUF` i wybierz pobrany plik,
- potem `Przetlumacz lokalnie`.

Wszystko dziala on-device.

## Opcjonalnie: jeszcze mniejszy model

Jesli chcesz lepsza wydajnosc na slabszym iPhone, zrob dodatkowa kwantyzacje do mniejszego formatu (kosztem jakosci), np. `Q4_0` albo `Q3_K_M`.
