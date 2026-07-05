#include "Socks5Core.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

// ---------------------------------------------------------------------------
// String helper (declare early so all functions can use it)
// ---------------------------------------------------------------------------

static void strxcpy(char *dst, const char *src, size_t n) {
    if (!dst || !src || n == 0) return;
    size_t i = 0;
    while (i < n - 1 && src[i]) { dst[i] = src[i]; i++; }
    dst[i] = '\0';
}

// ---------------------------------------------------------------------------
// Dynamic buffer
// ---------------------------------------------------------------------------

typedef struct {
    unsigned char *d;
    size_t len;
    size_t cap;
} buf_t;

static void buf_init(buf_t *b) { memset(b, 0, sizeof(*b)); }

static int buf_grow(buf_t *b, size_t need) {
    while (b->len + need > b->cap) {
        size_t nc = b->cap ? b->cap * 2 : 4096;
        unsigned char *p = (unsigned char *)realloc(b->d, nc);
        if (!p) return -1;
        b->d = p;
        b->cap = nc;
    }
    return 0;
}

static int buf_add(buf_t *b, const void *src, size_t n) {
    if (n == 0) return 0;
    if (buf_grow(b, n) < 0) return -1;
    memcpy(b->d + b->len, src, n);
    b->len += n;
    return 0;
}

static void buf_free(buf_t *b) { free(b->d); b->d = NULL; b->len = b->cap = 0; }

// ---------------------------------------------------------------------------
// poll wrapper
// ---------------------------------------------------------------------------

static int poll_fd(int fd, int for_write, int timeout_ms) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = (short)(for_write ? POLLOUT : POLLIN);
    pfd.revents = 0;
    int rc;
    do { rc = poll(&pfd, 1, timeout_ms); } while (rc < 0 && errno == EINTR);
    if (rc < 0) return -1;
    if (rc == 0) return -2;
    if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) return -1;
    return 0;
}

// ---------------------------------------------------------------------------
// TCP connect
// ---------------------------------------------------------------------------

static int tcp_connect(const char *host, uint16_t port, int tmo,
                       char *err, size_t err_sz) {
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);

    if (inet_pton(AF_INET, host, &addr.sin_addr) != 1) {
        struct addrinfo hints, *res = NULL;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_STREAM;
        if (getaddrinfo(host, NULL, &hints, &res) != 0 || !res) {
            snprintf(err, err_sz, "DNS resolution failed for %s", host);
            return -1;
        }
        addr = *(const struct sockaddr_in *)res->ai_addr;
        addr.sin_port = htons(port);
        freeaddrinfo(res);
    }

    int fd = (int)socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) { snprintf(err, err_sz, "socket: %s", strerror(errno)); return -1; }

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, sizeof(opt));

    int fl = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, fl | O_NONBLOCK);

    int rc = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
    if (rc < 0 && errno != EINPROGRESS) {
        snprintf(err, err_sz, "connect: %s", strerror(errno));
        close(fd); return -1;
    }
    if (rc < 0) {
        rc = poll_fd(fd, 1, tmo);
        if (rc == -2) { strxcpy(err, "Connection timed out", err_sz); close(fd); return -1; }
        if (rc < 0)   { strxcpy(err, "Connection failed", err_sz); close(fd); return -1; }
        int so_err = 0;
        socklen_t sl = sizeof(so_err);
        if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &so_err, &sl) < 0 || so_err != 0) {
            snprintf(err, err_sz, "Connect failed: %s",
                     so_err ? strerror(so_err) : strerror(errno));
            close(fd); return -1;
        }
    }
    fcntl(fd, F_SETFL, fl);
    return fd;
}

// ---------------------------------------------------------------------------
// Blocking send / recv (helpers, not exported)
// ---------------------------------------------------------------------------

