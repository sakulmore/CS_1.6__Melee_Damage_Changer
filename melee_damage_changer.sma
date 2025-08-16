#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fun>
#include <cstrike>

#define PLUGIN_NAME    "Melee Damage Changer"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_AUTHOR  "sakulmore"

new g_szCfgPath[256];
new g_pCvarDmgDefault;
new g_PlayerDmg[33];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
    g_pCvarDmgDefault = register_cvar("amx_changedmg", "200");
    register_clcmd("amx_changedmg", "Cmd_ClientSetDamage");

    new datadir[128];
    get_datadir(datadir, charsmax(datadir));
    formatex(g_szCfgPath, charsmax(g_szCfgPath), "%s/melee_dmg_changer.cfg", datadir);

    EnsureConfigFileExists();

    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage_Pre", 0);
}

public client_authorized(id)
{
    g_PlayerDmg[id] = 0;

    if (!is_user_connected(id))
        return;

    new auth[64];
    get_user_authid(id, auth, charsmax(auth));

    if (!auth[0] || equali(auth, "BOT") || equali(auth, "STEAM_ID_LAN"))
        return;

    new value = 0;
    if (LoadPlayerValue(auth, "amx_changedmg", value) && value > 0)
    {
        g_PlayerDmg[id] = value;
    }
}

public client_disconnected(id)
{
    g_PlayerDmg[id] = 0;
}

public OnPlayerTakeDamage_Pre(victim, inflictor, attacker, Float:damage, damagebits)
{
    if (attacker <= 0 || attacker > 32 || attacker == victim || !is_user_connected(attacker))
        return HAM_IGNORED;

    if (get_user_weapon(attacker) != CSW_KNIFE)
        return HAM_IGNORED;

    new iDmg = g_PlayerDmg[attacker];
    if (iDmg <= 0)
    {
        iDmg = get_pcvar_num(g_pCvarDmgDefault);
    }
    if (iDmg <= 0)
        return HAM_IGNORED;

    SetHamParamFloat(4, float(iDmg));
    return HAM_HANDLED;
}

public Cmd_ClientSetDamage(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

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
        new def = get_pcvar_num(g_pCvarDmgDefault);
        new cur = g_PlayerDmg[id] > 0 ? g_PlayerDmg[id] : def;
        client_print(id, print_chat, "[DMG Changer] Your value: %d (default: %d). Change by: amx_changedmg <number>", cur, def);
        return PLUGIN_HANDLED;
    }

    new val = str_to_num(arg);
    if (val <= 0)
    {
        client_print(id, print_chat, "[DMG Changer] Invalid value. Enter a positive number (e.g., 200).");
        return PLUGIN_HANDLED;
    }

    g_PlayerDmg[id] = val;

    SaveOrUpdatePlayerValue(auth, "amx_changedmg", val);

    client_print(id, print_chat, "[DMG Changer] Setten: %d. (saved for %s)", val, auth);
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
        "; Example: %c%s%c %c%s%c %c%d%c%c",
        34, "STEAM_0:1:23456789", 34,
        34, "amx_changedmg", 34,
        34, 200, 34,
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
            34, 200, 34,
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