import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var state = TranslatorState()
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model Core ML")
                        .font(.headline)

                    Text(state.loadedModelName)
                        .font(.subheadline)

                    Text(state.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button("Wczytaj ostatni model") {
                        Task {
                            await state.tryLoadBundledOrSavedModel()
                        }
                    }

                    Button("Importuj model Core ML") {
                        showFileImporter = true
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tekst PL")
                        .font(.headline)

                    TextEditor(text: $state.inputText)
                        .frame(minHeight: 160)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary)
                        }
                }

                Button {
                    Task {
                        await state.translate()
                    }
                } label: {
                    if state.isGenerating {
                        HStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Tlumacze...")
                        }
                    } else {
                        Text("Przetlumacz przez Core ML")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isGenerating)
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Wynik EN")
                        .font(.headline)

                    ScrollView {
                        Text(state.outputText.isEmpty ? "(brak wyniku)" : state.outputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 200)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    }
                }

                if !state.modelSchemaText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schemat modelu")
                            .font(.headline)

                        ScrollView {
                            Text(state.modelSchemaText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .frame(minHeight: 160)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Local Translator Core ML")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item, .folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let first = urls.first else {
                    return
                }

                if let message = state.validateSelectedModel(url: first) {
                    state.statusText = message
                    return
                }

                Task {
                    await state.importAndLoadModel(from: first)
                }

            case .failure(let error):
                state.statusText = "Blad wyboru pliku: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
}
