@echo off
echo Deploying Firebase Cloud Functions for SquadSync...
echo.

cd functions
call npm install
if %errorlevel% neq 0 (
    echo Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo Dependencies installed. Deploying functions...
firebase deploy --only functions
if %errorlevel% neq 0 (
    echo Failed to deploy functions
    pause
    exit /b 1
)

echo.
echo Functions deployed successfully!
echo Timers will now run server-side even when the app is closed.
pause