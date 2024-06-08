const std = @import("std");
const charToBigAsciiArt = @import("letters.zig").charToBigAsciiArt;
const kbhit = @import("kbhit_2.zig").kbhit;
const Curses = @import("curses.zig").Curses;

const print = std.debug.print;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const child_alloc = gpa.allocator();
var arena = std.heap.ArenaAllocator.init(child_alloc);
const local_alloc = arena.allocator();

pub fn textToArrayOfStripes(allocator: std.mem.Allocator, str: []u8) ![][]u8 {
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

fn renderStripe(cur: *Curses, stripe: []u8, x: usize, y: usize) !void {
    for (0.., stripe) |ind_in, let| {
        try cur.renderChar(let, @constCast(@ptrCast(&[_]u16{
            @intCast(x),
            @intCast(ind_in + y),
        })));
    }
}

fn renderObjectPerStripes(cur: *Curses, object: [][]u8, position_x: i16, position_y: i16) !void {
    for (0.., object) |ind, stripe| {
        const ind_i16: i16 = @intCast(ind);
        // const screenHeightUsize: usize = @intCast(cur.getScreenWidth());

        if (ind_i16 - position_x < 0) {
            continue;
        }
        const positionTranslation: usize = @intCast(ind_i16 - position_x);

        try renderStripe(cur, stripe, positionTranslation, @intCast(position_y));
    }
}

pub fn main() !void {
    // instant user input
    const stdin = std.io.getStdIn();

    var cur = Curses.init();

    while (true) {
        const internal_hit_counter = try kbhit();

        if (internal_hit_counter != 0) {
            var stripesArrList = std.ArrayList(u8).init(local_alloc);
            _ = &stripesArrList;
            var buff = [_]u8{0};
            _ = try stdin.read(&buff);
            const bigChar = charToBigAsciiArt(buff[0]) catch {
                return error.EstouEmPanico;
            };

            const arrayOfStripes = try textToArrayOfStripes(local_alloc, @ptrCast(@constCast(bigChar)));

            cur.clearScreen();
            try renderObjectPerStripes(&cur, arrayOfStripes, 0, 10);
            cur.updateFullScreen();
        }
    }
}
