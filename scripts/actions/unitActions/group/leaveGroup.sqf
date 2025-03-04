// scripts/actions/unitActions/group/leaveGroup.sqf
params ["_unit", "_selections"];

if !(_unit isKindOf "CAManBase") exitWith {
    systemChat "Not a person!";
};

// Check if unit is already alone
if (count (units group _unit) <= 1) exitWith {
    systemChat format ["%1 is already alone", name _unit];
};

// Get current group info for feedback
private _oldGroup = group _unit;
private _oldGroupId = groupId _oldGroup;

// Create new group for unit
[_unit] joinSilent grpNull;

// Don't change the unit's rank when leaving a group

// Provide feedback
systemChat format ["%1 has left %2", name _unit, _oldGroupId];