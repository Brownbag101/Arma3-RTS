// scripts/menu/menuInit.sqf
// Initialize menu system

// Load menu system with a delay to ensure other systems are ready
[] spawn {
    sleep 2; // Give other systems time to initialize
    
    // Load menu system
    [] execVM "scripts\menu\menuSystem.sqf";
    
    // Display initialization message
    systemChat "Menu system initialized!";
};