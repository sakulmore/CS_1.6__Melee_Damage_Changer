#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fun>
#include <cstrike>

#define PLUGIN_NAME    "Weapon Damage Changer"
#define PLUGIN_VERSION "1.1"
#define PLUGIN_AUTHOR  "sakulmore"

new g_szCfgPath[256];
new g_szAdminFlagCfg[256];

new g_PlayerDmg[33];
new g_TargetForValue[33];

new g_RequiredFlag = ADMIN_LEVEL_H;

enum PlayerDmgMode
{
    DMG_MODE_ORIGINAL = 0,
    DMG_MODE_CUSTOM
}

new PlayerDmgMode:g_PlayerMode[33];

new const g_AdminFlagNames[][] =
{
    "ADMIN_ALL",
    "ADMIN_IMMUNITY",
    "ADMIN_RESERVATION",
    "ADMIN_KICK",
    "ADMIN_BAN",
    "ADMIN_SLAY",
    "ADMIN_MAP",
    "ADMIN_CVAR",
    "ADMIN_CFG",
    "ADMIN_CHAT",
    "ADMIN_VOTE",
    "ADMIN_PASSWORD",
    "ADMIN_RCON",
    "ADMIN_LEVEL_A",
    "ADMIN_LEVEL_B",
    "ADMIN_LEVEL_C",
    "ADMIN_LEVEL_D",
    "ADMIN_LEVEL_E",
    "ADMIN_LEVEL_F",
    "ADMIN_LEVEL_G",
    "ADMIN_LEVEL_H",
    "ADMIN_MENU",
    "ADMIN_BAN_TEMP",
    "ADMIN_ADMIN",
    "ADMIN_USER"
};

new const g_AdminFlagBits[] =
{
    ADMIN_ALL,
    ADMIN_IMMUNITY,
    ADMIN_RESERVATION,
    ADMIN_KICK,
    ADMIN_BAN,
    ADMIN_SLAY,
    ADMIN_MAP,
    ADMIN_CVAR,
    ADMIN_CFG,
    ADMIN_CHAT,
    ADMIN_VOTE,
    ADMIN_PASSWORD,
    ADMIN_RCON,
    ADMIN_LEVEL_A,
    ADMIN_LEVEL_B,
    ADMIN_LEVEL_C,
    ADMIN_LEVEL_D,
    ADMIN_LEVEL_E,
    ADMIN_LEVEL_F,
    ADMIN_LEVEL_G,
    ADMIN_LEVEL_H,
    ADMIN_MENU,
    ADMIN_BAN_TEMP,
    ADMIN_ADMIN,
    ADMIN_USER
};

#define ADMIN_FLAG_COUNT (sizeof g_AdminFlagBits)

stock bool:IsOrigKeyword(const arg[])
{
    if (!arg[0])
        return false;

    new lower[32];
    copy(lower, charsmax(lower), arg);
    strtolower(lower);

    if (equali(lower, "orig") ||
        equali(lower, "original") ||
        equali(lower, "normal") ||
        equali(lower, "default") ||
        equali(lower, "def"))
    {
        return true;
    }

    return false;
}

stock bool:IsNumeric(const arg[])
{
    if (!arg[0])
        return false;

    new i = 0;

    if (arg[0] == '-' || arg[0] == '+')
    {
        if (!arg[1])
            return false;
        i = 1;
    }

    for (; arg[i]; i++)
    {
        if (!isdigit(arg[i]))
            return false;
    }

    return true;
}

stock FindAdminFlagIndexByName(const name[])
{
    for (new i = 0; i < ADMIN_FLAG_COUNT; i++)
    {
        if (equali(name, g_AdminFlagNames[i]))
            return i;
    }
    return -1;
}

stock FindAdminFlagIndexByBit(bit)
{
    for (new i = 0; i < ADMIN_FLAG_COUNT; i++)
    {
        if (g_AdminFlagBits[i] == bit)
            return i;
    }
    return -1;
}

