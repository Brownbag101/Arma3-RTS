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
    // Add more training modules as they're developed:
    // [] execVM "scripts\training\commandoTraining.sqf";
    // [] execVM "scripts\training\officerTraining.sqf";
    // [] execVM "scripts\training\specialTraining.sqf";
    
    // Wait for basic modules to load
    waitUntil {!isNil "fnc_startBasicTraining" && !isNil "fnc_startParatrooperTraining"};
    
    diag_log "Training Modules loaded successfully.";
    TRAINING_MODULES_LOADED = true;
};

// Initialize unit data monitoring
[] call fnc_initUnitDataMonitoring;

// Integration with existing research system (if available)
if (!isNil "MISSION_completedResearch") then {
    diag_log "Integrating Unit Management with Research System...";
    
    // Add research definitions if not already present
    if (isNil "MISSION_researchTree") then {
        MISSION_researchTree = [];
    };
    
    // Check if training research is already defined
    private _basicTrainingResearchDefined = false;
    private _paratrooperResearchDefined = false;
    private _commandoResearchDefined = false;
    private _officerResearchDefined = false;
    private _specialResearchDefined = false;
    
    {
        private _researchId = _x select 0;
        switch (_researchId) do {
            case "basic_training_doctrine": { _basicTrainingResearchDefined = true; };
            case "paratrooper_doctrine": { _paratrooperResearchDefined = true; };
            case "commando_training": { _commandoResearchDefined = true; };
            case "officer_academy": { _officerResearchDefined = true; };
            case "special_operations": { _specialResearchDefined = true; };
        };
    } forEach MISSION_researchTree;
    
    // Add training research if not already defined
    if (!_basicTrainingResearchDefined) then {
        MISSION_researchTree pushBack [
            "basic_training_doctrine",
            "Basic Training Doctrine",
            "Military Doctrine",
            "\a3\ui_f\data\gui\rsc\rscdisplaymain\hover_ca.paa",
            "Standardized training program for all recruits, improving combat effectiveness.",
            100, // Research cost
            120, // Research time
            [], // No prerequisites
            "technology", // Type
            "MISSION_basicTrainingDoctrine", // Effect variable
            [], // No resources
            0, // No construction time
            0 // No quantity
        ];
    };
    
    if (!_paratrooperResearchDefined) then {
        MISSION_researchTree pushBack [
            "paratrooper_doctrine",
            "Paratrooper Doctrine",
            "Military Doctrine",
            "\a3\ui_f\data\gui\rsc\rscdisplaymain\hover_ca.paa",
            "Airborne infantry training allowing troops to be dropped behind enemy lines.",
            150, // Research cost
            180, // Research time
            ["basic_training_doctrine"], // Requires basic training
            "technology", // Type
            "MISSION_paratrooperDoctrine", // Effect variable
            [], // No resources
            0, // No construction time
            0 // No quantity
        ];
    };
    
    if (!_commandoResearchDefined) then {
        MISSION_researchTree pushBack [
            "commando_training",
            "Commando Training",
            "Military Doctrine",
            "\a3\ui_f\data\gui\rsc\rscdisplaymain\hover_ca.paa",
            "Special forces training for elite troops, focusing on stealth and sabotage.",
            200, // Research cost
            240, // Research time
            ["basic_training_doctrine"], // Requires basic training
            "technology", // Type
            "MISSION_commandoTraining", // Effect variable
            [], // No resources
            0, // No construction time
            0 // No quantity
        ];
    };
    
    if (!_officerResearchDefined) then {
        MISSION_researchTree pushBack [
            "officer_academy",
            "Officer Academy",
            "Military Doctrine",
            "\a3\ui_f\data\gui\rsc\rscdisplaymain\hover_ca.paa",
            "Leadership training program to develop commanding officers.",
            180, // Research cost
            200, // Research time
            ["basic_training_doctrine"], // Requires basic training
            "technology", // Type
            "MISSION_officerAcademy", // Effect variable
            [], // No resources
            0, // No construction time
            0 // No quantity
        ];
    };
    
    if (!_specialResearchDefined) then {
        MISSION_researchTree pushBack [
            "special_operations",
            "Special Operations",
            "Military Doctrine",
            "\a3\ui_f\data\gui\rsc\rscdisplaymain\hover_ca.paa",
            "Advanced specialized training for battlefield capabilities.",
            250, // Research cost
            300, // Research time
            ["commando_training", "officer_academy"], // Requires commando training and officer academy
            "technology", // Type
            "MISSION_specialOperations", // Effect variable
            [], // No resources
            0, // No construction time
            0 // No quantity
        ];
    };
    
    diag_log "Unit Management integrated with Research System.";
};

// Signal that the unit management system is ready
missionNamespace setVariable ["UNIT_MANAGEMENT_READY", true, true];
systemChat "Unit Management System initialized.";

// Return success
true