#pragma once
#ifdef __cplusplus
extern "C" {
#endif

const char* dinor_version();
int dinor_encrypt(const char* plaintext, char* out, int out_len);

#ifdef __cplusplus
}
#endif
