const std = @import("std");

pub fn hashFile(file_path: []const u8) ![32]u8 {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var reader_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(&reader_buffer);

    const hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var writer_buffer: [4096]u8 = undefined;
    var hashing_writer = std.Io.Writer.Hashing(std.crypto.hash.sha2.Sha256).initHasher(hasher, &writer_buffer);

    _ = try file_reader.interface.streamRemaining(&hashing_writer.writer);

    var final_hash: [32]u8 = undefined;
    hashing_writer.hasher.final(&final_hash);
    return final_hash;
}
