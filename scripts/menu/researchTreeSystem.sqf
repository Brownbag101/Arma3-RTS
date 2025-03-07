// researchTreeSystem.sqf - Enhanced Research System with Tech Tree
// Extends openSmallArmsResearchUI.sqf with tech tree functionality

// Initialize research points if not already defined
// Uses existing economy resource framework
if (isNil "MISSION_researchPoints") then {
    MISSION_researchPoints = 1000; // Starting research points
};

// Track completed research items
if (isNil "MISSION_completedResearch") then {
    MISSION_completedResearch = [];
};

// Track active research
if (isNil "MISSION_activeResearch") then {
    MISSION_activeResearch = [];
};

// Initialize research tree - this defines the tech tree structure
if (isNil "MISSION_researchTree") then {
    MISSION_researchTree = [
        // Format: [
        //   "tech_id",              // Unique identifier
        //   "Tech Name",            // Display name
        //   "Category",             // Category for tab organization
        //   "path/to/icon.paa",     // Icon path
        //   "Detailed description", // Tooltip
        //   100,                    // Research point cost
        //   300,                    // Research time in seconds
        //   ["prereq1", "prereq2"], // Prerequisites (empty array [] if none)
        //   "constructable" or "technology", // Type
        //   "classname" or "variable_name",  // Effect identifier
        //   [["Resource", amount], ...],     // Resources (if constructable)
        //   60,                      // Construction time (if constructable)
        //   10                       // Quantity (if constructable)
        // ]
        
        // ===== SMALL ARMS =====
        [
            "rifle_basic",
            "Lee-Enfield No.4 Rifle",
            "Small Arms",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\primaryweapon_ca.paa",
            "Standard British infantry rifle with excellent accuracy and reliability.",
            100, // Research cost
            120, // Research time (2 minutes)
            [], // No prerequisites
            "constructable",
            "JMSSA_LeeEnfield_Rifle",
            [["Iron", 50], ["Wood", 30]],
            60, // Construction time
            10  // Quantity (box of 10)
        ],
        [
            "rifle_carbine",
            "Commando Carbine",
            "Small Arms",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\primaryweapon_ca.paa",
            "Shortened version of the Lee-Enfield for jungle and urban combat.",
            150,
            180,
            ["rifle_basic"], // Requires basic rifle research
            "constructable",
            "JMSSA_LeeEnfield_Carbine",
            [["Iron", 60], ["Wood", 20]],
            70,
            10
        ],
        [
            "smg_sten",
            "Sten Gun Mk II",
            "Small Arms",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\primaryweapon_ca.paa",
            "Inexpensive SMG for close quarters combat.",
            120,
            150,
            ["rifle_basic"],
            "constructable",
            "JMSSA_sten_Rifle",
            [["Iron", 80], ["Steel", 20]],
            65,
            10
        ],
        [
            "lmg_bren",
            "Bren Gun",
            "Small Arms",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\primaryweapon_ca.paa",
            "Light machine gun providing squad-level fire support.",
            200,
            240,
            ["rifle_basic"],
            "constructable",
            "fow_w_bren",
            [["Iron", 100], ["Steel", 40], ["Wood", 20]],
            80,
            5
        ],
        [
            "at_piat",
            "PIAT Launcher",
            "Small Arms",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\secondaryweapon_ca.paa",
            "Portable infantry anti-tank weapon.",
            250,
            300,
            ["lmg_bren"],
            "constructable",
            "fow_w_piat",
            [["Iron", 120], ["Steel", 60], ["Explosives", 40]],
            100,
            5
        ],
        
        // ===== VEHICLES =====
        [
            "vehicle_truck",
            "Bedford QL Truck",
            "Vehicles",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\itemacc_ca.paa",
            "Standard British Army truck for troop and supply transport.",
            150,
            180,
            [],
            "constructable",
            "JMSSA_veh_bedfordMW_F",
            [["Iron", 100], ["Steel", 50], ["Rubber", 30]],
            120,
            1
        ],
        [
            "vehicle_recon",
            "Daimler Dingo",
            "Vehicles",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\itemacc_ca.paa",
            "Fast armored car for reconnaissance operations.",
            200,
            240,
            ["vehicle_truck"],
            "constructable",
            "JMSSA_veh_daimlerMK2_F",
            [["Iron", 150], ["Steel", 80], ["Rubber", 40]],
            150,
            1
        ],
        [
            "vehicle_carrier",
            "Universal Carrier",
            "Vehicles",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\itemacc_ca.paa",
            "Light tracked vehicle for infantry transport and support.",
            250,
            300,
            ["vehicle_recon"],
            "constructable",
            "JMSSA_veh_UniversalCarrier_F",
            [["Iron", 180], ["Steel", 100], ["Rubber", 50]],
            180,
            1
        ],
        [
            "vehicle_cromwell",
            "Cromwell Tank",
            "Vehicles",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\itemacc_ca.paa",
            "Fast and reliable cruiser tank with 75mm gun.",
            400,
            480,
            ["vehicle_carrier"],
            "constructable",
            "fow_v_cromwell_uk",
            [["Iron", 300], ["Steel", 200], ["Rubber", 80]],
            300,
            1
        ],
        [
            "vehicle_churchill",
            "Churchill Mk VII",
            "Vehicles",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\itemacc_ca.paa",
            "Heavy infantry tank with excellent cross-country capability.",
            500,
            600,
            ["vehicle_cromwell"],
            "constructable",
            "LIB_Churchill_Mk7",
            [["Iron", 400], ["Steel", 300], ["Rubber", 100]],
            360,
            1
        ],
        
        // ===== AIRCRAFT =====
        [
            "aircraft_auster",
            "Auster AOP",
            "Aircraft",
            "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_sidebar_air_ca.paa",
            "Light aircraft for artillery spotting and reconnaissance.",
            200,
            240,
            [],
            "constructable",
            "LIB_RAF_P39",
            [["Aluminum", 100], ["Steel", 50], ["Rubber", 20]],
            180,
            1
        ],
        [
            "aircraft_spitfire",
            "Spitfire Mk IX",
            "Aircraft",
            "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_sidebar_air_ca.paa",
            "Iconic British fighter aircraft.",
            400,
            480,
            ["aircraft_auster"],
            "constructable",
            "LIB_RAF_P39",
            [["Aluminum", 200], ["Steel", 100], ["Rubber", 40]],
            240,
            1
        ],
        [
            "aircraft_typhoon",
            "Hawker Typhoon",
            "Aircraft",
            "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_sidebar_air_ca.paa",
            "Ground attack aircraft with rockets and heavy cannon.",
            500,
            600,
            ["aircraft_spitfire"],
            "constructable",
            "LIB_RAF_P39",
            [["Aluminum", 250], ["Steel", 150], ["Rubber", 50]],
            300,
            1
        ],
        [
            "aircraft_lancaster",
            "Avro Lancaster",
            "Aircraft",
            "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_sidebar_air_ca.paa",
            "Heavy bomber capable of carrying massive bomb loads.",
            600,
            720,
            ["aircraft_typhoon"],
            "constructable",
            "LIB_C47_RAF",
            [["Aluminum", 400], ["Steel", 200], ["Rubber", 80]],
            360,
            1
        ],
        [
            "aircraft_dakota",
            "C-47 Dakota",
            "Aircraft",
            "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_sidebar_air_ca.paa",
            "Transport aircraft for airborne operations and logistics.",
            450,
            540,
            ["aircraft_lancaster"],
            "constructable",
            "LIB_C47_RAF",
            [["Aluminum", 300], ["Steel", 150], ["Rubber", 70]],
            280,
            1
        ],
        
        // ===== INTELLIGENCE =====
        [
            "intel_observers",
            "Forward Observers",
            "Intelligence",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\binoculars_ca.paa",
            "Trained spotters who improve artillery accuracy and battlefield awareness.",
            150,
            180,
            [],
            "technology",
            "MISSION_forwardObservers",
            [],
            0,
            0
        ],
        [
            "intel_enigma",
            "Enigma Decryption",
            "Intelligence",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\radio_ca.paa",
            "Breaking the German Enigma code to reveal enemy movements and plans.",
            300,
            360,
            ["intel_observers"],
            "technology",
            "MISSION_enigmaDecrypted",
            [],
            0,
            0
        ],
        [
            "intel_radar",
            "Chain Home Radar",
            "Intelligence",
            "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\radar_ca.paa",
            "Radar network providing early warning of enemy air attacks.",
            400,
            480,
            ["intel_enigma"],
            "technology",
            "MISSION_radarResearched",
            [],
            0,
            0
        ],
        [
            "intel_h2s",
            "H2S Radar",
            "Intelligence",
            "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\radar_ca.paa",
            "Advanced radar system allowing bombing through cloud cover.",
            500,
            600,
            ["intel_radar"],
            "technology",
            "MISSION_h2sRadar",
            [],
            0,
            0
        ],
        [
            "intel_ultra",
            "Ultra Intelligence",
            "Intelligence",
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\face_ca.paa",
            "Complete integration of all intelligence sources for total battlefield awareness.",
            600,
            720,
            ["intel_h2s"],
            "technology",
            "MISSION_ultraIntelligence",
            [],
            0,
            0
        ]
    ];
};

