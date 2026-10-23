#pragma once
#ifdef __cplusplus
extern "C" {
#endif

const char* dinor_version();
int dinor_encrypt(const char* plaintext, char* out, int out_len);

// New Performance Functions
int dinor_fast_search(const char* haystack, const char* needle);
int dinor_format_message(const char* input, char* out, int out_len);

#ifdef __cplusplus
}
#endif
