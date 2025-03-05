// scripts/actions/vehicleActions/suppressArea.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Get vehicle name for feedback
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");

// Check if vehicle has weapons
private _weapons = weapons _vehicle;
if (count _weapons == 0) exitWith {
    systemChat format ["%1 has no weapons to suppress with", _vehicleName];
};

// Create a temporary marker for visualization
private _markerId = format ["suppress_marker_%1", floor(random 99999)];
createMarker [_markerId, [0,0,0]];
_markerId setMarkerShape "ELLIPSE";
_markerId setMarkerBrush "SolidBorder";
_markerId setMarkerColor "ColorRed";
_markerId setMarkerAlpha 0.5;
_markerId setMarkerSize [50, 50];

// Open the map to select area
systemChat "Click on map to select suppression area";
hint "Click on map to select suppression area";

[_vehicle, _vehicleName, _markerId] spawn {
    params ["_vehicle", "_vehicleName", "_markerId"];
    
    onMapSingleClick {
        params ["_pos", "_alt", "_shift"];
        
        // Update marker position
        _thisArgs params ["_vehicle", "_vehicleName", "_markerId"];
        _markerId setMarkerPos _pos;
        
        // Begin suppression
        private _mainGun = (weapons _vehicle) select 0;
        private _backupGun = if (count (weapons _vehicle) > 1) then {(weapons _vehicle) select 1} else {_mainGun};
        
        // Set combat mode to ensure vehicle engages
        _vehicle setCombatMode "RED";
        {
            _x setCombatMode "RED";
        } forEach (crew _vehicle);
        
        // Order vehicle to suppress
        _vehicle doSuppressiveFire _pos;
        
        // Provide feedback
        systemChat format ["%1 suppressing target area", _vehicleName];
        hint format ["%1 suppressing target area", _vehicleName];
        
        // Clean up
        onMapSingleClick {};
        
        // Remove marker after delay
        sleep 15;
        deleteMarker _markerId;
    };
};