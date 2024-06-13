const std = @import("std");
const Curses = @import("curses.zig").Curses;
const charToBigAsciiArt = @import("letters.zig").charToBigAsciiArt;

fn textToArrayOfStripes(allocator: std.mem.Allocator, str: []u8) ![][]u8 {
    var arrayOfArrayOfStripes = std.ArrayList(*std.ArrayList(u8)).init(allocator);

    var itt_nline = std.mem.split(u8, str, "\n");

    while (itt_nline.next()) |line| {
        for (0.., line) |ind, letter| {
            if (ind + 1 > arrayOfArrayOfStripes.items.len) {
                const new_stripe = try allocator.create(std.ArrayList(u8));
                new_stripe.* = std.ArrayList(u8).init(allocator);
                try arrayOfArrayOfStripes.append(new_stripe);
            }

            try arrayOfArrayOfStripes.items[ind].append(letter);
        }
    }

    //we using too much memory
    const arrayOfStripes = try allocator.alloc([]u8, arrayOfArrayOfStripes.items.len);

    for (0..arrayOfStripes.len) |ind| {
        arrayOfStripes[ind] = arrayOfArrayOfStripes.items[ind].items;
    }

    return arrayOfStripes;
}

fn renderStripe(cur: *Curses, stripe: []u8, xPosition: usize, yPosition: usize) !void {
    for (0.., stripe) |ind_in, let| {
        try cur.renderChar(let, @constCast(@ptrCast(&[_]u16{
            @intCast(xPosition),
            @intCast(ind_in + yPosition),
        })));
    }
}

fn renderPerStripe(cur: *Curses, strStripes: [][]u8, xPosition: i16, yPosition: i16) !void {
    for (0.., strStripes) |ind, stripe| {
        const ind_i16: i16 = @intCast(ind);

        if (ind_i16 - xPosition < 0) {
            continue;
        }
        const positionTranslation: usize = @intCast(ind_i16 - xPosition);

        try renderStripe(cur, stripe, positionTranslation, @intCast(yPosition));
    }
}

fn renderBigAsciiCharPerStripe(cur: *Curses, allocator: std.mem.Allocator, char: u8, xPosition: i16, yPosition: i16) !void {
    const bigAsciiChar = try charToBigAsciiArt(char);
    const bigAsciiCharArrayOfStripes = try textToArrayOfStripes(allocator, @ptrCast(@constCast(bigAsciiChar)));
    try renderPerStripe(cur, bigAsciiCharArrayOfStripes, xPosition, yPosition);
}

pub const BigAsciiChar = struct {
    position: []i16,
    bigAsciiChar: []u8,
    char: u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, char: u8) !BigAsciiChar {
        const pos = try allocator.alloc(i16, 2);
        pos[0] = 0;
        pos[1] = 0;
        const structChar = try charToBigAsciiArt(char);

        return .{
            .position = pos,
            .bigAsciiChar = @ptrCast(@constCast(structChar)),
            .char = char,
            .allocator = allocator,
        };
    }

    pub fn renderAt(
        self: Self,
        cur: *Curses,
        xPosition: i16,
        yPostion: i16,
    ) !void {
        const stripeBigAsciiChar = try textToArrayOfStripes(self.allocator, self.bigAsciiChar);
        try renderPerStripe(cur, stripeBigAsciiChar, xPosition, yPostion);
    }

    pub fn render(self: Self, cur: *Curses) !void {
        try self.renderAt(cur, self.position[0], self.position[1]);
    }

    pub fn getPosition(self: Self) []i16 {
        return self.position;
    }

    pub fn setPosition(self: Self, xPosition: i16, yPosition: i16) void {
        self.position[0] = xPosition;
        self.position[1] = yPosition;
    }
};

pub const BigAsciiTextDisplay = struct {
    bigAsciiCharQueue: *std.ArrayList(*BigAsciiChar),
    allocator: std.mem.Allocator,
    curses: *Curses,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, curses: *Curses) !BigAsciiTextDisplay {
        const queue = try allocator.create(std.ArrayList(*BigAsciiChar));
        queue.* = std.ArrayList(*BigAsciiChar).init(allocator);
        return .{
            .bigAsciiCharQueue = queue,
            .allocator = allocator,
            .curses = curses,
        };
    }

    pub fn moveCharsX(self: Self, amount: i16) !void {
        for (self.bigAsciiCharQueue.items) |bigChar| {
            bigChar.setPosition(bigChar.getPosition()[0] + amount, bigChar.getPosition()[1]);
        }
    }

    pub fn moveCharsY(self: Self, amount: i16) !void {
        for (self.bigAsciiCharQueue.items) |bigChar| {
            bigChar.setPosition(bigChar.getPosition()[0], bigChar.getPosition()[1] + amount);
        }
    }

    pub fn addBigAsciiChar(self: Self, bigAsciiChar: *BigAsciiChar) !void {
        if (self.bigAsciiCharQueue.items.len == 0) {
            try self.bigAsciiCharQueue.append(bigAsciiChar);
            return;
        }
        const lastAddedChar = self.bigAsciiCharQueue.getLast();
        bigAsciiChar.setPosition(lastAddedChar.getPosition()[0] - 30, bigAsciiChar.getPosition()[1]);
        try self.bigAsciiCharQueue.append(bigAsciiChar);
    }

    pub fn addChar(self: Self, char: u8) !void {
        const bigAsciiCharPtr = try self.allocator.create(BigAsciiChar);
        bigAsciiCharPtr.* = try BigAsciiChar.init(self.allocator, char);
        bigAsciiCharPtr.*.setPosition(-self.curses.getScreenHeight(), @divTrunc(self.curses.getScreenWidth(), 3));
        try self.addBigAsciiChar(bigAsciiCharPtr);
    }

    pub fn render(self: Self) !void {
        for (self.bigAsciiCharQueue.items) |bigChar| {
            try bigChar.render(self.curses);
        }
    }
};