EnsureAdminFlagCfgExists()
{
    if (file_exists(g_szAdminFlagCfg))
        return;

    g_RequiredFlag = ADMIN_LEVEL_H;

    SaveAdminFlagCfg();
}

SaveAdminFlagCfg()
{
    new fp = fopen(g_szAdminFlagCfg, "wt");
    if (!fp)
    {
        log_amx("[DMG Changer Weapon] Can't write admin flag cfg: %s", g_szAdminFlagCfg);
        return;
    }

    new line[256];

    formatex(line, charsmax(line), "; WDCH admin flag config%c", 10);
    fputs(fp, line);

    formatex(line, charsmax(line), "; Selectable flags via /changedmgweapsf%c", 10);
    fputs(fp, line);

    new idx = FindAdminFlagIndexByBit(g_RequiredFlag);
    new flagName[64];

    if (idx != -1)
    {
        copy(flagName, charsmax(flagName), g_AdminFlagNames[idx]);
    }
    else
    {
        copy(flagName, charsmax(flagName), "ADMIN_LEVEL_H");
    }

    formatex(line, charsmax(line), "%s%c", flagName, 10);
    fputs(fp, line);

    fclose(fp);
}

LoadAdminFlagCfg()
{
    g_RequiredFlag = ADMIN_LEVEL_H;

    new fp = fopen(g_szAdminFlagCfg, "rt");
    if (!fp)
    {
        SaveAdminFlagCfg();
        return;
    }

    new line[256];
    while (!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';')
            continue;

        new idx = FindAdminFlagIndexByName(line);
        if (idx != -1)
        {
            g_RequiredFlag = g_AdminFlagBits[idx];
        }
        else
        {
            log_amx("[DMG Changer Weapon] Unknown admin flag in cfg: %s", line);
        }
        break;
    }

    fclose(fp);
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_clcmd("amx_changedmg_weap", "Cmd_ClientSetDamageAll");

    register_clcmd("say /changedmgweap",      "Cmd_OpenChangeDmgMenuAll");
    register_clcmd("say_team /changedmgweap", "Cmd_OpenChangeDmgMenuAll");
    register_clcmd("changedmgweap",           "Cmd_OpenChangeDmgMenuAll");

    register_clcmd("ValueWeap", "Cmd_AdminEnteredValueAll");

    register_clcmd("say /changedmgweapsf",      "Cmd_OpenAdminFlagMenuWeap");
    register_clcmd("say_team /changedmgweapsf", "Cmd_OpenAdminFlagMenuWeap");

    new datadir[128];
    get_datadir(datadir, charsmax(datadir));
    formatex(g_szCfgPath,      charsmax(g_szCfgPath),      "%s/weapon_dmg_changer.cfg", datadir);
    formatex(g_szAdminFlagCfg, charsmax(g_szAdminFlagCfg), "%s/wdch_adminflag.cfg",     datadir);

    EnsureConfigFileExists();
    EnsureAdminFlagCfgExists();
    LoadAdminFlagCfg();

    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage_Pre_All", 0);
}

public client_putinserver(id)
{
    set_task(0.1, "InitPlayerDmgAll", id);
}

public InitPlayerDmgAll(id)
{
    g_PlayerDmg[id] = 0;
    g_PlayerMode[id] = DMG_MODE_ORIGINAL;
    g_TargetForValue[id] = 0;

    if (!is_user_connected(id))
        return;

    new auth[64];
    get_user_authid(id, auth, charsmax(auth));

    if (!auth[0] || equali(auth, "BOT") || equali(auth, "STEAM_ID_LAN"))
        return;

    new value = 0;
    if (LoadPlayerValue(auth, "amx_changedmg_weap", value))
    {
        if (value > 0)
        {
            g_PlayerDmg[id] = value;
            g_PlayerMode[id] = DMG_MODE_CUSTOM;
        }
        else
        {
            g_PlayerDmg[id] = 0;
            g_PlayerMode[id] = DMG_MODE_ORIGINAL;
        }
    }
    else
    {
        g_PlayerDmg[id] = 0;
        g_PlayerMode[id] = DMG_MODE_ORIGINAL;
    }
}

