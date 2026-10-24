/*
 * Dinor native core (C ABI for Dart FFI).
 *
 * Every function that writes into a caller buffer takes out_len (bytes,
 * including the terminating NUL) and never writes past it. Return values:
 *   >= 0  number of bytes written (excluding NUL), or a boolean/number result
 *   -1    invalid input or output buffer too small
 */
#pragma once
#ifdef __cplusplus
extern "C" {
#endif

/* ---- identity / diagnostics ---- */
const char* dinor_version(void);
int dinor_utf8_length(const char* text);                 /* bytes, -1 on NULL */

/* ---- text processing ---- */
int dinor_encrypt(const char* plaintext, char* out, int out_len);   /* reversible obfuscation, NOT crypto */
int dinor_fast_search(const char* haystack, const char* needle);    /* 1 = found, case-insensitive */
int dinor_format_message(const char* input, char* out, int out_len);
int dinor_extract_web_answer(const char* query, const char* html_text, char* out, int out_len);
int dinor_sanitize_input(const char* input, char* out, int out_len); /* strips control chars, keeps UTF-8 */
int dinor_batch_sanitize(const char* input, char* out, int out_len); /* sanitize + collapse spaces + trim */
int dinor_escape_like(const char* input, char* out, int out_len);   /* escapes % _ \ for ILIKE */
int dinor_calculate_hash(const char* text);                          /* djb2, 31-bit */

/* ---- timing / caching ---- */
long long dinor_fast_timestamp(void);                                /* unix epoch ms */
int dinor_is_stale(long long saved_at_ms, long long ttl_ms, long long now_ms); /* 1 = stale */
long long dinor_retry_delay_ms(int attempt, long long base_ms, long long cap_ms); /* exp. backoff */

/* ---- animation / status ---- */
float dinor_animation_scale(double time_seconds, int dot_index);
const char* dinor_get_status_icon(int status_code);

#ifdef __cplusplus
}
#endif
