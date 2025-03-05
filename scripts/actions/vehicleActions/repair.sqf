// scripts/actions/vehicleActions/repair.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Create progress bar
private _display = findDisplay 312;
private _ctrlGroup = _display ctrlCreate ["RscControlsGroup", -1];
_ctrlGroup ctrlSetPosition [
    safezoneX + 0.3 * safezoneW,
    safezoneY + 0.8 * safezoneH,
    0.4 * safezoneW,
    0.05 * safezoneH
];
_ctrlGroup ctrlCommit 0;

private _background = _display ctrlCreate ["RscText", -1, _ctrlGroup];
_background ctrlSetPosition [0, 0, 0.4 * safezoneW, 0.05 * safezoneH];
_background ctrlSetBackgroundColor [0, 0, 0, 0.7];
_background ctrlCommit 0;

private _text = _display ctrlCreate ["RscText", -1, _ctrlGroup];
_text ctrlSetPosition [0, 0, 0.4 * safezoneW, 0.025 * safezoneH];
_text ctrlSetText format ["Repairing %1...", getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];
_text ctrlCommit 0;

private _progress = _display ctrlCreate ["RscProgress", -1, _ctrlGroup];
_progress ctrlSetPosition [0.01, 0.03, 0.38 * safezoneW, 0.015 * safezoneH];
_progress ctrlSetTextColor [0.2, 0.9, 0.2, 1];
_progress ctrlCommit 0;

// Start repair process
[_vehicle, _ctrlGroup, _progress, _display] spawn {
    params ["_vehicle", "_ctrlGroup", "_progress", "_display"];
    
    private _damage = damage _vehicle;
    private _duration = 10 * _damage; // 10 seconds for full repair
    private _startTime = time;
    
    while {time < _startTime + _duration && !isNull _display} do {
        private _elapsed = time - _startTime;
        private _progressValue = _elapsed / _duration;
        
        // Update progress bar
        _progress progressSetPosition _progressValue;
        
        // Repair gradually
        _vehicle setDamage (_damage - (_damage * _progressValue));
        
        sleep 0.1;
    };
    
    // Final repair
    if (!isNull _vehicle && !isNull _display) then {
        _vehicle setDamage 0;
        systemChat format ["%1 has been fully repaired", getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];
    };
    
    // Cleanup
    if (!isNull _ctrlGroup) then {
        ctrlDelete _ctrlGroup;
    };
};