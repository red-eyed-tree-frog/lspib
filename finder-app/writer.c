#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>

static void report_error(const char *operation, const char *path, int error)
{
    syslog(LOG_ERR, "%s '%s': %s", operation, path, strerror(error));
    fprintf(stderr, "writer: %s '%s': %s\n", operation, path, strerror(error));
}

int main(int argc, char *argv[])
{
    openlog("writer", LOG_PID, LOG_USER);

    if (argc != 3) {
        syslog(LOG_ERR, "Expected a file path and a string; received %d arguments", argc - 1);
        fprintf(stderr, "Usage: %s <file> <string>\n", argv[0]);
        closelog();
        return EXIT_FAILURE;
    }

    const char *path = argv[1];
    const char *text = argv[2];
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0664);
    if (fd == -1) {
        report_error("Cannot open", path, errno);
        closelog();
        return EXIT_FAILURE;
    }

    syslog(LOG_DEBUG, "Writing %s to %s", text, path);
    size_t length = strlen(text);
    size_t offset = 0;
    int result = EXIT_SUCCESS;

    while (offset < length) {
        ssize_t written = write(fd, text + offset, length - offset);
        if (written < 0 && errno == EINTR)
            continue;
        if (written <= 0) {
            int error = written < 0 ? errno : EIO;
            report_error("Cannot write", path, error);
            result = EXIT_FAILURE;
            break;
        }
        offset += (size_t)written;
    }

    if (close(fd) == -1) {
        report_error("Cannot close", path, errno);
        result = EXIT_FAILURE;
    }
    closelog();
    return result;
}