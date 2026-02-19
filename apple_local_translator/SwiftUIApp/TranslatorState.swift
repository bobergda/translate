import Foundation

@MainActor
final class TranslatorState: ObservableObject {
    @Published var inputText: String = "Kamilek od zawsze chcial byc programista i marzyl, ze bedzie pisal kod szybciej niz kompilator zdazy sie zorientowac, co wlasnie sie stalo."
    @Published var outputText: String = ""
    @Published var statusText: String = "Wybierz model GGUF i kliknij 'Wczytaj model'."
    @Published var loadedModelName: String = "Brak"
    @Published var isGenerating = false

    private var llamaContext: LlamaContext?

    private let systemPrompt = """
    You are a funny but still understandable translator.

    Goal:
    - Translate Polish to English, but make it playful by sprinkling MANY languages.

    Rules:
    - Sprinkle MANY short words or very short phrases from at least EIGHT other languages.
    - Aim for 2–3 foreign words per sentence when possible.
    - Output only the translated text.
    """

    func loadModel(from modelURL: URL) async {
        statusText = "Ladowanie modelu..."

        do {
            llamaContext = try LlamaContext.createContext(path: modelURL.path)
            loadedModelName = modelURL.lastPathComponent
            statusText = "Model gotowy."
        } catch {
            llamaContext = nil
            loadedModelName = "Brak"
            statusText = "Blad ladowania modelu: \(error.localizedDescription)"
        }
    }

    func importAndLoadModel(from sourceURL: URL) async {
        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let targetURL = documents.appendingPathComponent(sourceURL.lastPathComponent)

            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            await loadModel(from: targetURL)
        } catch {
            statusText = "Nie udalo sie skopiowac modelu: \(error.localizedDescription)"
        }
    }

    func tryLoadBundledOrDocumentsModel() async {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let candidates = [
            documents.appendingPathComponent("gemma-3-1b-it-Q4_K_M.gguf"),
            documents.appendingPathComponent("iphone-translator-q4_k_m.gguf")
        ]

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            await loadModel(from: url)
            return
        }

        statusText = "Model nie znaleziony. Zaimportuj plik GGUF z Files."
    }

    func translate() async {
        guard !isGenerating else {
            return
        }

        guard let llamaContext else {
            statusText = "Najpierw wczytaj model GGUF."
            return
        }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = "Wpisz tekst do tlumaczenia."
            return
        }

        isGenerating = true
        outputText = ""
        statusText = "Tlumacze lokalnie..."

        let prompt = makePrompt(userText: trimmed)

        await llamaContext.completionInit(text: prompt, maxTokens: 1024)

        while await !llamaContext.isDone {
            let token = await llamaContext.completionLoop()
            outputText += token
        }

        await llamaContext.clear()
        isGenerating = false
        statusText = "Gotowe."
    }

    private func makePrompt(userText: String) -> String {
        """
        System:\n\(systemPrompt)\n\nUser:\n\(userText)\n\nAssistant:
        """
    }
}
