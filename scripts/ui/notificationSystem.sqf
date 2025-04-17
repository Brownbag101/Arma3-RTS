// scripts/ui/notificationSystem.sqf
// Centralized notification system for RTS UI
// Displays non-blocking hints with fade effect

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE NOTIFICATION BEHAVIOR ===
RTS_NOTIFICATION_DURATION = 5;        // Duration in seconds before fade begins
RTS_NOTIFICATION_FADE_TIME = 1;       // Fade out duration in seconds
RTS_NOTIFICATION_DEFAULT_COLOR = "#FFFFFF";  // Default text color (white)
RTS_NOTIFICATION_WARNING_COLOR = "#FFA500";  // Warning text color (orange)
RTS_NOTIFICATION_ERROR_COLOR = "#FF0000";    // Error text color (red)
RTS_NOTIFICATION_SUCCESS_COLOR = "#00FF00";  // Success text color (green)
RTS_NOTIFICATION_INFO_COLOR = "#00BFFF";     // Info text color (light blue)

// Array to store notification controls for cleanup
if (isNil "RTS_notificationControls") then {
    RTS_notificationControls = [];
};

// Track notification layer
if (isNil "RTS_notificationLayer") then {
    RTS_notificationLayer = ["RTS_Notification"] call BIS_fnc_rscLayer;
};

// Main notification function - call this from other scripts
// Example: ["Vehicle repaired successfully!", "success"] call RTS_fnc_showNotification;
RTS_fnc_showNotification = {
    params [
        ["_message", "No message provided", [""]],
        ["_type", "default", [""]],
        ["_duration", RTS_NOTIFICATION_DURATION, [0]]
    ];
    
    // Select color based on notification type
    private _color = switch (toLower _type) do {
        case "warning": { RTS_NOTIFICATION_WARNING_COLOR };
        case "error": { RTS_NOTIFICATION_ERROR_COLOR };
        case "success": { RTS_NOTIFICATION_SUCCESS_COLOR };
        case "info": { RTS_NOTIFICATION_INFO_COLOR };
        default { RTS_NOTIFICATION_DEFAULT_COLOR };
    };
    
    // Clean up existing notifications to prevent overlapping
    call RTS_fnc_clearNotifications;
    
    // Create display using the notification layer
    RTS_notificationLayer cutRsc ["RscTitleDisplayEmpty", "PLAIN", -1, false];
    private _display = uiNamespace getVariable "RscTitleDisplayEmpty";
    
    if (isNull _display) exitWith {
        diag_log "Notification System: Failed to create display for notification";
    };
    
    // Create notification background
    private _background = _display ctrlCreate ["RscText", -1];
    private _bgWidth = 0.4 * safezoneW;
    private _bgHeight = 0.08 * safezoneH;
    
    _background ctrlSetPosition [
        safezoneX + (safezoneW - _bgWidth) / 2,  // Centered horizontally
        safezoneY + (safezoneH - _bgHeight) / 2, // Centered vertically
        _bgWidth,
        _bgHeight
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _background ctrlCommit 0;
    RTS_notificationControls pushBack _background;
    
    // Create notification text
    private _textCtrl = _display ctrlCreate ["RscStructuredText", -1];
    _textCtrl ctrlSetPosition [
        safezoneX + (safezoneW - _bgWidth) / 2,
        safezoneY + (safezoneH - _bgHeight) / 2,
        _bgWidth,
        _bgHeight
    ];
    
    // Format message with HTML
    _textCtrl ctrlSetStructuredText parseText format [
        "<t align='center' size='1.2' color='%1'>%2</t>",
        _color,
        _message
    ];
    
    _textCtrl ctrlCommit 0;
    RTS_notificationControls pushBack _textCtrl;
    
    // Schedule notification removal with fade effect
    [_duration, _display] spawn {
        params ["_duration", "_display"];
        
        // Wait for specified duration
        sleep _duration;
        
        // Check if display still exists
        if (isNull _display) exitWith {};
        
        // Simple fade using cutText
        RTS_notificationLayer cutText ["", "PLAIN", RTS_NOTIFICATION_FADE_TIME];
        
        // Clear after fade
        sleep RTS_NOTIFICATION_FADE_TIME;
        call RTS_fnc_clearNotifications;
    };
    
    // Return true to indicate successful display
    true
};

// Clear all notification controls
RTS_fnc_clearNotifications = {
    {
        ctrlDelete _x;
    } forEach RTS_notificationControls;
    
    RTS_notificationControls = [];
    
    // Hide the layer
    RTS_notificationLayer cutText ["", "PLAIN"];
};

// Variant function for simple text hints (compatibility with existing code)
RTS_fnc_showHint = {
    params [
        ["_message", "No message provided", [""]],
        ["_duration", RTS_NOTIFICATION_DURATION, [0]]
    ];
    
    [_message, "default", _duration] call RTS_fnc_showNotification;
};

// Warning notification shortcut
RTS_fnc_showWarning = {
    params [
        ["_message", "Warning!", [""]],
        ["_duration", RTS_NOTIFICATION_DURATION, [0]]
    ];
    
    [_message, "warning", _duration] call RTS_fnc_showNotification;
};

// Error notification shortcut
RTS_fnc_showError = {
    params [
        ["_message", "Error!", [""]],
        ["_duration", RTS_NOTIFICATION_DURATION, [0]]
    ];
    
    [_message, "error", _duration] call RTS_fnc_showNotification;
};

// Success notification shortcut
RTS_fnc_showSuccess = {
    params [
        ["_message", "Success!", [""]],
        ["_duration", RTS_NOTIFICATION_DURATION, [0]]
    ];
    
    [_message, "success", _duration] call RTS_fnc_showNotification;
};

// Info notification shortcut
RTS_fnc_showInfo = {
    params [
        ["_message", "Information", [""]],
        ["_duration", RTS_NOTIFICATION_DURATION, [0]]
    ];
    
    [_message, "info", _duration] call RTS_fnc_showNotification;
};

// Log to system chat as well as show notification (for important messages)
RTS_fnc_logAndNotify = {
    params [
        ["_message", "No message provided", [""]],
        ["_type", "info", [""]],
        ["_duration", RTS_NOTIFICATION_DURATION, [0]]
    ];
    
    // Show in system chat
    systemChat _message;
    
    // Also show notification
    [_message, _type, _duration] call RTS_fnc_showNotification;
};