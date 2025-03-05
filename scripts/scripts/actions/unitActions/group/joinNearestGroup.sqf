// scripts/actions/unitActions/group/joinNearestGroup.sqf
params ["_unit", "_selections"];

if !(_unit isKindOf "CAManBase") exitWith {
    systemChat "Not a person!";
};

// Find nearby groups
private _nearestGroups = [];
private _nearestDistances = [];
private _radius = 100; // Search radius in meters

{
    if (_x != _unit && {side _x == side _unit} && {group _x != group _unit}) then {
        private _dist = _unit distance _x;
        if (_dist < _radius) then {
            private _grp = group _x;
            private _idx = _nearestGroups find _grp;
            
            if (_idx == -1) then {
                _nearestGroups pushBack _grp;
                _nearestDistances pushBack _dist;
            } else {
                // Update if this unit is closer
                if (_dist < (_nearestDistances select _idx)) then {
                    _nearestDistances set [_idx, _dist];
                };
            };
        };
    };
} forEach allUnits;

// No groups found
if (count _nearestGroups == 0) exitWith {
    systemChat format ["No groups found within %1m of %2", _radius, name _unit];
};

// Create pairs of groups and their distances
private _groupDistancePairs = [];
{
    _groupDistancePairs pushBack [_x, _nearestDistances select _forEachIndex];
} forEach _nearestGroups;

// Sort pairs by the distance value (lowest distance first)
_groupDistancePairs sort true;

// Get the nearest group
private _nearestGroup = (_groupDistancePairs select 0) select 0;

// Check unit's rank compared to highest rank in group
private _unitRank = rankId _unit;
private _highestRankId = -1;
private _highestRankUnit = objNull;

{
    private _rankId = rankId _x;
    if (_rankId > _highestRankId) then {
        _highestRankId = _rankId;
        _highestRankUnit = _x;
    };
} forEach units _nearestGroup;

// Join the group but preserve unit's rank
[_unit] joinSilent _nearestGroup;

// If unit is higher rank, make them leader (but don't change ranks)
if (_unitRank > _highestRankId) then {
    _nearestGroup selectLeader _unit;
    systemChat format ["%1 joined %2 and took command", name _unit, groupId _nearestGroup];
} else {
    systemChat format ["%1 joined %2", name _unit, groupId _nearestGroup];
};