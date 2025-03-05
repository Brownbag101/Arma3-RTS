// zeus_selective_control.sqf
if (hasInterface) then {
    [] spawn {
        waitUntil {!isNull player};
        waitUntil {!isNull (getAssignedCuratorLogic player)};
        
        private _zeus = getAssignedCuratorLogic player;
        
        // Initialize the variable first
        ZEUS_lastEnemySelected = false;
        
        
        
        // Monitor selection and adjust waypoint cost accordingly
        while {true} do {
            if (!isNull findDisplay 312) then {
                private _selectedUnits = curatorSelected select 0;
                
                if (count _selectedUnits > 0) then {
                    private _hasEnemySelected = false;
                    
                    {
                        if ((side _x) != (side player)) then {
                            _hasEnemySelected = true;
                        };
                    } forEach _selectedUnits;
                    
                    if (_hasEnemySelected) then {
                        // Prevent waypoints for enemy units by setting high cost
                        _zeus setCuratorWaypointCost 999999;
                        
                        // Optional visual feedback
                        if (!ZEUS_lastEnemySelected) then {
                            systemChat "Enemy units selected - cannot issue orders";
                            ZEUS_lastEnemySelected = true;
                        };
                    } else {
                        // Allow waypoints for friendly units
                        _zeus setCuratorWaypointCost 0;
                        
                        // Reset feedback flag
                        if (ZEUS_lastEnemySelected) then {
                            ZEUS_lastEnemySelected = false;
                        };
                    };
                };
            };
            
            sleep 0.1;
        };
    };
};