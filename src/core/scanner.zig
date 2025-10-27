const std = @import("std");
const database = @import("database.zig");
const hashing = @import("hashing.zig");

const ignored_dirs: []const []const u8 = &.{
    ".git",
    ".zig-cache",
    "zig-out",
    "node_modules",
    "boot",
    "usr",
    "bun",
    ".bun",
    ".*",
    ".npm",
    ".julia",
    ".config",
};

pub var file_count: i32 = 0;
pub var dir_count: i32 = 0;

fn traverseDir(
    allocator: std.mem.Allocator,
    graph: *database.Graph,
    dir_path: []const u8,
) !void {
    // use .iterate = true, to get iterator of the actual directory
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("Cannot open the directory  {s}: {s}\n", .{ dir_path, @errorName(err) });
        return;
    };
    defer dir.close();

    var iterator = dir.iterate();
    EntryLoop: while (try iterator.next()) |entry| {
        for (ignored_dirs) |ignored| {
            if (std.mem.eql(u8, entry.name, ignored)) {
                continue :EntryLoop;
            }
        }
        const entry_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
        defer allocator.free(entry_path);

        switch (entry.kind) {
            .directory => {
                dir_count += 1;
                // if this is a directory we go deeper
                try traverseDir(allocator, graph, entry_path);
            },
            .file => {
                file_count += 1;
                const hash = hashing.hashFile(entry_path) catch |err| {
                    std.debug.print("Cannot calculate SHA256 for file: {s}: {s}\n", .{ entry_path, @errorName(err) });
                    continue;
                };

                // copies path for database
                const owned_path = try allocator.dupe(u8, entry_path);

                const gop = try graph.nodes.getOrPut(hash);

                if (gop.found_existing) {
                    allocator.free(gop.value_ptr.path);
                }
                gop.value_ptr.* = .{ .path = owned_path };
                std.debug.print("SCANNING: {s}\n", .{entry_path});
            },
            else => {
                continue;
            },
        }
    }
}

pub fn scanDirectory(allocator: std.mem.Allocator, dir_path: []const u8) !void {
    var graph = try database.load(allocator);
    defer graph.deinit();
    std.debug.print("Starting sCaNnIng: {s}\n", .{dir_path});

    var timer = try std.time.Timer.start();
    // const total_files = try traverseDir(allocator, &graph, dir_path);

    try traverseDir(allocator, &graph, dir_path);
    const elapsed_ns = timer.read();
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));

    try database.save(&graph);
    std.debug.print("Scanning ended, database saved.\n", .{});

    std.debug.print(
        \\Scanning ended, database saved.
        \\----------------------------------
        \\Stats:
        \\ - Dir Scaned: {d}
        \\  - Files scanned: {d}
        \\  - Time taken: {d:.3}s
        \\----------------------------------
    , .{ dir_count, file_count, elapsed_s });
}
