// scripts/menu/unitManagementInit.sqf
// Initialization file for Unit Management System

// Monitor unit statistics (kills, etc.)
// This will be called by the main script after initialization
fnc_initUnitDataMonitoring = {
    // Create event handler to track kills
    if (isNil "UNIT_KILL_EH_ADDED") then {
        UNIT_KILL_EH_ADDED = true;
        
        // Add killed event handler to all units
        {
            if (side _x == side player) then {
                _x addEventHandler ["killed", {
                    params ["_unit", "_killer"];
                    
                    // Only count if killer is enemy and real
                    if (!isNull _killer && side _killer != side _unit && isPlayer _killer) then {
                        // Get unit data
                        private _unitData = [_killer] call fnc_getUnitData;
                        
                        // Increment kill count
                        private _kills = _unitData select 1;
                        _unitData set [1, _kills + 1];
                        
                        // Update unit data
                        [_killer, _unitData] call fnc_updateUnitData;
                        
                        // Log kill
                        diag_log format ["%1 killed %2, new kill count: %3", name _killer, name _unit, _kills + 1];
                    };
                }];
            };
        } forEach allUnits;
        
        // Check for new units periodically
        [] spawn {
            private ["_lastCheckedUnits"];
            _lastCheckedUnits = [];
            
            while {true} do {
                // Get current friendly units
                private _currentUnits = allUnits select {side _x == side player};
                
                // Check for new units
                {
                    if !(_x in _lastCheckedUnits) then {
                        // Add killed event handler
                        _x addEventHandler ["killed", {
                            params ["_unit", "_killer"];
                            
                            // Only count if killer is enemy and real
                            if (!isNull _killer && side _killer != side _unit && isPlayer _killer) then {
                                // Get unit data
                                private _unitData = [_killer] call fnc_getUnitData;
                                
                                // Increment kill count
                                private _kills = _unitData select 1;
                                _unitData set [1, _kills + 1];
                                
                                // Update unit data
                                [_killer, _unitData] call fnc_updateUnitData;
                                
                                // Log kill
                                diag_log format ["%1 killed %2, new kill count: %3", name _killer, name _unit, _kills + 1];
                            };
                        }];
                    };
                } forEach _currentUnits;
                
                // Update last checked units
                _lastCheckedUnits = _currentUnits;
                
                // Wait before checking again
                sleep 30;
            };
        };
    };
};

// Load main unit management system
if (isNil "UNIT_MANAGEMENT_LOADED") then {
    diag_log "Loading Unit Management System...";
    UNIT_MANAGEMENT_LOADED = false;
    
    // Execute main unit management script
    [] execVM "scripts\menu\unitManagementSystem.sqf";
    
    // Wait for main system to load
    waitUntil {!isNil "fnc_openUnitManagementUI"};
    
    diag_log "Unit Management System loaded successfully.";
    UNIT_MANAGEMENT_LOADED = true;
};

// Load training confirmation dialog
if (isNil "TRAINING_CONFIRMATION_LOADED") then {
    diag_log "Loading Training Confirmation Dialog...";
    TRAINING_CONFIRMATION_LOADED = false;
    
    // Execute training confirmation script
    [] execVM "scripts\training\trainingConfirmation.sqf";
    
    // Wait for confirmation dialog to load
    waitUntil {!isNil "fnc_openTrainingConfirmationDialog"};
    
    diag_log "Training Confirmation Dialog loaded successfully.";
    TRAINING_CONFIRMATION_LOADED = true;
};

// Load training modules
if (isNil "TRAINING_MODULES_LOADED") then {
    diag_log "Loading Training Modules...";
    TRAINING_MODULES_LOADED = false;
    
    // Execute training modules
    [] execVM "scripts\training\basicTraining.sqf";
    [] execVM "scripts\training\paratrooperTraining.sqf";
    
    // Create placeholder functions for other training types
    if (isNil "fnc_startCommandoTraining") then {
        fnc_startCommandoTraining = {
            params ["_unit"];
            hint format ["Commando training for %1 not yet implemented.", name _unit];
            // Use generic training as fallback
            [_unit, "commando"] call fnc_genericStartTraining;
        };
    };
    
    if (isNil "fnc_startOfficerTraining") then {
        fnc_startOfficerTraining = {
            params ["_unit"];
            hint format ["Officer training for %1 not yet implemented.", name _unit];
            // Use generic training as fallback
            [_unit, "officer"] call fnc_genericStartTraining;
        };
    };
    
    if (isNil "fnc_startSpecialTraining") then {
        fnc_startSpecialTraining = {
            params ["_unit"];
            hint format ["Special abilities training for %1 not yet implemented.", name _unit];
            // Use generic training as fallback
            [_unit, "special"] call fnc_genericStartTraining;
        };
    };
    
    // Wait for basic modules to load
    waitUntil {!isNil "fnc_startBasicTraining" && !isNil "fnc_startParatrooperTraining"};
    
    diag_log "Training Modules loaded successfully.";
    TRAINING_MODULES_LOADED = true;
};

// Initialize unit data monitoring
[] call fnc_initUnitDataMonitoring;

// Integration with existing research system (if available)
// We now check for research system instead of adding duplicate entries
if (!isNil "MISSION_researchTree") then {
    diag_log "Integrating Unit Management with Research System...";

    // Check if the research system has our required training categories
    private _hasTrainingResearch = false;
    {
        if (_x select 0 == "basic_training_doctrine") exitWith {
            _hasTrainingResearch = true;
        };
    } forEach MISSION_researchTree;
    
    if (_hasTrainingResearch) then {
        systemChat "✓ Research system already includes training doctrines";
    } else {
        systemChat "Research system found but missing training doctrines";
        // Let user know they should check the research system file
        hint "Note: The training doctrines are missing from your research system. Please check scripts/menu/researchTreeSystem.sqf to ensure training research options are included.";
    };
    
    diag_log "Unit Management integrated with Research System.";
};

// Signal that the unit management system is ready
missionNamespace setVariable ["UNIT_MANAGEMENT_READY", true, true];
systemChat "Unit Management System initialized.";

// Return success
true