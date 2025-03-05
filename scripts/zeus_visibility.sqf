// Enhanced Zeus Visibility
// Makes enemy units only visible to Zeus when they are detected by friendly units
// or when they are within a certain range of the Zeus camera

if (hasInterface) then {
    [] spawn {
        waitUntil {!isNull player};
        waitUntil {!isNull (getAssignedCuratorLogic player)};
        
        private _zeus = getAssignedCuratorLogic player;
        private _detectionRadius = 300;         // Base detection radius for units
        private _zeusDirectRadius = 200;        // Direct Zeus camera detection radius
        private _updateInterval = 1;            // Update interval in seconds
        private _removalTime = 30;             // Time in seconds before units are removed from visibility (5 minutes)
        
        // Initialize tracking arrays
        if (isNil "ZEUS_knownEnemies") then { ZEUS_knownEnemies = []; };
        
        // Add friendly units to Zeus visibility immediately
        {
            if ((side _x) == (side player)) then {
                _zeus addCuratorEditableObjects [[_x], false];
            } else {
                // Make sure enemies are not visible to begin with
                _zeus removeCuratorEditableObjects [[_x], false];
            };
        } forEach allUnits;
        
        // Add empty vehicles to Zeus visibility initially
        {
            if (count crew _x == 0) then {
                _zeus addCuratorEditableObjects [[_x], false];
            };
        } forEach vehicles;
        
        // Main detection loop
        while {true} do {
            // Get current Zeus camera position if interface is open
            private _zeusPos = [0,0,0];
            private _zeusActive = false;
            
            if (!isNull findDisplay 312) then {
                _zeusActive = true;
                _zeusPos = getPos curatorCamera;
            };
            
            private _friendlyUnits = allUnits select {(side _x) == (side player)};
            private _enemyUnits = allUnits select {(side _x) != (side player) && (side _x) != civilian};
            private _newDetections = [];
            
            // Check for newly detected enemies
            {
                private _enemyUnit = _x;
                private _isVisible = false;
                private _detectionMethod = "None";
                
                // Skip if already in known enemies
                private _alreadyKnown = false;
                {
                    if (_x select 0 == _enemyUnit) exitWith {
                        _alreadyKnown = true;
                    };
                } forEach ZEUS_knownEnemies;
                
                if (!_alreadyKnown) then {
                    // Method 1: Direct Zeus observation
                    if (_zeusActive && {_enemyUnit distance _zeusPos < _zeusDirectRadius}) then {
                        _isVisible = true;
                        _detectionMethod = "Direct Zeus observation";
                    };
                    
                    // Method 2: Knowledge-based detection from friendly units
                    if (!_isVisible) then {
                        {
                            private _friendlyUnit = _x;
                            private _knowledge = _friendlyUnit knowsAbout _enemyUnit;
                            
                            if (_knowledge > 1.5 && _friendlyUnit distance _enemyUnit < _detectionRadius) then {
                                _isVisible = true;
                                _detectionMethod = format ["Detected by %1", name _friendlyUnit];
                                break;
                            };
                        } forEach _friendlyUnits;
                    };
                    
                    // Method 3: Line of sight based detection
                    if (!_isVisible) then {
                        {
                            private _friendlyUnit = _x;
                            if (_friendlyUnit distance _enemyUnit < _detectionRadius * 0.5) then {
                                private _canSee = [_friendlyUnit, "VIEW"] checkVisibility [eyePos _friendlyUnit, eyePos _enemyUnit];
                                if (_canSee > 0.2) then {
                                    _isVisible = true;
                                    _detectionMethod = format ["Visual contact by %1", name _friendlyUnit];
                                    break;
                                };
                            };
                        } forEach _friendlyUnits;
                    };
                    
                    // If visible by any method, add to newly detected
                    if (_isVisible) then {
                        _newDetections pushBack [_enemyUnit, _detectionMethod, time];
                    };
                };
            } forEach _enemyUnits;
            
            // Process new detections
            {
                private _enemy = _x select 0;
                private _method = _x select 1;
                
                // Add to Zeus editability
                _zeus addCuratorEditableObjects [[_enemy], false];
                
                // Add to known enemies
                ZEUS_knownEnemies pushBack _x;
                
                // Notification
                if (_method != "Direct Zeus observation") then {
                    systemChat format ["New enemy detected: %1 - %2", 
                        if (_enemy isKindOf "CAManBase") then {name _enemy} else {typeOf _enemy}, 
                        _method
                    ];
                };
            } forEach _newDetections;
            
            // Remove null references and check for units to remove (very long timeout)
            private _toRemove = [];
            {
                private _entry = _x;
                private _enemy = _entry select 0;
                private _detectionTime = _entry select 2;
                
                if (isNull _enemy) then {
                    _toRemove pushBack _forEachIndex;
                } else {
                    // Only remove if extremely old detection (5 minutes) and direct zeus check fails
                    if (time - _detectionTime > _removalTime) then {
                        if (!(_zeusActive && {_enemy distance _zeusPos < _zeusDirectRadius})) then {
                            _zeus removeCuratorEditableObjects [[_enemy], false];
                            _toRemove pushBack _forEachIndex;
                            
                            // Debug message
                            systemChat format ["Enemy removed from visibility (timeout): %1", 
                                if (_enemy isKindOf "CAManBase") then {name _enemy} else {typeOf _enemy}
                            ];
                        };
                    };
                };
            } forEach ZEUS_knownEnemies;
            
            // Clean up the array (from last index to first to avoid shifting issues)
            _toRemove sort false; // Sort in descending order
            {
                ZEUS_knownEnemies deleteAt _x;
            } forEach _toRemove;
            
            sleep _updateInterval;
        };
    };
};