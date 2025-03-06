// Action Registry
// Defines all available actions and maps them to unit types

// Helper function to get action definition by ID
fnc_getActionById = {
    params ["_actionId"];
    private _index = RTSUI_actionDatabase findIf {(_x select 0) == _actionId};
    if (_index == -1) exitWith {[]};
    RTSUI_actionDatabase select _index
};

// Database of all actions - common structure:
// [
//     "actionId",               // Unique ID
//     "displayName",            // Name for display
//     "iconPath",               // Path to icon
//     "tooltip",                // Tooltip text
//     "scriptPath",             // Path to script
//     ["applicableTypes"]       // Array of applicable entity types
// ]

RTSUI_actionDatabase = [
    // === STANCE ACTIONS ===
    [
        "stance_stand",
        "Stand",
        "\A3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\SI_stand_ca.paa",
        "Set Standing Stance",
        "scripts\actions\unitActions\stance\setStandingStance.sqf",
        ["MAN"]
    ],
    [
        "stance_crouch",
        "Crouch",
        "\A3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\SI_crouch_ca.paa",
        "Set Crouching Stance",
        "scripts\actions\unitActions\stance\setCrouchStance.sqf",
        ["MAN"]
    ],
    [
        "stance_prone",
        "Prone",
        "\A3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\SI_prone_ca.paa",
        "Set Prone Stance",
        "scripts\actions\unitActions\stance\setProneStance.sqf",
        ["MAN"]
    ],
    [
        "unit_leavegroup",
        "Leave Group",
        "a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_toolbox_units_ca.paa",
        "Leave Current Group",
        "scripts\actions\unitActions\group\leaveGroup.sqf",
        ["MAN"]
    ],
    [
        "unit_joingroup",
        "Join Nearest Group",
        "a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_toolbox_groups_ca.paa",
        "Join Nearest Group",
        "scripts\actions\unitActions\group\joinNearestGroup.sqf",
        ["MAN"]
    ],

    
    // === SQUAD STANCE ACTIONS ===
    [
        "squad_stance_stand",
        "Squad Stand",
        "\A3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\SI_stand_ca.paa",
        "Set All Units Standing",
        "scripts\actions\squadActions\setSquadStandingStance.sqf",
        ["SQUAD"]
    ],
    [
        "squad_stance_crouch",
        "Squad Crouch",
        "\A3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\SI_crouch_ca.paa",
        "Set All Units Crouching",
        "scripts\actions\squadActions\setSquadCrouchStance.sqf",
        ["SQUAD"]
    ],
    [
        "squad_stance_prone",
        "Squad Prone",
        "\A3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\SI_prone_ca.paa",
        "Set All Units Prone",
        "scripts\actions\squadActions\setSquadProneStance.sqf",
        ["SQUAD"]
    ],
    
    // === COMBAT MODE ACTIONS ===
    [
        "combat_holdfire",
        "Hold Fire",
        "a3\ui_f\data\igui\cfg\commandbar\combatmode_texturemstealth_ca.paa",
        "Hold Fire",
        "scripts\actions\unitActions\combat\holdFire.sqf",
        ["MAN"]
    ],
    [
        "combat_fireatill",
        "Fire At Will",
        "a3\ui_f\data\igui\cfg\commandbar\combatmode_texturemcombat_ca.paa",
        "Fire At Will",
        "scripts\actions\unitActions\combat\fireAtWill.sqf",
        ["MAN"]
    ],
    [
        "combat_engage",
        "Engage Target",
        "a3\structures_f_bootcamp\vr\helpers\data\vr_symbol_balistics_ca.paa",
        "Engage Current Target",
        "scripts\actions\unitActions\combat\engageTarget.sqf",
        ["MAN"]
    ],
    
    // === SQUAD COMBAT MODE ACTIONS ===
    [
        "squad_combat_holdfire",
        "Squad Hold Fire",
        "a3\ui_f\data\igui\cfg\commandbar\combatmode_texturemstealth_ca.paa",
        "All Units Hold Fire",
        "scripts\actions\squadActions\squadHoldFire.sqf",
        ["SQUAD"]
    ],
    [
        "squad_combat_fireatill",
        "Squad Fire At Will",
        "a3\ui_f\data\igui\cfg\commandbar\combatmode_texturemcombat_ca.paa",
        "All Units Fire At Will",
        "scripts\actions\squadActions\squadFireAtWill.sqf",
        ["SQUAD"]
    ],
    [
        "squad_combat_engage",
        "Squad Engage Target",
        "a3\structures_f_bootcamp\vr\helpers\data\vr_symbol_balistics_ca.paa",
        "All Units Engage Current Target",
        "scripts\actions\squadActions\squadEngageTarget.sqf",
        ["SQUAD"]
    ],
    
    // === WEAPON SELECTION ACTIONS ===
    [
        "weapon_primary",
        "Primary",
        "\A3\ui_f\data\IGUI\Cfg\Actions\reammo_ca.paa",
        "Switch to Primary Weapon",
        "scripts\actions\unitActions\weapons\selectPrimary.sqf",
        ["MAN"]
    ],
    [
        "weapon_sidearm",
        "Sidearm",
        "\A3\ui_f\data\IGUI\Cfg\Actions\reammo_ca.paa",
        "Switch to Sidearm",
        "scripts\actions\unitActions\weapons\selectSidearm.sqf",
        ["MAN"]
    ],
    [
        "weapon_launcher",
        "Launcher",
        "\A3\ui_f\data\IGUI\Cfg\WeaponIcons\AT_ca.paa",
        "Switch to Launcher",
        "scripts\actions\unitActions\weapons\selectLauncher.sqf",
        ["MAN"]
    ],
    
    // === SQUAD ACTIONS ===
    [
        "squad_formation_line",
        "Line Formation",
        "a3\ui_f_curator\data\rsccommon\rscattributeformation\line_ca.paa",
        "Set Line Formation",
        "scripts\actions\squadActions\formationLine.sqf",
        ["SQUAD"]
    ],
    [
        "squad_formation_column",
        "Column Formation",
        "a3\3den\data\attributes\formation\stag_column_ca.paa",
        "Set Column Formation",
        "scripts\actions\squadActions\formationColumn.sqf",
        ["SQUAD"]
    ],
    
    // === VEHICLE COMMAND ACTIONS ===
    [
        "vehicle_togglehold",
        "Hold/Release",
        "a3\ui_f\data\igui\cfg\holdactions\holdaction_stop_ca.paa", // Default icon, will be updated dynamically
        "Toggle vehicle hold position",
        "scripts\actions\vehicleActions\toggleHold.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_exit",
        "Exit Vehicle",
        "a3\ui_f\data\igui\cfg\actions\getout_ca.paa",
        "All crew exit vehicle",
        "scripts\actions\vehicleActions\exitVehicle.sqf",
        ["VEHICLE"]
    ],
    
    // === VEHICLE COMBAT ACTIONS ===
    [
        "vehicle_toggleweapon",
        "Toggle Weapon",
        "\A3\ui_f\data\IGUI\Cfg\Actions\reammo_ca.paa",
        "Cycle through available weapons",
        "scripts\actions\vehicleActions\toggleVehicleWeapon.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_holdfire",
        "Hold Fire",
        "a3\ui_f\data\igui\cfg\commandbar\combatmode_texturemstealth_ca.paa",
        "Vehicle Hold Fire",
        "scripts\actions\vehicleActions\vehicleHoldFire.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_openfire",
        "Open Fire",
        "a3\ui_f\data\igui\cfg\commandbar\combatmode_texturemcombat_ca.paa",
        "Vehicle Fire At Will",
        "scripts\actions\vehicleActions\openFire.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_suppress",
        "Suppress Area",
        "a3\structures_f_bootcamp\vr\helpers\data\vr_symbol_balistics_ca.paa",
        "Suppress Target Area",
        "scripts\actions\vehicleActions\fireAtPosition.sqf",
        ["VEHICLE"]
    ],
    
    // === VEHICLE LOGISTICS ACTIONS ===
    [
        "vehicle_refuel",
        "Refuel",
        "\A3\ui_f\data\IGUI\Cfg\Actions\refuel_ca.paa",
        "Refuel Vehicle",
        "scripts\actions\vehicleActions\refuel.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_rearm",
        "Rearm",
        "\A3\ui_f\data\IGUI\Cfg\Actions\reammo_ca.paa",
        "Rearm Vehicle",
        "scripts\actions\vehicleActions\rearm.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_repair",
        "Repair",
        "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa",
        "Repair Vehicle",
        "scripts\actions\vehicleActions\repair.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_tow",
        "Tow/Unhook",
        "a3\3den\data\cfgwaypoints\hook_ca.paa", // Default icon, will be updated dynamically
        "Toggle towing for this vehicle",
        "scripts\actions\vehicleActions\toggleTow.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_loadcargo",
        "Load Cargo",
        "\A3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa",
        "Load cargo into vehicle",
        "scripts\actions\vehicleActions\loadCargo.sqf",
        ["VEHICLE"]
    ],
    [
        "vehicle_unloadcargo",
        "Unload Cargo",
        "\A3\ui_f\data\IGUI\Cfg\Actions\unloadVehicle_ca.paa",
        "Unload cargo from vehicle",
        "scripts\actions\vehicleActions\unloadCargo.sqf",
        ["VEHICLE"]
    ],
    
    // === OBJECT ACTIONS ===
    [
        "object_open",
        "Open",
        "\A3\ui_f\data\IGUI\Cfg\Actions\open_Door_ca.paa",
        "Open Object",
        "scripts\actions\objectActions\open.sqf",
        ["OBJECT"]
    ],
    [
        "object_close",
        "Close",
        "\A3\ui_f\data\IGUI\Cfg\Actions\open_Door_ca.paa",
        "Close Object",
        "scripts\actions\objectActions\close.sqf",
        ["OBJECT"]
    ]
];