// Function to check if a technology is available for research
fnc_isTechAvailable = {
    params ["_techId"];
    
    // Get technology data
    private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
    if (_techIndex == -1) exitWith {false};
    
    private _techData = MISSION_researchTree select _techIndex;
    private _prerequisites = _techData select 7;
    
    // Check if already researched
    if (_techId in MISSION_completedResearch) exitWith {false};
    
    // Check if already being researched
    if (count MISSION_activeResearch > 0) then {
        if ((MISSION_activeResearch select 0) == _techId) exitWith {false};
    };
    
    // Check all prerequisites
    private _allPrereqsMet = true;
    {
        if !(_x in MISSION_completedResearch) then {
            _allPrereqsMet = false;
        };
    } forEach _prerequisites;
    
    _allPrereqsMet
};

// Function to get all available technologies
fnc_getAvailableTechs = {
    private _availableTechs = [];
    
    {
        private _techId = _x select 0;
        if ([_techId] call fnc_isTechAvailable) then {
            _availableTechs pushBack _techId;
        };
    } forEach MISSION_researchTree;
    
    _availableTechs
};

// Function to start researching a technology
fnc_startResearchOnTech = {
    params ["_techId"];
    
    // Check if technology is available
    if !([_techId] call fnc_isTechAvailable) exitWith {
        hint "This technology is not available for research yet.";
        false
    };
    
    // Get technology data
    private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
    private _techData = MISSION_researchTree select _techIndex;
    
    _techData params ["", "_name", "", "", "", "_cost", "_time"];
    
    // Check if we have enough research points
    if (MISSION_researchPoints < _cost) exitWith {
        hint format ["Not enough research points. Need %1, have %2.", _cost, MISSION_researchPoints];
        false
    };
    
    // Deduct research points
    MISSION_researchPoints = MISSION_researchPoints - _cost;
    
    // Set as active research
    MISSION_activeResearch = [_techId, time, time + _time];
    
    hint format ["Started researching %1. Completion in %2 minutes.", _name, (_time / 60) toFixed 1];
    true
};

