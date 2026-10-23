#include "dinor_core.h"
#include <cstring>

extern "C" {
const char* dinor_version() { return "Dinor 0.1.0"; }
int dinor_encrypt(const char* plaintext, char* out, int out_len) {
    int n = strlen(plaintext);
    if (n + 1 > out_len) return -1;
    for (int i = 0; i < n; i++) out[i] = plaintext[n - 1 - i];
    out[n] = '\0';
    return n;
}
}
