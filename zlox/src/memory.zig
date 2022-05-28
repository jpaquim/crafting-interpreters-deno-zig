const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn GROW_CAPACITY(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn GROW_ARRAY(allocator: Allocator, comptime T: type, slice: ?[]T, old_count: usize, new_count: usize) ?[]T {
    return reallocate(allocator, u8, slice, @sizeOf(T) * old_count, @sizeOf(T) * new_count);
}

pub fn FREE_ARRAY(allocator: Allocator, comptime T: type, slice: ?[]T, old_count: usize) void {
    const result = reallocate(allocator, u8, slice, @sizeOf(T) * old_count, 0);
    std.debug.assert(result == null);
}

fn reallocate(allocator: Allocator, comptime T: type, slice: ?[]T, old_size: usize, new_size: usize) ?[]T {
    if (old_size == 0) {
        return allocator.alloc(u8, new_size) catch std.process.exit(1);
    }
    if (new_size == 0) {
        allocator.free(slice.?);
        return null;
    }

    const result = allocator.realloc(slice.?, new_size) catch std.process.exit(1);
    return result;
}
