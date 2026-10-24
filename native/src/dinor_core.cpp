#include "dinor_core.h"

#include <algorithm>
#include <cctype>
#include <vector>
#include <chrono>
#include <cmath>
#include <cstring>
#include <string>

namespace {

// Copy `s` into out (size out_len). Returns bytes written or -1 if it does not fit.
int copy_out(const std::string& s, char* out, int out_len) {
    if (!out || out_len <= 0) return -1;
    if (static_cast<long long>(s.size()) + 1 > out_len) return -1;
    std::memcpy(out, s.data(), s.size());
    out[s.size()] = '\0';
    return static_cast<int>(s.size());
}

// Length of the longest prefix of s that is <= max_bytes and does not split a UTF-8 code point.
size_t utf8_boundary(const std::string& s, size_t max_bytes) {
    if (s.size() <= max_bytes) return s.size();
    size_t cut = max_bytes;
    // Walk back over continuation bytes (10xxxxxx) so we land on a code point start.
    while (cut > 0 && (static_cast<unsigned char>(s[cut]) & 0xC0) == 0x80) --cut;
    return cut;
}

// True for control characters that never belong in chat text.
bool is_bad_control(unsigned char c) {
    return (c < 0x20 && c != '\n') || c == 0x7F;
}

std::string lower_ascii(std::string s) {
    for (auto& ch : s) {
        unsigned char c = static_cast<unsigned char>(ch);
        if (c >= 'A' && c <= 'Z') ch = static_cast<char>(c - 'A' + 'a');
    }
    return s;
}

std::string sanitize_keep_newlines(const char* input) {
    std::string out;
    out.reserve(std::strlen(input));
    for (const char* p = input; *p; ++p) {
        if (!is_bad_control(static_cast<unsigned char>(*p))) out.push_back(*p);
    }
    return out;
}

}  // namespace