public client_disconnected(id)
{
    g_PlayerDmg[id] = 0;
    g_PlayerMode[id] = DMG_MODE_ORIGINAL;
    g_TargetForValue[id] = 0;
}

public OnPlayerTakeDamage_Pre_All(victim, inflictor, attacker, Float:damage, damagebits)
{
    if (attacker <= 0 || attacker > 32 || attacker == victim || !is_user_connected(attacker))
        return HAM_IGNORED;

    if (get_user_weapon(attacker) == CSW_KNIFE)
        return HAM_IGNORED;

    if (g_PlayerMode[attacker] != DMG_MODE_CUSTOM || g_PlayerDmg[attacker] <= 0)
    {
        return HAM_IGNORED;
    }

    SetHamParamFloat(4, float(g_PlayerDmg[attacker]));
    return HAM_HANDLED;
}

public Cmd_ClientSetDamageAll(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if ( !(get_user_flags(id) & g_RequiredFlag) )
    {
        client_print(id, print_chat, "[DMG Changer Weapon] You don't have access to use this!");
        return PLUGIN_HANDLED;
    }

    new arg[32];
    read_argv(1, arg, charsmax(arg));

    new auth[64];
    get_user_authid(id, auth, charsmax(auth));

    if (!auth[0] || equali(auth, "BOT") || equali(auth, "STEAM_ID_LAN"))
    {
        client_print(id, print_chat, "[DMG Changer Weapon] This command isn't available for BOT/STEAM_ID_LAN.");
        return PLUGIN_HANDLED;
    }

    if (!arg[0])
    {
        if (g_PlayerMode[id] == DMG_MODE_CUSTOM && g_PlayerDmg[id] > 0)
        {
            client_print(id, print_chat,
                "[DMG Changer Weapon] Your current weapon damage: %d. Use: amx_changedmg_weap <number> to change, or amx_changedmg_weap orig to reset to original damage.",
                g_PlayerDmg[id]);
        }
        else
        {
            client_print(id, print_chat,
                "[DMG Changer Weapon] Your weapon damage is set to original game damage. Use: amx_changedmg_weap <number> to set custom damage.");
        }
        return PLUGIN_HANDLED;
    }

    if (IsOrigKeyword(arg))
    {
        g_PlayerMode[id] = DMG_MODE_ORIGINAL;
        g_PlayerDmg[id] = 0;

        SaveOrUpdatePlayerValue(auth, "amx_changedmg_weap", 0);

        client_print(id, print_chat, "[DMG Changer Weapon] Your weapon damage has been reset to original game damage.");
        return PLUGIN_HANDLED;
    }

    if (!IsNumeric(arg))
    {
        client_print(id, print_chat, "[DMG Changer Weapon] Invalid value. Enter a positive number (e.g., 8) or 'orig' to use original damage.");
        return PLUGIN_HANDLED;
    }

    new val = str_to_num(arg);

    if (val == 0)
    {
        g_PlayerMode[id] = DMG_MODE_ORIGINAL;
        g_PlayerDmg[id] = 0;

        SaveOrUpdatePlayerValue(auth, "amx_changedmg_weap", 0);

        client_print(id, print_chat, "[DMG Changer Weapon] Your weapon damage has been reset to original game damage.");
        return PLUGIN_HANDLED;
    }

    if (val < 0)
    {
        client_print(id, print_chat, "[DMG Changer Weapon] Invalid value. Enter a positive number (e.g., 8) or 'orig' to use original damage.");
        return PLUGIN_HANDLED;
    }

    g_PlayerDmg[id] = val;
    g_PlayerMode[id] = DMG_MODE_CUSTOM;

    SaveOrUpdatePlayerValue(auth, "amx_changedmg_weap", val);

    client_print(id, print_chat, "[DMG Changer Weapon] Set: %d. (saved for %s)", val, auth);
    return PLUGIN_HANDLED;
}