static int send_exact(int fd, const void *buf, size_t len, int tmo, char *err, size_t err_sz) {
    const unsigned char *p = (const unsigned char *)buf;
    size_t rem = len;
    while (rem > 0) {
        int rc = poll_fd(fd, 1, tmo);
        if (rc == -2) { strxcpy(err, "Send timed out", err_sz); return -1; }
        if (rc < 0)   { strxcpy(err, "Send failed", err_sz); return -1; }
        ssize_t n = send(fd, p, rem, 0);
        if (n < 0) { if (errno == EINTR) continue; snprintf(err, err_sz, "send: %s", strerror(errno)); return -1; }
        rem -= (size_t)n;
        p += n;
    }
    return 0;
}

/* Returns bytes read, 0 on EOF, -1 error, -2 timeout. */
static int recv_some(int fd, void *buf, size_t max, int tmo, char *err, size_t err_sz) {
    int rc = poll_fd(fd, 0, tmo);
    if (rc == -2) return -2;
    if (rc < 0)   { strxcpy(err, "Recv poll error", err_sz); return -1; }
    ssize_t n = recv(fd, buf, max, 0);
    if (n < 0) { if (errno == EINTR) return 0; snprintf(err, err_sz, "recv: %s", strerror(errno)); return -1; }
    if (n == 0) return 0; // EOF
    return (int)n;
}

