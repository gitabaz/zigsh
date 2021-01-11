const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const mem = std.mem;
const expect = std.testing.expect;
const builtin = @import("builtin");

const SHELL_NAME = "zigsh";

fn read_line(allocator: *Allocator) anyerror![]u8 {
    var buf_size: u32 = 10;
    var c: u8 = undefined;
    var idx: u32 = 0;

    var input_str: []u8 = try allocator.alloc(u8, buf_size);
    errdefer allocator.free(input_str);
    while (true) {
        c = try stdin.readByte();
        switch (c) {
            '\n' => {
                input_str.len = idx;
                break;
            },
            else => {},
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
        //std.log.info("str[{}] = {c}", .{ i, value });
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
            array_str[count_delim] = try allocator.alloc(u8, idx_end - idx_start);
            //std.log.info("str[{}..{}] = {}", .{ idx_start, idx_end, str[idx_start..idx_end] });
            mem.copy(u8, array_str[count_delim], str[idx_start..idx_end]);
            idx_start = i + 1;
            count_delim += 1;
        }
    }
    array_str.len = count_delim;
    //std.log.info("number of `{c}` = {}", .{ delim, count_delim });
    //std.log.info("number args {}", .{array_str.len});

    return array_str;
}

fn handle_cd(input_array: [][]const u8) !void {
    if (input_array.len > 2) {
        try stdout.print("cd: Too many arguments", .{});
    } else {
        if (input_array.len == 2) {
            std.os.chdir(input_array[1]) catch {
                try stdout.print("cd: No directory `{}`\n", .{input_array[1]});
            };
        } else {
            const home_dir = std.os.getenv("HOME");
            if (home_dir != null) {
                try std.os.chdir(home_dir.?);
            }
        }
    }
}

fn parse_input(allocator: *Allocator, input: []const u8) !bool {
    var input_array: [][]const u8 = try split_str(allocator, input, ' ');
    defer {
        for (input_array) |value, i| {
            allocator.free(value);
        }
        allocator.free(input_array);
    }

    if (input_array.len > 0) {
        if (mem.eql(u8, input_array[0], "exit")) {
            //std.log.info("Exiting...", .{});
            return false;
        } else if (mem.eql(u8, input_array[0], "help")) {
            //std.log.info("Helping...", .{});
        } else if (mem.eql(u8, input_array[0], "cd")) {
            try handle_cd(input_array);
        } else {
            //std.log.info("{s} does not match any built-in commands", .{input});
            var childproc = std.ChildProcess.exec(.{ .allocator = allocator, .argv = input_array }) catch null;
            if (childproc != null) {
                try stdout.print("{s}", .{childproc.?.stdout});
                allocator.free(childproc.?.stdout);
                allocator.free(childproc.?.stderr);
            } else {
                try stdout.print("{}: command not found\n", .{input_array[0]});
            }
        }
    }
    return true;
}

pub fn prompt_loop(allocator: *Allocator) !void {
    var keep_running: bool = true;
    while (keep_running) {
        var ps1 = try build_ps1(allocator);
        defer allocator.free(ps1);
        try stdout.print("{}", .{ps1});
        var input_str: ?[]const u8 = read_line(allocator) catch null;
        errdefer allocator.free(input_str.?);

        if (input_str != null) {
            defer allocator.free(input_str.?);
            keep_running = try parse_input(allocator, input_str.?);
            //std.log.info("string read: {}", .{input_str.?});
        } else {
            try stdout.print("exit\n", .{});
            break;
        }
    }
}

pub fn build_ps1(allocator: *Allocator) ![]u8 {
    const buf_size: u32 = 1024;
    var ps1 = try allocator.alloc(u8, buf_size);
    errdefer allocator.free(ps1);

    var hstnm: [64]u8 = undefined;
    _ = try std.os.gethostname(&hstnm);

    var curr_dir: []u8 = try allocator.alloc(u8, buf_size);
    defer allocator.free(curr_dir);
    curr_dir = try std.os.getcwd(curr_dir);

    _ = std.fmt.bufPrint(ps1, "{}:{}:{}$ ", .{ SHELL_NAME, hstnm, curr_dir }) catch {
        _ = try std.fmt.bufPrint(ps1, "{}:$ ", .{SHELL_NAME});
        ps1.len = SHELL_NAME.len + 2;
    };

    return ps1;
}

pub fn main() anyerror!void {
    //std.log.info("All your codebase are belong to us.", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) {
        std.log.info("memory leaks!", .{});
    };
    const allocator = &gpa.allocator;

    try prompt_loop(allocator);
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