public Cmd_OpenChangeDmgMenuAll(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if ( !(get_user_flags(id) & g_RequiredFlag) )
    {
        client_print(id, print_chat, "[DMG Changer Weapon] You don't have access to use this!");
        return PLUGIN_HANDLED;
    }

    ShowChangeDmgMenuAll(id);
    return PLUGIN_HANDLED;
}

stock bool:IsRealSteamClient(id)
{
    if (!is_user_connected(id)) return false;

    new auth[64];
    get_user_authid(id, auth, charsmax(auth));
    if (!auth[0]) return false;
    if (equali(auth, "BOT")) return false;
    if (equali(auth, "STEAM_ID_LAN")) return false;

    return true;
}

ShowChangeDmgMenuAll(id)
{
    new menu = menu_create("Select Player (Weapon)", "ChangeDmgMenuHandlerAll");
    menu_setprop(menu, MPROP_PERPAGE, 7);

    menu_setprop(menu, MPROP_EXITNAME, "Close");
    menu_setprop(menu, MPROP_BACKNAME, "Prev");
    menu_setprop(menu, MPROP_NEXTNAME, "Next");

    new name[32], info[8];

    for (new i = 1; i <= 32; i++)
    {
        if (!is_user_connected(i))
            continue;

        if (!IsRealSteamClient(i))
            continue;

        get_user_name(i, name, charsmax(name));
        num_to_str(i, info, charsmax(info));

        menu_additem(menu, name, info);
    }

    if (menu_items(menu) == 0)
    {
        client_print(id, print_chat, "[DMG Changer Weapon] No eligible players online (bots and STEAM_ID_LAN are excluded).");
        menu_destroy(menu);
        return;
    }

    menu_display(id, menu, 0);
}

