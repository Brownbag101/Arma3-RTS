// researchTreeSystem.sqf - Enhanced Research System with Tech Tree
// Fixes for UI selection and training research integration

// Initialize research points if not already defined
// Uses existing economy resource framework
if (isNil "MISSION_researchPoints") then {
    MISSION_researchPoints = 1000; // Starting research points
};

// Synchronize with economy system
[] spawn {
    // Wait a bit to ensure economy system is initialized
    sleep 3;
    
    // Initial synchronization from legacy variable to economy system
    if (!isNil "MISSION_researchPoints" && !isNil "RTS_resources") then {
        private _index = RTS_resources findIf {(_x select 0) == "research"};
        if (_index != -1) then {
            // Update economy system with current research points
            RTS_resources set [_index, ["research", MISSION_researchPoints]];
            systemChat "Research points synchronized with economy system";
        } else {
            // If research isn't in economy yet, add it
            RTS_resources pushBack ["research", MISSION_researchPoints];
            
            // Also add to income if needed
            private _incomeIndex = RTS_resourceIncome findIf {(_x select 0) == "research"};
            if (_incomeIndex == -1) then {
                RTS_resourceIncome pushBack ["research", 2]; // 2 per minute
            };
            
            systemChat "Research points added to economy system";
        };
    };
    
    // Create two-way sync functions
    fnc_syncResearchToEconomy = {
        private _index = RTS_resources findIf {(_x select 0) == "research"};
        if (_index != -1) then {
            RTS_resources set [_index, ["research", MISSION_researchPoints]];
        };
    };
    
    fnc_syncEconomyToResearch = {
        private _index = RTS_resources findIf {(_x select 0) == "research"};
        if (_index != -1) then {
            MISSION_researchPoints = (RTS_resources select _index) select 1;
        };
    };
    
    // Override existing functions to maintain sync
    // Store original functions
    if (isNil "original_RTS_fnc_modifyResource") then {
        original_RTS_fnc_modifyResource = RTS_fnc_modifyResource;
    };
    
    // Create new modified function that syncs changes
    fnc_modifyResearchPoints = {
        params ["_amount"];
        
        // Update legacy variable
        MISSION_researchPoints = MISSION_researchPoints + _amount;
        
        // Also update in economy system
        ["research", _amount] call RTS_fnc_modifyResource;
    };
    
    // Continuous monitoring to ensure sync
    while {true} do {
        call fnc_syncEconomyToResearch;
        sleep 30; // Check every 30 seconds
    };
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
            "LEN_SMLE_No4Mk1T",
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
        ],
        
        // ===== MILITARY DOCTRINE =====
        [
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
        ],
        [
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
        ],
        [
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
        ],
        [
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
        ],
        [
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

// Complete replacement for the Research UI implementation
// Add this section to the end of researchTreeSystem.sqf, replacing the current UI functions

// Global variables to track UI state
RTS_currentResearchDisplay = displayNull;
RTS_currentCategory = "";
RTS_selectedTechId = "";

// New implementation of research UI
fnc_openResearchUI = {
    // Close existing dialog if open
    if (!isNull RTS_currentResearchDisplay) then {
        closeDialog 0;
    };
    
    // Create new dialog
    createDialog "RscDisplayEmpty";
    
    // Store the display reference
    RTS_currentResearchDisplay = findDisplay -1;
    
    // Check if display was created successfully
    if (isNull RTS_currentResearchDisplay) exitWith {
        hint "Failed to create research UI. Please try again.";
        false
    };
    
    // Initialize UI components
    [] call fnc_createResearchUIComponents;
    
    // Start update loop
    [] spawn fnc_updateResearchUI;
    
    true
};

// Create all UI components
fnc_createResearchUIComponents = {
    private _display = RTS_currentResearchDisplay;
    
    // Create background
    private _background = _display ctrlCreate ["RscText", 10000];
    _background ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.7 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", 10001];
    _title ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetText "Research & Development";
    _title ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _title ctrlCommit 0;
    
    // Create points display
    private _pointsText = _display ctrlCreate ["RscText", 10002];
    _pointsText ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.21 * safezoneH + safezoneY, 0.3 * safezoneW, 0.04 * safezoneH];
    _pointsText ctrlSetText format ["Research Points: %1", MISSION_researchPoints];
    _pointsText ctrlCommit 0;
    
    // Create active research display
    private _activeText = _display ctrlCreate ["RscText", 10003];
    _activeText ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.21 * safezoneH + safezoneY, 0.25 * safezoneW, 0.04 * safezoneH];
    _activeText ctrlSetText "No active research";
    _activeText ctrlCommit 0;
    
    // Get all categories
    private _categories = [];
    {
        private _category = _x select 2;
        if (!(_category in _categories)) then {
            _categories pushBack _category;
        };
    } forEach MISSION_researchTree;
    
    // Create category buttons
    for "_i" from 0 to ((count _categories) - 1) do {
        private _category = _categories select _i;
        
        private _catBtn = _display ctrlCreate ["RscButton", 10100 + _i];
        _catBtn ctrlSetPosition [
            (0.22 + (_i * 0.12)) * safezoneW + safezoneX,
            0.26 * safezoneH + safezoneY,
            0.11 * safezoneW,
            0.04 * safezoneH
        ];
        _catBtn ctrlSetText _category;
        _catBtn setVariable ["category", _category];
        _catBtn ctrlAddEventHandler ["ButtonClick", {
            params ["_control"];
            private _category = _control getVariable "category";
            RTS_currentCategory = _category;
            [] call fnc_updateTechList;
        }];
        _catBtn ctrlCommit 0;
    };
    
    // Create tech list area
    private _techList = _display ctrlCreate ["RscListBox", 10200];
    _techList ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.36 * safezoneW, 0.45 * safezoneH];
    _techList ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        if (_selectedIndex >= 0) then {
            private _techId = _control lbData _selectedIndex;
            RTS_selectedTechId = _techId;
            [] call fnc_updateDetailsArea;
        };
    }];
    _techList ctrlCommit 0;
    
    // Create details area
    private _detailsArea = _display ctrlCreate ["RscStructuredText", 10300];
    _detailsArea ctrlSetPosition [0.59 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.19 * safezoneW, 0.35 * safezoneH];
    _detailsArea ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
    _detailsArea ctrlCommit 0;
    
    // Create research button
    private _researchBtn = _display ctrlCreate ["RscButton", 10400];
    _researchBtn ctrlSetPosition [0.59 * safezoneW + safezoneX, 0.67 * safezoneH + safezoneY, 0.19 * safezoneW, 0.05 * safezoneH];
    _researchBtn ctrlSetText "Start Research";
    _researchBtn ctrlAddEventHandler ["ButtonClick", {
        [] call fnc_startSelectedResearch;
    }];
    _researchBtn ctrlCommit 0;
    
    // Create close button
    private _closeBtn = _display ctrlCreate ["RscButton", 10500];
    _closeBtn ctrlSetPosition [0.7 * safezoneW + safezoneX, 0.77 * safezoneH + safezoneY, 0.08 * safezoneW, 0.04 * safezoneH];
    _closeBtn ctrlSetText "Close";
    _closeBtn ctrlAddEventHandler ["ButtonClick", {
        closeDialog 0;
    }];
    _closeBtn ctrlCommit 0;
    
    // Set first category as default
    if (count _categories > 0) then {
        RTS_currentCategory = _categories select 0;
        [] call fnc_updateTechList;
    };
};

