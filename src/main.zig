const std = @import("std");

const warn = std.debug.warn;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;

    var args = std.process.args();
    var _argv0 = try args.next(alloc) orelse error.MissingArgv0;
    var inName = try args.next(alloc) orelse error.MissingInputPath;
    var outName = try args.next(alloc) orelse error.MissingOutputPath;

    const inFile = try std.fs.cwd().openFile(inName, .{});
    const inLen = try inFile.getEndPos();
    const inBuf = try std.os.mmap(null, inLen, std.os.PROT_READ, std.os.MAP_PRIVATE, inFile.handle, 0);
    defer std.os.munmap(inBuf);
    var bits = std.io.bitInStream(.Little, std.io.fixedBufferStream(inBuf).inStream());
    const outFile = try std.fs.cwd().createFile(outName, .{});
    var out = std.io.bufferedOutStream(outFile.outStream());
    const outS = out.outStream();
    const print = outS.print;

    var width = try bits.readBitsNoEof(usize, 24);
    var height = try bits.readBitsNoEof(usize, 24);
    try print("P6\n{} {}\n{}\n", .{ width, height, 255 });
    const pixels = width * height;
    var buf = try alloc.alloc(u8, 3 * pixels);
    var drawn: usize = 0;
    while (drawn < pixels) {
        var action = try bits.readBitsNoEof(u1, 1);
        switch (action) {
            1 => {
                buf[3 * drawn + 0] = try bits.readBitsNoEof(u8, 8);
                buf[3 * drawn + 1] = try bits.readBitsNoEof(u8, 8);
                buf[3 * drawn + 2] = try bits.readBitsNoEof(u8, 8);
                drawn += 1;
            },
            0 => {
                var offset = try bits.readBitsNoEof(usize, 5);
                var count = try bits.readBitsNoEof(usize, 5);
                if (offset >= drawn) {
                    return error.OffsetOutOfBounds;
                }
                while (count > 0 and drawn < pixels) : (count -= 1) {
                    inline for (.{ 0, 1, 2 }) |c| {
                        buf[3 * (drawn) + c] = buf[3 * (drawn - offset - 1) + c];
                    }
                    drawn += 1;
                }
            },
        }
    }
    try out.flush();
    try outFile.outStream().writeAll(buf);
}