// Function to complete research
fnc_completeResearch = {
    params ["_techId"];
    
    // Get technology data
    private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
    if (_techIndex == -1) exitWith {false};
    
    private _techData = MISSION_researchTree select _techIndex;
    
    _techData params ["", "_name", "", "", "", "", "", "", "_type", "_effect"];
    
    // Mark as completed
    MISSION_completedResearch pushBack _techId;
    
    // Clear active research
    MISSION_activeResearch = [];
    
    // Apply effects based on type
    if (_type == "constructable") then {
        // Add to construction options
        [_techData] call fnc_addConstructionOption;
        hint format ["Research completed: %1. Item added to construction options.", _name];
    } else {
        // Set technology variable
        missionNamespace setVariable [_effect, true, true];
        hint format ["Research completed: %1. New capabilities unlocked.", _name];
    };
    
    true
};

// Function to add item to construction options
fnc_addConstructionOption = {
    params ["_techData"];
    
    _techData params ["_techId", "_name", "_category", "", "", "", "", "", "", "_className", "_resources", "_constructionTime", "_quantity"];
    
    // Initialize construction options if needed
    if (isNil "MISSION_constructionOptions") then {
        MISSION_constructionOptions = [];
    };
    
    // Check if item already exists in construction options
    private _existingIndex = MISSION_constructionOptions findIf {(_x select 0) == _className};
    
    if (_existingIndex != -1) then {
        // Update existing entry
        MISSION_constructionOptions set [_existingIndex, [_className, _name, _category, _quantity, _resources, _constructionTime]];
    } else {
        // Add new entry
        MISSION_constructionOptions pushBack [_className, _name, _category, _quantity, _resources, _constructionTime];
    };
};

