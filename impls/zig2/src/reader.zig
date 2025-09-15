const std = @import("std");

const ReaderError = error{
    UnterminatedString,
    OutOfMemory,
    EndOfInput,
};

const Token = struct {
    start: u32,
    end: u32,

    pub fn in(self: Token, buffer: []const u8) []const u8 {
        std.debug.assert(self.start < buffer.len);
        std.debug.assert(self.end <= buffer.len);
        return buffer[self.start..self.end];
    }
};

const Atom = union(enum) {
    number: u32,
    symbol: []u8,
};

const Data = union(enum) {
    atom: Atom,
    list: []Data,
};

const Reader = struct {
    current: u32,
    buffer: []Token,

    fn init(alloc: std.mem.Allocator, src: []const u8) ReaderError!Reader {
        var tokens = std.ArrayList(Token).initCapacity(alloc, 8);
        var reader = std.Io.Reader.fixed(src);
        try tokenize(alloc, &tokens, &reader);
        return Reader{ .current = 0, .buffer = tokens.toOwnedSlice(alloc) };
    }

    fn deinit(this: *Reader, alloc: std.mem.Allocator) void {
        alloc.free(this.buffer);
    }
};

fn tokenize(alloc: std.mem.Allocator, reader: *std.Io.Reader, tokens: *std.ArrayList(Token)) ReaderError!void {
    while (reader.seek < reader.end) {
        try skipWhiteSpace(reader);

        if (try parseMarker(reader)) |marker| {
            tokens.append(alloc, marker) catch return ReaderError.OutOfMemory;
            continue;
        }

        if (try parseSpecial(reader)) |special| {
            tokens.append(alloc, special) catch return ReaderError.OutOfMemory;
            continue;
        }

        if (try parseString(reader)) |str| {
            tokens.append(alloc, str) catch return ReaderError.OutOfMemory;
        }
        if (try parseComment(reader)) |comment| {
            tokens.append(alloc, comment) catch return ReaderError.OutOfMemory;
        }

        if (try parseAtom(reader)) |atom| {
            tokens.append(alloc, atom) catch return ReaderError.OutOfMemory;
            continue;
        }
        // Skip unrecognized Token
        reader.toss(1);
    }
}

test "tokenize" {
    const alloc = std.testing.allocator;
    const src = "( + 1 2 冬 \"cowabunga \\\" \" ~@)";
    var reader = std.Io.Reader.fixed(src);
    var tokens = try std.ArrayList(Token).initCapacity(alloc, 100);
    defer tokens.deinit(alloc);
    try tokenize(alloc, &reader, &tokens);

    try std.testing.expectEqualStrings("(", tokens.items[0].in(src));
    try std.testing.expectEqualStrings("+", tokens.items[1].in(src));
    try std.testing.expectEqualStrings("1", tokens.items[2].in(src));
    try std.testing.expectEqualStrings("2", tokens.items[3].in(src));
    try std.testing.expectEqualStrings("冬", tokens.items[4].in(src));
    try std.testing.expectEqualStrings("\"cowabunga \\\" \"", tokens.items[5].in(src));
    try std.testing.expectEqualStrings("~@", tokens.items[6].in(src));
    try std.testing.expectEqualStrings(")", tokens.items[7].in(src));

    try std.testing.expectEqual(tokens.items.len, 8);
}

fn skipWhiteSpace(reader: *std.Io.Reader) ReaderError!void {
    while (true) {
        const b = reader.peekByte() catch return ReaderError.EndOfInput;
        if (b != ' ' and b != '\n' and b != '\t') return;
        reader.toss(1);
    }
}

test "skip whitespace" {
    const src = "    candy";
    var reader = std.Io.Reader.fixed(src);

    try skipWhiteSpace(&reader);
    try std.testing.expectEqualStrings("candy", reader.buffered());
}

test "skip whitespace to end" {
    const src = "    ";
    var reader = std.Io.Reader.fixed(src);
    try std.testing.expectError(ReaderError.EndOfInput, skipWhiteSpace(&reader));
}

fn parseMarker(reader: *std.Io.Reader) ReaderError!?Token {
    const peek2 = reader.peek(2) catch return null;
    if (std.mem.eql(u8, peek2, "~@")) {
        reader.toss(2);
        // Assume reader contains less than 4 billion tokens / 4GB, so that we can use u32 to keep track of tokens;
        std.debug.assert(reader.end <= std.math.maxInt(u32));
        return Token{ .start = @intCast(reader.seek - 2), .end = @intCast(reader.seek) };
    } else {
        return null;
    }
}

test "parse ~@" {
    const src = "~@crazy";
    var reader = std.Io.Reader.fixed(src);
    const maybeToken = try parseMarker(&reader);
    try std.testing.expect(maybeToken != null);
    try std.testing.expectEqualStrings("~@", maybeToken.?.in(src));
}

fn parseSpecial(reader: *std.Io.Reader) ReaderError!?Token {
    const c = reader.peekByte() catch return ReaderError.EndOfInput;
    switch (c) {
        '[', ']', '(', ')', '{', '}', '\'', '`', '~', '^', '@' => {
            reader.toss(1);
            // Assume reader contains less than 4 billion tokens / 4GB, so that we can use u32 to keep track of tokens;
            std.debug.assert(reader.end <= std.math.maxInt(u32));
            return Token{ .start = @intCast(reader.seek - 1), .end = @intCast(reader.seek) };
        },
        else => {
            return null;
        },
    }
}

