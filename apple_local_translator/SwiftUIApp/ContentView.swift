import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var state = TranslatorState()
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.headline)
                    Text(state.loadedModelName)
                        .font(.subheadline)
                    Text(state.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button("Wczytaj domyslny model") {
                        Task {
                            await state.tryLoadBundledOrDocumentsModel()
                        }
                    }

                    Button("Importuj GGUF") {
                        showFileImporter = true
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tekst PL")
                        .font(.headline)
                    TextEditor(text: $state.inputText)
                        .frame(minHeight: 140)
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
                        Text("Przetlumacz lokalnie")
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
            }
            .padding()
            .navigationTitle("Local Translator")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let first = urls.first else {
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