// Function to check research progress
fnc_checkResearchProgress = {
    if (count MISSION_activeResearch == 0) exitWith {};
    
    MISSION_activeResearch params ["_techId", "_startTime", "_endTime"];
    private _currentTime = time;
    
    if (_currentTime >= _endTime) then {
        [_techId] call fnc_completeResearch;
    };
};

// This is a replacement for the original openSmallArmsResearchUI function
// that maintains compatibility but adds tech tree functionality
fnc_openResearchUI = {
    if (dialog) then {closeDialog 0;};
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    
    if (isNull _display) exitWith {
        diag_log "Failed to create Research UI";
        hint "Failed to create research UI. Please try again.";
    };
    
    // Create background - use the same style as original
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.7 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;

    // Create title
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetText "Research & Development";
    _title ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _title ctrlCommit 0;

    // Create Research Points display
    private _pointsText = _display ctrlCreate ["RscText", 1001];
    _pointsText ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.21 * safezoneH + safezoneY, 0.3 * safezoneW, 0.04 * safezoneH];
    _pointsText ctrlSetText format ["Research Points: %1", MISSION_researchPoints];
    _pointsText ctrlCommit 0;
    
    // Create active research display
    private _activeText = _display ctrlCreate ["RscText", 1002];
    _activeText ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.21 * safezoneH + safezoneY, 0.25 * safezoneW, 0.04 * safezoneH];
    
    if (count MISSION_activeResearch > 0) then {
        MISSION_activeResearch params ["_techId", "_startTime", "_endTime"];
        private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
        private _techName = (MISSION_researchTree select _techIndex) select 1;
        private _remaining = _endTime - time;
        _activeText ctrlSetText format ["Researching: %1 (%2s)", _techName, floor _remaining];
    } else {
        _activeText ctrlSetText "No active research";
    };
    
    _activeText ctrlCommit 0;
    
    // Create category tabs
    private _categories = [];
    {
        private _category = _x select 2;
        if !(_category in _categories) then {
            _categories pushBack _category;
        };
    } forEach MISSION_researchTree;
    
    for "_i" from 0 to (count _categories - 1) do {
        private _category = _categories select _i;
        private _tabButton = _display ctrlCreate ["RscButton", 1100 + _i];
        _tabButton ctrlSetPosition [
            (0.22 + (_i * 0.12)) * safezoneW + safezoneX,
            0.26 * safezoneH + safezoneY,
            0.11 * safezoneW,
            0.04 * safezoneH
        ];
        _tabButton ctrlSetText _category;
        _tabButton setVariable ["category", _category];
        _tabButton ctrlSetEventHandler ["ButtonClick", "params ['_ctrl']; [_ctrl getVariable 'category'] call fnc_switchResearchTab"];
        _tabButton ctrlCommit 0;
    };
    
    // Create research list area
    private _researchArea = _display ctrlCreate ["RscListBox", 1200];
    _researchArea ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.36 * safezoneW, 0.45 * safezoneH];
    _researchArea ctrlCommit 0;
    
    // Create details panel
    private _detailsPanel = _display ctrlCreate ["RscStructuredText", 1300];
    _detailsPanel ctrlSetPosition [0.59 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.19 * safezoneW, 0.35 * safezoneH];
    _detailsPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
    _detailsPanel ctrlCommit 0;
    
    // Create research button
    private _researchButton = _display ctrlCreate ["RscButton", 1400];
    _researchButton ctrlSetPosition [0.59 * safezoneW + safezoneX, 0.67 * safezoneH + safezoneY, 0.19 * safezoneW, 0.05 * safezoneH];
    _researchButton ctrlSetText "Start Research";
    _researchButton ctrlEnable false;
    _researchButton ctrlSetBackgroundColor [0.2, 0.4, 0.2, 1];
    _researchButton ctrlSetEventHandler ["ButtonClick", "[] call fnc_startSelectedResearch"];
    _researchButton ctrlCommit 0;
    
    // Create close button
    private _closeButton = _display ctrlCreate ["RscButton", 1500];
    _closeButton ctrlSetPosition [0.7 * safezoneW + safezoneX, 0.77 * safezoneH + safezoneY, 0.08 * safezoneW, 0.04 * safezoneH];
    _closeButton ctrlSetText "Close";
    _closeButton ctrlSetEventHandler ["ButtonClick", "closeDialog 0"];
    _closeButton ctrlCommit 0;
    
    // Set event handlers
    _researchArea ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        [_control, _selectedIndex] call fnc_updateDetailsPanel;
    }];
    
    // Add handler for dialog closure
    _display displayAddEventHandler ["Unload", {
        // Any cleanup needed here
    }];
    
    // Switch to first tab
    if (count _categories > 0) then {
        [_categories select 0] call fnc_switchResearchTab;
    };
    
    // Start UI update loop
    [] spawn {
        while {!isNull findDisplay -1} do {
            private _display = findDisplay -1;
            
            // Update active research text
            private _activeText = _display displayCtrl 1002;
            if (count MISSION_activeResearch > 0) then {
                MISSION_activeResearch params ["_techId", "_startTime", "_endTime"];
                private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
                private _techName = (MISSION_researchTree select _techIndex) select 1;
                private _remaining = _endTime - time;
                _activeText ctrlSetText format ["Researching: %1 (%2s)", _techName, floor _remaining];
            } else {
                _activeText ctrlSetText "No active research";
            };
            
            // Check research progress
            call fnc_checkResearchProgress;
            
            sleep 0.5;
        };
    };
};

