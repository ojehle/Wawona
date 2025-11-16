#include "logging.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

FILE *compositor_log_file = NULL;
FILE *client_log_file = NULL;

void init_compositor_logging(void) {
    // Logging now goes to stdout/stderr which is redirected to /tmp/compositor-run.log
    // No separate log file needed
    compositor_log_file = NULL;
}

void init_client_logging(void) {
    // Logging now goes to stdout/stderr which is redirected to /tmp/client-run.log or /tmp/input-client-run.log
    // No separate log file needed
    client_log_file = NULL;
}

void log_printf(const char *prefix, const char *format, ...) {
    va_list args;
    
    // Print to stdout
    if (prefix) {
        printf("%s", prefix);
    }
    va_start(args, format);
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wformat-nonliteral"
    vprintf(format, args);
    #pragma clang diagnostic pop
    va_end(args);
    fflush(stdout);
    
    // Print to log file (compositor or client based on which is initialized)
    FILE *log_file = compositor_log_file ? compositor_log_file : client_log_file;
    if (log_file) {
        if (prefix) {
            fprintf(log_file, "%s", prefix);
        }
        va_start(args, format);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wformat-nonliteral"
        vfprintf(log_file, format, args);
        #pragma clang diagnostic pop
        va_end(args);
        fflush(log_file);
    }
}

void log_fflush(void) {
    fflush(stdout);
    if (compositor_log_file) fflush(compositor_log_file);
    if (client_log_file) fflush(client_log_file);
}

void cleanup_logging(void) {
    if (compositor_log_file) {
        fprintf(compositor_log_file, "\n=== Compositor Log Ended ===\n\n");
        fclose(compositor_log_file);
        compositor_log_file = NULL;
    }
    if (client_log_file) {
        fprintf(client_log_file, "\n=== Client Log Ended ===\n\n");
        fclose(client_log_file);
        client_log_file = NULL;
    }
}

