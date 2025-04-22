// scripts\ui\infoPanels\squadInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

private _group = group _unit;
if (isNull _group) exitWith {
    _ctrl ctrlSetText "Squad: None";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Get squad info - for multi-selection show the count of selected units
private _selectedUnits = curatorSelected select 0;
private _groupId = groupId _group;
private _totalInGroup = count (units _group);
private _selectedCount = 0;

if (count _selectedUnits > 1) then {
    // Count how many of the selected units belong to this group
    {
        if (group _x == _group) then {
            _selectedCount = _selectedCount + 1;
        };
    } forEach _selectedUnits;
};

// Get leader info
private _leader = leader _group;
private _leaderName = if (!isNull _leader) then { name _leader } else { "None" };
private _leaderRank = if (!isNull _leader) then { rank _leader } else { "Private" };

// Determine text to show based on selection
private _displayText = "";
if (_selectedCount > 0 && _selectedCount < _totalInGroup) then {
    _displayText = format ["Squad: %1 (%2/%3 selected)", _groupId, _selectedCount, _totalInGroup];
} else {
    _displayText = format ["Squad: %1 (%2 members)", _groupId, _totalInGroup];
};

// Add leader info
_displayText = _displayText + format [" | Leader: %1 (%2)", _leaderName, _leaderRank];

_ctrl ctrlSetText _displayText;
_ctrl ctrlSetTextColor [1, 0.8, 0.6, 1];
_ctrl ctrlShow true;