// Create a simpler version of recruitmentInit.sqf with proper path handling
// Replace the content of scripts/menu/recruitmentInit.sqf with this:

// scripts/menu/recruitmentInit.sqf
// Initialize recruitment system

// Load the recruitment system directly
private _result = [] execVM "scripts\menu\recruitmentSystem.sqf";

// Log loading attempt
diag_log "Attempting to load recruitment system...";
systemChat "Attempting to load recruitment system...";

// Wait a bit and check if the system loaded
[] spawn {
    sleep 5; // Give it some time to load
    
    if (!isNil "RTS_fnc_recruitOrder") then {
        systemChat "✓ Recruitment system loaded successfully";
        
        // Create test markers if they don't exist
        if (markerType "recruit_spawn" == "") then {
            private _marker = createMarker ["recruit_spawn", [0, 3000, 500]];
            _marker setMarkerType "mil_start";
            _marker setMarkerText "Recruit Spawn";
        };
        
        if (markerType "recruit_land" == "") then {
            private _marker = createMarker ["recruit_land", [0, 0, 0]];
            _marker setMarkerType "mil_landing";
            _marker setMarkerText "Recruit Land";
        };
        
        if (markerType "recruit_assembly" == "") then {
            private _marker = createMarker ["recruit_assembly", [50, 50, 0]];
            _marker setMarkerType "mil_dot";
            _marker setMarkerText "Recruit Assembly";
        };
        
        if (markerType "recruit_despawn" == "") then {
            private _marker = createMarker ["recruit_despawn", [0, -3000, 500]];
            _marker setMarkerType "mil_end";
            _marker setMarkerText "Recruit Despawn";
        };
        
        systemChat "✓ Test recruitment markers created";
    } else {
        systemChat "✗ Recruitment system failed to load - check path and script";
    };
};