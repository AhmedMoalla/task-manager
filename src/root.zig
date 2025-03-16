const std = @import("std");
const builtin = @import("builtin");

const native_os = builtin.os.tag;

pub const Process = struct {
    pid: std.posix.pid_t,
    name: []const u8,
};

const Processes = std.ArrayList(Process);

const LinuxProcessManager = struct {
    allocator: std.mem.Allocator,

    const procdir = "/proc";

    fn init(allocator: std.mem.Allocator) LinuxProcessManager {
        return .{ .allocator = allocator };
    }

    fn listProcesses(self: *LinuxProcessManager) ![]Process {
        var dir = try std.fs.openDirAbsolute(procdir, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterateAssumeFirstIteration();

        var processes = try Processes.initCapacity(self.allocator, 30);
        defer processes.deinit();
        while (try iterator.next()) |entry| {
            if (entry.kind != .directory or !isNumeric(entry.name)) continue;

            try processes.append(Process{
                .pid = try std.fmt.parseUnsigned(std.posix.pid_t, entry.name, 10),
                .name = try self.proc(entry.name, "comm"),
            });
        }

        return processes.toOwnedSlice();
    }

    // TODO: filename should be enum
    fn proc(self: *LinuxProcessManager, pid: []const u8, filename: []const u8) ![]const u8 {
        const filepath = try std.fs.path.join(self.allocator, &[_][]const u8{ procdir, pid, filename });
        const file = try std.fs.openFileAbsolute(filepath, .{});
        defer file.close();

        return file.reader().readAllAlloc(self.allocator, 1024);
    }
};

/// Interface for all ProcessManager implementations. Pattern taken from std.process.ArgIterator.
pub const ProcessManager = union(enum) {
    const InnerType = switch (native_os) {
        .linux => LinuxProcessManager,
        else => unreachable,
    };

    inner: InnerType,

    pub fn init(allocator: std.mem.Allocator) ProcessManager {
        if (native_os != .linux) {
            @compileError("Only Linux is supported for now.");
        }

        return ProcessManager{ .inner = LinuxProcessManager.init(allocator) };
    }

    pub fn listProcesses(self: *ProcessManager) ![]Process {
        return self.inner.listProcesses();
    }
};

fn isNumeric(input: []const u8) bool {
    return for (input) |char| {
        if (!std.ascii.isDigit(char)) break false;
    } else true;
}

test "isPid" {
    try std.testing.expect(isNumeric("123"));
    try std.testing.expect(isNumeric("1234"));
    try std.testing.expect(!isNumeric("a123"));
    try std.testing.expect(!isNumeric("123a"));
    try std.testing.expect(!isNumeric("12-3"));
}