// Function to switch research tab
fnc_switchResearchTab = {
    params ["_category"];
    
    private _display = findDisplay -1;
    
    // Update tab button visuals
    for "_i" from 0 to 10 do {
        private _tabButton = _display displayCtrl (1100 + _i);
        if (!isNull _tabButton) then {
            if ((_tabButton getVariable ["category", ""]) == _category) then {
                _tabButton ctrlSetBackgroundColor [0.3, 0.3, 0.8, 1];
            } else {
                _tabButton ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
            };
        };
    };
    
    // Store current category
    _display setVariable ["currentCategory", _category];
    
    // Update research list
    [_category] call fnc_updateResearchList;
};

// Function to update research list for a category
fnc_updateResearchList = {
    params ["_category"];
    
    private _display = findDisplay -1;
    private _researchArea = _display displayCtrl 1200;
    
    // Clear current list
    lbClear _researchArea;
    
    // Filter technologies by category
    private _categoryTechs = MISSION_researchTree select {(_x select 2) == _category};
    
    // Add each technology to the list
    {
        // Safely extract tech ID and name with error checking
        private _techId = _x select 0;
        private _name = _x select 1;
        
        if (isNil "_techId") then { _techId = "unknown"; };
        if (isNil "_name") then { _name = "Unknown Technology"; };
        
        // Determine status indicator
        private _status = "";
        if (_techId in MISSION_completedResearch) then {
            _status = "✓"; // Completed
        } else {
            if (count MISSION_activeResearch > 0 && (MISSION_activeResearch select 0) == _techId) then {
                _status = "⟳"; // In progress
            } else {
                if ([_techId] call fnc_isTechAvailable) then {
                    _status = "◯"; // Available
                } else {
                    _status = "✗"; // Not available
                };
            };
        };
        
        // Add to list with status
        private _index = _researchArea lbAdd format ["%1 %2", _status, _name];
        _researchArea lbSetData [_index, _techId];
        
        // Set text color based on status
        private _color = [1, 1, 1, 1]; // Default white
        switch (_status) do {
            case "✓": { _color = [0.4, 0.8, 0.4, 1]; }; // Green for completed
            case "⟳": { _color = [0.8, 0.8, 0.2, 1]; }; // Yellow for in progress
            case "◯": { _color = [1, 1, 1, 1]; };       // White for available
            case "✗": { _color = [0.5, 0.5, 0.5, 1]; }; // Gray for unavailable
        };
        
        _researchArea lbSetColor [_index, _color];
    } forEach _categoryTechs;
    
    // Select first item by default
    if (lbSize _researchArea > 0) then {
        _researchArea lbSetCurSel 0;
    };
};