extern "C" {

const char* dinor_version(void) {
    return "Dinor 0.6.0 (Core)";
}

int dinor_utf8_length(const char* text) {
    if (!text) return -1;
    return static_cast<int>(std::strlen(text));
}

int dinor_encrypt(const char* plaintext, char* out, int out_len) {
    if (!plaintext) return -1;
    std::string s(plaintext);
    std::reverse(s.begin(), s.end());
    return copy_out(s, out, out_len);
}

int dinor_fast_search(const char* haystack, const char* needle) {
    if (!haystack || !needle) return 0;
    if (!*needle) return 1;
    return lower_ascii(haystack).find(lower_ascii(needle)) != std::string::npos ? 1 : 0;
}

int dinor_format_message(const char* input, char* out, int out_len) {
    if (!input) return -1;
    std::string result;
    bool last_was_space = true;
    for (const char* p = input; *p; ++p) {
        if (*p == ' ') {
            if (!last_was_space) { result.push_back(' '); last_was_space = true; }
        } else {
            result.push_back(*p);
            last_was_space = false;
        }
    }
    if (!result.empty() && result.back() == ' ') result.pop_back();
    return copy_out(result, out, out_len);
}

int dinor_extract_web_answer(const char* query, const char* html_text, char* out, int out_len) {
    if (!query || !html_text) return -1;

    std::vector<std::string> keywords;
    {
        std::string q(query);
        size_t i = 0;
        while (i < q.size()) {
            while (i < q.size() && std::isspace(static_cast<unsigned char>(q[i]))) ++i;
            size_t start = i;
            while (i < q.size() && !std::isspace(static_cast<unsigned char>(q[i]))) ++i;
            std::string w;
            for (size_t k = start; k < i; ++k) {
                if (!std::ispunct(static_cast<unsigned char>(q[k]))) w.push_back(q[k]);
            }
            if (w.size() > 2) keywords.push_back(lower_ascii(w));
        }
    }

    std::string best;
    int max_matches = 0;
    std::string text(html_text);
    size_t start = 0;
    while (start <= text.size()) {
        size_t end = text.find('.', start);
        if (end == std::string::npos) end = text.size();
        std::string sentence = text.substr(start, end - start);
        start = end + 1;

        size_t a = sentence.find_first_not_of(" \n\r\t");
        if (a == std::string::npos) continue;
        size_t b = sentence.find_last_not_of(" \n\r\t");
        sentence = sentence.substr(a, b - a + 1);
        if (sentence.size() < 20 || sentence.size() > 300) continue;

        std::string lower = lower_ascii(sentence);
        int matches = 0;
        for (const auto& kw : keywords) {
            if (lower.find(kw) != std::string::npos) matches++;
        }
        if (matches > max_matches) {
            max_matches = matches;
            best = sentence + ".";
        }
    }

    if (best.empty()) return -1;
    return copy_out(best, out, out_len);
}

int dinor_sanitize_input(const char* input, char* out, int out_len) {
    if (!input || !out || out_len <= 0) return -1;
    std::string clean = sanitize_keep_newlines(input);
    clean = clean.substr(0, utf8_boundary(clean, static_cast<size_t>(out_len - 1)));
    return copy_out(clean, out, out_len);
}

int dinor_batch_sanitize(const char* input, char* out, int out_len) {
    if (!input || !out || out_len <= 0) return -1;
    std::string result;
    result.reserve(std::strlen(input));
    bool last_was_space = true;
    for (const char* p = input; *p; ++p) {
        unsigned char c = static_cast<unsigned char>(*p);
        if (is_bad_control(c) || c == '\n' || c == '\r' || c == '\t') {
            // Treat line breaks and tabs as a single space; drop other controls.
            if ((c == '\n' || c == '\r' || c == '\t') && !last_was_space) {
                result.push_back(' ');
                last_was_space = true;
            }
            continue;
        }
        if (c == ' ') {
            if (!last_was_space) { result.push_back(' '); last_was_space = true; }
        } else {
            result.push_back(*p);
            last_was_space = false;
        }
    }
    while (!result.empty() && result.back() == ' ') result.pop_back();
    result = result.substr(0, utf8_boundary(result, static_cast<size_t>(out_len - 1)));
    return copy_out(result, out, out_len);
}

int dinor_escape_like(const char* input, char* out, int out_len) {
    if (!input) return -1;
    std::string r;
    for (const char* p = input; *p; ++p) {
        if (*p == '%' || *p == '_' || *p == '\\') r.push_back('\\');
        r.push_back(*p);
    }
    return copy_out(r, out, out_len);
}

int dinor_calculate_hash(const char* text) {
    if (!text) return 0;
    unsigned long hash = 5381;
    for (const unsigned char* p = reinterpret_cast<const unsigned char*>(text); *p; ++p) {
        hash = ((hash << 5) + hash) + *p;
    }
    return static_cast<int>(hash & 0x7FFFFFFFUL);
}

long long dinor_fast_timestamp(void) {
    using namespace std::chrono;
    return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

int dinor_is_stale(long long saved_at_ms, long long ttl_ms, long long now_ms) {
    if (saved_at_ms <= 0 || ttl_ms <= 0) return 1;      // never saved / no TTL: treat as stale
    if (now_ms < saved_at_ms) return 1;                  // clock went backwards: refresh
    return (now_ms - saved_at_ms) > ttl_ms ? 1 : 0;
}

long long dinor_retry_delay_ms(int attempt, long long base_ms, long long cap_ms) {
    if (attempt < 0) attempt = 0;
    if (base_ms <= 0) base_ms = 250;
    if (cap_ms < base_ms) cap_ms = base_ms;
    double d = static_cast<double>(base_ms) * std::pow(2.0, std::min(attempt, 30));
    return static_cast<long long>(std::min(d, static_cast<double>(cap_ms)));
}

float dinor_animation_scale(double time_seconds, int dot_index) {
    double delay = dot_index * 0.2;
    double progress = std::fmod(time_seconds - delay, 1.0);
    if (progress < 0) progress += 1.0;
    double scale = 1.0 + (0.6 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2));
    return static_cast<float>(scale);
}

const char* dinor_get_status_icon(int status_code) {
    switch (status_code) {
        case 0: return "sending";
        case 1: return "sent";
        case 2: return "failed";
        default: return "unknown";
    }
}

}  // extern "C"
