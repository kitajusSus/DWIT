const std = @import("std");

pub const FileNode = struct {
    hash: [32]u8,
    // Other metadata can be added here, e.g., last_seen: i64
};

pub const Tag = struct {
    name: []const u8,
};

pub const Link = struct {
    source_hash: [32]u8,
    target_hash: [32]u8,
};
