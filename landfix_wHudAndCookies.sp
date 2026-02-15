#include <sdktools>
#include <sdkhooks>
#include <shavit/core>
#include <clientprefs>

#pragma semicolon 1

public Plugin myinfo = 
{
	name = "LandFix",
	author = "Haze, nimmy, shinoum, lukah, nora",
	description = "Modified Landfix plugin that saves players settings and has a toggleable HUD.",
	version = "1.2.1",
	url = "https://github.com/tadehack/landfix_wHudAndCookies"
}

#define CHERRY 0
#define HAZE 1

int gI_TicksOnGround[MAXPLAYERS + 1];
int gI_Jump[MAXPLAYERS + 1];
int gI_HudPosition[MAXPLAYERS + 1];
int gI_HudColor[MAXPLAYERS + 1];
float gF_HudPositionX[MAXPLAYERS + 1];
float gF_HudPositionY[MAXPLAYERS + 1];
float gF_HudTimerDuration = 0.7;

bool gB_LandfixType[MAXPLAYERS + 1] = {true, ...}; // false = Cherry | true = Haze
bool gB_Enabled[MAXPLAYERS+1] = {true, ...};
bool gB_UseHud[MAXPLAYERS+1] = {true, ...};

// Simplified timer management - remove timer ID system
Handle g_hudTimers[MAXPLAYERS + 1] = { null, ... };

Cookie g_cEnabledCookie;
Cookie g_cUseHudCookie;
Cookie g_cHudPositionCookie;
Cookie g_cHudColorCookie;
Cookie g_cLandfixTypeCookie;

int g_iColorRGB[6][4] = {
	{255,255,255,255},	// 0: White (Default)
	{0,255,255,255},	// 1: Cyan
	{255,0,255,255},	// 2: Purple
	{255,255,0,255},	// 3: Yellow
	{0,255,0,255},		// 4: Green
	{255,0,0,255}		// 5: Red
};

