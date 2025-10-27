const std = @import("std");
// (database, hashing, scanner, etc.) from lib.zig.
const core = @import("core");

/// Using an enum allows for easy parsing and dispatch.
const Commands = enum {
    scan, // New: Recursively scan a directory to build the file database
    list, // New: List known files, with optional filtering
    tag,
    link,
    info,
    find,
    @"export-graph", // The '@' symbol allows using a string that might be a keyword
};
/// The main entry point of the application.
pub fn main() !void {
    // Set up a General Purpose Allocator.
    // This is a robust allocator good for general use.
    // The empty struct '.{}' means we use the default options.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // 'defer' ensures this code block runs at the end of the function,
    // right before it returns. This is crucial for resource cleanup.
    defer {
        // Check for memory leaks. If deinit() returns .leak,
        // it means we forgot to free some memory.
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("memory leak!\n", .{});
        }
    }

    // Allocate and retrieve command-line arguments.
    const args_const = try std.process.argsAlloc(allocator);
    // Free the argument memory when main exits.
    defer std.process.argsFree(allocator, args_const);

    // Copy the const arguments into an ArrayList.
    // This provides a more flexible API (e.g., args.items)
    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(allocator);
    for (args_const) |arg| {
        try args_list.append(allocator, arg);
    }
    const args = args_list.items;

    // The program name (arg[0]) and a command (arg[1]) are required.
    if (args.len < 2) {
        std.debug.print("Error: No command provided.\n", .{});
        std.debug.print("Usage: dwit <command> [options]\n", .{});
        return error.InvalidArguments;
    }

    const command_str = args[1];
    // Convert the command string (e.g., "scan") into our Commands enum.
    // 'orelse' provides a fallback if the string doesn't match any enum value.
    const command = std.meta.stringToEnum(Commands, command_str) orelse {
        std.debug.print("Error: Unknown command '{s}'\n", .{command_str});
        return error.UnknownCommand;
    };

    // This is the main command dispatcher.
    // It routes execution to the correct handler function based on the enum.
    switch (command) {
        .scan => try handleScanCommand(allocator, args),
        .list => try handleListCommand(allocator, args),
        .tag => try handleTagCommand(allocator, args),
        .link => try handleLinkCommand(allocator, args),
        .info => try handleInfoCommand(allocator, args),
        .find => try handleFindCommand(allocator, args),
        .@"export-graph" => try handleExportGraphCommand(allocator),
    }
}

/// Handles the 'scan' command.
/// Usage: dwit scan <directory_path>
fn handleScanCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len != 3) {
        std.debug.print("Usage: dwit scan <directory_path>\n", .{});
        return error.InvalidArguments;
    }
    const dir_path = args[2];
    try core.scanner.scanDirectory(allocator, dir_path);
}

/// Handles the 'list' command.
/// Usage: dwit list
///        dwit list --type <extension>
fn handleListCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    var filter_ext: ?[]const u8 = null;

    // Parse optional filter arguments
    if (args.len > 2) {
        if (args.len != 4 or !std.mem.eql(u8, args[2], "--type")) {
            std.debug.print("Usage: dwit list [--type <extension>]\n", .{});
            return error.InvalidArguments;
        }

        // User can provide "pdf" or ".pdf". We standardize on ".pdf".
        if (args[3][0] == '.') {
            filter_ext = args[3];
        } else {
            // Allocate a new string to add the '.' prefix.
            filter_ext = try std.fmt.allocPrint(allocator, ".{s}", .{args[3]});
            // Ensure this new string is freed later.
            defer if (args[3][0] != '.') allocator.free(filter_ext.?);
        }
    }

    var graph = try core.database.load(allocator);
    defer graph.deinit();

    std.debug.print("Known files:\n", .{});
    var it = graph.nodes.iterator();
    while (it.next()) |entry| {
        // entry.value_ptr is the FileNode struct, which contains the path.
        const path = entry.value_ptr.path;

        if (filter_ext) |ext| {
            // If a filter is active, check the file extension.
            if (std.mem.eql(u8, std.fs.path.extension(path), ext)) {
                std.debug.print("  - {s}\n", .{path});
            }
        } else {
            // No filter, print all paths.
            std.debug.print("  - {s}\n", .{path});
        }
    }
}

/// Handles the 'tag' command.
/// Usage: dwit tag <file_path> <tag1> [tag2] ...
fn handleTagCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: dwit tag <file_path> <tag1> [tag2] ...\n", .{});
        return error.InvalidArguments;
    }
    const file_path = args[2];
    const tags = args[3..]; // 'tags' is a slice of all remaining arguments
    try core.tagFile(allocator, file_path, tags);
    std.debug.print("Tagged: {s}\n", .{file_path});
}

