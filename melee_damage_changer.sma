#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fun>
#include <cstrike>

#define PLUGIN_NAME    "Melee Damage Changer"
#define PLUGIN_VERSION "1.3"
#define PLUGIN_AUTHOR  "sakulmore"

#define REQUIRED_FLAG ADMIN_LEVEL_H

new g_szCfgPath[256];
new g_PlayerDmg[33];
new g_TargetForValue[33];

enum PlayerDmgMode
{
    DMG_MODE_ORIGINAL = 0,
    DMG_MODE_CUSTOM
}

new PlayerDmgMode:g_PlayerMode[33];

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

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_clcmd("amx_changedmg", "Cmd_ClientSetDamage");

    register_clcmd("say /changedmg",      "Cmd_OpenChangeDmgMenu");
    register_clcmd("say_team /changedmg", "Cmd_OpenChangeDmgMenu");
    register_clcmd("changedmg",           "Cmd_OpenChangeDmgMenu");

    register_clcmd("Value", "Cmd_AdminEnteredValue");

    new datadir[128];
    get_datadir(datadir, charsmax(datadir));
    formatex(g_szCfgPath, charsmax(g_szCfgPath), "%s/melee_dmg_changer.cfg", datadir);

    EnsureConfigFileExists();

    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage_Pre", 0);
}

public client_putinserver(id)
{
    set_task(0.1, "InitPlayerDmg", id);
}

public InitPlayerDmg(id)
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
    if (LoadPlayerValue(auth, "amx_changedmg", value))
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

public OnPlayerTakeDamage_Pre(victim, inflictor, attacker, Float:damage, damagebits)
{
    if (attacker <= 0 || attacker > 32 || attacker == victim || !is_user_connected(attacker))
        return HAM_IGNORED;

    if (get_user_weapon(attacker) != CSW_KNIFE)
        return HAM_IGNORED;

    if (g_PlayerMode[attacker] != DMG_MODE_CUSTOM || g_PlayerDmg[attacker] <= 0)
    {
        return HAM_IGNORED;
    }

    SetHamParamFloat(4, float(g_PlayerDmg[attacker]));
    return HAM_HANDLED;
}

public Cmd_ClientSetDamage(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if ( !(get_user_flags(id) & REQUIRED_FLAG) )
    {
        client_print(id, print_chat, "[DMG Changer] You don't have access to use this!");
        return PLUGIN_HANDLED;
    }

    new arg[32];
    read_argv(1, arg, charsmax(arg));

    new auth[64];
    get_user_authid(id, auth, charsmax(auth));

    if (!auth[0] || equali(auth, "BOT") || equali(auth, "STEAM_ID_LAN"))
    {
        client_print(id, print_chat, "[DMG Changer] This command isn't available for BOT/STEAM_ID_LAN.");
        return PLUGIN_HANDLED;
    }

    if (!arg[0])
    {
        if (g_PlayerMode[id] == DMG_MODE_CUSTOM && g_PlayerDmg[id] > 0)
        {
            client_print(id, print_chat,
                "[DMG Changer] Your current knife damage: %d. Use: amx_changedmg <number> to change, or amx_changedmg orig to reset to original damage.",
                g_PlayerDmg[id]);
        }
        else
        {
            client_print(id, print_chat,
                "[DMG Changer] Your knife damage is set to original game damage. Use: amx_changedmg <number> to set custom damage.");
        }
        return PLUGIN_HANDLED;
    }

    if (IsOrigKeyword(arg))
    {
        g_PlayerMode[id] = DMG_MODE_ORIGINAL;
        g_PlayerDmg[id] = 0;

        SaveOrUpdatePlayerValue(auth, "amx_changedmg", 0);

        client_print(id, print_chat, "[DMG Changer] Your knife damage has been reset to original game damage.");
        return PLUGIN_HANDLED;
    }

    new val = str_to_num(arg);

    if (val == 0)
    {
        g_PlayerMode[id] = DMG_MODE_ORIGINAL;
        g_PlayerDmg[id] = 0;

        SaveOrUpdatePlayerValue(auth, "amx_changedmg", 0);

        client_print(id, print_chat, "[DMG Changer] Your knife damage has been reset to original game damage.");
        return PLUGIN_HANDLED;
    }

    if (val < 0)
    {
        client_print(id, print_chat, "[DMG Changer] Invalid value. Enter a positive number (e.g., 8) or 'orig' to use original damage.");
        return PLUGIN_HANDLED;
    }

    g_PlayerDmg[id] = val;
    g_PlayerMode[id] = DMG_MODE_CUSTOM;

    SaveOrUpdatePlayerValue(auth, "amx_changedmg", val);

    client_print(id, print_chat, "[DMG Changer] Set: %d. (saved for %s)", val, auth);
    return PLUGIN_HANDLED;
}

