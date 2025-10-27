const std = @import("std");
const core = @import("..");

fn traverseDir(
    allocator: std.mem.Allocator,
    graph: *core.database.Graph,
    dir_path: []const u8,
) !void {
    // use .iterate = true, to get iterator of the actual directory
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("Cannot open the directory  {s}: {s}\n", .{ dir_path, @errorName(err) });
        return;
    };
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        const entry_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
        defer allocator.free(entry_path);

        switch (entry.kind) {
            .directory => {
                // if this is a directory we go deeper
                try traverseDir(allocator, graph, entry_path);
            },
            .file => {
                const hash = core.hashing.hashFile(entry_path) catch |err| {
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
                std.debug.print("Zeskanowano: {s}\n", .{entry_path});
            },
            else => {
                continue;
            },
        }
    }
}

pub fn scanDirectory(allocator: std.mem.Allocator, dir_path: []const u8) !void {
    var graph = try core.database.load(allocator);
    defer graph.deinit();

    std.debug.print("Starting sCaNnIng: {s}\n", .{dir_path});
    try traverseDir(allocator, &graph, dir_path);

    try core.database.save(&graph);
    std.debug.print("Scanning ended, database saved.\n", .{});
}
