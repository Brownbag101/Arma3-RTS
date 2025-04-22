// scripts/economy/economyInit.sqf
// Initialize economy system

// First load economy system to initialize variables
[] execVM "scripts\economy\economySystem.sqf";

// Wait for resources to be initialized
waitUntil {!isNil "RTS_resources"};
waitUntil {!isNil "RTS_resourceIcons"};

// Then load economy UI with a small delay
[] spawn {
    sleep 2;
    [] execVM "scripts\economy\economyUI.sqf";
};

// Display initialization message
systemChat "Economy system initialized!";