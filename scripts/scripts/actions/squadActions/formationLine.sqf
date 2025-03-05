// scripts/actions/squadActions/formationLine.sqf
params ["_unit", "_selections"];

systemChat format ["Formation Line called with %1 selections", count _selections];

// When called with squad selections, set formation for whole group
if (count _selections > 1) then {
    // Identify all groups in selection
    private _groups = [];
    {
        private _group = group _x;
        if (!isNull _group && !(_group in _groups)) then {
            _groups pushBack _group;
        };
    } forEach _selections;
    
    systemChat format ["Found %1 groups in selection", count _groups];
    
    // Set formation for each group
    {
        _x setFormation "LINE";
        systemChat format ["%1 switching to LINE formation", groupId _x];
    } forEach _groups;
} else {
    // Single unit - just set formation for its group
    private _group = group _unit;
    if (!isNull _group) then {
        _group setFormation "LINE";
        systemChat format ["%1 switching to LINE formation", groupId _group];
    };
};