/// Handles the 'link' command.
/// Usage: dwit link <source_file> <target_file>
fn handleLinkCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len != 4) {
        std.debug.print("Usage: dwit link <source_file> <target_file>\n", .{});
        return error.InvalidArguments;
    }
    const source_path = args[2];
    const target_path = args[3];
    try core.linkFiles(allocator, source_path, target_path);
    std.debug.print("Linked: {s} -> {s}\n", .{ source_path, target_path });
}

/// Handles the 'info' command.
/// Usage: dwit info <file_path>
/// This function now correctly looks up paths from hashes.
fn handleInfoCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len != 3) {
        std.debug.print("Usage: dwit info <file_path>\n", .{});
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

    // --- Find Tags ---
    std.debug.print("Tags:\n", .{});
    var it = graph.tags.iterator();
    while (it.next()) |entry| {
        // entry.value_ptr is the ArrayList of hashes for this tag
        for (entry.value_ptr.items) |h| {
            if (std.mem.eql(u8, &h, &hash)) {
                // entry.key_ptr.* is the tag name (string)
                std.debug.print("  - {s}\n", .{entry.key_ptr.*});
                break; // Found it, move to the next tag
            }
        }
    }

    // --- Find Links ---
    std.debug.print("Links:\n", .{});
    for (graph.links.items) |link| {
        // Check for outgoing links
        if (std.mem.eql(u8, &link.source_hash, &hash)) {
            // We have the target_hash, now find its path in the nodes map.
            if (graph.nodes.get(link.target_hash)) |node| {
                std.debug.print("  -> {s}\n", .{node.path});
            } else {
                std.debug.print("  -> [Unknown file hash]\n", .{});
            }
        }
        // Check for incoming links
        if (std.mem.eql(u8, &link.target_hash, &hash)) {
            // We have the source_hash, find its path.
            if (graph.nodes.get(link.source_hash)) |node| {
                std.debug.print("  <- {s}\n", .{node.path});
            } else {
                std.debug.print("  <- [Unknown file hash]\n", .{});
            }
        }
    }
}

/// Handles the 'find' command.
/// Usage: dwit find --tag <tag_name>
/// This function now correctly looks up paths from hashes.
fn handleFindCommand(allocator: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len != 4 or !std.mem.eql(u8, args[2], "--tag")) {
        std.debug.print("Usage: dwit find --tag <tag_name>\n", .{});
        return error.InvalidArguments;
    }
    const tag = args[3];
    var graph = try core.database.load(allocator);
    defer graph.deinit();

    // Look up the tag in the tags HashMap
    if (graph.tags.get(tag)) |hashes| {
        // 'hashes' is an ArrayList of file hashes
        std.debug.print("Files with tag '{s}':\n", .{tag});
        for (hashes.items) |hash| {
            // For each hash, find the corresponding file path in the nodes map
            if (graph.nodes.get(hash)) |node| {
                std.debug.print("  - {s}\n", .{node.path});
            } else {
                // This case can happen if a file was tagged and then deleted
                // before the next 'scan'.
                std.debug.print("  - [Path not found for known hash]\n", .{});
            }
        }
    } else {
        std.debug.print("No files found with tag: {s}\n", .{tag});
    }
}

/// Handles the 'export-graph' command.
/// Usage: dwit export-graph
/// This now prints a .dot file with file paths as labels for readability.
fn handleExportGraphCommand(allocator: std.mem.Allocator) !void {
    // _ = allocator; // Allocator isn't used here, but part of the signature
    var graph = try core.database.load(allocator);
    defer graph.deinit();

    // Start the graphviz 'dot' language output
    std.debug.print("digraph dwit {{\n", .{});
    std.debug.print("  node [shape=box, style=filled, fillcolor=lightgray];\n", .{});

    // 1. Define all nodes with their paths as labels
    var node_it = graph.nodes.iterator();
    while (node_it.next()) |entry| {
        // entry.key_ptr.* is the hash (the node's unique ID)
        // entry.value_ptr.path is the file path (the node's readable label)
        std.debug.print("  \"", .{});
        for (entry.key_ptr.*) |byte| {
            std.debug.print("{x:02}", .{byte});
        }
        // Use the path as the human-readable label
        std.debug.print("\" [label=\"{s}\"];\n", .{entry.value_ptr.path});
    }

    // 2. Define all links (edges) between nodes
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
