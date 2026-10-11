#include "systemcalls.h"
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static bool wait_success(pid_t pid)
{
    int status;
    pid_t result;
    do { result = waitpid(pid, &status, 0); } while (result == -1 && errno == EINTR);
    return result == pid && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

bool do_system(const char *cmd)
{
    if (!cmd) return false;
    int status = system(cmd);
    return status != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

static bool execute(const char *outputfile, int count, va_list args)
{
    if (count < 1) return false;
    char **command = calloc((size_t)count + 1, sizeof(*command));
    if (!command) return false;
    for (int i = 0; i < count; ++i) {
        command[i] = va_arg(args, char *);
        if (!command[i]) { free(command); return false; }
    }
    pid_t pid = fork();
    if (pid == 0) {
        if (outputfile) {
            int fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
            if (fd == -1) _exit(127);
            if (fd != STDOUT_FILENO) {
                if (dup2(fd, STDOUT_FILENO) == -1) _exit(127);
                close(fd);
            }
        }
        execv(command[0], command);
        _exit(127);
    }
    free(command);
    return pid > 0 && wait_success(pid);
}

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    bool result = execute(NULL, count, args);
    va_end(args);
    return result;
}

bool do_exec_redirect(const char *outputfile, int count, ...)
{
    if (!outputfile) return false;
    va_list args;
    va_start(args, count);
    bool result = execute(outputfile, count, args);
    va_end(args);
    return result;
}