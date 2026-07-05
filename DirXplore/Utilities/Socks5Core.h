#ifndef SOCKS5_CORE_H
#define SOCKS5_CORE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int success;               // 1 = ok, 0 = error
    unsigned char *response;   // full HTTP response (headers + body), malloced
    size_t response_len;
    char error_msg[512];       // human-readable error message
} socks5_result_t;

/*
 * Connect through SOCKS5 proxy, send HTTP request, read full response.
 *
 * All C-string parameters must be null-terminated.
 * http_request  = the raw HTTP request string (e.g. "GET / HTTP/1.1\r\nHost: ...\r\n\r\n")
 * http_req_len  = length of http_request in bytes
 * timeout_sec   = per-I/O timeout (total may be up to 3x this for connect+handshake+response)
 *
 * Call socks5_free_result() to free the result.
 */
socks5_result_t socks5_fetch(
    const char *proxy_host,      uint16_t proxy_port,
    const char *proxy_username,  const char *proxy_password,
    const char *target_host,     uint16_t target_port,
    const void *http_request,    size_t http_req_len,
    double timeout_seconds);

void socks5_free_result(socks5_result_t *result);

#ifdef __cplusplus
}
#endif

#endif
