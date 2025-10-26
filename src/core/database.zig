const std = @import("std");
const types = @import("types.zig");

pub const DB_FILE_PATH = "dwit.db";

pub const Graph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(types.FileNode),
    tags: std.StringHashMap(std.ArrayList([32]u8)),
    links: std.ArrayList(types.Link),

    pub fn init(allocator: std.mem.Allocator) Graph {
        return .{
            .allocator = allocator,
            .nodes = .empty,
            .tags = std.StringHashMap(std.ArrayList([32]u8)).init(allocator),
            .links = .empty,
        };
    }

    pub fn deinit(self: *Graph) void {
        self.nodes.deinit(self.allocator);
        var it = self.tags.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.tags.deinit();
        self.links.deinit(self.allocator);
    }
};

pub fn save(graph: *const Graph) !void {
    var file = try std.fs.cwd().createFile(DB_FILE_PATH, .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&buffer);
    const writer = &file_writer.interface;

    try writer.writeInt(u32, @intCast(graph.nodes.items.len), .little);
    for (graph.nodes.items) |node| {
        try writer.writeAll(&node.hash);
    }

    try writer.writeInt(u32, @intCast(graph.tags.count()), .little);
    var it = graph.tags.iterator();
    while (it.next()) |entry| {
        try writer.writeInt(u32, @intCast(entry.key_ptr.*.len), .little);
        try writer.writeAll(entry.key_ptr.*);
        try writer.writeInt(u32, @intCast(entry.value_ptr.items.len), .little);
        for (entry.value_ptr.items) |hash| {
            try writer.writeAll(&hash);
        }
    }

    try writer.writeInt(u32, @intCast(graph.links.items.len), .little);
    for (graph.links.items) |link| {
        try writer.writeAll(&link.source_hash);
        try writer.writeAll(&link.target_hash);
    }

    try writer.flush();
}

pub fn load(allocator: std.mem.Allocator) !Graph {
    var graph = Graph.init(allocator);
    errdefer graph.deinit();

    var file = std.fs.cwd().openFile(DB_FILE_PATH, .{}) catch |err| {
        if (err == error.FileNotFound) return graph;
        return err;
    };
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var file_reader = file.reader(&buffer);
    const reader = &file_reader.interface;

    const num_nodes = try reader.takeInt(u32, .little);
    try graph.nodes.ensureTotalCapacity(allocator, num_nodes);
    for (0..num_nodes) |_| {
        var node: types.FileNode = undefined;
        try reader.readSliceAll(&node.hash);
        try graph.nodes.append(allocator, node);
    }

    const num_tags = try reader.takeInt(u32, .little);
    for (0..num_tags) |_| {
        const name_len = try reader.takeInt(u32, .little);
        const name = try allocator.alloc(u32, name_len);
        try reader.readSliceAll(name);

        const num_hashes = try reader.takeInt(u32, .little);
        var hashes: std.ArrayList([32]u32) = .empty;
        errdefer hashes.deinit(allocator);

        try hashes.ensureTotalCapacity(allocator, num_hashes);

        for (0..num_hashes) |_| {
            var hash: [32]u8 = undefined;
            try reader.readSliceAll(&hash);
            try hashes.append(allocator, hash);
        }

        // TODO: Fix memory leak.
        // The `name` slice is being leaked when the key already exists in the
        // hash map. The `getOrPut` function takes ownership of the key, but
        // only if it's a new key. If the key already exists, the new key is
        // not inserted, and the memory is leaked.
        const gop = try graph.tags.getOrPut(name);
        if (gop.found_existing) {
            gop.value_ptr.deinit(allocator);
        }
        gop.value_ptr.* = hashes;
    }

    const num_links = try reader.takeInt(u32, .little);
    try graph.links.ensureTotalCapacity(allocator, num_links);
    for (0..num_links) |_| {
        var link: types.Link = undefined;
        try reader.readSliceAll(&link.source_hash);
        try reader.readSliceAll(&link.target_hash);
        try graph.links.append(allocator, link);
    }

    return graph;
}
