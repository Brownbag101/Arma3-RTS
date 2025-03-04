// towCargoGlobals.sqf - Initialize TOW and CARGO system variables

// Define classes that can carry cargo
if (isNil "MISSION_cargoVehicles") then {
    MISSION_cargoVehicles = [
        "JMSSA_veh_bedfordMW_F",
        "JMSSA_veh_matador_F",
        "JMSSA_veh_willys_tent_F",
        "JMSSA_veh_bedfordMW_E_ammo",
        "LIB_C47_RAF",
        "LIB_HORSA_RAF",
        "JMSSA_veh_bedfordMW_E_oil"
        // Add more vehicle classnames as needed
    ];
    systemChat "MISSION_cargoVehicles initialized";
};

// Define cargo object classes
if (isNil "MISSION_cargoObjects") then {
    MISSION_cargoObjects = [
        "LIB_AmmoCrate_Arty_SU",
        "LIB_AmmoCrate_Mortar_SU",
        "LIB_AmmoCrate_Mines_SU",
        "LIB_BasicAmmunitionBox_SU",
        "fow_b_uk_bergenpack",
        "LIB_BasicWeaponsBox_SU",
        "LIB_Mine_Ammo_Box_Su",
        "LIB_Lone_Big_Box",
        "LIB_BasicWeaponsBox_UK"
        // Add more cargo object classnames as needed
    ];
    systemChat "MISSION_cargoObjects initialized";
};

// Define cargo capacity for each vehicle class
if (isNil "MISSION_cargoCapacity") then {
    MISSION_cargoCapacity = [
        ["JMSSA_veh_bedfordMW_F", 10],
        ["JMSSA_veh_matador_F", 8],
        ["JMSSA_veh_willys_tent_F", 4],
        ["JMSSA_veh_bedfordMW_E_ammo", 12],
        ["JMSSA_veh_bedfordMW_E_oil", 12],
        ["LIB_HORSA_RAF", 2],
        ["LIB_C47_RAF", 10]    
        // Add more vehicle classes and their capacities
    ];
    systemChat "MISSION_cargoCapacity initialized";
};

// Define classes that can tow
if (isNil "MISSION_towingVehicles") then {
    MISSION_towingVehicles = [
        "JMSSA_veh_bedfordMW_F",
        "JMSSA_veh_matador_F",
        "JMSSA_veh_willys_open_F",
        "JMSSA_veh_willys_tent_F",
        "fow_v_cromwell_uk",
        "LIB_C47_RAF",
        "LIB_Churchill_Mk7"
        // Add more vehicle classnames as needed
    ];
    systemChat "MISSION_towingVehicles initialized";
};

// Define classes that can be towed
if (isNil "MISSION_towableVehicles") then {
    MISSION_towableVehicles = [
        "JMSSA_veh_willys_open_F",
        "JMSSA_veh_willys_tent_F",
        "JMSSA_veh_A9cruis_F",
        "JMSSA_veh_A10cruis_F",
		"JMSSA_veh_matador_F",
        "JMSSA_veh_austinK2_repair_F",
        "LIB_C47_RAF",
        "LIB_HORSA_RAF",
        "LIB_Cromwell_Mk4"
        // Add more vehicle classnames as needed
    ];
    systemChat "MISSION_towableVehicles initialized";
};

// Return true to verify script execution
systemChat "TOW and CARGO globals initialized successfully";
true