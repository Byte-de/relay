// Owns exactly one cloudflared child. EOF on the private stdin pipe means the
// app stopped sharing or exited (including a crash). No detached tunnel remains.
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;
static volatile sig_atomic_t stopping = 0;
static void request_stop(int signal_number) { (void)signal_number; stopping = 1; }

static double monotonic_seconds(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + (double)now.tv_nsec / 1000000000.0;
}

int main(int argc, char **argv) {
    if (argc < 2 || argv[1][0] != '/') return 64;
    struct sigaction action = {0};
    action.sa_handler = request_stop;
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGHUP, &action, NULL);

    posix_spawn_file_actions_t files;
    int error = posix_spawn_file_actions_init(&files);
    if (error != 0) { fprintf(stderr, "Tunnel supervisor setup failed (%d)\n", error); return 71; }
    // cloudflared never inherits the control pipe or the app's input.
    error = posix_spawn_file_actions_addopen(&files, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    if (error != 0) {
        posix_spawn_file_actions_destroy(&files);
        fprintf(stderr, "Tunnel supervisor input setup failed (%d)\n", error);
        return 71;
    }
    pid_t child = 0;
    error = posix_spawn(&child, argv[1], &files, NULL, &argv[1], environ);
    posix_spawn_file_actions_destroy(&files);
    if (error != 0) { fprintf(stderr, "Tunnel client could not start (%d)\n", error); return 71; }

    struct pollfd control = { .fd = STDIN_FILENO, .events = POLLIN | POLLHUP };
    double deadline = 0;
    int status = 0;
    for (;;) {
        pid_t result = waitpid(child, &status, WNOHANG);
        if (result == child) break;
        if (result == -1 && errno != EINTR) return 71;
        if (stopping && deadline == 0) {
            kill(child, SIGTERM);
            deadline = monotonic_seconds() + 2;
        }
        if (deadline != 0 && monotonic_seconds() >= deadline) {
            // Only our unreaped child can have this PID. Never signal a server.
            kill(child, SIGKILL);
            while (waitpid(child, &status, 0) == -1 && errno == EINTR) {}
            break;
        }
        int ready = poll(&control, 1, 50);
        if (ready > 0 && control.revents) {
            char byte;
            if ((control.revents & (POLLHUP | POLLERR | POLLNVAL)) || read(STDIN_FILENO, &byte, 1) <= 0) {
                stopping = 1;
                control.fd = -1;
            }
        } else if (ready < 0 && errno != EINTR) { stopping = 1; }
    }
    if (stopping) return 0;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