public ChangeDmgMenuHandlerAll(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);

    new target = str_to_num(info);

    if (!is_user_connected(target))
    {
        client_print(id, print_chat, "[DMG Changer Weapon] Target is no longer connected.");
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    if (!IsRealSteamClient(target))
    {
        client_print(id, print_chat, "[DMG Changer Weapon] You cannot set damage for BOT/STEAM_ID_LAN players.");
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    g_TargetForValue[id] = target;

    client_cmd(id, "messagemode ValueWeap");

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public Cmd_AdminEnteredValueAll(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if ( !(get_user_flags(id) & g_RequiredFlag) )
    {
        client_print(id, print_chat, "[DMG Changer Weapon] You don't have access to use this!");
        return PLUGIN_HANDLED;
    }

    new target = g_TargetForValue[id];
    if (target <= 0 || target > 32 || !is_user_connected(target))
    {
        client_print(id, print_chat, "[DMG Changer Weapon] No target selected or target disconnected.");
        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    if (!IsRealSteamClient(target))
    {
        client_print(id, print_chat, "[DMG Changer Weapon] You cannot set damage for BOT/STEAM_ID_LAN players.");
        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    new arg[32];
    read_argv(1, arg, charsmax(arg));

    if (!arg[0])
    {
        client_print(id, print_chat, "[DMG Changer Weapon] Please enter a number (e.g., 8) or 'orig' for original damage.");
        return PLUGIN_HANDLED;
    }

    new auth[64];
    get_user_authid(target, auth, charsmax(auth));

    new adminName[32], targetName[32];
    get_user_name(id, adminName, charsmax(adminName));
    get_user_name(target, targetName, charsmax(targetName));

    if (IsOrigKeyword(arg))
    {
        g_PlayerMode[target] = DMG_MODE_ORIGINAL;
        g_PlayerDmg[target] = 0;

        SaveOrUpdatePlayerValue(auth, "amx_changedmg_weap", 0);
        client_print(0, print_chat, "[DMG Changer Weapon] %s reset %s's weapon damage to original.", adminName, targetName);

        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    if (!IsNumeric(arg))
    {
        client_print(id, print_chat, "[DMG Changer Weapon] Invalid value. Enter a positive number (e.g., 8) or 'orig' for original damage.");
        return PLUGIN_HANDLED;
    }

    new val = str_to_num(arg);

    if (val == 0)
    {
        g_PlayerMode[target] = DMG_MODE_ORIGINAL;
        g_PlayerDmg[target] = 0;

        SaveOrUpdatePlayerValue(auth, "amx_changedmg_weap", 0);
        client_print(0, print_chat, "[DMG Changer Weapon] %s reset %s's weapon damage to original.", adminName, targetName);

        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    if (val < 0)
    {
        client_print(id, print_chat, "[DMG Changer Weapon] Invalid value. Enter a positive number (e.g., 8) or 'orig' for original damage.");
        return PLUGIN_HANDLED;
    }

    g_PlayerDmg[target] = val;
    g_PlayerMode[target] = DMG_MODE_CUSTOM;

    SaveOrUpdatePlayerValue(auth, "amx_changedmg_weap", val);
    client_print(0, print_chat, "[DMG Changer Weapon] %s set %s's weapon damage to %d.", adminName, targetName, val);

    g_TargetForValue[id] = 0;

    return PLUGIN_HANDLED;
}

public Cmd_OpenAdminFlagMenuWeap(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if ( !(get_user_flags(id) & g_RequiredFlag) )
    {
        client_print(id, print_chat, "[DMG Changer Weapon] You don't have access to change admin flag!");
        return PLUGIN_HANDLED;
    }

    ShowAdminFlagMenuWeap(id);
    return PLUGIN_HANDLED;
}

ShowAdminFlagMenuWeap(id)
{
    new menu = menu_create("Select Admin Flag (Weapon)", "AdminFlagMenuHandlerWeap");
    menu_setprop(menu, MPROP_PERPAGE, 7);
    menu_setprop(menu, MPROP_EXITNAME, "Close");
    menu_setprop(menu, MPROP_BACKNAME, "Prev");
    menu_setprop(menu, MPROP_NEXTNAME, "Next");

    new itemName[64], info[8];

    for (new i = 0; i < ADMIN_FLAG_COUNT; i++)
    {
        if (g_RequiredFlag == g_AdminFlagBits[i])
        {
            formatex(itemName, charsmax(itemName), "[*] %s", g_AdminFlagNames[i]);
        }
        else
        {
            formatex(itemName, charsmax(itemName), "%s", g_AdminFlagNames[i]);
        }

        num_to_str(i, info, charsmax(info));
        menu_additem(menu, itemName, info);
    }

    menu_display(id, menu, 0);
}

public AdminFlagMenuHandlerWeap(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);

    new idx = str_to_num(info);
    if (idx < 0 || idx >= ADMIN_FLAG_COUNT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    g_RequiredFlag = g_AdminFlagBits[idx];
    SaveAdminFlagCfg();

    client_print(id, print_chat, "[DMG Changer Weapon] Admin flag set to: %s.", g_AdminFlagNames[idx]);

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

EnsureConfigFileExists()
{
    if (file_exists(g_szCfgPath))
        return;

    new fp = fopen(g_szCfgPath, "wt");
    if (!fp)
    {
        log_amx("[DMG Changer Weapon] Can't create file: %s", g_szCfgPath);
        return;
    }

    new line[256];
    formatex(line, charsmax(line), "; Per-player weapon damage%c", 10);
    fputs(fp, line);

    formatex(line, charsmax(line),
        "; Syntax: %c%s%c %c%s%c %c%s%c%c",
        34, "<SteamID>", 34,
        34, "amx_changedmg_weap", 34,
        34, "<value>", 34,
        10
    );
    fputs(fp, line);

    formatex(line, charsmax(line),
        "; <value> > 0  = custom damage (e.g. 8)%c", 10
    );
    fputs(fp, line);

    formatex(line, charsmax(line),
        "; <value> <= 0 = original game damage%c", 10
    );
    fputs(fp, line);

    formatex(line, charsmax(line),
        "; Example: %c%s%c %c%s%c %c%d%c%c",
        34, "STEAM_0:1:23456789", 34,
        34, "amx_changedmg_weap", 34,
        34, 8, 34,
        10
    );
    fputs(fp, line);

    fclose(fp);
}

bool:LoadPlayerValue(const steamid[], const key[], &outValue)
{
    outValue = 0;

    new fp = fopen(g_szCfgPath, "rt");
    if (!fp) return false;

    new line[256], sSteam[64], sKey[64], sVal[64], n;

    while (!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';') continue;

        n = parse(line, sSteam, charsmax(sSteam), sKey, charsmax(sKey), sVal, charsmax(sVal));
        if (n >= 3 && equali(sSteam, steamid) && equali(sKey, key))
        {
            outValue = str_to_num(sVal);
            fclose(fp);
            return true;
        }
    }

    fclose(fp);
    return false;
}

SaveOrUpdatePlayerValue(const steamid[], const key[], value)
{
    new tmpPath[256];
    copy(tmpPath, charsmax(tmpPath), g_szCfgPath);
    add(tmpPath, charsmax(tmpPath), ".tmp");

    new fpr = fopen(g_szCfgPath, "rt");
    new fpw = fopen(tmpPath, "wt");

    if (!fpw)
    {
        if (fpr) fclose(fpr);
        log_amx("[DMG Changer Weapon] Can't write to: %s", tmpPath);
        return;
    }

    new line[256], sSteam[64], sKey[64], sVal[64], n;
    new bool:written = false;

    if (fpr)
    {
        while (!feof(fpr))
        {
            fgets(fpr, line, charsmax(line));

            new line2[256]; copy(line2, charsmax(line2), line);
            trim(line2);

            if (line2[0] && line2[0] != ';')
            {
                n = parse(line2, sSteam, charsmax(sSteam), sKey, charsmax(sKey), sVal, charsmax(sVal));
                if (n >= 3 && equali(sSteam, steamid) && equali(sKey, key))
                {
                    formatex(line, charsmax(line), "%c%s%c %c%s%c %c%d%c%c",
                        34, steamid, 34,
                        34, key, 34,
                        34, value, 34,
                        10
                    );
                    fputs(fpw, line);
                    written = true;
                    continue;
                }
            }

            fputs(fpw, line);
        }
        fclose(fpr);
    }
    else
    {
        formatex(line, charsmax(line), "; Per-player weapon damage%c", 10);
        fputs(fpw, line);
        formatex(line, charsmax(line),
            "; Syntax: %c%s%c %c%s%c %c%s%c%c",
            34, "<SteamID>", 34,
            34, "amx_changedmg_weap", 34,
            34, "<value>", 34,
            10
        );
        fputs(fpw, line);
        formatex(line, charsmax(line),
            "; Example: %c%s%c %c%s%c %c%d%c%c",
            34, "STEAM_0:1:23456789", 34,
            34, "amx_changedmg_weap", 34,
            34, 8, 34,
            10
        );
        fputs(fpw, line);
    }

    if (!written)
    {
        formatex(line, charsmax(line), "%c%s%c %c%s%c %c%d%c%c",
            34, steamid, 34,
            34, key, 34,
            34, value, 34,
            10
        );
        fputs(fpw, line);
    }

    fclose(fpw);

    delete_file(g_szCfgPath);
    rename_file(tmpPath, g_szCfgPath, true);
}