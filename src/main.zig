const std = @import("std");
const print = std.debug.print;

// Version info
const VERSION = "0.1.0";
const PROGRAM_NAME = "Dwit";

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("Memory leak detected!", .{});
        }
    }
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse command
    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version")) {
        printVersion();
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        printUsage();
    } else if (std.mem.eql(u8, command, "scan")) {
        try handleScanCommand(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "list")) {
        try handleListCommand(allocator, args[2..]);
    } else {
        print("Unknown command: {s}\n", .{command});
        print("Use '{s} help' for usage information.\n", .{PROGRAM_NAME});
        std.process.exit(1);
    }
}

fn printVersion() void {
    print("{s} v{s} ~kitajusSus \n", .{ PROGRAM_NAME, VERSION });
    print("Smart File Manager - Dwit - written in Zig 0.15.1\n", .{});
}

fn printUsage() void {
    print("Usage: {s} <command> [options]\n\n", .{PROGRAM_NAME});
    print("Commands:\n", .{});
    print("  scan <directory>    Scan directory and index files\n", .{});
    print("  list [options]      List indexed files\n", .{});
    print("  version             Show version information\n", .{});
    print("  help                Show this help message\n", .{});
    print("\nExamples:\n", .{});
    print("  {s} scan ./documents\n", .{PROGRAM_NAME});
    print("  {s} list --type=pdf\n", .{PROGRAM_NAME});
    print("  {s} scan ~/Desktop --recursive\n", .{PROGRAM_NAME});
}

fn handleScanCommand(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len == 0) {
        print("Error: scan command requires a directory path\n", .{});
        print("Usage: {s} scan <directory> [--recursive]\n", .{PROGRAM_NAME});
        return;
    }

    const directory = args[0];
    var recursive = false;

    // Check for recursive flag
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--recursive") or std.mem.eql(u8, arg, "-r")) {
            recursive = true;
        }
    }

    print("📁 Scanning directory: {s}\n", .{directory});
    if (recursive) {
        print("🔄 Recursive mode enabled\n", .{});
    }

    try basicDirectoryScan(allocator, directory, recursive);
}

fn handleListCommand(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    _ = allocator;
    _ = args;

    print("📋 Listing files...\n", .{});
    print("(Not implemented yet - this will show indexed files)\n", .{});
}

// Updated for 0.15.1 - better error handling
fn basicDirectoryScan(allocator: std.mem.Allocator, path: []const u8, recursive: bool) !void {
    print("🔍 Opening directory: {s}\n", .{path});

    // Try to open directory with better error handling
    var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => {
            print("❌ Error: Directory not found: {s}\n", .{path});
            return;
        },
        error.AccessDenied => {
            print("❌ Error: Access denied to directory: {s}\n", .{path});
            return;
        },
        error.NotDir => {
            print("❌ Error: Path is not a directory: {s}\n", .{path});
            return;
        },
        else => {
            print("❌ Error: Failed to open directory: {s} ({})\n", .{ path, err });
            return;
        },
    };
    defer dir.close();

    var file_count: u32 = 0;
    var dir_count: u32 = 0;

    // Iterator pattern for 0.15.1
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        switch (entry.kind) {
            .file => {
                file_count += 1;
                print("📄 File: {s}\n", .{entry.name});

                // Get file info with proper error handling
                if (getBasicFileInfo(dir, entry.name)) |info| {
                    print("   Size: {} bytes, Modified: {}\n", .{ info.size, info.modified });
                } else |err| {
                    print("   (Could not get file info: {})\n", .{err});
                }
            },
            .directory => {
                dir_count += 1;
                print("📁 Directory: {s}\n", .{entry.name});

                if (recursive) {
                    // Updated path joining for 0.15.1
                    const subdir_path = try std.fs.path.join(allocator, &[_][]const u8{ path, entry.name });
                    defer allocator.free(subdir_path);
                    print("  ↳ Scanning subdirectory...\n", .{});
                    try basicDirectoryScan(allocator, subdir_path, recursive);
                }
            },
            else => {
                print("🔗 Other: {s} (type: {})\n", .{ entry.name, entry.kind });
            },
        }
    }

    print("\n✅ Scan complete: {} files, {} directories\n", .{ file_count, dir_count });
}

// Helper function compatible with 0.15.1
fn getBasicFileInfo(dir: std.fs.Dir, name: []const u8) !struct { size: u64, modified: i128 } {
    const file = try dir.openFile(name, .{});
    defer file.close();

    const stat = try file.stat();
    return .{
        .size = stat.size,
        .modified = stat.mtime,
    };
}

// Simple test to verify everything works
test "basic functionality" {
    const testing = std.testing;

    // Test that our program name is correct
    try testing.expect(std.mem.eql(u8, PROGRAM_NAME, "Dwit"));
    try testing.expect(std.mem.eql(u8, VERSION, "0.1.0"));
}