public void OnPluginStart()
{
	// Toggle Landfix
	RegConsoleCmd("sm_landfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_lfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_lf", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_land", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64fix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64", Command_LandFix, "Landfix");
	
	// Toggle Landfix HUD
	RegConsoleCmd("sm_landfixhud", Command_LandFixHud, "LandfixHud");
	RegConsoleCmd("sm_lfhud", Command_LandFixHud, "LandfixHud");
	RegConsoleCmd("sm_landhud", Command_LandFixHud, "LandfixHud");
	RegConsoleCmd("sm_lhud", Command_LandFixHud, "LandfixHud");
	
	// Change HUD Position
	RegConsoleCmd("sm_lfp", Command_LandFixHudPos, "LandfixHudPos");
	RegConsoleCmd("sm_lfpos", Command_LandFixHudPos, "LandfixHudPos");
	RegConsoleCmd("sm_landfixpos", Command_LandFixHudPos, "LandfixHudPos");
	RegConsoleCmd("sm_lfhp", Command_LandFixHudPos, "LandfixHudPos");
	RegConsoleCmd("sm_lfhudpos", Command_LandFixHudPos, "LandfixHudPos");
	RegConsoleCmd("sm_lfhudposition", Command_LandFixHudPos, "LandfixHudPos");
	
	// Change HUD Color
	RegConsoleCmd("sm_lfc", Command_LandFixHudColor, "LandfixHUDColor");
	RegConsoleCmd("sm_lfcolor", Command_LandFixHudColor, "LandfixHUDColor");
	RegConsoleCmd("sm_lfhc", Command_LandFixHudColor, "LandfixHUDColor");
	RegConsoleCmd("sm_lfhudcolor", Command_LandFixHudColor, "LandfixHUDColor");
	
	// Landfix Menu
	RegConsoleCmd("sm_landfixmenu", Command_LandFixMenu, "LandfixMenu");
	RegConsoleCmd("sm_landmenu", Command_LandFixMenu, "LandfixMenu");
	RegConsoleCmd("sm_lfmenu", Command_LandFixMenu, "LandfixMenu");
	RegConsoleCmd("sm_lfm", Command_LandFixMenu, "LandfixMenu");
	RegConsoleCmd("sm_landfixsettings", Command_LandFixMenu, "LandfixMenu");
	RegConsoleCmd("sm_lfsettings", Command_LandFixMenu, "LandfixMenu");
	RegConsoleCmd("sm_lfoptions", Command_LandFixMenu, "LandfixMenu");

	// Landfix Type
	RegConsoleCmd("sm_lft", Command_LandFixType, "LandfixType");
	RegConsoleCmd("sm_lftype", Command_LandFixType, "LandfixType");
	RegConsoleCmd("sm_landfixtype", Command_LandFixType, "LandfixType");
	
	HookEvent("player_jump", PlayerJump);
	
	// Cookies
	g_cEnabledCookie = new Cookie("landfix_enabled", "Landfix enabled state", CookieAccess_Protected);
	g_cUseHudCookie = new Cookie("landfix_hud", "Landfix HUD enabled state", CookieAccess_Protected);
	g_cHudPositionCookie = new Cookie("landfix_hud_position", "Landfix HUD position state", CookieAccess_Protected);
	g_cHudColorCookie = new Cookie("landfix_hud_color", "Landfix HUD Color", CookieAccess_Protected);
	g_cLandfixTypeCookie = new Cookie("landfix_type", "Landfix type (Haze/Cherry)", CookieAccess_Protected);
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			OnClientPutInServer(client);
			
			if (AreClientCookiesCached(client))
			    OnClientCookiesCached(client);
		}
	}
	
	AutoExecConfig();
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;
	
	char buffer[8];
	
	// Load Landfix enabled cookie
	g_cEnabledCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
	    gB_Enabled[client] = true;
	    g_cEnabledCookie.Set(client, "1");
	}
	else
	{
	    gB_Enabled[client] = (StringToInt(buffer) == 1);
	}
	
	// Load HUD enabled cookie
	g_cUseHudCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
	    gB_UseHud[client] = true;
	    g_cUseHudCookie.Set(client, "1");
	}
	else
	{
	    gB_UseHud[client] = (StringToInt(buffer) == 1);
	}

	// Load HUD position cookie
	g_cHudPositionCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
		gI_HudPosition[client] = 1;
		g_cHudPositionCookie.Set(client, "1");
	}
	else
	{
		gI_HudPosition[client] = StringToInt(buffer);
	}

	// Load HUD color cookie
	char colorBuffer[6];
	g_cHudColorCookie.Get(client, colorBuffer, sizeof(colorBuffer));
	if(colorBuffer[0] == '\0')
	{
		gI_HudColor[client] = 0;
		g_cHudColorCookie.Set(client, "0");
	}
	else
	{
		gI_HudColor[client] = StringToInt(colorBuffer);
	}

	// Load Landfix type cookie
    g_cLandfixTypeCookie.Get(client, buffer, sizeof(buffer));
    if (buffer[0] == '\0')
    {
        gB_LandfixType[client] = true; // false = Cherry | true = Haze
        g_cLandfixTypeCookie.Set(client, "1");
    }
    else
    {
        gB_LandfixType[client] = (StringToInt(buffer) == 1);
    }
	
	// Set HUD position and start timer if needed
	SetHudPosition(client);
	StartHudTimer(client);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_GroundEntChangedPost, OnGroundChange);
	
    gI_Jump[client] = 0;
    
    // Initialize timer handle
    g_hudTimers[client] = null;
    
    // Load player cookies
    OnClientCookiesCached(client);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsClientConnected(client) || !IsPlayerAlive(client) || IsFakeClient(client) || !gB_Enabled[client])
	{
		return Plugin_Continue;
	}

	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(gI_TicksOnGround[client] > 15)
		{
			gI_Jump[client] = 0;
		}
		gI_TicksOnGround[client]++;

		if(buttons & IN_JUMP && gI_TicksOnGround[client] == 1)
		{
			gI_TicksOnGround[client] = 0;
		}
	}
	else
	{
		gI_TicksOnGround[client] = 0;
	}

	return Plugin_Continue;
}

// LandFix Stuff -----

public PlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if(!gB_Enabled[client] || gB_LandfixType[client] == view_as<bool>(HAZE))
	{
		return;
	}

	if(IsFakeClient(client))
	{
		return;
	}

	if(gB_Enabled[client])
	{
		gI_Jump[client]++;
		if(gI_Jump[client] > 1)
		{
			CreateTimer(0.1, TimerFix, client);
		}
	}
}

public void OnGroundChange(int client)
{
	if(!gB_Enabled[client])
	{
		return;
	}

	if(gB_LandfixType[client])
	{
		RequestFrame(DoLandFix, client);
	}
}

// Menus -----

public Action Command_LandFixMenu(int client, int args)
{
	if(client == 0)
		return Plugin_Handled;
	
	ShowLandFixMenu(client);
	return Plugin_Handled;
}

