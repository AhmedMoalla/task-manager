/// Interface for all ProcessManager implementations. Pattern taken from std.process.ArgIterator.
const std = @import("std");
const builtin = @import("builtin");

const model = @import("model.zig");
const Process = model.Process;
const Pid = model.Pid;

const ProcessManager = @This();

const native_os = builtin.os.tag;

const InnerType = switch (builtin.os.tag) {
    .linux => @import("LinuxProcessManager.zig"),
    .windows => @import("WindowsProcessManager.zig"),
    else => @compileError(@tagName(native_os) ++ " is not supported"),
};

inner: InnerType,

pub fn init(allocator: std.mem.Allocator) ProcessManager {
    return switch (native_os) {
        .linux, .windows => ProcessManager{ .inner = InnerType.init(allocator) },
        else => @compileError(@tagName(native_os) ++ " is not supported"),
    };
}

pub fn listProcesses(self: *ProcessManager) ![]Process {
    return self.inner.listProcesses();
}
