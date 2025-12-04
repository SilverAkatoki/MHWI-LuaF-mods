-- 会在大型怪物血量变化时打印总血量和变化血量的调试 mod
-- 建议正常的时候关着，除非你没 HTP

core.require_version(">=0.3.0")

local Common = require("_framework.game.common")
local Message = require("_framework.game.message")

-- 血量模块有特征码 48 8B 87 70 76 00 00 (mov rax,[rdi+7670])
-- 但是最后还是没用上

local MONSTER_ID_OFFSET = 0x12280 -- 怪物对象基址 -> 怪物 ID 的偏移
local HP_MODULE_OFFSET = 0x7670   -- 怪物对象基址 -> HP模块指针 的偏移
local HP_CURRENT_OFFSET = 0x64    -- HP模块指针 -> 当前血量 的偏移
local HP_MAX_OFFSET = 0x60        -- HP模块指针 -> 最大血量 的偏移
local HP_DISPLAY_STEP = 100       -- 每 100 血量变化才通知


local LARGE_MONSTERS = {
    -- 本体怪物
    [0x00] = true,
    [0x01] = true,
    [0x04] = true,
    [0x07] = true,
    [0x09] = true,
    [0x0A] = true,
    [0x0B] = true,
    [0x0C] = true,
    [0x0D] = true,
    [0x0E] = true,
    [0x0F] = true,
    [0x10] = true,
    [0x11] = true,
    [0x12] = true,
    [0x13] = true,
    [0x14] = true,
    [0x15] = true,
    [0x16] = true,
    [0x17] = true,
    [0x18] = true,
    [0x19] = true,
    [0x1A] = true,
    [0x1B] = true,
    [0x1C] = true,
    [0x1D] = true,
    [0x1E] = true,
    [0x1F] = true,
    [0x20] = true,
    [0x21] = true,
    [0x22] = true,
    [0x23] = true,
    [0x24] = true,
    [0x25] = true,
    [0x26] = true,
    [0x27] = true,
    -- 冰原怪物
    [0x3D] = true,
    [0x3E] = true,
    [0x3F] = true,
    [0x40] = true,
    [0x41] = true,
    [0x42] = true,
    [0x43] = true,
    [0x44] = true,
    [0x45] = true,
    [0x46] = true,
    [0x47] = true,
    [0x48] = true,
    [0x49] = true,
    [0x4A] = true,
    [0x4B] = true,
    [0x4C] = true,
    [0x4D] = true,
    [0x4E] = true,
    [0x4F] = true,
    [0x50] = true,
    [0x51] = true,
    -- 免费更新怪物
    [0x33] = true,
    [0x57] = true,
    [0x58] = true,
    [0x59] = true,
    [0x5A] = true,
    [0x5B] = true,
    [0x5C] = true,
    [0x5D] = true,
    [0x5E] = true,
    [0x5F] = true,
    [0x60] = true,
    [0x61] = true,
    [0x63] = true,
    [0x64] = true,
    [0x65] = true
}

local last_hp = {}

--- 读取怪物血量信息
--- @param ptr sdk.LuaPtr 怪物对象基址
--- @return number? current 当前血量
--- @return number? max 最大血量
local function get_health(ptr)
    if not ptr or ptr:to_integer() == 0 then return nil end

    local hp_module = ptr:offset(HP_MODULE_OFFSET):read_ptr()
    if not hp_module or hp_module:to_integer() == 0 then return nil end

    local current = hp_module:offset(HP_CURRENT_OFFSET):read_f32()
    local max = hp_module:offset(HP_MAX_OFFSET):read_f32()

    if type(current) ~= "number" or type(max) ~= "number" then return nil end
    return current, max
end

local function monitor()
    if not Common.is_player_in_scene() then
        last_hp = {}
        return
    end

    local active = {}
    local monsters = sdk.Monster.list()
    if not monsters then return end

    for _, addr in pairs(monsters) do
        local ptr = sdk.LuaPtr(addr)
        -- ptr 是怪物对象基址

        local id = ptr:offset(MONSTER_ID_OFFSET):read_i32()

        if not LARGE_MONSTERS[id] then goto continue end
        
        local current, max = get_health(ptr)
        if current and max then
            local key = ptr:to_integer()
            active[key] = true
            local bucket = math.floor(current / HP_DISPLAY_STEP)

            if last_hp[key] ~= bucket then
                last_hp[key] = bucket
                Message.show_system(
                    string.format("大型怪物[ID:%X] 血: %.0f / %.0f", id, current, max),
                    Message.SystemMessageColor.Purple
                )
            end
        end

        ::continue::
    end

    for key in pairs(last_hp) do
        if not active[key] then last_hp[key] = nil end
    end
end

core.on_update(monitor)
core.on_destroy(function() last_hp = {} end)
