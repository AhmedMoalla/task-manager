const std = @import("std");
const mem = std.mem;

const model = @import("model.zig");
const Process = model.Process;
const Pid = model.Pid;

const LinuxProcessManager = @This();

allocator: mem.Allocator,

const procdir = "/proc";

pub fn init(allocator: mem.Allocator) LinuxProcessManager {
    return .{ .allocator = allocator };
}

pub fn listProcesses(self: *LinuxProcessManager) ![]Process {
    var dir = try std.fs.openDirAbsolute(procdir, .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterateAssumeFirstIteration();

    var processes = try std.ArrayList(Process).initCapacity(self.allocator, 30);
    defer processes.deinit();
    while (try iterator.next()) |entry| {
        if (entry.kind != .directory or !isNumeric(entry.name)) continue;

        try processes.append(Process{
            .pid = try std.fmt.parseUnsigned(Pid, entry.name, 10),
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

fn isNumeric(input: []const u8) bool {
    return for (input) |char| {
        if (!std.ascii.isDigit(char)) break false;
    } else true;
}
