// Add this to your zeus.sqf for debugging
if (isNull z1) then {
  diag_log "Zeus module 'z1' not found!";
} else {
  diag_log "Zeus module 'z1' exists.";
};






while {true} do {
    sleep 1;
    {
        if ((side _x) == west) then {  // Check for WEST units instead
            if ((independent knowsAbout _x) >= 2) then {
                z1 addCuratorEditableObjects [[_x], true];
            } else {
                z1 removeCuratorEditableObjects [[_x], true];
            };
        };
    } forEach allUnits;
};