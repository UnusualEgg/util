const util = @import("w4_util");
const get_enum_len = util.get_enum_len;
const std = @import("std");
//buttons has fields with name of their type and their def
pub fn menus(enum_type: type, menu_type: type, button_types_struct: anytype) type {
    const menus_type: type = struct {
        current_menu: Menu,
        cursor: ENUM_TYPE,

        const Self = @This();
        const ENUM_TYPE = enum_type;
        const Menu = menu_type;
        const button_types = button_types_struct;

        //pub fn init() Self {
        //    return Self{ .buttons = button_types };
        //}
        pub fn go(self: *Self, menu: Menu) void {
            self.current_menu = menu;
            self.cursor = 0;
        }
        pub fn next(self: *Self) void {
            const len = get_menu_len(self.current_menu);
            self.cursor +|= 1;
            self.cursor %= @truncate(len);
        }
        pub fn prev(self: *Self) void {
            const len = get_menu_len(self.current_menu);
            if (self.cursor == 0) {
                self.cursor = @truncate(len -| 1);
            } else {
                self.cursor -|= 1;
            }
        }

        pub const menu_len = get_enum_len(Menu);
        const lookup: std.EnumArray(Menu, ?std.builtin.Type.Enum) = blk: {
            var lookup_enum: std.EnumArray(Menu, ?std.builtin.Type.Enum) = .{null} ** menu_len;
            //only have to write associated enums here! :D
            for (@typeInfo(Menu).@"enum".fields) |field| {
                if (@hasField(@TypeOf(button_types), field.name)) {
                    lookup_enum.set(field.value, @field(button_types, field.name));
                }
            }
            break :blk lookup_enum;
        };
        pub fn get_menu(buttons: type) ?Menu {
            for (@typeInfo(Menu).@"enum".fields) |field| {
                const menu: Menu = @field(Menu, field.name);
                if (get_buttons_enum(menu) == buttons) {
                    return menu;
                }
            } else {
                @compileError("invalid buttons " ++ @tagName(buttons));
            }
        }
        pub const Button = struct { name: []const u8, value: ENUM_TYPE };

        pub fn get_buttons(menu: Menu) ?[]const Button {
            return BUTTONS[@intFromEnum(menu)];
        }
        inline fn get_buttons_enum(menu: Menu) ?type {
            return lookup.get(@intFromEnum(menu));
        }
        pub fn get_menu_len(menu: Menu) usize {
            return menu_lens[@intFromEnum(menu)];
        }
        //below here is automated so shouldn't need to change much
        const menu_lens: [get_enum_len(Menu)]usize = blk: {
            var lens: [get_enum_len(Menu)]usize = undefined;
            for (@typeInfo(Menu).@"enum".fields) |field| {
                lens[field.value] = get_enum_len(get_buttons_enum(@enumFromInt(field.value)));
            }
            break :blk lens;
        };
        //we need a buf of side_by_side strings and buttons with refs to those strings
        //then a list of refs to slice of buttons (key=Menu,value=[]Button)
        //1. put field names ino buf
        //2. buf -> buttons_buf
        //3. have list of button slices

        //first calc lengths
        const total_buttons = blk: {
            var total_fields_n = 0;
            var iter = lookup.iterator();
            while (iter.next()) |t| {
                if (t.value) |ty| {
                    const fields = @typeInfo(ty).@"enum".fields;
                    total_fields_n += fields.len;
                }
            }
            break :blk total_fields_n;
        };
        const total_button_names_len = blk: {
            var total_name_len_n = 0;
            var iter = lookup.iterator();
            while (iter.next()) |t| {
                if (t.value) |ty| {
                    const field_names = std.meta.fieldNames(ty);
                    for (field_names) |field| {
                        total_name_len_n += field.name.len;
                    }
                }
            }
            break :blk total_name_len_n;
        };
        //then make bufs
        const button_names_buf: [total_button_names_len]u8 = blk: {
            var names_buf_local: [total_button_names_len]u8 = undefined;

            var buf_i = 0;
            var iter = lookup.iterator();
            while (iter.next()) |t| {
                if (t.value) |ty| {
                    const names = std.meta.fieldNames(ty);
                    for (names) |name_sentinel| {
                        const name_only: []const u8 = name_sentinel[0..name_sentinel.len];
                        const str = names_buf_local[buf_i..][0..names.len];
                        @memcpy(str, name_only);
                        std.mem.replaceScalar(u8, str, '_', ' ');
                        buf_i += str.len;
                    }
                }
            }

            break :blk names_buf_local;
        };
        const buttons_buf: [total_buttons]Button = blk: {
            var buttons_buf_local: [total_buttons]Button = undefined;
            var buf_i = 0;
            var button_i = 0;
            for (lookup) |t| {
                if (t) |ty| {
                    const fields = @typeInfo(ty).@"enum".fields;
                    for (fields) |field| {
                        const field_len = field.name.len;
                        const str: []u8 = button_names_buf[buf_i..][0..field_len];
                        //then make buttons with refs to those
                        buttons_buf_local[button_i] = Button{ .name = str, .value = field.value };

                        buf_i += field_len;
                        button_i += 1;
                    }
                }
            }
            break :blk buttons_buf_local;
        };
        //then make list of slices that reference the bufs
        //index this with a Menu to get a slice(array) of buttons(which have names(strings) and values(value of enum))
        const BUTTONS = blk: {
            var buttons: [menu_len]?[]Button = undefined;
            var button_i = 0;
            var menu_i = 0;
            for (lookup) |t| {
                if (t) |ty| {
                    const fields = @typeInfo(ty).@"enum".fields;
                    const buttons_begin = button_i;
                    button_i += fields.len;
                    buttons[menu_i] = buttons_buf[buttons_begin..button_i];
                } else {
                    buttons[menu_i] = null;
                }
                menu_i += 1;
            }
            break :blk buttons;
        };
    };
    return menus_type;
}
