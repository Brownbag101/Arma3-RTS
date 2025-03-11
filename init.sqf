// Add to the init.sqf file, after the economy initialization
// (around line 7, after the economy and menu init):

if (hasInterface) then {
    // Load core UI system
    [] execVM "scripts\ui\rtsUI.sqf";
    
    // Load special abilities system
    [] execVM "scripts\specialAbilities\abilityManager.sqf";
	
    // Load economy system
    [] execVM "scripts\economy\economyInit.sqf";
	
	// Load Task System
	[] execVM "scripts\mission\taskSystemArray.sqf";
	
    // Load menu system
    [] execVM "scripts\menu\menuInit.sqf";
    
    // Load recruitment system (after economy is loaded)
    [] execVM "scripts\menu\recruitmentInit.sqf";

    // Load Zeus selective control
    [] execVM "zeus_selective_control.sqf";
    [] execVM "zeus_visibility.sqf";
    
    // Initialize weapon toggle system for vehicles
    [] execVM "scripts\actions\vehicleActions\weaponToggleInit.sqf";
};

[] execVM "scripts\towCargoGlobals.sqf";
[] execVM "scripts\cargoSystem.sqf";
[] execVM "scripts\towSystem.sqf";
[] execVM "scripts\menu\researchTreeSystem.sqf";
[] execVM "scripts\menu\procurementSystem.sqf";
[] execVM "scripts\menu\constructionSystem.sqf";

if (isServer) then {
    [] execVM "zeusUISystem.sqf";
};

//[] execVM "zeus.sqf";