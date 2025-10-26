const std = @import("std");
const core = @import("core");

const Commands = enum {
    tag,
    link,
    info,
    find,
    @"export-graph",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("memory leak!\n", .{});
        }
    }

    const args_const = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_const);

    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(allocator);
    for (args_const) |arg| {
        try args_list.append(allocator, arg);
    }
    const args = args_list.items;

    if (args.len < 2) {
        return error.InvalidArguments;
    }

    const command_str = args[1];
    const command = std.meta.stringToEnum(Commands, command_str) orelse {
        return error.UnknownCommand;
    };

    switch (command) {
        .tag => try handleTagCommand(allocator, args),
        .link => try handleLinkCommand(allocator, args),
        .info => try handleInfoCommand(allocator, args),
        .find => try handleFindCommand(allocator, args),
        .@"export-graph" => try handleExportGraphCommand(allocator),
    }
}

fn handleTagCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len < 4) {
        return error.InvalidArguments;
    }
    const file_path = args[2];
    const tags = args[3..];
    try core.tagFile(allocator, file_path, tags);
}

fn handleLinkCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len != 4) {
        return error.InvalidArguments;
    }
    const source_path = args[2];
    const target_path = args[3];
    try core.linkFiles(allocator, source_path, target_path);
}

fn handleInfoCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len != 3) {
        return error.InvalidArguments;
    }
    const file_path = args[2];
    var graph = try core.database.load(allocator);
    defer graph.deinit();

    const hash = try core.hashing.hashFile(file_path);

    std.debug.print("File: {s}\nHash: ", .{file_path});
    for (hash) |byte| {
        std.debug.print("{x:02}", .{byte});
    }
    std.debug.print("\n", .{});

    std.debug.print("Tags:\n", .{});
    var it = graph.tags.iterator();
    while (it.next()) |entry| {
        for (entry.value_ptr.items) |h| {
            if (std.mem.eql(u8, &h, &hash)) {
                std.debug.print("  - {s}\n", .{entry.key_ptr.*});
                break;
            }
        }
    }

    std.debug.print("Links:\n", .{});
    for (graph.links.items) |link| {
        if (std.mem.eql(u8, &link.source_hash, &hash)) {
            // How to get file path from hash? Need a reverse map.
            std.debug.print("  -> ?\n", .{});
        }
        if (std.mem.eql(u8, &link.target_hash, &hash)) {
            // How to get file path from hash? Need a reverse map.
            std.debug.print("  <- ?\n", .{});
        }
    }
}

fn handleFindCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len != 4 or !std.mem.eql(u8, args[2], "--tag")) {
        return error.InvalidArguments;
    }
    const tag = args[3];
    var graph = try core.database.load(allocator);
    defer graph.deinit();

    if (graph.tags.get(tag)) |hashes| {
        for (hashes.items) |hash| {
            // How to get file path from hash? Need a reverse map.
            for (hash) |byte| {
                std.debug.print("{x:02}", .{byte});
            }
            std.debug.print("\n", .{});
        }
    }
}

fn handleExportGraphCommand(allocator: std.mem.Allocator) !void {
    var graph = try core.database.load(allocator);
    defer graph.deinit();

    std.debug.print("digraph dwit {{\n", .{});
    for (graph.nodes.items) |node| {
        std.debug.print("  \"", .{});
        for (node.hash) |byte| {
            std.debug.print("{x:02}", .{byte});
        }
        std.debug.print("\";\n", .{});
    }
    for (graph.links.items) |link| {
        std.debug.print("  \"", .{});
        for (link.source_hash) |byte| {
            std.debug.print("{x:02}", .{byte});
        }
        std.debug.print("\" -> \"", .{});
        for (link.target_hash) |byte| {
            std.debug.print("{x:02}", .{byte});
        }
        std.debug.print("\";\n", .{});
    }
    std.debug.print("}}\n", .{});
}
