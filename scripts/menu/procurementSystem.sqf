// procurementSystem.sqf - Integrated Procurement System
// For deploying constructed items to the field

// Initialize global variables if not already defined
if (isNil "MISSION_selectedItems") then {
    MISSION_selectedItems = [];
};

if (isNil "MISSION_cargoShips") then {
    MISSION_cargoShips = 2;
};

if (isNil "MISSION_procurementUIOpen") then {
    MISSION_procurementUIOpen = false;
};

// Initialize available equipment if needed
if (isNil "MISSION_availableEquipment") then {
    MISSION_availableEquipment = [];
    // Format: [className, displayName, category, quantity]
};

// Function to open the Procurement UI
fnc_openProcurementUI = {
    if (dialog) then {closeDialog 0};
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    
    if (isNull _display) exitWith {
        diag_log "Failed to create Procurement UI";
    };
    
    // Set flag
    MISSION_procurementUIOpen = true;
    
    // Create background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.7 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetText "Procurement System";
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _title ctrlCommit 0;
    
    // Create cargo ships text
    private _cargoShipsText = _display ctrlCreate ["RscText", 1001];
    _cargoShipsText ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.21 * safezoneH + safezoneY, 0.56 * safezoneW, 0.04 * safezoneH];
    _cargoShipsText ctrlSetText format ["Available Cargo Ships: %1", MISSION_cargoShips];
    _cargoShipsText ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
    _cargoShipsText ctrlCommit 0;
    
    // Create category tabs
    private _categories = [];
    {
        private _category = _x select 2;
        if (!(_category in _categories) && _category != "") then {
            _categories pushBack _category;
        };
    } forEach MISSION_availableEquipment;
    
    for "_i" from 0 to ((count _categories) - 1) min 4 do {
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
        _tabButton ctrlSetEventHandler ["ButtonClick", "params ['_ctrl']; [_ctrl getVariable 'category'] call fnc_switchProcurementTab"];
        _tabButton ctrlCommit 0;
    };
    
    // Create left list box (available items)
    private _leftListBox = _display ctrlCreate ["RscListBox", 1200];
    _leftListBox ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.25 * safezoneW, 0.4 * safezoneH];
    _leftListBox ctrlCommit 0;
    
    // Create right list box (selected items)
    private _rightListBox = _display ctrlCreate ["RscListBox", 1300];
    _rightListBox ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.25 * safezoneW, 0.4 * safezoneH];
    _rightListBox ctrlCommit 0;
    
    // Create ADD button
    private _addButton = _display ctrlCreate ["RscButton", 1400];
    _addButton ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.72 * safezoneH + safezoneY, 0.25 * safezoneW, 0.05 * safezoneH];
    _addButton ctrlSetText "ADD TO SHIPMENT";
    _addButton ctrlSetBackgroundColor [0.2, 0.4, 0.2, 1];
    _addButton ctrlSetEventHandler ["ButtonClick", "[] call fnc_addToProcurement"];
    _addButton ctrlCommit 0;
    
    // Create REMOVE button
    private _removeButton = _display ctrlCreate ["RscButton", 1500];
    _removeButton ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.72 * safezoneH + safezoneY, 0.25 * safezoneW, 0.05 * safezoneH];
    _removeButton ctrlSetText "REMOVE FROM SHIPMENT";
    _removeButton ctrlSetBackgroundColor [0.4, 0.2, 0.2, 1];
    _removeButton ctrlSetEventHandler ["ButtonClick", "[] call fnc_removeFromProcurement"];
    _removeButton ctrlCommit 0;
    
    // Create CANCEL button
    private _cancelButton = _display ctrlCreate ["RscButton", 1600];
    _cancelButton ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.78 * safezoneH + safezoneY, 0.25 * safezoneW, 0.04 * safezoneH];
    _cancelButton ctrlSetText "CANCEL";
    _cancelButton ctrlSetBackgroundColor [0.3, 0.3, 0.3, 1];
    _cancelButton ctrlSetEventHandler ["ButtonClick", "closeDialog 0"];
    _cancelButton ctrlCommit 0;
    
    // Create CONFIRM button
    private _confirmButton = _display ctrlCreate ["RscButton", 1700];
    _confirmButton ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.78 * safezoneH + safezoneY, 0.25 * safezoneW, 0.04 * safezoneH];
    _confirmButton ctrlSetText "CONFIRM SHIPMENT";
    _confirmButton ctrlSetBackgroundColor [0.3, 0.3, 0.8, 1];
    _confirmButton ctrlSetEventHandler ["ButtonClick", "[] call fnc_confirmProcurement"];
    _confirmButton ctrlCommit 0;
    
    // Add handler for dialog closure
    _display displayAddEventHandler ["Unload", {
        MISSION_procurementUIOpen = false;
    }];
    
    // Switch to first tab if available
    if (count _categories > 0) then {
        [_categories select 0] call fnc_switchProcurementTab;
    };
    
    // Start UI update loop
    [] spawn {
        while {MISSION_procurementUIOpen && !isNull findDisplay -1} do {
            call fnc_updateProcurementUI;
            sleep 0.5;
        };
    };
};

