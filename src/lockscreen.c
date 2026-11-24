// lockscreen: lock the Mac screen immediately (the same lock as Control Center's "Lock Screen").
// `lockscreen --check` only verifies the lock function is available, without locking.
#include <dlfcn.h>
#include <string.h>

int main(int argc, char **argv) {
    void *h = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY);
    if (!h) return 2;
    int (*lock)(void) = (int (*)(void))dlsym(h, "SACLockScreenImmediate");
    if (!lock) return 3;
    if (argc > 1 && strcmp(argv[1], "--check") == 0) return 0;
    lock();
    return 0;
}
