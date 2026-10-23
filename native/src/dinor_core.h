#pragma once
#ifdef __cplusplus
extern "C" {
#endif

const char* dinor_version();
int dinor_encrypt(const char* plaintext, char* out, int out_len);
int dinor_fast_search(const char* haystack, const char* needle);
int dinor_format_message(const char* input, char* out, int out_len);
int dinor_extract_web_answer(const char* query, const char* html_text, char* out, int out_len);

// New High-Performance Text Processing Functions
int dinor_sanitize_input(const char* input, char* out, int out_len);
int dinor_calculate_hash(const char* text);


// New Animation & Status Functions
float dinor_animation_scale(double time_seconds, int dot_index);
const char* dinor_get_status_icon(int status_code);


// New Performance Functions for Caching & Timing
long long dinor_fast_timestamp();
int dinor_batch_sanitize(const char* input, char* out, int out_len);

#ifdef __cplusplus
}
#endif
