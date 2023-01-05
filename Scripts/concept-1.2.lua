-- This script is used in a simulation software called V-REP.
-- It is used to control a joint, called "Cradle_Joint", in the simulation.

-- This function is called by V-REP when the simulation starts.
function sysCall_init()
    -- A coroutine is a special kind of function that can be paused and resumed.
    -- They are useful for creating long-running processes that don't block the main program.
    -- Create a coroutine and start it.
    corout = coroutine.create(coroutineMain)

    -- Create a user interface (UI) using XML code.
    xml = [[
        <ui title="Cradle Control" closeable="true" resizable="false" activate="false">
            <group layout="form" flat="true">
                <label text="Cradle max position (m): 0.00" id="1"/>
                <hslider tick-position="above" tick-interval="1" minimum="0" maximum="10" on-change="Position" id="2"/>
                <label text="Cradle max velocity (m/s): 0.00" id="3"/>
                <hslider tick-position="above" tick-interval="1" minimum="0" maximum="10" on-change="Velocity" id="4"/>
                <label text="Cradle" id="7"/>
                <button text="Deactivated" on-click="switch" checkable="true" id="8"/>
            </group>
            <label text="" style="* {margin-left: 400px;}"/>
        </ui>
    ]]
    ui = simUI.create(xml)
end

-- This function is called by V-REP at each simulation time step.
function sysCall_actuation()
    -- Check if the coroutine is still running.
    if coroutine.status(corout) ~= 'dead' then
        -- Resume the coroutine.
        local ok, errorMsg = coroutine.resume(corout)
        -- If there is an error in the coroutine, display an error message.
        if errorMsg then
            error(debug.traceback(corout, errorMsg), 2)
        end
    end
end

-- This function is the coroutine that is created and started in the sysCall_init function.
-- It contains the main loop of the script, which sets the joint target position to oscillate
-- between a positive and negative value.
function coroutineMain()
    -- Get the handle to the "Cradle_Joint" joint.
    cradle = sim.getObjectHandle('Cradle_Joint')
    
    -- Initialize the "previous_time" variable.
    previous_time = 0
    
    -- Initialize the "enabled" and "position" variables.
    enabled = false
    waitTime = 15
    
    -- Get the current target position and velocity of the "Cradle_Joint" joint.
    position = sim.getJointTargetPosition(cradle)
    velocity = sim.getJointTargetVelocity(cradle)
    
    -- The main loop of the script.
    while true do
        -- Check if the "enabled" variable is true.
        while enabled do
            -- Set the joint target position to the current "position" variable value.
            sim.setJointTargetPosition(cradle, position)
            
            -- Wait for the time it takes for the joint to reach the target position at its current velocity.
            sim.wait(position / velocity)
            
            -- Set the joint target position to 0.
            sim.setJointTargetPosition(cradle, 0)
            
            -- Wait for the time it takes for the joint to reach the target position at its current velocity.
            sim.wait(position / velocity)
            
            -- Get the current time and calculate the time difference from the previous loop iteration.
            current_time = simGetSimulationTime()
            dt = current_time - previous_time
            previous_time = current_time
            print("Time since last loop:", dt)
        end
    end
end


-- This function is called by V-REP when the value of a UI element, a horizontal slider, changes.
-- It updates the joint position based on the new value of the slider, and also updates a UI label
-- to display the new position.
function Position(ui, id, newVal)
    -- Calculate the new joint position from the new value of the slider.
    local val = newVal * 0.01
    position = val
    
    -- Update the UI label to display the new position.
    simUI.setLabelText(ui, 1, string.format("Cradle max position (m): %.2f", val))
end

-- This function is called by V-REP when the value of a UI element, a horizontal slider, changes.
-- It updates the joint velocity based on the new value of the slider, and also updates a UI label
-- to display the new velocity.
function Velocity(ui, id, newVal)
    -- Calculate the new joint velocity from the new value of the slider.
    local val = newVal * 0.01
    velocity = val
    
    -- Update the UI label to display the new velocity.
    simUI.setLabelText(ui, 3, string.format("Cradle max velocity (m/s): %.2f", val))
end


-- This function is called by V-REP when the user clicks a UI button.
-- It toggles the value of the "enabled" variable between "true" and "false",
-- and updates the text on the button to reflect the current state.
function switch(ui)
    -- Toggle the value of the "enabled" variable.
    if enabled then
        enabled = false
        --reset position
        sim.setJointTargetPosition(cradle, 0)
        -- Update the text on the button to reflect the current state.
        simUI.setButtonText(ui, 8, "Deactivated")
    else
        enabled = true
        -- Update the text on the button to reflect the current state.
        simUI.setButtonText(ui, 8, "Activated")
    end
end