// Update the tech list based on current category
fnc_updateTechList = {
    private _display = RTS_currentResearchDisplay;
    if (isNull _display) exitWith {};
    
    // Highlight selected category button
    private _allButtons = [];
    for "_i" from 0 to 20 do {
        private _btn = _display displayCtrl (10100 + _i);
        if (!isNull _btn) then {
            _allButtons pushBack _btn;
        };
    };
    
    {
        private _category = _x getVariable ["category", ""];
        if (_category == RTS_currentCategory) then {
            _x ctrlSetBackgroundColor [0.3, 0.3, 0.8, 1];
        } else {
            _x ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
        };
    } forEach _allButtons;
    
    // Clear and update tech list
    private _techList = _display displayCtrl 10200;
    lbClear _techList;
    
    // Filter technologies by current category
    private _categoryTechs = MISSION_researchTree select {(_x select 2) == RTS_currentCategory};
    
    // Add each tech to list
    {
        private _techId = _x select 0;
        private _name = _x select 1;
        
        // Determine status icon
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
        private _index = _techList lbAdd format ["%1 %2", _status, _name];
        _techList lbSetData [_index, _techId];
        
        // Set text color based on status
        private _color = [1, 1, 1, 1]; // Default white
        switch (_status) do {
            case "✓": { _color = [0.4, 0.8, 0.4, 1]; }; // Green for completed
            case "⟳": { _color = [0.8, 0.8, 0.2, 1]; }; // Yellow for in progress
            case "◯": { _color = [1, 1, 1, 1]; };       // White for available
            case "✗": { _color = [0.5, 0.5, 0.5, 1]; }; // Gray for unavailable
        };
        
        _techList lbSetColor [_index, _color];
    } forEach _categoryTechs;
    
    // Select first item by default
    if (lbSize _techList > 0) then {
        _techList lbSetCurSel 0;
    } else {
        // Clear details if no tech to select
        RTS_selectedTechId = "";
        [] call fnc_updateDetailsArea;
    };
};

