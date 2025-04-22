// simulateBackspace.sqf
// Directly triggers the displayEH with backspace key

[] spawn {
    // Wait for mission to fully initialize
    waitUntil {time > 0};
    
    // Wait exactly 2 seconds
    sleep 2;
    
    // Wait for Zeus interface to be open
    waitUntil {!isNull findDisplay 312};
    
    // Get the Zeus display
    private _display = findDisplay 312;
    
    // Create a KeyDown event handler that will be triggered first
    private _keyDownEH = _display displayAddEventHandler ["KeyDown", {
        params ["_display", "_key", "_shift", "_ctrl", "_alt"];
        
        // Only handle backspace key
        if (_key == 14) then {
            systemChat "Backspace key simulation triggered";
            true
        } else {
            false
        };
    }];
    
    // Small delay to ensure the handler is registered
    sleep 0.1;
    
    // Now manually trigger our own event handler with the backspace key code
    ["KeyDown", [_display, 14, false, false, false]] call (_display getVariable ["RscDisplayCurator_keyDown", {false}]);
    
    // Remove our temporary handler
    _display displayRemoveEventHandler ["KeyDown", _keyDownEH];
    
    systemChat "Backspace key simulation completed";
};