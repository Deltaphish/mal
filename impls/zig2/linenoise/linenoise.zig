const c_linenoise = @cImport({
    @cInclude("linenoise.h");
});

// Cast the API from cpointers to appropriate zig types

pub const linenoise: fn (prompt: [*:0]const u8) callconv(.c) ?[*:0]u8 = c_linenoise.linenoise;
pub const linenoiseFree: fn (?*anyopaque) callconv(.c) void = c_linenoise.linenoiseFree;
pub const linenoiseHistoryAdd: fn (line: [*:0]const u8) callconv(.c) c_int = c_linenoise.linenoiseHistoryAdd;
pub const linenoiseHistorySetMaxLen: fn (len: c_int) callconv(.c) c_int = c_linenoise.linenoiseHistorySetMaxLen;
