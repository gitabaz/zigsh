const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    try stdout.print("zsh$ ", .{});

    var buf: [100]u8 = undefined;
    const bytes_read: anyerror!usize = stdin.read(&buf);
}
