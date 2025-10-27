const std = @import("std");
const types = @import("types.zig");

const U8ArrayContext = struct {
    pub fn hash(self: U8ArrayContext, key: [32]u8) u64 {
        _ = self;
        return std.hash.Wyhash.hash(0, key[0..]);
    }

    pub fn eql(self: U8ArrayContext, a: [32]u8, b: [32]u8) bool {
        _ = self;
        return std.mem.eql(u8, &a, &b);
    }
};
pub const NodeMap = std.hash_map.HashMap(
    [32]u8, // 1. K (KeyType): Hash of the file
    types.FileNode, // 2. V (ValueType):struct holding a path
    U8ArrayContext, // 3. Context
    std.hash_map.default_max_load_percentage, // 4. max_load_percentage
);

pub const DB_FILE_PATH = "dwit.db";

pub const Graph = struct {
    allocator: std.mem.Allocator,
    nodes: NodeMap,
    tags: std.StringHashMap(std.ArrayList([32]u8)),
    links: std.ArrayList(types.Link),

    pub fn init(allocator: std.mem.Allocator) Graph {
        return .{
            .allocator = allocator,
            .nodes = NodeMap.init(allocator),
            .tags = std.StringHashMap(std.ArrayList([32]u8)).init(allocator),
            .links = .empty,
        };
    }

    pub fn deinit(self: *Graph) void {
        var node_it = self.nodes.iterator();
        while (node_it.next()) |entry| {
            self.allocator.free(entry.value_ptr.path);
        }
        self.nodes.deinit();

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

    // save NodeMap
    try writer.writeInt(u32, @intCast(graph.nodes.count()), .little);
    var node_it = graph.nodes.iterator();
    while (node_it.next()) |entry| {
        // '&' to convert array [32]u8 on a slice []const u8
        try writer.writeAll(&entry.key_ptr.*); // Key (Hash)

        try writer.writeInt(u32, @intCast(entry.value_ptr.path.len), .little);
        try writer.writeAll(entry.value_ptr.path);
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
    // save links
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

    // Wczytaj NodeMap
    const num_nodes = try reader.takeInt(u32, .little);
    for (0..num_nodes) |_| {
        var hash: [32]u8 = undefined;
        try reader.readSliceAll(&hash);

        const path_len = try reader.takeInt(u32, .little);
        const path = try allocator.alloc(u8, path_len);
        errdefer allocator.free(path);
        try reader.readSliceAll(path);

        try graph.nodes.put(hash, .{ .path = path });
    }
    // load tags
    const num_tags = try reader.takeInt(u32, .little);
    for (0..num_tags) |_| {
        const name_len = try reader.takeInt(u32, .little);
        const name = try allocator.alloc(u8, name_len);
        try reader.readSliceAll(name);

        const num_hashes = try reader.takeInt(u32, .little);
        var hashes: std.ArrayList([32]u8) = .empty;
        errdefer hashes.deinit(allocator);

        try hashes.ensureTotalCapacity(allocator, num_hashes);
        for (0..num_hashes) |_| {
            var hash: [32]u8 = undefined;
            try reader.readSliceAll(&hash);
            try hashes.append(allocator, hash);
        }

        const gop = try graph.tags.getOrPut(name);
        if (gop.found_existing) {
            allocator.free(name);
            gop.value_ptr.deinit(allocator);
        }
        gop.value_ptr.* = hashes;
    }
    //load links
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
