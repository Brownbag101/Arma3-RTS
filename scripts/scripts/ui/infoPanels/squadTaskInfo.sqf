// scripts\ui\infoPanels\squadTaskInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

private _group = group _unit;
if (isNull _group) exitWith {
    _ctrl ctrlSetText "Task: None";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Get current task information
private _taskInfo = "None";
private _taskState = "";
private _color = [0.7, 0.7, 0.7, 1]; // Default gray

try {
    // Try to get assigned tasks - use unit instead of group
    private _currentTask = currentTask _unit;  // Change this to use unit instead of group
    
    if (isNull _currentTask) then {
        // Try alternative method
        private _allTasks = simpleTasks _unit;
        if (count _allTasks > 0) then {
            _currentTask = _allTasks select 0;
        };
    };
    
    if (!isNull _currentTask) then {
        // Get task description
        private _description = taskDescription _currentTask;
        if (count _description > 0) then {
            _taskInfo = _description select 0;
            if (_taskInfo == "") then {
                _taskInfo = getText(configFile >> "CfgTaskTypes" >> taskType _currentTask >> "displayName");
                if (_taskInfo == "") then {
                    _taskInfo = format ["Task %1", taskName _currentTask];
                };
            };
        };
        
        // Get task state
        _taskState = taskState _currentTask;
        
        // Set appropriate color based on task state
        _color = switch (_taskState) do {
            case "SUCCEEDED": { [0.2, 0.8, 0.2, 1] }; // Green
            case "FAILED": { [0.8, 0.2, 0.2, 1] }; // Red
            case "CANCELED": { [0.5, 0.5, 0.5, 1] }; // Gray
            default { [0.9, 0.8, 0.1, 1] }; // Yellow (in progress)
        };
    };
} catch {
    // If task functions aren't available, show a simpler message
    _taskInfo = "No Task System";
};

_ctrl ctrlSetText format ["Task: %1%2", _taskInfo, if (_taskState != "") then {format [" [%1]", _taskState]} else {""}];
_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;