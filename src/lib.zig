const std = @import("std");

pub const database = @import("core/database.zig");
pub const hashing = @import("core/hashing.zig");
pub const types = @import("core/types.zig");
pub const scanner = @import("core/scanner.zig"); // DODANE: Eksportujemy nowy moduł

pub fn tagFile(allocator: std.mem.Allocator, file_path: []const u8, tags: []const []const u8) !void {
    var graph = try database.load(allocator);
    defer graph.deinit();

    const hash = try hashing.hashFile(file_path);

    // Change: HashMap of nodes
    // Checks if the node exist
    if (graph.nodes.get(hash) == null) {
        // if not create new
        const path_owned = try allocator.dupe(u8, file_path);
        errdefer allocator.free(path_owned);

        try graph.nodes.put(hash, .{ .path = path_owned });
    }

    for (tags) |tag| {
        const gop = try graph.tags.getOrPut(tag);
        if (!gop.found_existing) {
            gop.value_ptr.* = .empty;
        }
        // TODO: dont duplicate
        try gop.value_ptr.append(allocator, hash);
    }

    try database.save(&graph);
}

pub fn linkFiles(allocator: std.mem.Allocator, source_path: []const u8, target_path: []const u8) !void {
    var graph = try database.load(allocator);
    defer graph.deinit();

    const source_hash = try hashing.hashFile(source_path);
    const target_hash = try hashing.hashFile(target_path);

    // TODO: Ensure nodes for these hashes exist

    try graph.links.append(allocator, .{ .source_hash = source_hash, .target_hash = target_hash });

    try database.save(&graph);
}

test "tag file" {
    const allocator = std.testing.allocator;
    const file_name = "test_file.txt";

    // Clean up from previous runs
    std.fs.cwd().deleteFile(database.DB_FILE_PATH) catch {};

    var file = try std.fs.cwd().createFile(file_name, .{});
    var buf: [16]u8 = undefined;
    var file_writer = file.writer(&buf);
    try file_writer.interface.writeAll("hello");
    file.close();
    defer std.fs.cwd().deleteFile(file_name) catch {};

    const tags = &[_][]const u8{ "tag1", "tag2" };
    try tagFile(allocator, file_name, tags);

    var graph = try database.load(allocator);
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 1), graph.nodes.items.len);

    const hash = try hashing.hashFile(file_name);
    try std.testing.expectEqualSlices(u8, &hash, &graph.nodes.items[0].hash);

    try std.testing.expectEqual(@as(usize, 2), graph.tags.count());

    var tag1_hashes = graph.tags.get("tag1").?;
    try std.testing.expectEqual(@as(usize, 1), tag1_hashes.items.len);
    try std.testing.expectEqualSlices(u8, &hash, &tag1_hashes.items[0]);

    var tag2_hashes = graph.tags.get("tag2").?;
    try std.testing.expectEqual(@as(usize, 1), tag2_hashes.items.len);
    try std.testing.expectEqualSlices(u8, &hash, &tag2_hashes.items[0]);
}
