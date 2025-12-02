const std = @import("std");
const os = std.os;
const linux = std.os.linux;

const FAKE_OS_RELEASE =
    \\PRETTY_NAME="Ubuntu 22.04.5 LTS"
    \\NAME="Ubuntu"
    \\VERSION_ID="22.04"
    \\VERSION="22.04.5 LTS (Jammy Jellyfish)"
    \\VERSION_CODENAME=jammy
    \\ID=ubuntu
    \\
;

fn createFakeFd() c_int {
    // Use memfd_create syscall directly
    const fd = linux.memfd_create("fake-os-release", linux.MFD.CLOEXEC);
    if (@as(isize, @bitCast(fd)) < 0) return -1;

    const fd_i32: i32 = @intCast(fd);
    const written = linux.write(fd_i32, FAKE_OS_RELEASE, FAKE_OS_RELEASE.len);
    if (written != FAKE_OS_RELEASE.len) {
        _ = linux.close(fd_i32);
        return -1;
    }
    _ = linux.lseek(fd_i32, 0, linux.SEEK.SET);
    return fd_i32;
}

fn isOsRelease(pathname: ?[*:0]const u8) bool {
    if (pathname == null) return false;
    const path = std.mem.span(pathname.?);
    return std.mem.eql(u8, path, "/etc/os-release") or
        std.mem.eql(u8, path, "/usr/lib/os-release");
}

const OpenFn = *const fn ([*:0]const u8, c_int, linux.mode_t) callconv(std.builtin.CallingConvention.c) c_int;

var real_open: ?OpenFn = null;
var real_open64: ?OpenFn = null;

fn getNextOpen(comptime name: [*:0]const u8) ?OpenFn {
    const RTLD_NEXT: *anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
    const sym = std.c.dlsym(RTLD_NEXT, name);
    if (sym) |s| {
        return @ptrCast(s);
    }
    return null;
}

export fn open(pathname: ?[*:0]const u8, flags: c_int, mode: linux.mode_t) callconv(std.builtin.CallingConvention.c) c_int {
    if (isOsRelease(pathname)) {
        return createFakeFd();
    }

    if (real_open == null) {
        real_open = getNextOpen("open");
    }
    if (real_open) |func| {
        return func(pathname.?, flags, mode);
    }
    return -1;
}

export fn open64(pathname: ?[*:0]const u8, flags: c_int, mode: linux.mode_t) callconv(std.builtin.CallingConvention.c) c_int {
    if (isOsRelease(pathname)) {
        return createFakeFd();
    }

    if (real_open64 == null) {
        real_open64 = getNextOpen("open64");
    }
    if (real_open64) |func| {
        return func(pathname.?, flags, mode);
    }
    return -1;
}