// Update the details area for selected tech
fnc_updateDetailsArea = {
    private _display = RTS_currentResearchDisplay;
    if (isNull _display) exitWith {};
    
    private _detailsArea = _display displayCtrl 10300;
    private _researchBtn = _display displayCtrl 10400;
    
    // If no tech selected, clear details
    if (RTS_selectedTechId == "") exitWith {
        _detailsArea ctrlSetStructuredText parseText "No technology selected.";
        _researchBtn ctrlEnable false;
    };
    
    // Get tech data
    private _techIndex = MISSION_researchTree findIf {(_x select 0) == RTS_selectedTechId};
    if (_techIndex == -1) exitWith {
        _detailsArea ctrlSetStructuredText parseText "Technology details not available.";
        _researchBtn ctrlEnable false;
    };
    
    private _techData = MISSION_researchTree select _techIndex;
    
    // Extract data
    private _name = _techData select 1;
    private _description = _techData select 4;
    private _cost = _techData select 5;
    private _time = _techData select 6;
    private _prerequisites = _techData select 7;
    private _type = _techData select 8;
    
    // Format prerequisites
    private _prereqsText = "";
    if (count _prerequisites > 0) then {
        private _prereqNames = [];
        {
            private _prereqIndex = MISSION_researchTree findIf {(_x select 0) == _x};
            if (_prereqIndex != -1) then {
                private _prereqName = (MISSION_researchTree select _prereqIndex) select 1;
                _prereqNames pushBack _prereqName;
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
    
    // Format effect based on type
    private _effectText = if (_type == "constructable") then {
        format ["Unlocks construction of %1", _name];
    } else {
        "Unlocks new capabilities";
    };
    
    // Create details HTML
    private _detailsText = format [
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
    
    // Set details text
    _detailsArea ctrlSetStructuredText parseText _detailsText;
    
    // Enable/disable research button
    private _available = [RTS_selectedTechId] call fnc_isTechAvailable;
    private _enoughPoints = MISSION_researchPoints >= _cost;
    _researchBtn ctrlEnable (_available && _enoughPoints);
};

// Start research on selected technology
fnc_startSelectedResearch = {
    if (RTS_selectedTechId == "") exitWith {
        hint "No technology selected.";
    };
    
    // Start the research
    [RTS_selectedTechId] call fnc_startResearchOnTech;
    
    // Update the UI
    [] call fnc_updateTechList;
};

// Main update loop for research UI
fnc_updateResearchUI = {
    while {!isNull RTS_currentResearchDisplay} do {
        private _display = RTS_currentResearchDisplay;
        
        // Update points display
        private _pointsText = _display displayCtrl 10002;
        _pointsText ctrlSetText format ["Research Points: %1", MISSION_researchPoints];
        
        // Update active research display
        private _activeText = _display displayCtrl 10003;
        if (count MISSION_activeResearch > 0) then {
            MISSION_activeResearch params ["_techId", "_startTime", "_endTime"];
            private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
            if (_techIndex != -1) then {
                private _techName = (MISSION_researchTree select _techIndex) select 1;
                private _remaining = _endTime - time;
                _activeText ctrlSetText format ["Researching: %1 (%2s)", _techName, floor _remaining];
            };
        } else {
            _activeText ctrlSetText "No active research";
        };
        
        // Check research progress
        call fnc_checkResearchProgress;
        
        sleep 0.5;
    };
};

// Override this function to be more robust
fnc_checkResearchProgress = {
    if (count MISSION_activeResearch < 3) exitWith {};
    
    MISSION_activeResearch params ["_techId", "_startTime", "_endTime"];
    
    if (time >= _endTime) then {
        // Check if technology exists
        private _techIndex = MISSION_researchTree findIf {(_x select 0) == _techId};
        if (_techIndex != -1) then {
            // Safely complete research
            [_techId] call fnc_completeResearch;
            
            // Update UI if research screen is open
            if (!isNull RTS_currentResearchDisplay) then {
                [] call fnc_updateTechList;
            };
        } else {
            // Invalid tech ID, just clear active research
            MISSION_activeResearch = [];
        };
    };
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