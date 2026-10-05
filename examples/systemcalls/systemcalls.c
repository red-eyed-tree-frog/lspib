#include "systemcalls.h"

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{
    if (cmd == NULL) {
        return false;
    }

    int status = system(cmd);

    return status != -1 &&
           WIFEXITED(status) &&
           WEXITSTATUS(status) == 0;
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

static bool run_command(const char *outputfile, int count, va_list args)
{
    if (count < 1) {
        return false;
    }

    char *command[count + 1];

    for (int i = 0; i < count; ++i) {
        command[i] = va_arg(args, char *);
        if (command[i] == NULL) {
            return false;
        }
    }
    command[count] = NULL;

    pid_t child = fork();

    if (child == -1) {
        return false;
    }

    if (child == 0) {
        if (outputfile != NULL) {
            int fd = open(outputfile,
                          O_WRONLY | O_CREAT | O_TRUNC,
                          0644);
            if (fd == -1) {
                _exit(EXIT_FAILURE);
            }

            if (dup2(fd, STDOUT_FILENO) == -1) {
                close(fd);
                _exit(EXIT_FAILURE);
            }

            if (fd != STDOUT_FILENO) {
                close(fd);
            }
        }

        execv(command[0], command);

        /* Reached only if execv() fails. */
        _exit(EXIT_FAILURE);
    }

    int status;
    pid_t result;

    do {
        result = waitpid(child, &status, 0);
    } while (result == -1 && errno == EINTR);

    return result == child &&
           WIFEXITED(status) &&
           WEXITSTATUS(status) == 0;
}

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    bool success = run_command(NULL, count, args);
    va_end(args);

    return success;
}

bool do_exec_redirect(const char *outputfile, int count, ...)
{
    if (outputfile == NULL) {
        return false;
    }

    va_list args;
    va_start(args, count);
    bool success = run_command(outputfile, count, args);
    va_end(args);

    return success;
}
