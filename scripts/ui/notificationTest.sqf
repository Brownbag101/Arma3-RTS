// scripts/ui/notificationTest.sqf
// Test script for notification system

// Wait to ensure notification system is loaded
waitUntil {!isNil "RTS_fnc_showNotification"};

// Test different notification types with increasing delays
[] spawn {
    // Default notification
    ["Default notification test", "default"] call RTS_fnc_showNotification;
    sleep 9;
    
    // Success notification
    ["Operation successful!", "success"] call RTS_fnc_showNotification;
    sleep 9;
    
    // Info notification
    ["Enemy units spotted near objective", "info"] call RTS_fnc_showNotification;
    sleep 9;
    
    // Warning notification
    ["Low fuel warning for selected vehicle", "warning"] call RTS_fnc_showNotification;
    sleep 9;
    
    // Error notification
    ["Insufficient resources for construction", "error"] call RTS_fnc_showNotification;
    sleep 9;
    
    // Using shortcut functions
    ["This is a direct warning message"] call RTS_fnc_showWarning;
    sleep 9;
    
    // Log and notify
    ["Important message in both system chat and notification", "info"] call RTS_fnc_logAndNotify;
    
    // Show a longer message to test text wrapping
    sleep 9;
    ["This is a longer notification message that should wrap properly in the notification box. Testing how the system handles multi-line text content.", "default", 8] call RTS_fnc_showNotification;
};

// Return true to indicate test executed
true