const std = @import("std");
const kbhit = @import("kbhit_2.zig").kbhit;
const Curses = @import("curses.zig").Curses;
const bigAsciiCharArray = @import("bigAsciiCharHandler.zig").BigAsciiCharArray;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const child_alloc = gpa.allocator();
var arena = std.heap.ArenaAllocator.init(child_alloc);
const local_alloc = arena.allocator();

pub fn main() !void {
    // instant user input
    const stdin = std.io.getStdIn();

    var cur = Curses.init();

    const asciiArtArray = try bigAsciiCharArray.init(local_alloc, &cur);

    while (true) {
        const internal_hit_counter = try kbhit();
        cur.clearScreen();

        if (internal_hit_counter != 0) {
            var buff = [_]u8{0};
            _ = try stdin.read(&buff);

            try asciiArtArray.addChar(buff[0]);
        }

        try asciiArtArray.render();
        std.time.sleep(40000000);
        try asciiArtArray.moveCharXFree(1);
        cur.updateFullScreen();
    }
}
