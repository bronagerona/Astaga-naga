#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <mutex>
#include <algorithm>
#include "llama.h"

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "ZeniaLocalAI", __VA_ARGS__)
static llama_model * g_model = nullptr;
static llama_context * g_ctx = nullptr;
static const llama_vocab * g_vocab = nullptr;
static std::mutex g_mutex;

static void unload_locked() {
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; }
    g_vocab = nullptr;
}
static std::string jstr(JNIEnv *env, jstring s) {
    if (!s) return {};
    const char *p = env->GetStringUTFChars(s, nullptr);
    std::string out = p ? p : "";
    if (p) env->ReleaseStringUTFChars(s, p);
    return out;
}
extern "C" JNIEXPORT jstring JNICALL
Java_id_bronagerona_zenia_MainActivity_nativeLoadModel(JNIEnv *env, jobject, jstring jpath) {
    std::lock_guard<std::mutex> lock(g_mutex);
    unload_locked();
    const std::string path = jstr(env, jpath);
    llama_backend_init();
    llama_model_params mp = llama_model_default_params();
    mp.load_mode = LLAMA_LOAD_MODE_MMAP;
    g_model = llama_model_load_from_file(path.c_str(), mp);
    if (!g_model) {
        LOGE("Could not load GGUF path: %s", path.c_str());
        return env->NewStringUTF("Model gagal dibuka. Pilih file GGUF lokal yang bisa diakses langsung.");
    }
    llama_context_params cp = llama_context_default_params();
    cp.n_ctx = 768;
    cp.n_batch = 128;
    cp.n_threads = 1;
    cp.n_threads_batch = 1;
    cp.n_outputs_max = 1;
    g_ctx = llama_init_from_model(g_model, cp);
    if (!g_ctx) {
        unload_locked();
        return env->NewStringUTF("Context inference gagal dibuat. Coba tutup aplikasi lain lalu ulangi.");
    }
    g_vocab = llama_model_get_vocab(g_model);
    return env->NewStringUTF("");
}

extern "C" JNIEXPORT jstring JNICALL
Java_id_bronagerona_zenia_MainActivity_nativeGenerate(JNIEnv *env, jobject, jstring jprompt) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_model || !g_ctx || !g_vocab) return env->NewStringUTF("");
    const std::string prompt = jstr(env, jprompt);
    std::vector<llama_token> tokens(std::max<size_t>(4096, prompt.size() * 2));
    int n = llama_tokenize(g_vocab, prompt.c_str(), (int32_t)prompt.size(),
                           tokens.data(), (int32_t)tokens.size(), false, true);
    if (n < 0) {
        tokens.resize((size_t)(-n));
        n = llama_tokenize(g_vocab, prompt.c_str(), (int32_t)prompt.size(),
                           tokens.data(), (int32_t)tokens.size(), false, true);
    }
    if (n <= 0 || n >= 1000) return env->NewStringUTF("");
    tokens.resize((size_t)n);
    llama_memory_clear(llama_get_memory(g_ctx), true);
    llama_batch batch = llama_batch_get_one(tokens.data(), (int32_t)tokens.size());
    if (llama_decode(g_ctx, batch) != 0) return env->NewStringUTF("");

    llama_sampler * sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.75f));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9f, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    std::string out;
    std::vector<char> piece(512);
    for (int i = 0; i < 8; ++i) {
        llama_token tok = llama_sampler_sample(sampler, g_ctx, -1);
        if (llama_vocab_is_eog(g_vocab, tok)) break;
        int32_t bytes = llama_token_to_piece(g_vocab, tok, piece.data(), (int32_t)piece.size(), 0, true);
        if (bytes > 0) out.append(piece.data(), (size_t)bytes);
        const auto stop = out.find("<end_of_turn>");
        if (stop != std::string::npos) {
            out.erase(stop);
            break;
        }
        if (out.size() > 400) break;
        llama_token next = tok;
        llama_batch next_batch = llama_batch_get_one(&next, 1);
        if (llama_decode(g_ctx, next_batch) != 0) break;
    }
    llama_sampler_free(sampler);
    const auto start = out.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) out.clear();
    else out = out.substr(start);
    const auto end = out.find_last_not_of(" \t\r\n");
    if (end != std::string::npos) out.resize(end + 1);
    return env->NewStringUTF(out.c_str());
}
extern "C" JNIEXPORT void JNICALL
Java_id_bronagerona_zenia_MainActivity_nativeUnloadModel(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    unload_locked();
}
