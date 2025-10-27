const std = @import("std");

pub const FileNode = struct {
    path: []u8,
};

pub const Tag = struct {
    name: []const u8,
};

pub const Link = struct {
    source_hash: [32]u8,
    target_hash: [32]u8,
};
