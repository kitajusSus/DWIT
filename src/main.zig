const std = @import("std");
const print = std.debug.print;

const VERSION = "0.1.3";
const PROGRAM_NAME = "DWIT";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("Memory leak detected!", .{});
            std.process.exit(1);
        }
    }
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];
    const command_args = args[2..];
    if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version")) {
        printVersion();
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        printUsage();
    } else if (std.mem.eql(u8, command, "scan")) {
        try handleScanCommand(allocator, command_args);
    } else if (std.mem.eql(u8, command, "list")) {
        try handleListCommand(command_args);
    } else {
        print("Unknown command: {s}\n", .{command});
        print("Use '{s} help' for usage information.\n", .{PROGRAM_NAME});
        std.process.exit(1);
    }
}

fn printVersion() void {
    print("{s} v{s} ~kitajusSus \n", .{ PROGRAM_NAME, VERSION });
    print("Smart File Manager - Dwit - written in Zig {s}\n", .{@import("builtin").zig_version_string});
}

fn printUsage() void {
    print("Usage: {s} <command> [directory] [options]\n\n", .{PROGRAM_NAME});
    print("Commands:\n", .{});
    print("  scan <directory>    Scan directory and index files\n", .{});
    print("    --recursive, -r   Scan recursively (equivalent to --depth=all)\n", .{});
    print("    --depth=<num>     Scan to specified depth (e.g., --depth=2; use 'all' for unlimited)\n", .{});
    print("    --benchmark, -b   Show benchmark (files scanned, time taken)\n", .{});
    print("  list [directory]    List indexed files (defaults to current dir)\n", .{});
    print("    --type=<ext>      Filter by file extension (e.g., --type=pdf)\n", .{});
    print("  version             Show version information\n", .{});
    print("  help                Show this help message\n", .{});
    print("\nExamples:\n", .{});
    print("  {s} scan ~/Documents\n", .{PROGRAM_NAME});
    print("  {s} scan ~/Desktop --depth=2\n", .{PROGRAM_NAME});
    print("  {s} scan ~/Desktop --recursive --benchmark\n", .{PROGRAM_NAME});
    print("  {s} list ~/Downloads --type=pdf\n", .{PROGRAM_NAME});
}

fn handleScanCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        print("Error: scan command requires a directory path\n", .{});
        print("Usage: {s} scan <directory> [--depth=<num>|--recursive] [--benchmark]\n", .{PROGRAM_NAME});
        return;
    }

    const directory = args[0];
    var depth_str: []const u8 = "0"; // default no recursion
    var benchmark = false;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--recursive") or std.mem.eql(u8, arg, "-r")) {
            depth_str = "all";
        } else if (std.mem.startsWith(u8, arg, "--depth=")) {
            depth_str = arg["--depth=".len..];
        } else if (std.mem.eql(u8, arg, "--benchmark") or std.mem.eql(u8, arg, "-b")) {
            benchmark = true;
        }
    }

    var depth: ?u32 = null;
    if (std.mem.eql(u8, depth_str, "all")) {
        depth = null; // unlimited
    } else {
        depth = std.fmt.parseInt(u32, depth_str, 10) catch {
            print("Error: Invalid depth value '{s}'. Use a number or 'all'.\n", .{depth_str});
            return;
        };
    }

    print("📁 Scanning directory: {s}\n", .{directory});
    if (depth == null) {
        print("🔄 Recursive mode enabled (unlimited depth)\n", .{});
    } else if (depth.? > 0) {
        print("🔄 Scanning to depth: {}\n", .{depth.?});
    }
    if (benchmark) {
        print("⏱️  Benchmark mode enabled\n", .{});
    }

    const start_time = if (benchmark) std.time.nanoTimestamp() else 0;
    var total_files: u32 = 0;

    try basicDirectoryScan(allocator, directory, depth, benchmark, &total_files);

    if (benchmark) {
        const end_time = std.time.nanoTimestamp();
        const elapsed_ns = end_time - start_time;
        const elapsed_ms = @divFloor(elapsed_ns, 1_000_000);
        print("\n⏱️  Benchmark: Scanned {} files in {} ms\n", .{ total_files, elapsed_ms });
    }
}

// ZMIANA: Poprawiona logika parsowania i usunięty nieużywany `allocator`.
fn handleListCommand(args: []const []const u8) !void {
    var dir_path: []const u8 = ".";
    var ext: []const u8 = "";
    var dir_path_set = false;

    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--type=")) {
            ext = arg["--type=".len..];
        } else if (!std.mem.startsWith(u8, arg, "-") and !dir_path_set) {
            // Pierwszy argument, który nie jest flagą, to ścieżka.
            dir_path = arg;
            dir_path_set = true;
        }
    }

    print("📋 Listing files in: {s} (filter: {s})\n", .{ dir_path, if (ext.len == 0) "all" else ext });
    try listing(dir_path, ext);
}

fn listing(dir_path: []const u8, ext: []const u8) !void {
    var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch |err| {
        print("❌ Error opening directory '{s}': {s}\n", .{ dir_path, @errorName(err) });
        return;
    };
    defer dir.close();

    var iterator = dir.iterate();
    var found: u32 = 0;

    while (try iterator.next()) |entry| {
        if (entry.kind == .file and std.mem.eql(u8, std.fs.path.extension(entry.name), ext)) {
            found += 1;
            print("📄 {s}\n", .{entry.name});

            const stat = dir.statFile(entry.name) catch |err| {
                print("   (Could not get file info: {s})\n", .{@errorName(err)});
                continue;
            };

            print("   Size: {} bytes, Modified: {d}\n", .{ stat.size, stat.mtime });
        }
    }

    if (found == 0) {
        print("\nℹ️  No matching files found.\n", .{});
    } else {
        print("\n✅ Listed {} files\n", .{found});
    }
}

fn basicDirectoryScan(allocator: std.mem.Allocator, path: []const u8, depth: ?u32, benchmark: bool, total_files: *u32) !void {
    print("🔍 Scanning: {s}\n", .{path});

    var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |err| {
        print("❌ Error opening directory '{s}': {s}\n", .{ path, @errorName(err) });
        return;
    };
    defer dir.close();

    var file_count: u32 = 0;
    var dir_count: u32 = 0;

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        switch (entry.kind) {
            .file => {
                file_count += 1;
                if (!benchmark) {
                    print("📄 File: {s}\n", .{entry.name});

                    if (dir.statFile(entry.name)) |stat| {
                        print("   Size: {} bytes, Modified: {d}\n", .{ stat.size, stat.mtime });
                    } else |err| {
                        print("   (Could not get file info: {s})\n", .{@errorName(err)});
                    }
                }
            },
            .directory => {
                dir_count += 1;
                if (!benchmark) {
                    print("📁 Directory: {s}\n", .{entry.name});
                }

                if (depth == null or depth.? > 0) {
                    const new_depth = if (depth) |d| d - 1 else null;
                    const subdir_path = try std.fs.path.join(allocator, &[_][]const u8{ path, entry.name });
                    defer allocator.free(subdir_path);
                    try basicDirectoryScan(allocator, subdir_path, new_depth, benchmark, total_files);
                }
            },
            else => {},
        }
    }

    total_files.* += file_count;

    if (!benchmark) {
        print("✅ Scan of '{s}' complete: {} files, {} directories\n", .{ path, file_count, dir_count });
    }
}

test "basic functionality" {
    const testing = std.testing;
    try testing.expect(std.mem.eql(u8, PROGRAM_NAME, "DWIT"));
    try testing.expect(std.mem.eql(u8, VERSION, "0.1.2"));
}

