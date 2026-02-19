import Foundation
import llama

enum LlamaError: Error {
    case couldNotInitializeContext
}

private func llamaBatchClear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

private func llamaBatchAdd(
    _ batch: inout llama_batch,
    _ token: llama_token,
    _ position: llama_pos,
    _ seqIds: [llama_seq_id],
    _ logits: Bool
) {
    batch.token[Int(batch.n_tokens)] = token
    batch.pos[Int(batch.n_tokens)] = position
    batch.n_seq_id[Int(batch.n_tokens)] = Int32(seqIds.count)

    for i in 0..<seqIds.count {
        batch.seq_id[Int(batch.n_tokens)]![i] = seqIds[i]
    }

    batch.logits[Int(batch.n_tokens)] = logits ? 1 : 0
    batch.n_tokens += 1
}

actor LlamaContext {
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer

    private var sampler: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var tokens: [llama_token] = []
    private var pendingUtf8Bytes: [CChar] = []

    private(set) var isDone = false

    private var currentPosition: Int32 = 0
    private var maxGeneratedTokens: Int32 = 1024

    init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
        self.vocab = llama_model_get_vocab(model)
        self.batch = llama_batch_init(512, 0, 1)

        let samplerParams = llama_sampler_chain_default_params()
        self.sampler = llama_sampler_chain_init(samplerParams)
        llama_sampler_chain_add(self.sampler, llama_sampler_init_top_k(80))
        llama_sampler_chain_add(self.sampler, llama_sampler_init_top_p(0.97, 1))
        llama_sampler_chain_add(self.sampler, llama_sampler_init_temp(1.05))
        llama_sampler_chain_add(self.sampler, llama_sampler_init_dist(UInt32(Date().timeIntervalSince1970)))
    }

    deinit {
        llama_sampler_free(sampler)
        llama_batch_free(batch)
        llama_model_free(model)
        llama_free(context)
        llama_backend_free()
    }

    static func createContext(path: String) throws -> LlamaContext {
        llama_backend_init()

        var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
#endif

        guard let model = llama_model_load_from_file(path, modelParams) else {
            throw LlamaError.couldNotInitializeContext
        }

        let threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048
        contextParams.n_threads = Int32(threads)
        contextParams.n_threads_batch = Int32(threads)

        guard let context = llama_init_from_model(model, contextParams) else {
            throw LlamaError.couldNotInitializeContext
        }

        return LlamaContext(model: model, context: context)
    }

    func completionInit(text: String, maxTokens: Int32) {
        isDone = false
        pendingUtf8Bytes.removeAll()
        maxGeneratedTokens = maxTokens

        tokens = tokenize(text: text, addBos: true)
        let neededKv = tokens.count + Int(maxGeneratedTokens)

        if neededKv > Int(llama_n_ctx(context)) {
            isDone = true
            return
        }

        llamaBatchClear(&batch)

        for i in 0..<tokens.count {
            llamaBatchAdd(&batch, tokens[i], Int32(i), [0], false)
        }

        if batch.n_tokens > 0 {
            batch.logits[Int(batch.n_tokens) - 1] = 1
        }

        if llama_decode(context, batch) != 0 {
            isDone = true
            return
        }

        currentPosition = batch.n_tokens
    }

    func completionLoop() -> String {
        if isDone {
            return ""
        }

        let token = llama_sampler_sample(sampler, context, batch.n_tokens - 1)

        if llama_vocab_is_eog(vocab, token) || currentPosition >= maxGeneratedTokens {
            isDone = true
            let rest = String(cString: pendingUtf8Bytes + [0])
            pendingUtf8Bytes.removeAll()
            return rest
        }

        let tokenBytes = tokenToPiece(token: token)
        pendingUtf8Bytes.append(contentsOf: tokenBytes)

        let textPiece: String
        if let valid = String(validatingUTF8: pendingUtf8Bytes + [0]) {
            pendingUtf8Bytes.removeAll()
            textPiece = valid
        } else {
            textPiece = ""
        }

        llamaBatchClear(&batch)
        llamaBatchAdd(&batch, token, currentPosition, [0], true)
        currentPosition += 1

        if llama_decode(context, batch) != 0 {
            isDone = true
        }

        return textPiece
    }

    func clear() {
        tokens.removeAll()
        pendingUtf8Bytes.removeAll()
        isDone = false
        llama_memory_clear(llama_get_memory(context), true)
    }

    private func tokenize(text: String, addBos: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let bufferSize = utf8Count + (addBos ? 1 : 0) + 16
        let buffer = UnsafeMutablePointer<llama_token>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        let count = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            buffer,
            Int32(bufferSize),
            addBos,
            false
        )

        if count <= 0 {
            return []
        }

        return Array(UnsafeBufferPointer(start: buffer, count: Int(count)))
    }

    private func tokenToPiece(token: llama_token) -> [CChar] {
        let smallBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        smallBuffer.initialize(repeating: 0, count: 8)
        defer { smallBuffer.deallocate() }

        let written = llama_token_to_piece(vocab, token, smallBuffer, 8, 0, false)

        if written >= 0 {
            return Array(UnsafeBufferPointer(start: smallBuffer, count: Int(written)))
        }

        let capacity = Int(-written)
        let largeBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: capacity)
        largeBuffer.initialize(repeating: 0, count: capacity)
        defer { largeBuffer.deallocate() }

        let exact = llama_token_to_piece(vocab, token, largeBuffer, Int32(capacity), 0, false)
        if exact <= 0 {
            return []
        }

        return Array(UnsafeBufferPointer(start: largeBuffer, count: Int(exact)))
    }
}
