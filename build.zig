const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    var builder = Builder.init(b);
    _ = builder
        .executable(.{ .name = "task_manager", .root_source_file = "src/main.zig", .link_lib_c = true })
        .module(.{ .name = "manager", .root_source_file = "src/manager/root.zig" });
}

const BuilderOptions = struct {
    name: []const u8,
    root_source_file: []const u8,
    link_lib_c: bool = false,
};

const Builder = struct {
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    // Steps
    run_step: *Build.Step,
    test_step: *Build.Step,

    exe_module: ?*Build.Module = undefined,

    pub fn init(b: *Build) Builder {
        return initWithOptions(b, b.standardTargetOptions(.{}), b.standardOptimizeOption(.{}));
    }

    pub fn initWithOptions(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Builder {
        return Builder{
            .b = b,
            .target = target,
            .optimize = optimize,
            .run_step = b.step("run", "Run the app"),
            .test_step = b.step("test", "Run unit tests"),
        };
    }

    pub fn executable(self: *Builder, options: BuilderOptions) *Builder {
        var b = self.b;
        self.exe_module = b.createModule(.{
            .root_source_file = b.path(options.root_source_file),
            .target = self.target,
            .optimize = self.optimize,
            .link_libc = true,
        });

        const exe = b.addExecutable(.{
            .name = options.name,
            .root_module = self.exe_module,
        });

        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        self.run_step.dependOn(&run_cmd.step);

        const exe_unit_tests = b.addTest(.{
            .root_module = self.exe_module,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        self.test_step.dependOn(&run_exe_unit_tests.step);

        return self;
    }

    pub fn module(self: *Builder, options: BuilderOptions) *Builder {
        if (self.exe_module == null) {
            @panic("executable should be created before adding modules");
        }

        var b = self.b;
        const lib_mod = b.createModule(.{
            .root_source_file = b.path(options.root_source_file),
            .target = self.target,
            .optimize = self.optimize,
        });
        self.exe_module.?.addImport(options.name, lib_mod);
        const lib_unit_tests = b.addTest(.{
            .root_module = lib_mod,
        });
        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
        self.test_step.dependOn(&run_lib_unit_tests.step);
        return self;
    }
};