// Group actions by category for easier access
RTSUI_actionCategories = [
    ["STANCE", ["stance_stand", "stance_crouch", "stance_prone"]],
    ["STANCE", ["squad_stance_stand", "squad_stance_crouch", "squad_stance_prone", "squad_stance_all"]],
    ["COMBAT", ["combat_holdfire", "combat_fireatill", "combat_engage"]],
    ["COMBAT", ["squad_combat_holdfire", "squad_combat_fireatill", "squad_combat_engage"]],
    ["WEAPONS", ["weapon_primary", "weapon_sidearm", "weapon_launcher"]],
    ["GROUP", ["unit_leavegroup", "unit_joingroup"]],
    ["FORMATION", ["squad_formation_line", "squad_formation_column"]],
    
    // Reorganized vehicle categories
    ["COMMAND", ["vehicle_togglehold", "vehicle_exit"]],
    ["COMBAT", ["vehicle_toggleweapon", "vehicle_holdfire", "vehicle_openfire", "vehicle_suppress"]],
    ["LOGISTICS", ["vehicle_refuel", "vehicle_rearm", "vehicle_repair", "vehicle_tow", "vehicle_loadcargo", "vehicle_unloadcargo"]],
    
    ["OBJECT", ["object_open", "object_close"]]
];

// Function to determine entity type for selection(s)
fnc_getSelectionType = {
    params ["_selections"];
    
    if (count _selections == 0) exitWith {"NONE"};
    
    // Check for multiple units (squad)
    if (count _selections > 1) then {
        // If all selections are infantry units, it's a squad
        private _allInfantry = true;
        {
            if !(_x isKindOf "CAManBase") then {
                _allInfantry = false;
            };
        } forEach _selections;
        
        if (_allInfantry) exitWith {"SQUAD"};
        
        // Check if all selections are same vehicle type
        private _allSameVehicleType = true;
        private _firstType = "";
        {
            private _currentType = switch (true) do {
                case (_x isKindOf "Car"): {"Car"};
                case (_x isKindOf "Tank"): {"Tank"};
                case (_x isKindOf "Air"): {"Air"};
                default {"Other"};
            };
            
            if (_firstType == "") then {
                _firstType = _currentType;
            } else {
                if (_currentType != _firstType) then {
                    _allSameVehicleType = false;
                };
            };
        } forEach _selections;
        
        if (_allSameVehicleType && _firstType != "Other") exitWith {"VEHICLE"};
        
        // Mixed selection - default to first unit type
        _selections = [_selections select 0];
    };
    
    // Single selection
    private _selection = _selections select 0;
    
    switch (true) do {
        case (_selection isKindOf "CAManBase"): {"MAN"};
        case (_selection isKindOf "Car" || _selection isKindOf "Tank" || _selection isKindOf "Air"): {"VEHICLE"};
        default {"OBJECT"};
    };
};

// Function to get applicable actions for an entity type
fnc_getActionsForType = {
    params ["_entityType"];
    
    private _applicable = [];
    
    {
        private _actionId = _x select 0;
        private _types = _x select 5;
        
        if (_entityType in _types) then {
            _applicable pushBack _actionId;
        };
    } forEach RTSUI_actionDatabase;
    
    _applicable
};

// Get category for given action ID
fnc_getActionCategory = {
    params ["_actionId"];
    
    private _category = "";
    {
        _x params ["_catName", "_actionIds"];
        if (_actionId in _actionIds) exitWith {
            _category = _catName;
        };
    } forEach RTSUI_actionCategories;
    
    _category
};