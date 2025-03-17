const std = @import("std");
const mem = std.mem;
const windows = std.os.windows;

const model = @import("model.zig");
const Process = model.Process;
const Pid = model.Pid;

const WindowsProcessManager = @This();

allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator) WindowsProcessManager {
    return .{ .allocator = allocator };
}

pub fn listProcesses(self: *WindowsProcessManager) ![]Process {
    const handle = windows.kernel32.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0);
    if (handle == windows.INVALID_HANDLE_VALUE) {
        switch (windows.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
    defer windows.CloseHandle(handle);

    var processEntry: PROCESSENTRY32 = undefined;
    processEntry.dwSize = @sizeOf(PROCESSENTRY32);
    if (Process32First(handle, &processEntry) == 0) {
        return error.MissingDebugInfo;
    }

    var processes = try std.ArrayList(Process).initCapacity(self.allocator, 30);
    defer processes.deinit();

    var moduleValid = true;
    while (moduleValid) {
        const name = self.allocator.dupe(u8, mem.sliceTo(&processEntry.szExeFile, 0)) catch &.{};
        errdefer self.allocator.free(name);

        try processes.append(Process{
            .pid = processEntry.th32ProcessID,
            .name = name,
        });
        moduleValid = Process32Next(handle, &processEntry) == 1;
    }

    return processes.toOwnedSlice();
}

const PROCESSENTRY32 = extern struct {
    dwSize: windows.DWORD,
    cntUsage: windows.DWORD,
    th32ProcessID: windows.DWORD,
    th32DefaultHeapID: windows.ULONG_PTR,
    th32ModuleID: windows.DWORD,
    cntThreads: windows.DWORD,
    th32ParentProcessID: windows.DWORD,
    pcPriClassBase: windows.LONG,
    dwFlags: windows.DWORD,
    szExeFile: [windows.MAX_PATH]windows.CHAR,
};

extern "kernel32" fn Process32First(
    hSnapshot: windows.HANDLE,
    lppe: *PROCESSENTRY32,
) callconv(.winapi) windows.BOOL;

extern "kernel32" fn Process32Next(
    hSnapshot: windows.HANDLE,
    lppe: *PROCESSENTRY32,
) callconv(.winapi) windows.BOOL;
