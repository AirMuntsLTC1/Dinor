#include "dinor_core.h"
#include <cstring>
#include <cctype>
#include <string>
#include <sstream>
#include <vector>
#include <algorithm>

extern "C" {

const char* dinor_version() {
    return "Dinor 0.3.0 (AI Core)";
}

int dinor_encrypt(const char* plaintext, char* out, int out_len) {
    int n = strlen(plaintext);
    if (n + 1 > out_len) return -1;
    for (int i = 0; i < n; i++) out[i] = plaintext[n - 1 - i];
    out[n] = '\0';
    return n;
}

int dinor_fast_search(const char* haystack, const char* needle) {
    if (!*needle) return 1;
    for (const char* h = haystack; *h; ++h) {
        const char* h_ptr = h;
        const char* n_ptr = needle;
        while (*h_ptr && *n_ptr && (tolower(*h_ptr) == tolower(*n_ptr))) {
            h_ptr++; n_ptr++;
        }
        if (!*n_ptr) return 1;
    }
    return 0;
}

int dinor_format_message(const char* input, char* out, int out_len) {
    std::string result;
    bool last_was_space = true;
    for (const char* p = input; *p; ++p) {
        if (*p == ' ') {
            if (!last_was_space) { result += ' '; last_was_space = true; }
        } else {
            result += *p; last_was_space = false;
        }
    }
    if (!result.empty() && result.back() == ' ') result.pop_back();
    if (result.length() + 1 > out_len) return -1;
    strcpy(out, result.c_str());
    return result.length();
}

// AI Logic: Find the sentence in the web text that best matches the user's query
int dinor_extract_web_answer(const char* query, const char* html_text, char* out, int out_len) {
    std::string text(html_text);
    std::string q(query);
    std::string best_sentence = "";
    int max_matches = 0;

    // Split HTML/text into sentences (naive splitting by punctuation)
    std::stringstream ss(text);
    std::string sentence;
    
    // Clean the query into words
    std::vector<std::string> keywords;
    std::stringstream qss(q);
    std::string word;
    while (qss >> word) {
        // Remove punctuation from keyword
        word.erase(std::remove_if(word.begin(), word.end(), ::ispunct), word.end());
        if (word.length() > 2) keywords.push_back(word);
    }

    while (std::getline(ss, sentence, '.')) {
        // Trim leading spaces
        sentence.erase(0, sentence.find_first_not_of(" \n\r\t"));
        sentence.erase(sentence.find_last_not_of(" \n\r\t") + 1);

        if (sentence.length() < 20 || sentence.length() > 300) continue;

        int matches = 0;
        for (const auto& kw : keywords) {
            if (dinor_fast_search(sentence.c_str(), kw.c_str())) matches++;
        }

        if (matches > max_matches) {
            max_matches = matches;
            best_sentence = sentence + ".";
        }
    }

    if (best_sentence.empty()) return -1; // No good sentence found

    if (best_sentence.length() + 1 > out_len) return -1;
    strcpy(out, best_sentence.c_str());
    return best_sentence.length();
}

}
