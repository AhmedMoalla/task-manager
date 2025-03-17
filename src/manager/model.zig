const std = @import("std");
const builtin = @import("builtin");

const native_os = builtin.os.tag;

pub const Pid = if (native_os == .windows) std.os.windows.DWORD else std.posix.pid_t;

pub const Process = struct {
    pid: Pid,
    name: []const u8,
};
