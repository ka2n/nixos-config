/*
 * LD_PRELOAD library to intercept /etc/os-release reads
 * Returns fake Ubuntu os-release content for Intune compatibility
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>

static const char FAKE_OS_RELEASE[] =
    "PRETTY_NAME=\"Ubuntu 22.04.5 LTS\"\n"
    "NAME=\"Ubuntu\"\n"
    "VERSION_ID=\"22.04\"\n"
    "VERSION=\"22.04.5 LTS (Jammy Jellyfish)\"\n"
    "VERSION_CODENAME=jammy\n"
    "ID=ubuntu\n";

typedef int (*open_func_t)(const char *, int, ...);

static int create_fake_fd(void) {
    int fd = memfd_create("fake-os-release", MFD_CLOEXEC);
    if (fd < 0) return -1;

    size_t len = sizeof(FAKE_OS_RELEASE) - 1;
    if (write(fd, FAKE_OS_RELEASE, len) != (ssize_t)len) {
        close(fd);
        return -1;
    }
    lseek(fd, 0, SEEK_SET);
    return fd;
}

static int is_os_release(const char *pathname) {
    if (!pathname) return 0;
    return (strcmp(pathname, "/etc/os-release") == 0 ||
            strcmp(pathname, "/usr/lib/os-release") == 0);
}

int open(const char *pathname, int flags, ...) {
    if (is_os_release(pathname)) {
        return create_fake_fd();
    }

    open_func_t real_open = (open_func_t)dlsym(RTLD_NEXT, "open");
    if (!real_open) return -1;

    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return real_open(pathname, flags, mode);
    }
    return real_open(pathname, flags);
}

int open64(const char *pathname, int flags, ...) {
    if (is_os_release(pathname)) {
        return create_fake_fd();
    }

    open_func_t real_open64 = (open_func_t)dlsym(RTLD_NEXT, "open64");
    if (!real_open64) return -1;

    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return real_open64(pathname, flags, mode);
    }
    return real_open64(pathname, flags);
}