public Cmd_OpenChangeDmgMenu(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if ( !(get_user_flags(id) & REQUIRED_FLAG) )
    {
        client_print(id, print_chat, "[DMG Changer] You don't have access to use this!");
        return PLUGIN_HANDLED;
    }

    ShowChangeDmgMenu(id);
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

ShowChangeDmgMenu(id)
{
    new menu = menu_create("Select Player", "ChangeDmgMenuHandler");
    menu_setprop(menu, MPROP_PERPAGE, 5);

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
        client_print(id, print_chat, "[DMG Changer] No eligible players online (bots and STEAM_ID_LAN are excluded).");
        menu_destroy(menu);
        return;
    }

    menu_display(id, menu, 0);
}

public ChangeDmgMenuHandler(id, menu, item)
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
        client_print(id, print_chat, "[DMG Changer] Target is no longer connected.");
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    if (!IsRealSteamClient(target))
    {
        client_print(id, print_chat, "[DMG Changer] You cannot set damage for BOT/STEAM_ID_LAN players.");
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    g_TargetForValue[id] = target;

    client_cmd(id, "messagemode Value");

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public Cmd_AdminEnteredValue(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if ( !(get_user_flags(id) & REQUIRED_FLAG) )
    {
        client_print(id, print_chat, "[DMG Changer] You don't have access to use this!");
        return PLUGIN_HANDLED;
    }

    new target = g_TargetForValue[id];
    if (target <= 0 || target > 32 || !is_user_connected(target))
    {
        client_print(id, print_chat, "[DMG Changer] No target selected or target disconnected.");
        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    if (!IsRealSteamClient(target))
    {
        client_print(id, print_chat, "[DMG Changer] You cannot set damage for BOT/STEAM_ID_LAN players.");
        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    new arg[32];
    read_argv(1, arg, charsmax(arg));

    if (!arg[0])
    {
        client_print(id, print_chat, "[DMG Changer] Please enter a number (e.g., 8) or 'orig' for original damage.");
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

        SaveOrUpdatePlayerValue(auth, "amx_changedmg", 0);
        client_print(0, print_chat, "[DMG Changer] %s reset %s's knife damage to original.", adminName, targetName);

        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    new val = str_to_num(arg);

    if (val == 0)
    {
        g_PlayerMode[target] = DMG_MODE_ORIGINAL;
        g_PlayerDmg[target] = 0;

        SaveOrUpdatePlayerValue(auth, "amx_changedmg", 0);
        client_print(0, print_chat, "[DMG Changer] %s reset %s's knife damage to original.", adminName, targetName);

        g_TargetForValue[id] = 0;
        return PLUGIN_HANDLED;
    }

    if (val < 0)
    {
        client_print(id, print_chat, "[DMG Changer] Invalid value. Enter a positive number (e.g., 8) or 'orig' for original damage.");
        return PLUGIN_HANDLED;
    }

    g_PlayerDmg[target] = val;
    g_PlayerMode[target] = DMG_MODE_CUSTOM;

    SaveOrUpdatePlayerValue(auth, "amx_changedmg", val);
    client_print(0, print_chat, "[DMG Changer] %s set %s's knife damage to %d.", adminName, targetName, val);

    g_TargetForValue[id] = 0;

    return PLUGIN_HANDLED;
}

EnsureConfigFileExists()
{
    if (file_exists(g_szCfgPath))
        return;

    new fp = fopen(g_szCfgPath, "wt");
    if (!fp)
    {
        log_amx("[DMG Changer] Can't create file: %s", g_szCfgPath);
        return;
    }

    new line[256];
    formatex(line, charsmax(line), "; Per-player melee damage%c", 10);
    fputs(fp, line);

    formatex(line, charsmax(line),
        "; Syntax: %c%s%c %c%s%c %c%s%c%c",
        34, "<SteamID>", 34,
        34, "amx_changedmg", 34,
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
        34, "amx_changedmg", 34,
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
        log_amx("[DMG Changer] Can't write to: %s", tmpPath);
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
        formatex(line, charsmax(line), "; Per-player melee damage%c", 10);
        fputs(fpw, line);
        formatex(line, charsmax(line),
            "; Syntax: %c%s%c %c%s%c %c%s%c%c",
            34, "<SteamID>", 34,
            34, "amx_changedmg", 34,
            34, "<value>", 34,
            10
        );
        fputs(fpw, line);
        formatex(line, charsmax(line),
            "; Example: %c%s%c %c%s%c %c%d%c%c",
            34, "STEAM_0:1:23456789", 34,
            34, "amx_changedmg", 34,
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