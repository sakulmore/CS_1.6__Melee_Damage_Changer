# CS 1.6 - Melee Damage Changer
This is officially my OWN very first plugin for CS 1.6. It is a "simple" plugin that allows your players to change damage. It is "per-player" damage, meaning each player can set their own damage as needed. For now, it is a "fun" plugin, but with future updates (which I am planning), you will have more configuration options. For example, admin flags, etc...

# Installation
- Just download the plugin and upload the .amxx file to your plugins folder on your server (or you can of course compile the .sma file and then upload the compilated .amxx file to your server).
- Then write the plugin name (with .amxx) to `/cstrike/addons/amxmodx/configs/plugins.ini`.

# Requirements
- AMX Mod X 1.10
- Module `cstrike_amxx_i386.so`

# CVARs
`amx_changedmg <value>` (Default: 8)

The command is protected by an Admin Flag. To change the Admin Flag, simply edit the line `#define REQUIRED_FLAG ADMIN_LEVEL_H` in the .sma file.

# Notes
- After installing the plugin on the server, a new .cfg file `melee_dmg_changer.cfg` will be created in the `/cstrike/addons/amxmodx/data` folder. Your SteamID, the name of the cvar, and its value will be written here. The values are saved, so it is not necessary to enter the command again each time.
- If you wish to change the default value (8), simply open the .sma script and edit this line: `g_pCvarDmgDefault = register_cvar("amx_changedmg", "8");` specifically the ending number, which defines the default value.

# Showcases
https://youtu.be/tjFB44Qvx3I

# Support
If you having any issues please feel free to write your issue to the issue section :) .
