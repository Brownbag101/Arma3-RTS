// scripts/actions/squadActions/squadFireAtWill.sqf
params ["_unit", "_selections"];

// Apply to all selected units
{
    _x enableAI "TARGET";
    _x enableAI "AUTOTARGET";
    _x setCombatMode "RED";
	_x setBehaviour "COMBAT";
} forEach _selections;

// Also set group combat mode if they're in the same group
private _groups = [];
{
    private _group = group _x;
    if (!isNull _group && !(_group in _groups)) then {
        _groups pushBack _group;
    };
} forEach _selections;

{
    _x setCombatMode "RED";
    systemChat format ["%1 set to Fire At Will", groupId _x];
} forEach _groups;