/* Read exactly `count` bytes. Returns 0 on success, -1 error, -2 timeout. */
static int recv_exact(int fd, unsigned char *buf, size_t count, int tmo, char *err, size_t err_sz) {
    size_t off = 0;
    while (off < count) {
        int rc = poll_fd(fd, 0, tmo);
        if (rc == -2) return -2;
        if (rc < 0)   { strxcpy(err, "Recv poll error", err_sz); return -1; }
        ssize_t n = recv(fd, buf + off, count - off, 0);
        if (n < 0) { if (errno == EINTR) continue; snprintf(err, err_sz, "recv: %s", strerror(errno)); return -1; }
        if (n == 0) { strxcpy(err, "Connection closed prematurely", err_sz); return -1; }
        off += (size_t)n;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// SOCKS5 handshake
// ---------------------------------------------------------------------------

static int socks5_handshake(int fd, const char *host, uint16_t port,
                            const char *user, const char *pass,
                            int tmo, char *err, size_t err_sz) {
    // --- Greeting ---
    unsigned char greet[4];
    int greet_len;
    if (user && pass) {
        greet[0] = 0x05; greet[1] = 0x02; greet[2] = 0x00; greet[3] = 0x02;
        greet_len = 4;
    } else {
        greet[0] = 0x05; greet[1] = 0x01; greet[2] = 0x00;
        greet_len = 3;
    }
    if (send_exact(fd, greet, (size_t)greet_len, tmo, err, err_sz) < 0) return -1;

    unsigned char sel[2];
    if (recv_exact(fd, sel, 2, tmo, err, err_sz) < 0 || sel[0] != 0x05) {
        strxcpy(err, "Bad SOCKS5 greeting", err_sz);
        return -1;
    }

    // --- Auth ---
    if (sel[1] == 0x02) {
        if (!user || !pass) { strxcpy(err, "Auth required", err_sz); return -1; }
        size_t ul = strlen(user), pl = strlen(pass);
        unsigned char *apkt = (unsigned char *)malloc(3 + ul + pl);
        if (!apkt) { strxcpy(err, "Out of memory", err_sz); return -1; }
        size_t o = 0;
        apkt[o++] = 0x01;
        apkt[o++] = (unsigned char)ul;
        memcpy(apkt + o, user, ul); o += ul;
        apkt[o++] = (unsigned char)pl;
        memcpy(apkt + o, pass, pl); o += pl;
        int r = send_exact(fd, apkt, o, tmo, err, err_sz);
        free(apkt);
        if (r < 0) return -1;
        unsigned char ar[2];
        if (recv_exact(fd, ar, 2, tmo, err, err_sz) < 0 || ar[1] != 0x00) {
            strxcpy(err, "Auth rejected", err_sz);
            return -1;
        }
    } else if (sel[1] != 0x00) {
        snprintf(err, err_sz, "Unsupported auth method %d", sel[1]);
        return -1;
    }

    // --- Connect ---
    unsigned char cbuf[260];
    size_t clen;
    memset(cbuf, 0, sizeof(cbuf));
    cbuf[0] = 0x05; cbuf[1] = 0x01; cbuf[2] = 0x00;

    struct in_addr ia;
    if (inet_pton(AF_INET, host, &ia) == 1) {
        cbuf[3] = 0x01; // IPv4
        memcpy(cbuf + 4, &ia, 4);
        clen = 10;
    } else {
        size_t hlen = strlen(host);
        if (hlen > 255) { strxcpy(err, "Hostname too long", err_sz); return -1; }
        cbuf[3] = 0x03; // domain
        cbuf[4] = (unsigned char)hlen;
        memcpy(cbuf + 5, host, hlen);
        clen = 5 + hlen + 2;
    }
    uint16_t pbe = htons(port);
    memcpy(cbuf + clen - 2, &pbe, 2);

    if (send_exact(fd, cbuf, clen, tmo, err, err_sz) < 0) return -1;

    unsigned char hdr[4];
    if (recv_exact(fd, hdr, 4, tmo, err, err_sz) < 0 || hdr[0] != 0x05 || hdr[1] != 0x00) {
        if (hdr[0] == 0x05)
            snprintf(err, err_sz, "Target refused (reply %d)", hdr[1]);
        else
            strxcpy(err, "Bad connect response", err_sz);
        return -1;
    }

    // Skip remaining address+port in response
    size_t skip;
    switch (hdr[3]) {
        case 0x01: skip = 6;  break; // IPv4(4) + port(2)
        case 0x03: skip = (size_t)hdr[4] + 2; break;
        case 0x04: skip = 18; break; // IPv6(16) + port(2)
        default:   skip = 0;
    }
    while (skip > 0) {
        unsigned char tmp[64];
        size_t rd = skip < sizeof(tmp) ? skip : sizeof(tmp);
        if (recv_exact(fd, tmp, rd, tmo, err, err_sz) < 0) return -1;
        skip -= rd;
    }

    return 0;
}

// ---------------------------------------------------------------------------
// Read full HTTP response (handles Content-Length, chunked, close)
// ---------------------------------------------------------------------------

/* Locate \r\n\r\n in buffer, return offset or -1. */
static int find_header_end(const unsigned char *d, size_t len) {
    if (len < 4) return -1;
    for (size_t i = 0; i <= len - 4; i++) {
        if (d[i] == '\r' && d[i+1] == '\n' && d[i+2] == '\r' && d[i+3] == '\n')
            return (int)i;
    }
    return -1;
}

/* Parse Content-Length from header block. Returns -1 if not present. */
static long parse_content_length(const char *hdr, size_t hdr_len) {
    const char *p = hdr;
    const char *end = hdr + hdr_len;
    while (p < end) {
        const char *nl = (const char *)memchr(p, '\n', (size_t)(end - p));
        if (!nl) break;
        size_t llen = (size_t)(nl - p);
        if (llen > 0 && p[llen-1] == '\r') llen--;
        if (llen > 16) {
            // Check for "content-length:" (case-insensitive)
            int match = 1;
            const char *key = "content-length:";
            for (int i = 0; key[i]; i++) {
                char c = (i < (int)llen) ? p[i] : 0;
                char k = key[i];
                if ((c >= 'A' && c <= 'Z')) c = (char)(c - 'A' + 'a');
                if (c != k) { match = 0; break; }
            }
            if (match) {
                const char *val = p + 15; // skip "content-length:"
                while (val < nl && (*val == ' ' || *val == '\t')) val++;
                if (val < nl) return atol(val);
            }
        }
        p = nl + 1;
    }
    return -1;
}

/* Check for Transfer-Encoding: chunked. Returns 1 if true. */
static int has_chunked(const char *hdr, size_t hdr_len) {
    const char *p = hdr;
    const char *end = hdr + hdr_len;
    while (p < end) {
        const char *nl = (const char *)memchr(p, '\n', (size_t)(end - p));
        if (!nl) break;
        size_t llen = (size_t)(nl - p);
        if (llen > 0 && p[llen-1] == '\r') llen--;
        if (llen > 22) {
            int match = 1;
            const char *key = "transfer-encoding:";
            for (int i = 0; key[i]; i++) {
                char c = (i < (int)llen) ? p[i] : 0;
                char k = key[i];
                if ((c >= 'A' && c <= 'Z')) c = (char)(c - 'A' + 'a');
                if (c != k) { match = 0; break; }
            }
            if (match) {
                const char *val = p + 19; // skip "transfer-encoding:"
                while (val < nl && (*val == ' ' || *val == '\t')) val++;
                size_t vlen = (size_t)(nl - val);
                const char *chk = "chunked";
                if (vlen >= 7) {
                    int cm = 1;
                    for (size_t i = 0; i < 7; i++) {
                        char c = val[i];
                        if ((c >= 'A' && c <= 'Z')) c = (char)(c - 'A' + 'a');
                        if (c != chk[i]) { cm = 0; break; }
                    }
                    if (cm) return 1;
                }
            }
        }
        p = nl + 1;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

socks5_result_t socks5_fetch(
    const char *proxy_host,      uint16_t proxy_port,
    const char *proxy_username,  const char *proxy_password,
    const char *target_host,     uint16_t target_port,
    const void *http_request,    size_t http_req_len,
    double timeout_seconds)
{
    socks5_result_t res;
    memset(&res, 0, sizeof(res));

    int tmo = (int)(timeout_seconds * 1000.0);
    if (tmo < 2000) tmo = 2000;
    if (tmo > 60000) tmo = 60000;

    // --- TCP + SOCKS5 ---
    int fd = tcp_connect(proxy_host, proxy_port, tmo,
                          res.error_msg, sizeof(res.error_msg));
    if (fd < 0) return res;

    if (socks5_handshake(fd, target_host, target_port,
                         proxy_username, proxy_password,
                         tmo, res.error_msg, sizeof(res.error_msg)) < 0) {
        close(fd); return res;
    }

    // --- Send HTTP request ---
    if (send_exact(fd, http_request, http_req_len, tmo,
                   res.error_msg, sizeof(res.error_msg)) < 0) {
        close(fd); return res;
    }

    // --- Read response ---
    buf_t resp;
    buf_init(&resp);

    int header_done = 0;
    int he = -1;
    long content_length = -1;
    int chunked = 0;

    while (1) {
        unsigned char chunk[65536];
        int n = recv_some(fd, chunk, sizeof(chunk), tmo,
                          res.error_msg, sizeof(res.error_msg));
        if (n == -2) { // timeout — could be end of body or real timeout
            if (header_done && content_length < 0 && !chunked) break; // assume done
            strxcpy(res.error_msg, "Response timed out", sizeof(res.error_msg));
            buf_free(&resp); close(fd); return res;
        }
        if (n < 0) { buf_free(&resp); close(fd); return res; }
        if (n == 0) break; // EOF

        if (buf_add(&resp, chunk, (size_t)n) < 0) {
            strxcpy(res.error_msg, "Out of memory", sizeof(res.error_msg));
            buf_free(&resp); close(fd); return res;
        }

        if (!header_done) {
            he = find_header_end(resp.d, resp.len);
            if (he >= 0) {
                header_done = 1;
                content_length = parse_content_length((const char *)resp.d, (size_t)he);
                chunked = has_chunked((const char *)resp.d, (size_t)he);
            }
        }

        if (header_done && content_length >= 0) {
            size_t body_off = (size_t)he + 4;
            size_t body_have = resp.len > body_off ? resp.len - body_off : 0;
            if (body_have >= (size_t)content_length) break; // got all
        }
    }

    close(fd);

    // --- Prepare result ---
    if (resp.len > 0) {
        res.response = (unsigned char *)malloc(resp.len);
        if (res.response) {
            memcpy(res.response, resp.d, resp.len);
            res.response_len = resp.len;
        } else {
            strxcpy(res.error_msg, "Out of memory", sizeof(res.error_msg));
        }
    }
    buf_free(&resp);
    res.success = 1;
    return res;
}

void socks5_free_result(socks5_result_t *result) {
    if (!result) return;
    free(result->response);
    result->response = NULL;
    result->response_len = 0;
    result->success = 0;
}
