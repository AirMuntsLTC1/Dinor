#include "dinor_core.h"
#include <cstring>
#include <cctype>
#include <string>

extern "C" {

const char* dinor_version() {
    return "Dinor 0.2.0 (Performance Core)";
}

int dinor_encrypt(const char* plaintext, char* out, int out_len) {
    int n = strlen(plaintext);
    if (n + 1 > out_len) return -1;
    for (int i = 0; i < n; i++) out[i] = plaintext[n - 1 - i];
    out[n] = '\0';
    return n;
}

// Fast Case-Insensitive Search (Returns 1 if found, 0 if not)
int dinor_fast_search(const char* haystack, const char* needle) {
    if (!*needle) return 1; // Empty needle matches
    
    for (const char* h = haystack; *h; ++h) {
        const char* h_ptr = h;
        const char* n_ptr = needle;
        
        while (*h_ptr && *n_ptr && (tolower(*h_ptr) == tolower(*n_ptr))) {
            h_ptr++;
            n_ptr++;
        }
        if (!*n_ptr) return 1; // Match found
    }
    return 0; // Not found
}

// Fast String Formatter (Removes double spaces, trims edges)
int dinor_format_message(const char* input, char* out, int out_len) {
    std::string result;
    bool last_was_space = true; // Skips leading spaces
    
    for (const char* p = input; *p; ++p) {
        if (*p == ' ') {
            if (!last_was_space) {
                result += ' ';
                last_was_space = true;
            }
        } else {
            result += *p;
            last_was_space = false;
        }
    }
    
    // Remove trailing space if any
    if (!result.empty() && result.back() == ' ') {
        result.pop_back();
    }
    
    if (result.length() + 1 > out_len) return -1;
    strcpy(out, result.c_str());
    return result.length();
}

}
