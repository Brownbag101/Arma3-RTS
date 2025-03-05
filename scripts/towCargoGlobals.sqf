// scripts/towCargoGlobals.sqf - Initialize TOW and CARGO system variables

// Add debug message at the start
systemChat "Starting TOW and CARGO globals initialization...";

// Define classes that can carry cargo
if (isNil "MISSION_cargoVehicles") then {
    MISSION_cargoVehicles = [
        "JMSSA_veh_bedfordMW_F",
        "JMSSA_veh_matador_F",
        "JMSSA_veh_willys_tent_F",
        "JMSSA_veh_bedfordMW_E_ammo",
        "LIB_C47_RAF",
        "LIB_HORSA_RAF",
        "JMSSA_veh_bedfordMW_E_oil",
        // WW2 mod vehicles
        "LIB_US_GMC_Tent",
        "LIB_US_GMC_Open",
        "LIB_US_GMC_Ammo",
        "LIB_US_GMC_Fuel",
        "LIB_US_GMC_Repair",
        "LIB_US_GMC_Ambulance",
        "LIB_OpelBlitz_Tent_Y_Camo",
        "LIB_OpelBlitz_Open_Y_Camo",
        "LIB_SdKfz_7",
        // Fallback to include vanilla vehicles for testing
        "B_Truck_01_transport_F",
        "B_Truck_01_covered_F",
        "C_Van_01_transport_F"
        // Add more vehicle classnames as needed
    ];
    systemChat "MISSION_cargoVehicles initialized with " + str(count MISSION_cargoVehicles) + " vehicles";
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
        "LIB_BasicWeaponsBox_UK",
        // Additional WW2 crates
        "LIB_BasicAmmunitionBox_GER",
        "LIB_BasicAmmunitionBox_US",
        "LIB_BasicWeaponsBox_GER",
        "LIB_BasicWeaponsBox_US",
        "LIB_GER_Equip_box",
        "LIB_US_Equip_box",
        // Fallback to include vanilla objects for testing
        "Box_NATO_Ammo_F",
        "Box_NATO_Wps_F",
        "Land_WoodenCrate_01_F",
        "Land_MetalCase_01_large_F"
        // Add more cargo object classnames as needed
    ];
    systemChat "MISSION_cargoObjects initialized with " + str(count MISSION_cargoObjects) + " objects";
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
        ["LIB_C47_RAF", 10],
        // WW2 mod vehicles
        ["LIB_US_GMC_Tent", 8],
        ["LIB_US_GMC_Open", 8],
        ["LIB_US_GMC_Ammo", 6],
        ["LIB_US_GMC_Fuel", 6],
        ["LIB_US_GMC_Repair", 6],
        ["LIB_US_GMC_Ambulance", 4],
        ["LIB_OpelBlitz_Tent_Y_Camo", 8],
        ["LIB_OpelBlitz_Open_Y_Camo", 8],
        ["LIB_SdKfz_7", 6],
        // Fallback vanilla vehicles
        ["B_Truck_01_transport_F", 10],
        ["B_Truck_01_covered_F", 12],
        ["C_Van_01_transport_F", 6]
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
        "LIB_Churchill_Mk7",
        // WW2 mod vehicles
        "LIB_US_GMC_Tent",
        "LIB_US_GMC_Open",
        "LIB_US_Willys_MB",
        "LIB_OpelBlitz_Tent_Y_Camo",
        "LIB_OpelBlitz_Open_Y_Camo",
        "LIB_SdKfz_7",
        // Fallback vanilla vehicles
        "B_Truck_01_transport_F",
        "B_Truck_01_covered_F",
        "C_Van_01_transport_F",
        "C_Offroad_01_F"
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
        "LIB_Cromwell_Mk4",
        // WW2 mod vehicles
        "LIB_US_Willys_MB",
        "LIB_US_Scout_M3",
        "LIB_US_M3_Halftrack",
        "LIB_Kfz1",
        "LIB_Kfz1_hood_camo",
        "LIB_SdKfz251",
        // Fallback vanilla vehicles
        "C_Offroad_01_F",
        "B_MRAP_01_F",
        "B_MRAP_01_hmg_F"
        // Add more vehicle classnames as needed
    ];
    systemChat "MISSION_towableVehicles initialized";
};

// Adding additional debug
if (!isNil "MISSION_cargoVehicles" && !isNil "MISSION_cargoObjects" && !isNil "MISSION_cargoCapacity" &&
    !isNil "MISSION_towingVehicles" && !isNil "MISSION_towableVehicles") then {
    systemChat "TOW and CARGO globals initialized successfully";
    true
} else {
    systemChat "WARNING: Some TOW and CARGO globals failed to initialize!";
    false
};