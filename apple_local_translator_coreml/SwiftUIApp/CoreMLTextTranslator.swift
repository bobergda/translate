import Foundation
import CoreML

struct CoreMLModelSummary {
    let modelName: String
    let schemaDescription: String
}

enum CoreMLTranslatorError: LocalizedError {
    case unsupportedModelFormat(String)
    case missingStringInput
    case missingStringOutput
    case unsupportedRequiredInput(name: String, type: MLFeatureType)
    case modelNotLoaded
    case missingOutputValue(name: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedModelFormat(let ext):
            return "Nieobslugiwane rozszerzenie modelu: \(ext). Uzyj .mlpackage, .mlmodel lub .mlmodelc."
        case .missingStringInput:
            return "Model nie ma wejscia typu String. Ta appka obsluguje modele text -> text."
        case .missingStringOutput:
            return "Model nie ma wyjscia typu String. Ta appka obsluguje modele text -> text."
        case .unsupportedRequiredInput(let name, let type):
            return "Wymagane wejscie '\(name)' typu \(type.displayName) nie jest obslugiwane automatycznie."
        case .modelNotLoaded:
            return "Model nie jest zaladowany."
        case .missingOutputValue(let name):
            return "Model nie zwrocil pola tekstowego '\(name)'."
        }
    }
}

private extension MLFeatureType {
    var displayName: String {
        switch self {
        case .invalid:
            return "invalid"
        case .int64:
            return "int64"
        case .double:
            return "double"
        case .string:
            return "string"
        case .image:
            return "image"
        case .multiArray:
            return "multiArray"
        case .dictionary:
            return "dictionary"
        case .sequence:
            return "sequence"
        @unknown default:
            return "unknown"
        }
    }
}

