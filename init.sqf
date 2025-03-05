if (hasInterface) then {
    // Load core UI system
    [] execVM "scripts\ui\rtsUI.sqf";
    
    // Load special abilities system
    [] execVM "scripts\specialAbilities\abilityManager.sqf";
	
	[] execVM "scripts\economy\economyInit.sqf";
	
	    [] execVM "scripts\menu\menuInit.sqf";

	
    [] execVM "zeus_selective_control.sqf";
    [] execVM "zeus_visibility.sqf";
    
    // Initialize weapon toggle system for vehicles
    [] execVM "scripts\actions\vehicleActions\weaponToggleInit.sqf";
};

[] execVM "scripts\towCargoGlobals.sqf";
[] execVM "scripts\cargoSystem.sqf";
[] execVM "scripts\towSystem.sqf";



if (isServer) then {
	[] execVM "zeusUISystem.sqf";
};


//[] execVM "zeus.sqf";