const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const mem = std.mem;
const expect = std.testing.expect;

fn read_line(allocator: *Allocator) anyerror![]u8 {
    var buf_size: u32 = 10;
    var c: u8 = undefined;
    var idx: u32 = 0;

    var input_str: []u8 = try allocator.alloc(u8, buf_size);
    while (true) {
        c = stdin.readByte() catch {
            try stdout.print("exit\n", .{});
            std.os.exit(0);
        };
        if (c == '\n') {
            input_str.len = idx;
            break;
        }

        if (idx >= buf_size) {
            buf_size *= 2;
            input_str = try allocator.realloc(input_str, buf_size);
        }
        input_str[idx] = c;
        idx += 1;
    }

    return input_str;
}

fn split_str(allocator: *Allocator, str: []const u8, delim: u8) anyerror![][]u8 {
    var buf_size: u32 = 32;
    var array_str = try allocator.alloc([]u8, buf_size);

    var count_delim: u32 = 0;
    var idx_start: usize = 0;
    var idx_end: usize = 0;
    for (str) |value, i| {
        std.log.info("str[{}] = {c}", .{ i, value });
        if (value == delim or i == str.len - 1) {
            if (count_delim >= buf_size) {
                buf_size *= 2;
                array_str = try allocator.realloc(array_str, buf_size);
            }
            if (i == str.len - 1) {
                idx_end = str.len;
            } else {
                idx_end = i;
            }
            std.log.info("i - 1 - idx_start = {}", .{idx_end - 1 - idx_start});
            array_str[count_delim] = try allocator.alloc(u8, idx_end - idx_start);
            std.log.info("str[{}..{}] = {}", .{ idx_start, i, str[idx_start..idx_end] });
            mem.copy(u8, array_str[count_delim], str[idx_start..idx_end]);
            idx_start = i + 1;
            count_delim += 1;
        }
    }
    std.log.info("number of `{c}` = {}", .{ delim, count_delim });

    return array_str;
}

fn parse_input(input: []u8) !void {
    if (mem.eql(u8, input, "exit")) {
        std.log.info("Exiting...", .{});
        std.os.exit(0);
    } else {
        std.log.info("{s} does not match exit", .{input});
    }
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) {
        std.log.info("memory leaks!", .{});
    };
    const allocator = &gpa.allocator;

    while (true) {
        try stdout.print("zigsh$ ", .{});
        var input_str: []u8 = try read_line(allocator);
        defer allocator.free(input_str);

        try parse_input(input_str);

        std.log.info("string read: {}", .{input_str});
    }
}

test "split_str" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;

    const str: []const u8 = "There is no cow level";
    var str_lines = try split_str(allocator, str, ' ');

    std.log.info("array_str[0]: {}", .{str_lines[0]});

    expect(mem.eql(u8, str_lines[0], "There"));
    expect(mem.eql(u8, str_lines[1], "is"));
    expect(mem.eql(u8, str_lines[2], "no"));
    expect(mem.eql(u8, str_lines[3], "cow"));
    expect(mem.eql(u8, str_lines[4], "level"));

    allocator.free(str_lines[0]);
    allocator.free(str_lines[1]);
    allocator.free(str_lines[2]);
    allocator.free(str_lines[3]);
    allocator.free(str_lines[4]);

    allocator.free(str_lines);
}
