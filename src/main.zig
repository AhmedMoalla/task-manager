const std = @import("std");
const ProcessManager = @import("manager").ProcessManager;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var pmon = ProcessManager.init(arena.allocator());
    const processes = try pmon.listProcesses();
    for (processes) |process| {
        std.debug.print("{d} {s}\n", .{ process.pid, process.name });
    }
}
