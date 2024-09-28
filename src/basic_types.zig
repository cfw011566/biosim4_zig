const std = @import("std");

pub const Compass = enum(u8) { SW = 0, S, SE, W, CENTER, E, NW, N, NE };

const NW = Dir.init(Compass.NW);
const N = Dir.init(Compass.N);
const NE = Dir.init(Compass.NE);
const SW = Dir.init(Compass.SW);
const S = Dir.init(Compass.S);
const SE = Dir.init(Compass.SE);
const W = Dir.init(Compass.W);
const C = Dir.init(Compass.CENTER);
const E = Dir.init(Compass.E);

const rotations = [_]Dir{
    SW, W,  NW, N,  NE, E,  SE, S,
    S,  SW, W,  NW, N,  NE, E,  SE,
    SE, S,  SW, W,  NW, N,  NE, E,
    W,  NW, N,  NE, E,  SE, S,  SW,
    C,  C,  C,  C,  C,  C,  C,  C,
    E,  SE, S,  SW, W,  NW, N,  NE,
    NW, N,  NE, E,  SE, S,  SW, W,
    N,  NE, E,  SE, S,  SW, W,  NW,
    NE, E,  SE, S,  SW, W,  NW, N,
};

pub const Dir = struct {
    dir9: Compass,

    pub fn init(d: Compass) Dir {
        return Dir{ .dir9 = d };
    }

    fn asU8(self: Dir) u8 {
        return @intFromEnum(self.dir9);
    }

    pub fn rotate(self: Dir, n: isize) Dir {
        return rotations[self.asU8() * 8 + @as(usize, @intCast(n & 7))];
    }
};

test "Dir functions" {
    const dir = Dir.init(Compass.SW);
    try std.testing.expectEqual(@intFromEnum(Compass.S), dir.rotate(-1).asU8());
    try std.testing.expectEqual(@intFromEnum(Compass.SW), dir.rotate(0).asU8());
    try std.testing.expectEqual(@intFromEnum(Compass.W), dir.rotate(1).asU8());
    try std.testing.expectEqual(@intFromEnum(Compass.SW), dir.rotate(8).asU8());
}

const Coor = struct {
    x: i16,
    y: i16,
};

const Polar = struct {
    mag: isize,
    dir: Dir,
};
