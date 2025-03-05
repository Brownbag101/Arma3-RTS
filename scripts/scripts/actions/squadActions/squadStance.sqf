// scripts/actions/squadActions/squadStance.sqf
params ["_unit", "_selections"];

// Create dialog to select stance for all units
if (!isNull findDisplay 312) then {
    private _display = findDisplay 312;
    
    // Create background
    private _bg = _display ctrlCreate ["RscText", -1];
    _bg ctrlSetPosition [
        safezoneX + 0.4 * safezoneW,
        safezoneY + 0.4 * safezoneH,
        0.2 * safezoneW,
        0.2 * safezoneH
    ];
    _bg ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _bg ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [
        safezoneX + 0.4 * safezoneW,
        safezoneY + 0.4 * safezoneH,
        0.2 * safezoneW,
        0.03 * safezoneH
    ];
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.8];
    _title ctrlSetText "Select Squad Stance";
    _title ctrlCommit 0;
    
    // Create stance buttons
    private _btnSize = 0.05 * safezoneH;
    private _btnY = safezoneY + 0.45 * safezoneH;
    
    // Stand Button
    private _standBtn = _display ctrlCreate ["RscButton", -1];
    _standBtn ctrlSetPosition [
        safezoneX + 0.425 * safezoneW,
        _btnY,
        0.15 * safezoneW,
        _btnSize
    ];
    _standBtn ctrlSetText "STAND";
    _standBtn ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];
        private _selections = _ctrl getVariable "selections";
        
        {
            _x setUnitPos "UP";
        } forEach _selections;
        
        systemChat format ["Set %1 units to STANDING stance", count _selections];
        
        // Close dialog
        {
            ctrlDelete _x;
        } forEach (_ctrl getVariable "dialogControls");
    }];
    _standBtn setVariable ["selections", _selections];
    _standBtn ctrlCommit 0;
    
    // Crouch Button
    private _crouchBtn = _display ctrlCreate ["RscButton", -1];
    _crouchBtn ctrlSetPosition [
        safezoneX + 0.425 * safezoneW,
        _btnY + _btnSize + 0.01,
        0.15 * safezoneW,
        _btnSize
    ];
    _crouchBtn ctrlSetText "CROUCH";
    _crouchBtn ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];
        private _selections = _ctrl getVariable "selections";
        
        {
            _x setUnitPos "MIDDLE";
        } forEach _selections;
        
        systemChat format ["Set %1 units to CROUCH stance", count _selections];
        
        // Close dialog
        {
            ctrlDelete _x;
        } forEach (_ctrl getVariable "dialogControls");
    }];
    _crouchBtn setVariable ["selections", _selections];
    _crouchBtn ctrlCommit 0;
    
    // Prone Button
    private _proneBtn = _display ctrlCreate ["RscButton", -1];
    _proneBtn ctrlSetPosition [
        safezoneX + 0.425 * safezoneW,
        _btnY + (_btnSize + 0.01) * 2,
        0.15 * safezoneW,
        _btnSize
    ];
    _proneBtn ctrlSetText "PRONE";
    _proneBtn ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];
        private _selections = _ctrl getVariable "selections";
        
        {
            _x setUnitPos "DOWN";
        } forEach _selections;
        
        systemChat format ["Set %1 units to PRONE stance", count _selections];
        
        // Close dialog
        {
            ctrlDelete _x;
        } forEach (_ctrl getVariable "dialogControls");
    }];
    _proneBtn setVariable ["selections", _selections];
    _proneBtn ctrlCommit 0;
    
    // Store all controls for cleanup
    private _dialogControls = [_bg, _title, _standBtn, _crouchBtn, _proneBtn];
    
    // Share dialog controls with all buttons for cleanup
    _standBtn setVariable ["dialogControls", _dialogControls];
    _crouchBtn setVariable ["dialogControls", _dialogControls];
    _proneBtn setVariable ["dialogControls", _dialogControls];