void ShowLandFixMenu(int client)
{
	char typeText[64];
	Format(typeText, sizeof(typeText), "%s\n \n", gB_LandfixType[client] ? "Type: Haze" : "Type: Cherry");
	
	Menu menu = CreateMenu(LandFixMenu_Callback);
	SetMenuTitle(menu, "Landfix Menu\n \n");
	AddMenuItem(menu, "toggle", (gB_Enabled[client]) ? "Landfix: On" : "Landfix: Off");
	AddMenuItem(menu, "type", typeText);
	AddMenuItem(menu, "hud", (gB_UseHud[client]) ? "HUD: On" : "HUD: Off");
	AddMenuItem(menu, "hudpos", "HUD Position");
	AddMenuItem(menu, "hudcolor", "HUD Color");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int LandFixMenu_Callback(Menu menu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, option, info, sizeof(info));
		
		if(StrEqual(info, "toggle"))
		{
			Command_LandFix(client, 0);
			ShowLandFixMenu(client);
		}
		else if(StrEqual(info, "type"))
		{
			Command_LandFixType(client, 0);
			ShowLandFixMenu(client);
		}
		else if(StrEqual(info, "hud"))
		{
			Command_LandFixHud(client, 0);
			ShowLandFixMenu(client);
		}
		else if(StrEqual(info, "hudpos"))
		{
			ShowLandFixHudPosMenu(client);
		}
		else if(StrEqual(info, "hudcolor"))
		{
			ShowLandFixHudColorMenu(client);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowLandFixHudPosMenu(int client)
{
	Menu menu = CreateMenu(LandFixHudPosMenu_Callback);
	SetMenuTitle(menu, "Landfix HUD Position\n \n");
	AddMenuItem(menu, "0", "Top Left");
	AddMenuItem(menu, "1", "Top Right");
	AddMenuItem(menu, "2\n \n", "Top Center\n \n");
	AddMenuItem(menu, "back", "Back");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int LandFixHudPosMenu_Callback(Menu menu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, option, info, sizeof(info));
		
		if(StrEqual(info, "back"))
		{
			ShowLandFixMenu(client);
		}
		else
		{
			int hudPos = StringToInt(info);
			gI_HudPosition[client] = hudPos;
			SetHudPosition(client);
			
			char buffer[2];
			Format(buffer, sizeof(buffer), "%d", gI_HudPosition[client]);
			g_cHudPositionCookie.Set(client, buffer);
			
			// Refresh HUD display with new position
			RefreshHudDisplay(client);
			
			Shavit_PrintToChat(client, "Landfix HUD position set to: %d", hudPos);
			ShowLandFixHudPosMenu(client);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowLandFixHudColorMenu(int client)
{
	Menu menu = CreateMenu(LandFixHudColorMenu_Callback);
	SetMenuTitle(menu, "Landfix HUD Color\n \n");
	AddMenuItem(menu, "0", "White (Default)");
	AddMenuItem(menu, "1", "Cyan");
	AddMenuItem(menu, "2", "Purple");
	AddMenuItem(menu, "3", "Yellow");
	AddMenuItem(menu, "4", "Green");
	AddMenuItem(menu, "5\n \n", "Red\n \n");
	AddMenuItem(menu, "back", "Back");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int LandFixHudColorMenu_Callback(Menu menu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, option, info, sizeof(info));
		
		if(StrEqual(info, "back"))
		{
			ShowLandFixMenu(client);
		}
		else
		{
			int colorIndex = StringToInt(info);
			gI_HudColor[client] = colorIndex;
			char buffer[6];
			Format(buffer, sizeof(buffer), "%d", colorIndex);
			g_cHudColorCookie.Set(client, buffer);
			
			// Refresh HUD display with new color
			RefreshHudDisplay(client);
			
			Shavit_PrintToChat(client, "Landfix HUD color set to: %d", colorIndex);
			ShowLandFixHudColorMenu(client);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

// Commands -----

public Action Command_LandFixType(int client, int args) 
{
    if(client == 0)
    {
        return Plugin_Handled;
    }

    gB_LandfixType[client] = !gB_LandfixType[client];
    
    // Save the landfix type preference to cookie
    char buffer[2];
    Format(buffer, sizeof(buffer), "%d", gB_LandfixType[client]);
    g_cLandfixTypeCookie.Set(client, buffer);
    
    SetHudPosition(client);
    RefreshHudDisplay(client);
    
    Shavit_PrintToChat(client, "Landfix Type: %s", gB_LandfixType[client] ? "Haze" : "Cherry");
    return Plugin_Handled;
}

public Action Command_LandFixHud(int client, int args) 
{
	if (client == 0)
		return Plugin_Handled;
	
	gB_UseHud[client] = !gB_UseHud[client];
	Shavit_PrintToChat(client, "Landfix Hud: %s", gB_UseHud[client] ? "On" : "Off");
	
	// Save the new HUD enabled state in the cookie
	char buffer[2];
	Format(buffer, sizeof(buffer), "%d", gB_UseHud[client]);
	g_cUseHudCookie.Set(client, buffer);
	
	// Use centralized HUD management
	if (gB_UseHud[client])
	{
		StartHudTimer(client);
	}
	else
	{
		StopHudTimer(client);
	}
	
	return Plugin_Handled;
}

public Action Command_LandFixHudPos(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	if (args < 1)
	{
		Shavit_PrintToChat(client, "Choose a position from 0 to 2, example: /lfhudpos 1");
		Shavit_PrintToChat(client, "Current Landfix Hud position: %d", gI_HudPosition[client]);
		return Plugin_Handled;
	}
	
	char arg[2];
	GetCmdArg(1, arg, sizeof(arg));
	int hudPosition = StringToInt(arg);
	
	if (hudPosition < 0 || hudPosition > 2)
	{
		Shavit_PrintToChat(client, "Choose a position from 0 to 2, example: /lfhudpos 1");
		Shavit_PrintToChat(client, "Current Landfix Hud position: %d", gI_HudPosition[client]);
		return Plugin_Handled;
	}
	
	gI_HudPosition[client] = hudPosition;
	SetHudPosition(client);
	
	char buffer[2];
	Format(buffer, sizeof(buffer), "%d", gI_HudPosition[client]);
	g_cHudPositionCookie.Set(client, buffer);

	// Refresh HUD display with new position
	RefreshHudDisplay(client);

	Shavit_PrintToChat(client, "Landfix Hud position set to: %d", hudPosition);

	return Plugin_Handled;
}

void SetHudPosition(int client)
{
    // Top Left
    if (gI_HudPosition[client] == 0)
    {
        gF_HudPositionX[client] = 0.01;
        gF_HudPositionY[client] = 0.16;
    }
    // Top Right
    else if (gI_HudPosition[client] == 1)
    {
        if (gB_LandfixType[client] == true)
        {
            gF_HudPositionX[client] = 0.882;
        }
        else
        {
            gF_HudPositionX[client] = 0.868;
        }
        
        gF_HudPositionY[client] = 0.01;
    }
    // Top Center
    else if (gI_HudPosition[client] == 2)
    {
        if (gB_LandfixType[client] == true)
        {
            gF_HudPositionX[client] = 0.444;
        }
        else
        {
            gF_HudPositionX[client] = 0.437;
        }
        
        gF_HudPositionY[client] = 0.01;
    }
}

public Action Command_LandFixHudColor(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	if (args < 1)
	{
		Shavit_PrintToChat(client, "Choose a color from 0 to 5, example: /lfhudcolor 1");
		Shavit_PrintToChat(client, "Current Landfix Hud color: %d", gI_HudColor[client]);
		return Plugin_Handled;
	}
	
	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));
	int color = StringToInt(arg);
	if (color < 0 || color >= 6)
	{
		Shavit_PrintToChat(client, "Choose a color from 0 to 5, example: /lfhudcolor 1");
		Shavit_PrintToChat(client, "Current Landfix Hud color: %d", gI_HudColor[client]);
		return Plugin_Handled;
	}
	
	gI_HudColor[client] = color;
	char buffer[8];
	Format(buffer, sizeof(buffer), "%d", color);
	g_cHudColorCookie.Set(client, buffer);
	
	// Refresh HUD display with new color
	RefreshHudDisplay(client);
	
	Shavit_PrintToChat(client, "Landfix HUD color set to: %d", color);
	return Plugin_Handled;
}

public Action Command_LandFix(int client, int args) 
{
	if (client == 0)
		return Plugin_Handled;
	
	gB_Enabled[client] = !gB_Enabled[client];

	if(gB_LandfixType[client] == true)
	{
		Shavit_PrintToChat(client, "Landfix: %s", gB_Enabled[client] ? "\x078efeffOn \x07ffffff(Haze)" : "\x07a082ffOff");
	}
	else
	{
		Shavit_PrintToChat(client, "Landfix: %s", gB_Enabled[client] ? "\x078efeffOn \x07ffffff(Cherry)" : "\x07a082ffOff");
	}
	
	// Save the new Landfix enabled state in the cookie
	char buffer[2];
	Format(buffer, sizeof(buffer), "%d", gB_Enabled[client]);
	g_cEnabledCookie.Set(client, buffer);
	
	// Use centralized HUD management
	if (gB_Enabled[client])
	{
		StartHudTimer(client);
	}
	else
	{
		StopHudTimer(client);
	}
	
	return Plugin_Handled;
}

// Hud Timer
public Action Timer_ShowHudText(Handle timer, any client) 
{
	// Validate client and settings
	if (!IsClientInGame(client) || !gB_Enabled[client] || !gB_UseHud[client]) 
	{
		g_hudTimers[client] = null;
		return Plugin_Stop;
	}
	
	// Validate timer handle
	if (g_hudTimers[client] != timer)
	{
		// This timer is outdated, stop it
		return Plugin_Stop;
	}
	
	char hudText[32];
	Format(hudText, sizeof(hudText), "Landfix: %s", gB_LandfixType[client] ? "Haze" : "Cherry");
	
	SetHudTextParams(gF_HudPositionX[client], gF_HudPositionY[client], gF_HudTimerDuration,
        g_iColorRGB[gI_HudColor[client]][0],
        g_iColorRGB[gI_HudColor[client]][1],
        g_iColorRGB[gI_HudColor[client]][2],
        g_iColorRGB[gI_HudColor[client]][3],
        0, 0.0, 0.0);
	ShowHudText(client, -1, hudText);
	
	return Plugin_Continue;
}

// Centralized HUD management functions
void StopHudTimer(int client)
{
	if (g_hudTimers[client] != null)
	{
		KillTimer(g_hudTimers[client]);
		g_hudTimers[client] = null;
	}
	
	// Clear any existing HUD text
	SetHudTextParams(-1.0, -1.0, 0.01, 255, 255, 255, 0, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, "");
}

void StartHudTimer(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;
		
	// Always stop any existing timer first
	StopHudTimer(client);
	
	// Only start if both landfix and HUD are enabled
	if (gB_Enabled[client] && gB_UseHud[client])
	{
		g_hudTimers[client] = CreateTimer(gF_HudTimerDuration, Timer_ShowHudText, client, TIMER_REPEAT);
	}
}

void RefreshHudDisplay(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;
		
	// Stop current timer and restart with new settings
	StartHudTimer(client);
}

// More LandFix Stuff -----

//Thanks MARU for the idea/http://steamcommunity.com/profiles/76561197970936804
float GetGroundUnits(int client)
{
	if (!IsPlayerAlive(client) || GetEntityMoveType(client) != MOVETYPE_WALK || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1)
	{
		return 0.0;
	}

	float origin[3], originBelow[3], landingMins[3], landingMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(client, Prop_Data, "m_vecMins", landingMins);
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", landingMaxs);

	originBelow[0] = origin[0];
	originBelow[1] = origin[1];
	originBelow[2] = origin[2] - 2.0;

	TR_TraceHullFilter(origin, originBelow, landingMins, landingMaxs, MASK_PLAYERSOLID, PlayerFilter, client);

	if(TR_DidHit())
	{
		TR_GetEndPosition(originBelow, null);
		float defaultheight = originBelow[2] - RoundToFloor(originBelow[2]);

		if(defaultheight > 0.03125)
		{
			defaultheight = 0.03125;
		}

		float heightbug = origin[2] - originBelow[2] + defaultheight;
		return heightbug;
	}
	else
	{
		return 0.0;
	}
}

void DoLandFix(int client)
{
	if(GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != -1)
	{
		float difference = (1.50 - GetGroundUnits(client)), origin[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
		origin[2] += difference;
		SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	}
}

Action TimerFix(Handle timer, any client)
{
	float cll[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", cll);
	cll[2] += 1.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cll);

	CreateTimer(0.05, TimerFix2, client);
	return Plugin_Handled;
}

Action TimerFix2(Handle timer, any client)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		float cll[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", cll);
		cll[2] -= 1.5;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cll);
	}
	return Plugin_Handled;
}

public bool PlayerFilter(int entity, int mask)
{
	return !(1 <= entity <= MaxClients);
}