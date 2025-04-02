// Add to the init.sqf file, after the economy initialization
// (around line 7, after the economy and menu init):

if (hasInterface) then {
    // Load core UI system
    [] execVM "scripts\ui\rtsUI.sqf";
    
    // Load special abilities system
    [] execVM "scripts\specialAbilities\abilityManager.sqf";
	
    // Load economy system
    [] execVM "scripts\economy\economyInit.sqf";
	

	// First load task system
	systemChat "Loading task system...";
	[] execVM "scripts\mission\taskSystemArray.sqf";

	// Wait a moment to ensure task system is initialized
	[] spawn {
		sleep 3;
		
		// Then load HVT system
		systemChat "Loading HVT system...";
		[] execVM "scripts\mission\hvtSystem.sqf";
		
		// Then load factory system after a slight delay
		sleep 2;
		systemChat "Loading factory resource system...";
		[] execVM "scripts\mission\factoryResourceSystem.sqf";
	};
	
    // Load menu system
    [] execVM "scripts\menu\menuInit.sqf";
    
    // Load recruitment system (after economy is loaded)
    [] execVM "scripts\menu\recruitmentInit.sqf";

    // Load Zeus selective control
    [] execVM "zeus_selective_control.sqf";
    [] execVM "zeus_visibility.sqf";
    
    // Initialize weapon toggle system for vehicles
    [] execVM "scripts\actions\vehicleActions\weaponToggleInit.sqf";
	
	// Load Unit Management System
    [] execVM "scripts\menu\unitManagementInit.sqf";
	
	[] execVM "scripts\virtualHangar\hangarInit.sqf";
	
	// Load Air Operations system
	[] execVM "scripts\airOperations\airOperationsInit.sqf";
};

[] execVM "scripts\towCargoGlobals.sqf";
[] execVM "scripts\cargoSystem.sqf";
[] execVM "scripts\towSystem.sqf";
[] execVM "scripts\menu\researchTreeSystem.sqf";
[] execVM "scripts\menu\procurementSystem.sqf";
[] execVM "scripts\menu\constructionSystem.sqf";
[] execVM "scripts\functions\focusCamera.sqf";

if (isServer) then {
    [] execVM "zeusUISystem.sqf";
};

//[] execVM "zeus.sqf";