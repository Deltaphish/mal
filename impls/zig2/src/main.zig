const std = @import("std");
const libmal = @import("libmal");
const linenoise = @import("linenoise");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    // var stdin_buffer: [1024]u8 = undefined;

    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    // var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);

    const stdout = &stdout_writer.interface;
    // const stdin = &stdin_reader.interface;

    _ = linenoise.linenoiseHistorySetMaxLen(10);

    while (true) {
        const maybeLine: ?[*:0]u8 = linenoise.linenoise("user> ");
        if (maybeLine) |line| {
            // Keep things in Zig lang
            _ = linenoise.linenoiseHistoryAdd(line);
            const slicedLine = line[0..std.mem.len(line)];
            const out = libmal.rep(slicedLine);
            try stdout.print("{s}\n", .{out});
            try stdout.flush(); // Don't forget to flush!
            linenoise.linenoiseFree(line);
        } else {
            try stdout.print("\ngoodbye\n", .{});
            try stdout.flush(); // Don't forget to flush!
            break;
        }
    }

    // try stdout.print("user> ", .{});
    // try stdout.flush();
    // const line = stdin.takeDelimiterExclusive('\n') catch {
    //     break;
    // };

    // const out = libmal.rep(line[0..]);

    // try stdout.print("{s}\n", .{out});
    // try stdout.flush(); // Don't forget to flush!
}
