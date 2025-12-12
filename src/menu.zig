const util = @import("w4_util");
const get_enum_len = util.get_enum_len;
const std = @import("std");

/// Menu helper
/// `menu_type` is an enum with each field being a possible menu/screen/state
/// menus don't have to have buttons (ie. one used when unpaused) so they can also be thought of as screens
///
/// `button_types_struct` is a struct with each field name being a field also in menu_type.
/// each field is also an enum with each field being the name of a button (all '_' are replaced with spaces in Button.name).
/// keep in mind that the default `cursor` value when going to a new menu with `go` is `0`.
///
/// the tag type of all the `button_types_struct` enums should be `enum_type`.
///
/// this module does not display anything. I recommend using `Menu.get_current_buttons()` and `util.text_centered(button.name, ...)`
///
/// example:
/// ```
/// const menu = @import("menu.zig");
///
/// const ENUM_TYPE = u8;
/// //Every single Screen/Menu we could be on
/// pub const Menus = enum {
///     Start,
///     Options,
///     Game,
/// };
/// //the buttons displayed on each menu
/// pub const Buttons = .{
///     //all enums here need to be tagged with ENUM_TYPE
///     .Start = enum(ENUM_TYPE) {
///         start,
///         options,
///         save,
///         load,
///     },
///     .Options = enum(ENUM_TYPE) {
///         colors,
///         palette,
///         back,
///     },
///     //etc.
/// };
/// pub const Menu: type = menu.menus(
///     ENUM_TYPE,
///     Menus,
///     Buttons,
/// );
/// ```
pub fn menus(enum_type: type, menu_type: type, button_types_struct: anytype) type {
    const menus_type: type = struct {
        current_menu: Menu,
        cursor: ENUM_TYPE,

        const Self = @This();
        const ENUM_TYPE = enum_type;
        const Menu = menu_type;
        const button_types = button_types_struct;

        /// go to `menu` and reset `cursor` to `0`
        pub fn go(self: *Self, menu: Menu) void {
            self.current_menu = menu;
            self.cursor = 0;
        }
        /// this assumes the current buttons enum is in order and skips no numbers
        pub fn next(self: *Self) void {
            const len = get_menu_len(self.current_menu);
            self.cursor +|= 1;
            self.cursor %= @truncate(len);
        }
        /// this assumes the current buttons enum is in order and skips no numbers and starts at 0
        pub fn prev(self: *Self) void {
            const len = get_menu_len(self.current_menu);
            if (self.cursor == 0) {
                self.cursor = @truncate(len -| 1);
            } else {
                self.cursor -|= 1;
            }
        }

        pub const menu_len = get_enum_len(Menu);
        const button_enum_lookup: std.EnumArray(Menu, ?std.builtin.Type.Enum) = blk: {
            var lookup_enum: std.EnumArray(Menu, ?std.builtin.Type.Enum) = .initFill(null);
            //only have to write associated enums here! :D
            for (@typeInfo(Menu).@"enum".fields) |field| {
                if (@hasField(@TypeOf(button_types), field.name)) {
                    lookup_enum.set(@enumFromInt(field.value), @typeInfo(@field(button_types, field.name)).@"enum");
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
            return BUTTONS.get(menu);
        }
        pub fn get_current_buttons(self: *const Self) ?[]const Button {
            return BUTTONS.get(self.current_menu);
        }
        fn get_type_from_enum(@"enum": std.builtin.Type.Enum) type {
            return @Type(std.builtin.Type{ .@"enum" = @"enum" });
        }
        inline fn get_buttons_enum(menu: Menu) ?type {
            if (button_enum_lookup.get(menu)) |@"enum"| {
                return get_type_from_enum(@"enum");
            } else {
                return null;
            }
        }
        pub fn get_menu_len(menu: Menu) usize {
            return menu_lens.get(menu);
        }

        const menu_lens: std.EnumArray(Menu, usize) = blk: {
            var lens: std.EnumArray(Menu, usize) = .initFill(0);
            for (@typeInfo(Menu).@"enum".fields) |field| {
                lens.set(@enumFromInt(field.value), get_enum_len(get_buttons_enum(@field(Menu, field.name))));
            }
            break :blk lens;
        };

        //BUTTONS: lookup list of buttons associated with a menu
        //this is done by storing button names in a buffer contiguously
        //then making each element of BUTTONS be a slice that references part of that buffer
        const BUTTONS: std.EnumArray(Menu, ?[]const Button) = blk: {
            //make a local var copy for iterator (for some reason there's no const iterator)
            var button_enum_lookup_local = button_enum_lookup;
            const total_buttons = total_buttons: {
                var total_fields_n = 0;
                var iter = button_enum_lookup_local.iterator();
                while (iter.next()) |t| {
                    if (t.value.*) |ty| {
                        total_fields_n += ty.fields.len;
                    }
                }
                break :total_buttons total_fields_n;
            };
            const name_slices = names: {
                const total_button_names_len = names_len: {
                    var total_name_len_n = 0;
                    var iter = button_enum_lookup_local.iterator();
                    while (iter.next()) |t| {
                        if (t.value.*) |ty| {
                            const field_names = std.meta.fieldNames(get_type_from_enum(ty));
                            for (field_names) |field_name| {
                                total_name_len_n += field_name.len;
                            }
                        }
                    }
                    break :names_len total_name_len_n;
                };

                var names_buf: [total_button_names_len]u8 = undefined;

                var buf_i = 0;
                var iter = button_enum_lookup_local.iterator();
                while (iter.next()) |t| {
                    if (t.value.*) |ty| {
                        const names = std.meta.fieldNames(get_type_from_enum(ty));
                        for (names) |name_sentinel| {
                            const name_only: []const u8 = name_sentinel[0..name_sentinel.len];
                            const str: *[name_only.len]u8 =
                                names_buf[buf_i..(buf_i + name_only.len)];
                            @memcpy(str, name_only);
                            std.mem.replaceScalar(u8, str, '_', ' ');

                            buf_i += str.len;
                        }
                    }
                }
                var name_slices_local: [total_buttons][]const u8 = undefined;
                const names_buf_const = names_buf;
                //first move array to static memory, *then* make references to it
                const S = struct {
                    const s_names_buf = names_buf_const;
                };
                buf_i = 0;
                var button_i = 0;
                iter = button_enum_lookup_local.iterator();
                while (iter.next()) |t| {
                    if (t.value.*) |ty| {
                        const names = std.meta.fieldNames(get_type_from_enum(ty));
                        for (names) |name_sentinel| {
                            const name_only: []const u8 = name_sentinel[0..name_sentinel.len];
                            const str: *const [name_only.len]u8 =
                                S.s_names_buf[buf_i..(buf_i + name_only.len)];

                            name_slices_local[button_i] = str;

                            buf_i += str.len;
                            button_i += 1;
                        }
                    }
                }
                break :names name_slices_local;
            };

            var buttons_buf: [total_buttons]Button = undefined;
            var button_i = 0;
            var fields_iter = button_enum_lookup_local.iterator();
            while (fields_iter.next()) |t| {
                // const entry = buttons_iter.next().?;
                if (t.value.*) |buttons_enum| {
                    const fields = buttons_enum.fields;

                    // const start = button_i;
                    for (fields) |field| {
                        const str: []const u8 = name_slices[button_i];
                        //then make buttons with refs to those
                        buttons_buf[button_i] = Button{ .name = str, .value = field.value };
                        button_i += 1;
                    }
                    // entry.value.* = buttons_buf[start..button_i];
                }
            }
            //store the actual values in static memory
            //result of BUTTONS is a slice that references this
            //each menu may have an array of buttons which are stored here
            const buttons_buf_const = buttons_buf;
            const S = struct {
                const s_buttons_buf = buttons_buf_const;
            };
            var buttons: std.EnumArray(Menu, ?[]const Button) = .initFill(null);
            var buttons_iter = buttons.iterator();
            button_i = 0;
            fields_iter = button_enum_lookup_local.iterator();
            while (fields_iter.next()) |t| {
                const entry = buttons_iter.next().?;
                if (t.value.*) |buttons_enum| {
                    const fields = buttons_enum.fields;

                    const start = button_i;
                    button_i += fields.len;
                    entry.value.* = S.s_buttons_buf[start..button_i];
                }
            }
            break :blk buttons;
        };
    };
    return menus_type;
}