// Function to update details panel
fnc_updateDetailsPanel = {
    params ["_control", "_selectedIndex"];
    
    if (_selectedIndex < 0) exitWith {};
    
    private _techId = _control lbData _selectedIndex;
    private _display = ctrlParent _control;
    private _detailsPanel = _display displayCtrl 1300;
    private _researchButton = _display displayCtrl 1400;
    
    // Get technology data
    private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
    if (_techIndex == -1) exitWith {};
    
    private _techData = MISSION_researchTree select _techIndex;
    
    // Safely extract parameters with default values
    private _name = _techData param [1, "Unknown"];
    private _category = _techData param [2, "Misc"];
    private _iconPath = _techData param [3, ""];
    private _description = _techData param [4, "No description available."];
    private _cost = _techData param [5, 100];
    private _time = _techData param [6, 60];
    private _prerequisites = _techData param [7, []];
    private _type = _techData param [8, "technology"];
    private _effect = _techData param [9, ""];
    private _resources = _techData param [10, []];
    private _constructionTime = _techData param [11, 30];
    private _quantity = _techData param [12, 0];
    
    // Format prerequisites text
    private _prereqsText = "";
    if (count _prerequisites > 0) then {
        private _prereqNames = [];
        {
            private _prereqId = _x;
            private _prereqIndex = MISSION_researchTree findIf {(_x select 0) == _prereqId};
            if (_prereqIndex != -1) then {
                private _prereqName = (MISSION_researchTree select _prereqIndex) select 1;
                if (!isNil "_prereqName") then {
                    _prereqNames pushBack _prereqName;
                };
            };
        } forEach _prerequisites;
        
        if (count _prereqNames > 0) then {
            _prereqsText = "Prerequisites: " + (_prereqNames joinString ", ");
        } else {
            _prereqsText = "Prerequisites: Unknown";
        }
    } else {
        _prereqsText = "No prerequisites";
    };
    
    // Format effect text
    private _effectText = if (_type == "constructable") then {
        format ["Unlocks construction of %1", _name];
    } else {
        "Unlocks new capabilities";
    };
    
    // Format details string
    private _detailsString = format [
        "<t size='1.2' align='center'>%1</t><br/><br/>" +
        "<t size='1.0'>%2</t><br/><br/>" +
        "<t color='#ADD8E6'>Research Cost: %3 points</t><br/>" +
        "<t color='#ADD8E6'>Research Time: %4 min</t><br/><br/>" +
        "<t color='#AAAAAA'>%5</t><br/><br/>" +
        "<t color='#90EE90'>%6</t>",
        _name,
        _description,
        _cost,
        (_time / 60) toFixed 1,
        _prereqsText,
        _effectText
    ];
    
    // Add construction details if applicable
    if (_type == "constructable") then {
        private _materialsText = "";
        {
            _x params ["_resourceName", "_amount"];
            _materialsText = _materialsText + format ["<br/>- %1: %2", _resourceName, _amount];
        } forEach _resources;
        
        _detailsString = _detailsString + format [
            "<br/><br/><t color='#FFD700'>Construction:</t>" +
            "<t color='#CCCCCC'>%1</t><br/>" +
            "<t color='#CCCCCC'>Time: %2 min</t>",
            _materialsText,
            (_constructionTime / 60) toFixed 1
        ];
    };
    
    _detailsPanel ctrlSetStructuredText parseText _detailsString;
    
    // Enable/disable research button based on availability
    _researchButton ctrlEnable ([_techId] call fnc_isTechAvailable && MISSION_researchPoints >= _cost);
};

// Function to start research on selected technology
fnc_startSelectedResearch = {
    private _display = findDisplay -1;
    private _researchArea = _display displayCtrl 1200;
    private _selectedIndex = lbCurSel _researchArea;
    
    if (_selectedIndex < 0) exitWith {
        hint "No technology selected.";
    };
    
    private _techId = _researchArea lbData _selectedIndex;
    [_techId] call fnc_startResearchOnTech;
};

// Start background process to update research points
[] spawn {
    while {true} do {
        // Check research progress
        call fnc_checkResearchProgress;
        
        sleep 1;
    };
};

// Register function with existing menu button
if (!isNil "RTS_menuButtons") then {
    // Find research button in the menu
    private _index = RTS_menuButtons findIf {(_x select 0) == "research"};
    
    if (_index != -1) then {
        // Update button click handler in the switch statement
        // Note: This needs to be properly integrated with your menuSystem.sqf
        systemChat "Research tree system integrated with menu button.";
    } else {
        systemChat "Warning: Could not find research button in RTS_menuButtons.";
    };
};

// Return true when script is loaded
true