actor CoreMLTextTranslator {
    private var model: MLModel?
    private var textInputName: String?
    private var textOutputName: String?
    private var staticInputs: [String: MLFeatureValue] = [:]

    func unloadModel() {
        model = nil
        textInputName = nil
        textOutputName = nil
        staticInputs = [:]
    }

    func loadModel(from sourceURL: URL, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) throws -> CoreMLModelSummary {
        let compiledURL = try compiledModelURL(for: sourceURL)

        let config = MLModelConfiguration()
        config.computeUnits = computeUnits

        let loadedModel = try MLModel(contentsOf: compiledURL, configuration: config)
        let inputDescriptions = sortedFeatureEntries(loadedModel.modelDescription.inputDescriptionsByName)
        let outputDescriptions = sortedFeatureEntries(loadedModel.modelDescription.outputDescriptionsByName)

        let selectedInput = try selectTextInput(from: inputDescriptions)
        let selectedOutput = try selectTextOutput(from: outputDescriptions)
        let defaults = try buildDefaults(for: inputDescriptions, primaryTextInput: selectedInput)

        self.model = loadedModel
        self.textInputName = selectedInput
        self.textOutputName = selectedOutput
        self.staticInputs = defaults

        let schema = schemaText(
            inputs: inputDescriptions,
            outputs: outputDescriptions,
            selectedInput: selectedInput,
            selectedOutput: selectedOutput,
            defaults: defaults,
            computeUnits: computeUnits
        )

        return CoreMLModelSummary(
            modelName: sourceURL.lastPathComponent,
            schemaDescription: schema
        )
    }

    func translate(_ text: String) throws -> String {
        guard let model else {
            throw CoreMLTranslatorError.modelNotLoaded
        }
        guard let textInputName else {
            throw CoreMLTranslatorError.missingStringInput
        }
        guard let textOutputName else {
            throw CoreMLTranslatorError.missingStringOutput
        }

        var inputValues = staticInputs
        inputValues[textInputName] = MLFeatureValue(string: text)

        let provider = try MLDictionaryFeatureProvider(dictionary: inputValues)
        let prediction = try model.prediction(from: provider)

        guard let output = prediction.featureValue(for: textOutputName)?.stringValue else {
            throw CoreMLTranslatorError.missingOutputValue(name: textOutputName)
        }

        return output
    }

    private func compiledModelURL(for sourceURL: URL) throws -> URL {
        switch sourceURL.pathExtension.lowercased() {
        case "mlmodelc":
            return sourceURL
        case "mlpackage", "mlmodel":
            return try MLModel.compileModel(at: sourceURL)
        default:
            throw CoreMLTranslatorError.unsupportedModelFormat(sourceURL.pathExtension)
        }
    }

    private func sortedFeatureEntries(
        _ dictionary: [String: MLFeatureDescription]
    ) -> [(name: String, description: MLFeatureDescription)] {
        dictionary
            .map { (name: $0.key, description: $0.value) }
            .sorted { $0.name < $1.name }
    }

    private func selectTextInput(
        from inputs: [(name: String, description: MLFeatureDescription)]
    ) throws -> String {
        let stringInputs = inputs.filter { $0.description.type == .string }
        guard !stringInputs.isEmpty else {
            throw CoreMLTranslatorError.missingStringInput
        }

        return stringInputs
            .sorted {
                let lhs = textInputScore(name: $0.name, isOptional: $0.description.isOptional)
                let rhs = textInputScore(name: $1.name, isOptional: $1.description.isOptional)
                if lhs == rhs {
                    return $0.name < $1.name
                }
                return lhs > rhs
            }
            .first!
            .name
    }

    private func selectTextOutput(
        from outputs: [(name: String, description: MLFeatureDescription)]
    ) throws -> String {
        let stringOutputs = outputs.filter { $0.description.type == .string }
        guard !stringOutputs.isEmpty else {
            throw CoreMLTranslatorError.missingStringOutput
        }

        return stringOutputs
            .sorted {
                let lhs = textOutputScore(name: $0.name)
                let rhs = textOutputScore(name: $1.name)
                if lhs == rhs {
                    return $0.name < $1.name
                }
                return lhs > rhs
            }
            .first!
            .name
    }

    private func buildDefaults(
        for inputs: [(name: String, description: MLFeatureDescription)],
        primaryTextInput: String
    ) throws -> [String: MLFeatureValue] {
        var values: [String: MLFeatureValue] = [:]

        for entry in inputs {
            if entry.name == primaryTextInput || entry.description.isOptional {
                continue
            }

            switch entry.description.type {
            case .string:
                values[entry.name] = MLFeatureValue(string: defaultStringValue(for: entry.name))
            case .int64:
                values[entry.name] = MLFeatureValue(int64: defaultIntValue(for: entry.name))
            case .double:
                values[entry.name] = MLFeatureValue(double: defaultDoubleValue(for: entry.name))
            default:
                throw CoreMLTranslatorError.unsupportedRequiredInput(
                    name: entry.name,
                    type: entry.description.type
                )
            }
        }

        return values
    }

    private func textInputScore(name: String, isOptional: Bool) -> Int {
        let lower = name.lowercased()
        var score = isOptional ? 0 : 200

        if lower.contains("text") { score += 120 }
        if lower.contains("input") { score += 90 }
        if lower.contains("prompt") { score += 70 }
        if lower.contains("sentence") { score += 60 }
        if lower.contains("source") || lower.contains("src") { score += 30 }
        if lower.contains("lang") { score -= 40 }

        return score
    }

    private func textOutputScore(name: String) -> Int {
        let lower = name.lowercased()
        var score = 0

        if lower.contains("translation") { score += 150 }
        if lower.contains("output") { score += 110 }
        if lower.contains("text") { score += 100 }
        if lower.contains("result") { score += 70 }
        if lower.contains("label") { score -= 40 }

        return score
    }

    private func defaultStringValue(for name: String) -> String {
        let lower = name.lowercased()

        if lower.contains("source") || lower.contains("src") {
            return "pl"
        }
        if lower.contains("target") || lower.contains("tgt") || lower.contains("dest") {
            return "en"
        }
        if lower.contains("lang") {
            return lower.contains("to") ? "en" : "pl"
        }

        return ""
    }

    private func defaultIntValue(for name: String) -> Int64 {
        let lower = name.lowercased()

        if lower.contains("max") {
            return 256
        }
        if lower.contains("top_k") || lower.contains("topk") {
            return 50
        }
        if lower.contains("beam") {
            return 1
        }
        if lower.contains("sample") {
            return 1
        }
        if lower.contains("seed") {
            return 42
        }

        return 0
    }

    private func defaultDoubleValue(for name: String) -> Double {
        let lower = name.lowercased()

        if lower.contains("temperature") {
            return 0.7
        }
        if lower.contains("top_p") || lower.contains("topp") {
            return 0.95
        }
        if lower.contains("repetition") {
            return 1.05
        }

        return 0.0
    }

    private func schemaText(
        inputs: [(name: String, description: MLFeatureDescription)],
        outputs: [(name: String, description: MLFeatureDescription)],
        selectedInput: String,
        selectedOutput: String,
        defaults: [String: MLFeatureValue],
        computeUnits: MLComputeUnits
    ) -> String {
        var lines: [String] = []

        lines.append("Compute units: \(computeUnitsLabel(computeUnits))")
        lines.append("Input tekstowy: \(selectedInput)")
        lines.append("Output tekstowy: \(selectedOutput)")
        lines.append("")

        lines.append("Inputs:")
        for entry in inputs {
            let optionalText = entry.description.isOptional ? "optional" : "required"
            lines.append("- \(entry.name): \(entry.description.type.displayName) (\(optionalText))")
        }

        lines.append("")
        lines.append("Outputs:")
        for entry in outputs {
            lines.append("- \(entry.name): \(entry.description.type.displayName)")
        }

        if !defaults.isEmpty {
            lines.append("")
            lines.append("Auto-values for required inputs:")
            for key in defaults.keys.sorted() {
                let value = defaults[key]
                if let stringValue = value?.stringValue {
                    lines.append("- \(key): \(stringValue)")
                } else if let intValue = value?.int64Value {
                    lines.append("- \(key): \(intValue)")
                } else if let doubleValue = value?.doubleValue {
                    lines.append("- \(key): \(doubleValue)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func computeUnitsLabel(_ computeUnits: MLComputeUnits) -> String {
        switch computeUnits {
        case .all:
            return "all"
        case .cpuOnly:
            return "cpuOnly"
        case .cpuAndGPU:
            return "cpuAndGPU"
        case .cpuAndNeuralEngine:
            return "cpuAndNeuralEngine (ANE preferred)"
        @unknown default:
            return "unknown"
        }
    }
}