// Function to switch procurement tab
fnc_switchProcurementTab = {
    params ["_category"];
    
    private _display = findDisplay -1;
    
    // Update tab button visuals
    for "_i" from 0 to 4 do {
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
    
    // Update available items list
    [_category] call fnc_updateAvailableItemsList;
};

// Function to update available items list for a category
fnc_updateAvailableItemsList = {
    params ["_category"];
    
    private _display = findDisplay -1;
    private _leftListBox = _display displayCtrl 1200;
    
    // Clear current list
    lbClear _leftListBox;
    
    // Filter equipment by category
    private _categoryEquipment = MISSION_availableEquipment select {(_x select 2) == _category};
    
    // Add each item to the list
    {
        _x params ["_className", "_displayName", "", "_quantity"];
        
        if (_quantity > 0) then {
            private _index = _leftListBox lbAdd format ["%1 (x%2)", _displayName, _quantity];
            _leftListBox lbSetData [_index, _className];
        };
    } forEach _categoryEquipment;
    
    // Sort alphabetically
    lbSort _leftListBox;
};

// Function to update selected items list
fnc_updateSelectedItemsList = {
    private _display = findDisplay -1;
    private _rightListBox = _display displayCtrl 1300;
    
    // Clear current list
    lbClear _rightListBox;
    
    // Add each selected item to the list
    {
        _x params ["_className", "_quantity"];
        
        // Find display name
        private _itemIndex = MISSION_availableEquipment findIf {(_x select 0) == _className};
        if (_itemIndex != -1) then {
            private _displayName = (MISSION_availableEquipment select _itemIndex) select 1;
            private _index = _rightListBox lbAdd format ["%1 (x%2)", _displayName, _quantity];
            _rightListBox lbSetData [_index, _className];
        };
    } forEach MISSION_selectedItems;
    
    // Sort alphabetically
    lbSort _rightListBox;
};

// Function to update the entire procurement UI
fnc_updateProcurementUI = {
    private _display = findDisplay -1;
    private _cargoShipsText = _display displayCtrl 1001;
    
    // Update cargo ships display
    _cargoShipsText ctrlSetText format ["Available Cargo Ships: %1", MISSION_cargoShips];
    
    // Get current category
    private _currentCategory = _display getVariable ["currentCategory", ""];
    
    // Update lists
    if (_currentCategory != "") then {
        [_currentCategory] call fnc_updateAvailableItemsList;
    };
    
    call fnc_updateSelectedItemsList;
    
    // Enable/disable confirm button based on available ships and selected items
    private _confirmButton = _display displayCtrl 1700;
    _confirmButton ctrlEnable (MISSION_cargoShips > 0 && count MISSION_selectedItems > 0);
};

// Function to add an item to the procurement list
fnc_addToProcurement = {
    private _display = findDisplay -1;
    private _leftListBox = _display displayCtrl 1200;
    private _selectedIndex = lbCurSel _leftListBox;
    
    if (_selectedIndex == -1) exitWith {
        hint "No item selected to add.";
    };
    
    // Get selected item
    private _className = _leftListBox lbData _selectedIndex;
    private _itemIndex = MISSION_availableEquipment findIf {(_x select 0) == _className};
    
    if (_itemIndex == -1) exitWith {
        hint "Error: Item not found in available equipment.";
    };
    
    // Get item data
    private _itemData = MISSION_availableEquipment select _itemIndex;
    _itemData params ["_class", "_name", "_category", "_quantity"];
    
    // Check if quantity is available
    if (_quantity <= 0) exitWith {
        hint format ["No %1 available for procurement.", _name];
    };
    
    // Decrease available quantity
    _itemData set [3, _quantity - 1];
    
    // Add to selected items
    private _selectedIndex = MISSION_selectedItems findIf {(_x select 0) == _className};
    if (_selectedIndex == -1) then {
        MISSION_selectedItems pushBack [_className, 1];
    } else {
        private _currentCount = (MISSION_selectedItems select _selectedIndex) select 1;
        (MISSION_selectedItems select _selectedIndex) set [1, _currentCount + 1];
    };
    
    // Update UI
    call fnc_updateProcurementUI;
    
    hint format ["%1 added to shipment.", _name];
};

// Function to remove an item from the procurement list
fnc_removeFromProcurement = {
    private _display = findDisplay -1;
    private _rightListBox = _display displayCtrl 1300;
    private _selectedIndex = lbCurSel _rightListBox;
    
    if (_selectedIndex == -1) exitWith {
        hint "No item selected to remove.";
    };
    
    // Get selected item
    private _className = _rightListBox lbData _selectedIndex;
    private _itemIndex = MISSION_availableEquipment findIf {(_x select 0) == _className};
    
    if (_itemIndex == -1) exitWith {
        hint "Error: Item not found in available equipment.";
    };
    
    // Get item data
    private _itemData = MISSION_availableEquipment select _itemIndex;
    _itemData params ["_class", "_name", "_category", "_quantity"];
    
    // Increase available quantity
    _itemData set [3, _quantity + 1];
    
    // Remove from selected items
    private _selectedItemIndex = MISSION_selectedItems findIf {(_x select 0) == _className};
    if (_selectedItemIndex != -1) then {
        private _currentCount = (MISSION_selectedItems select _selectedItemIndex) select 1;
        
        if (_currentCount > 1) then {
            (MISSION_selectedItems select _selectedItemIndex) set [1, _currentCount - 1];
        } else {
            MISSION_selectedItems deleteAt _selectedItemIndex;
        };
    };
    
    // Update UI
    call fnc_updateProcurementUI;
    
    hint format ["%1 removed from shipment.", _name];
};

// Function to confirm procurement
fnc_confirmProcurement = {
    if (MISSION_cargoShips <= 0) exitWith {
        hint "No cargo ships available for shipment.";
    };
    
    if (count MISSION_selectedItems == 0) exitWith {
        hint "No items selected for shipment.";
    };
    
    // Reduce available ships
    MISSION_cargoShips = MISSION_cargoShips - 1;
    
    // Copy the selected items to a new array to avoid reference issues
    private _itemsToShip = +MISSION_selectedItems;
    
    // Clear selected items
    MISSION_selectedItems = [];
    
    // Close dialog
    closeDialog 0;
    
    // Start shipment process
    [_itemsToShip] spawn fnc_spawnCargoShip;
    
    hint "Shipment confirmed. Cargo ship en route.";
};

// Function to spawn cargo ship and deliver items
fnc_spawnCargoShip = {
    params ["_items"];
    
    // Debug
    systemChat format ["Starting shipment with %1 items", count _items];
    
    // Get marker positions
    private _spawnMarkerName = "cargo_ship_spawn";
    private _destinationMarkerName = "cargo_ship_destination";
    private _exitMarkerName = "cargo_ship_exit";
    private _spawnPos = [0, 3000, 0]; // Default position
    private _destinationPos = [0, 0, 0]; // Default position
    private _exitPos = [0, -3000, 0]; // Default position
    
    // Check for actual markers
    if (getMarkerType _spawnMarkerName != "") then {
        _spawnPos = getMarkerPos _spawnMarkerName;
    };
    
    if (getMarkerType _destinationMarkerName != "") then {
        _destinationPos = getMarkerPos _destinationMarkerName;
    };
    
    if (getMarkerType _exitMarkerName != "") then {
        _exitPos = getMarkerPos _exitMarkerName;
    };
    
    // Create the ship
    private _shipType = "JMSSA_veh_matador_F"; // Default to whatever vehicle we have
    if (isClass (configFile >> "CfgVehicles" >> "sab_nl_liberty")) then {
        _shipType = "sab_nl_liberty"; // Use liberty ship if available
    };
    
    private _ship = createVehicle [_shipType, _spawnPos, [], 0, "NONE"];
    _ship setDir (_ship getDir _destinationPos);
    
    // Create crew
    private _shipGroup = createGroup [side player, true];
    private _crew = [_ship, _shipGroup] call BIS_fnc_spawnCrew;
    
    // Set crew skill
    {
        _x setSkill 1;
    } forEach _crew;
    
    _shipGroup setCombatMode "GREEN";
    _shipGroup allowFleeing 0;
    
    // Make ship Zeus editable
    {
        _x addCuratorEditableObjects [[_ship], true];
        _x addCuratorEditableObjects _crew, true;
    } forEach allCurators;
    
    // Notify about ship departure
    hint "Cargo ship en route. ETA 3 minutes.";
    systemChat "Cargo ship en route with supplies. ETA 3 minutes.";
    
    // Move ship to destination
    _ship doMove _destinationPos;
    
    // Set up transit time for the ship
    private _startTime = time;
    private _transitTime = 180; // 3 minutes
    
    // Wait until ship arrives or is destroyed
    waitUntil {
        sleep 5;
        
        // Calculate remaining time
        private _remainingTime = _transitTime - (time - _startTime);
        private _remainingTimeRounded = round(_remainingTime max 0);
        
        if (_remainingTimeRounded > 0 && (_remainingTimeRounded mod 30 == 0 || _remainingTimeRounded <= 10)) then {
            // Update progress message every 30 seconds or for last 10 seconds
            systemChat format ["Cargo ship ETA: %1 seconds", _remainingTimeRounded];
        };
        
        // Check if the ship is dead or arrived
        (!alive _ship) || (time > _startTime + _transitTime) || (_ship distance _destinationPos < 100)
    };
    
    // Handle ship destruction
    if (!alive _ship) exitWith {
        hint "Cargo ship lost! Shipment failed.";
        systemChat "Alert: Cargo ship has been destroyed. Supplies lost.";
        
        // Return ship to pool
        MISSION_cargoShips = MISSION_cargoShips + 1;
        
        // Delete crew and group
        {deleteVehicle _x} forEach _crew;
        deleteGroup _shipGroup;
    };
    
    // Handle successful arrival
    if (_ship distance _destinationPos < 100 || time > _startTime + _transitTime) then {
        // Notify of arrival
        hint "Cargo ship arrived. Unloading supplies...";
        systemChat "Cargo ship has docked. Beginning unloading process...";
        
        // Wait for unloading
        sleep 10;
        
        // Define spawn locations for different item types
        private _vehicleSpawnMarkers = ["vehicle_spawn_1", "vehicle_spawn_2", "vehicle_spawn_3", "vehicle_spawn_4", "vehicle_spawn_5"];
        private _crateSpawnMarkers = ["crate_spawn_1", "crate_spawn_2", "crate_spawn_3", "crate_spawn_4", "crate_spawn_5"];
        
        // Vehicle and crate counters
        private _vehicleCount = 0;
        private _crateCount = 0;
        
        // Flag to track if spawn markers are missing
        private _missingMarkers = false;
        
        // Spawn items
        {
            _x params ["_className", "_quantity"];
            
            // Get item info
            private _itemIndex = MISSION_availableEquipment findIf {(_x select 0) == _className};
            if (_itemIndex != -1) then {
                private _itemData = MISSION_availableEquipment select _itemIndex;
                _itemData params ["", "_displayName", "_category"];
                
                // Determine if it's a vehicle or equipment
                private _isVehicle = false;
                
                if (_className isKindOf "LandVehicle" || _className isKindOf "Air" || _className isKindOf "Ship") then {
                    _isVehicle = true;
                };
                
                // Spawn the requested quantity
                for "_i" from 1 to _quantity do {
                    if (_isVehicle) then {
                        // Spawn vehicle
                        if (_vehicleCount < count _vehicleSpawnMarkers) then {
                            private _markerName = _vehicleSpawnMarkers select _vehicleCount;
                            
                            // Check if marker exists
                            if (getMarkerType _markerName != "") then {
                                private _spawnPos = getMarkerPos _markerName;
                                private _vehicle = createVehicle [_className, _spawnPos, [], 0, "NONE"];
                                
                                // Clear cargo
                                clearWeaponCargoGlobal _vehicle;
                                clearMagazineCargoGlobal _vehicle;
                                clearItemCargoGlobal _vehicle;
                                clearBackpackCargoGlobal _vehicle;
                                
                                // Make Zeus editable
                                {
                                    _x addCuratorEditableObjects [[_vehicle], true];
                                } forEach allCurators;
                                
                                _vehicleCount = _vehicleCount + 1;
                                
                                systemChat format ["Unloaded: %1", _displayName];
                            } else {
                                _missingMarkers = true;
                                systemChat format ["Warning: Missing vehicle spawn marker %1", _markerName];
                            };
                        } else {
                            systemChat format ["Warning: Too many vehicles for available spawn points. %1 not spawned.", _displayName];
                        };
                    } else {
                        // Spawn weapon crate
                        if (_crateCount < count _crateSpawnMarkers) then {
                            private _markerName = _crateSpawnMarkers select _crateCount;
                            
                            // Check if marker exists
                            if (getMarkerType _markerName != "") then {
                                private _spawnPos = getMarkerPos _markerName;
                                [_className, _spawnPos] call fnc_spawnWeaponCrate;
                                
                                _crateCount = _crateCount + 1;
                                
                                systemChat format ["Unloaded: %1", _displayName];
                            } else {
                                _missingMarkers = true;
                                systemChat format ["Warning: Missing crate spawn marker %1", _markerName];
                            };
                        } else {
                            systemChat format ["Warning: Too many crates for available spawn points. %1 not spawned.", _displayName];
                        };
                    };
                };
            };
        } forEach _items;
        
        // Warn about missing markers if needed
        if (_missingMarkers) then {
            hint "Warning: Some spawn markers are missing. Create markers named 'vehicle_spawn_1', 'vehicle_spawn_2', etc. and 'crate_spawn_1', 'crate_spawn_2', etc.";
        };
        
        // Notification of completed unloading
        hint "Supplies have been delivered to the docks.";
        systemChat "All supplies unloaded. Cargo ship preparing to depart.";
        
        // Ship departure
        _ship setDir ((_ship getDir _exitPos) + 180);
        _ship doMove _exitPos;
        
        // Wait for the ship to leave or timeout
        waitUntil {
            sleep 5;
            (_ship distance _exitPos < 100) || (!alive _ship) || (time > _startTime + _transitTime + 300)
        };
        
        // Return ship to the pool
        MISSION_cargoShips = MISSION_cargoShips + 1;
        
        // Delete ship and crew
        {deleteVehicle _x} forEach _crew;
        deleteGroup _shipGroup;
        deleteVehicle _ship;
        
        hint "A cargo ship has returned to base and is available for new shipments.";
        systemChat "Cargo ship has returned to base. New shipments are now available.";
    };
};

// Function to spawn weapon crates
fnc_spawnWeaponCrate = {
    params ["_weaponClass", "_position"];
    
    // Determine crate type based on what's available
    private _crateType = "Box_NATO_Ammo_F"; // Default
    
    if (isClass (configFile >> "CfgVehicles" >> "JMSSA_Ammo_crate_big")) then {
        _crateType = "JMSSA_Ammo_crate_big";
    } else if (isClass (configFile >> "CfgVehicles" >> "LIB_BasicWeaponsBox_US")) then {
        _crateType = "LIB_BasicWeaponsBox_US";
    };
    
    // Create the crate
    private _crate = createVehicle [_crateType, _position, [], 0, "NONE"];
    
    // Clear existing cargo
    clearWeaponCargoGlobal _crate;
    clearMagazineCargoGlobal _crate;
    clearItemCargoGlobal _crate;
    clearBackpackCargoGlobal _crate;
    
    // Determine type of item to add (weapon, magazine, etc.)
    if (isClass (configFile >> "CfgWeapons" >> _weaponClass)) then {
        // It's a weapon - add appropriate magazines too
        _crate addWeaponCargoGlobal [_weaponClass, 10]; // 10 weapons per crate
        
        // Get compatible magazines
        private _mags = getArray (configFile >> "CfgWeapons" >> _weaponClass >> "magazines");
        if (count _mags > 0) then {
            _crate addMagazineCargoGlobal [_mags select 0, 50]; // 50 magazines
        };
    } else if (isClass (configFile >> "CfgMagazines" >> _weaponClass)) then {
        // It's a magazine
        _crate addMagazineCargoGlobal [_weaponClass, 50];
    } else if (isClass (configFile >> "CfgVehicles" >> _weaponClass)) then {
        // It's a vehicle - can't add to a crate, log warning
        systemChat format ["Warning: Cannot add vehicle %1 to a crate", _weaponClass];
    } else {
        // Try as a generic item
        _crate addItemCargoGlobal [_weaponClass, 10];
    };
    
    // Make Zeus editable
    {
        _x addCuratorEditableObjects [[_crate], true];
    } forEach allCurators;
    
    // Return the crate
    _crate
};

// This function creates the necessary markers if they don't exist
fnc_createProcurementMarkers = {
    // Create cargo ship markers if they don't exist
    if (getMarkerType "cargo_ship_spawn" == "") then {
        private _marker = createMarker ["cargo_ship_spawn", [3000, 0, 0]];
        _marker setMarkerType "mil_start";
        _marker setMarkerText "Cargo Ship Spawn";
    };
    
    if (getMarkerType "cargo_ship_destination" == "") then {
        private _marker = createMarker ["cargo_ship_destination", [0, 0, 0]];
        _marker setMarkerType "mil_objective";
        _marker setMarkerText "Cargo Ship Dock";
    };
    
    if (getMarkerType "cargo_ship_exit" == "") then {
        private _marker = createMarker ["cargo_ship_exit", [-3000, 0, 0]];
        _marker setMarkerType "mil_end";
        _marker setMarkerText "Cargo Ship Exit";
    };
    
    // Create spawn markers for vehicles and crates
    for "_i" from 1 to 5 do {
        if (getMarkerType format ["vehicle_spawn_%1", _i] == "") then {
            private _pos = [50 * _i, 50, 0];
            private _marker = createMarker [format ["vehicle_spawn_%1", _i], _pos];
            _marker setMarkerType "mil_dot";
            _marker setMarkerText format ["Vehicle Spawn %1", _i];
            _marker setMarkerColor "ColorBlue";
        };
        
        if (getMarkerType format ["crate_spawn_%1", _i] == "") then {
            private _pos = [50 * _i, -50, 0];
            private _marker = createMarker [format ["crate_spawn_%1", _i], _pos];
            _marker setMarkerType "mil_box";
            _marker setMarkerText format ["Crate Spawn %1", _i];
            _marker setMarkerColor "ColorGreen";
        };
    };
    
    systemChat "Procurement system markers created.";
};

// Integration with menu system
// This should be called when the menu is initialized
// We need to add a new button to RTS_menuButtons in menuSystem.sqf
fnc_addProcurementMenuItem = {
    // Check if menu buttons exists
    if (isNil "RTS_menuButtons") exitWith {
        systemChat "Error: RTS_menuButtons not found. Cannot add procurement menu item.";
    };
    
    // Check if procurement is already in the menu
    private _index = RTS_menuButtons findIf {(_x select 0) == "procurement"};
    
    if (_index == -1) then {
        // Add procurement to menu buttons
        RTS_menuButtons pushBack [
            "procurement", 
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\cargoput_ca.paa", 
            "Procurement", 
            "Deploy constructed items to the field"
        ];
        
        systemChat "Added Procurement button to the menu.";
    };
};

// Create procurement markers
call fnc_createProcurementMarkers;

// Add procurement to menu
call fnc_addProcurementMenuItem;

// Return true to indicate script loaded
true