params ["_unit"];

systemChat format ["%1 is using Scouting ability!", name _unit];

private _range = 500;
private _nearEnemies = _unit nearEntities [["Man", "Car", "Tank"], _range];

{
    if (side _x != side _unit) then {
        _x setVariable ["revealed", true];
        systemChat format ["Found enemy: %1", typeOf _x];
    };
} forEach _nearEnemies;