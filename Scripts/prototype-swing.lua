-- This script is a simulation control script written for the V-REP simulation software.
-- It is intended to control the behavior of a simulated arm with a joint.

-- Get a handle to the arm actuator object:
arm = sim.getObjectHandle('Arm_actuator')

function sysCall_init()
    -- Create a coroutine called "coroutineMain":
    corout = coroutine.create(coroutineMain)
    
    -- Create a user interface (UI) using XML code:
    xml = [[
        <ui title="Crane Control" closeable="true" resizable="false" activate="false">
            <group layout="form" flat="true">
                <label text="Arm velocity (m/s): 0.00" id="1"/>
                <hslider tick-position="above" tick-interval="1" minimum="0" maximum="10" on-change="ArmActuator" id="2"/>
                <label text="Velocity" id="3"/>
                <button text="Deactivated" on-click="Velocity_enabled" checkable="true" id="4"/>
                <label text="Force" id="5"/>
                <button text="Deactivated" on-click="Force_enabled" checkable="true" id="6"/>
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
-- It contains the main loop of the script, which sets the joint target velocity and target force to the values specified by the user via the UI.
function coroutineMain()
    -- Initialize the "velocity_enabled" and "force_enabled" variables.
    velocity_enabled = false
    force_enabled = false
    -- Initialize the "velocity" and "torque" variables.
    velocity = 0
    torque = 100000
    friction = 1000

    -- The main loop of the script.
    while true do
        -- If the "velocity_enabled" variable is true, set the joint target velocity to the value specified by the user.
        if velocity_enabled then
            sim.setJointTargetVelocity(arm, velocity)
        else
            sim.setJointTargetVelocity(arm, 0)
        end
        
        -- If the "force_enabled" variable is true, set the joint target force to the value specified by the user.
        if force_enabled then
            sim.setJointTargetForce(arm, torque)
        else
            sim.setJointTargetForce(arm, friction)
        end
    end
end

-- The ArmActuator function is called when the arm velocity slider is changed:
function ArmActuator(ui, id, newVal)
    -- Set the "velocity" variable to the new slider value:
    velocity = newVal 
    -- Set the joint target velocity to the new value:
    sim.setJointTargetVelocity(arm, velocity)
    -- Update the label text to show the new arm velocity:
    simUI.setLabelText(ui, 1, string.format("Arm velocity (m/s): %.2f", velocity))
end

-- The Velocity_enabled function is called when the "Velocity" button is clicked:
function Velocity_enabled(ui)
    -- Toggle the value of the "velocity_enabled" variable.
    if velocity_enabled then
        velocity_enabled = false
        -- Update the text on the button to reflect the current state.
        simUI.setButtonText(ui, 4, "Deactivated")
    else
        velocity_enabled = true
        -- Update the text on the button to reflect the current state.
        simUI.setButtonText(ui, 4, "Activated")
    end
end

-- The Force_enabled function is called when the "Force" button is clicked:
function Force_enabled(ui)
    -- Toggle the value of the "force_enabled" variable.
    if force_enabled then
        force_enabled = false
        -- Update the text on the button to reflect the current state.
        simUI.setButtonText(ui, 6, "Deactivated")
    else
        force_enabled = true
        -- Update the text on the button to reflect the current state.
        simUI.setButtonText(ui, 6, "Activated")
    end
end
