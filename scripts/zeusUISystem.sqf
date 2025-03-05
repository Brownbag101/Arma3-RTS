// Zeus UI Control System

[] spawn {
    waitUntil {!isNull player};
    
    // Add event handler for Zeus opening (Y key)
    (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["", "_key"];
        if (_key == 21) then { // 21 is 'Y' key
            [] spawn {
                sleep 0.1;
                findDisplay 312 createDisplay "RscDisplayEmpty";
            };
        };
    }];
    
    // Keep unit icons and selection boxes visible
    while {true} do {
        if (!isNull findDisplay 312) then {
            showHUD [true, true, true, true, true, true, true, true];
        };
        sleep 0.1;
    };
};