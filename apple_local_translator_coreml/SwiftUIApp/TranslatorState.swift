import Foundation
import CoreML

@MainActor
final class TranslatorState: ObservableObject {
    @Published var inputText: String = "Kamilek od zawsze chcial byc programista i marzyl, ze bedzie pisal kod szybciej niz kompilator zdazy sie zorientowac, co wlasnie sie stalo."
    @Published var outputText: String = ""
    @Published var statusText: String = "Zaimportuj model Core ML (.mlpackage/.mlmodel/.mlmodelc)."
    @Published var loadedModelName: String = "Brak"
    @Published var modelSchemaText: String = ""
    @Published var isGenerating = false

    private let translator = CoreMLTextTranslator()

    private let supportedModelExtensions: Set<String> = [
        "mlpackage",
        "mlmodel",
        "mlmodelc"
    ]

    func loadModel(from modelURL: URL) async {
        statusText = "Ladowanie modelu Core ML (CPU + ANE)..."

        do {
            let summary = try await translator.loadModel(
                from: modelURL,
                computeUnits: .cpuAndNeuralEngine
            )
            loadedModelName = summary.modelName
            modelSchemaText = summary.schemaDescription
            statusText = "Model gotowy. Uzywana konfiguracja: cpuAndNeuralEngine (ANE)."
        } catch {
            await translator.unloadModel()
            loadedModelName = "Brak"
            modelSchemaText = ""
            statusText = "Blad ladowania: \(error.localizedDescription)"
        }
    }

    func importAndLoadModel(from sourceURL: URL) async {
        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard isSupportedModelURL(sourceURL) else {
            statusText = "Nieobslugiwany format. Wybierz .mlpackage, .mlmodel lub .mlmodelc."
            return
        }

        do {
            let modelsDir = try appModelsDirectory()
            let targetURL = modelsDir.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: false)

            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            await loadModel(from: targetURL)
        } catch {
            statusText = "Nie udalo sie zapisac modelu: \(error.localizedDescription)"
        }
    }

    func tryLoadBundledOrSavedModel() async {
        let bundledCandidates: [(name: String, ext: String)] = [
            ("TranslatorCoreML", "mlmodelc"),
            ("TranslatorCoreML", "mlpackage"),
            ("TranslatorCoreML", "mlmodel")
        ]

        for candidate in bundledCandidates {
            if let url = Bundle.main.url(forResource: candidate.name, withExtension: candidate.ext) {
                await loadModel(from: url)
                return
            }
        }

        do {
            let modelsDir = try appModelsDirectory()
            let files = try FileManager.default.contentsOfDirectory(
                at: modelsDir,
                includingPropertiesForKeys: nil
            )

            let candidates = files
                .filter { isSupportedModelURL($0) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            if let modelURL = candidates.first {
                await loadModel(from: modelURL)
                return
            }

            statusText = "Brak zapisanych modeli Core ML. Zaimportuj plik modelu."
        } catch {
            statusText = "Nie udalo sie odczytac katalogu modeli: \(error.localizedDescription)"
        }
    }

    func translate() async {
        guard !isGenerating else {
            return
        }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = "Wpisz tekst do tlumaczenia."
            return
        }

        isGenerating = true
        outputText = ""
        statusText = "Tlumacze lokalnie przez Core ML..."

        do {
            let translated = try await translator.translate(trimmed)
            outputText = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            statusText = "Gotowe."
        } catch {
            outputText = ""
            statusText = "Blad inferencji: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func validateSelectedModel(url: URL) -> String? {
        if isSupportedModelURL(url) {
            return nil
        }

        return "Nieobslugiwany plik: \(url.lastPathComponent). Uzyj .mlpackage, .mlmodel lub .mlmodelc."
    }

    private func isSupportedModelURL(_ url: URL) -> Bool {
        supportedModelExtensions.contains(url.pathExtension.lowercased())
    }

    private func appModelsDirectory() throws -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        let dir = appSupport
            .appendingPathComponent("LocalTranslatorCoreML", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