test "parse specials" {
    const src = "[](){}'`~^@";
    var reader = std.Io.Reader.fixed(src);

    const lbr = try parseSpecial(&reader);
    try std.testing.expect(lbr != null);
    try std.testing.expectEqualStrings("[", lbr.?.in(src));

    const rbr = try parseSpecial(&reader);
    try std.testing.expect(rbr != null);
    try std.testing.expectEqualStrings("]", rbr.?.in(src));

    const lpr = try parseSpecial(&reader);
    try std.testing.expect(lpr != null);
    try std.testing.expectEqualStrings("(", lpr.?.in(src));

    const rpr = try parseSpecial(&reader);
    try std.testing.expect(rpr != null);
    try std.testing.expectEqualStrings(")", rpr.?.in(src));

    const lsquig = try parseSpecial(&reader);
    try std.testing.expect(lsquig != null);
    try std.testing.expectEqualStrings("{", lsquig.?.in(src));

    const rsquig = try parseSpecial(&reader);
    try std.testing.expect(rsquig != null);
    try std.testing.expectEqualStrings("}", rsquig.?.in(src));

    const quote = try parseSpecial(&reader);
    try std.testing.expect(quote != null);
    try std.testing.expectEqualStrings("'", quote.?.in(src));

    const tick = try parseSpecial(&reader);
    try std.testing.expect(tick != null);
    try std.testing.expectEqualStrings("`", tick.?.in(src));

    const squig = try parseSpecial(&reader);
    try std.testing.expect(squig != null);
    try std.testing.expectEqualStrings("~", squig.?.in(src));

    const carrot = try parseSpecial(&reader);
    try std.testing.expect(carrot != null);
    try std.testing.expectEqualStrings("^", carrot.?.in(src));

    const at = try parseSpecial(&reader);
    try std.testing.expect(at != null);
    try std.testing.expectEqualStrings("@", at.?.in(src));
}

fn parseString(reader: *std.Io.Reader) ReaderError!?Token {
    const b = reader.peekByte() catch return ReaderError.EndOfInput;
    if (b != '"') return null;
    const start = reader.seek;
    reader.toss(1);
    while (true) {
        const str = reader.takeDelimiterInclusive('"') catch return ReaderError.UnterminatedString;
        if (str.len == 1) {
            return Token{ .start = @intCast(start), .end = @intCast(reader.seek) };
        }
        if (str[str.len - 2] == '\\') {
            continue;
        }
        return Token{ .start = @intCast(start), .end = @intCast(reader.seek) };
    }
}

test "parse string" {
    const src = "\"So that's cool@(){}\"nope";
    var reader = std.Io.Reader.fixed(src);
    const maybeToken = try parseString(&reader);
    try std.testing.expect(maybeToken != null);
    try std.testing.expectEqualStrings("\"So that's cool@(){}\"", maybeToken.?.in(src));
}

test "parse escaped \" " {
    const src = "\"so that's when I said \\\"LOL\\\"\"";
    var reader = std.Io.Reader.fixed(src);
    const maybeToken = try parseString(&reader);
    try std.testing.expect(maybeToken != null);
    try std.testing.expectEqualStrings("\"so that's when I said \\\"LOL\\\"\"", maybeToken.?.in(src));
}

fn parseComment(reader: *std.Io.Reader) ReaderError!?Token {
    const b = reader.peekByte() catch return ReaderError.EndOfInput;
    if (b != ';') return null;
    defer reader.seek = reader.end;
    // Assume reader contains less than 4 billion tokens / 4GB, so that we can use u32 to keep track of tokens;
    std.debug.assert(reader.end <= std.math.maxInt(u32));
    return Token{ .start = @intCast(reader.seek), .end = @intCast(reader.end) };
}

test "parse comment" {
    const src = ";this is a helpfull comment;;\"";
    var reader = std.Io.Reader.fixed(src);
    const parsedComment = try parseComment(&reader);
    try std.testing.expect(parsedComment != null);
    try std.testing.expectEqualStrings(";this is a helpfull comment;;\"", parsedComment.?.in(src[0..]));
}

fn parseAtom(reader: *std.Io.Reader) ReaderError!?Token {
    var b = reader.peekByte() catch return ReaderError.EndOfInput;
    if (isSpecial(b) or isWhiteSpace(b)) return null;

    const start = reader.seek;
    reader.toss(1);
    b = reader.peekByte() catch return Token{ .start = @intCast(start), .end = @intCast(start + 1) };
    while (!(isSpecial(b) or isWhiteSpace(b))) {
        reader.toss(1);
        b = reader.peekByte() catch return Token{ .start = @intCast(start), .end = @intCast(reader.seek) };
    }
    return Token{ .start = @intCast(start), .end = @intCast(reader.seek) };
}

test "parse atom" {
    const src = "cow花火🚀)";
    var reader = std.Io.Reader.fixed(src);
    const maybeToken = try parseAtom(&reader);
    try std.testing.expect(maybeToken != null);
    try std.testing.expectEqualStrings("cow花火🚀", maybeToken.?.in(src[0..]));
}

fn pushToken(alloc: std.mem.Allocator, list: std.ArrayList(Token), current_offset: u32, length: u32) !void {
    const t: *Token = try list.addOne(alloc);
    t.*.start = current_offset;
    t.*.end = current_offset + length;
}

fn isWhiteSpace(c: u8) bool {
    return c == ' ' or c == ',' or c == '\t' or c == '\n';
}

fn isSpecial(c: u8) bool {
    return switch (c) {
        '(', ')', '[', ']', '~', '{', '}', '\'', '`', '^', '@' => true,
        else => false,
    };
}
