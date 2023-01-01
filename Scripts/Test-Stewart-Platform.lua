function sysCall_init()
    corout=coroutine.create(coroutineMain)
    -- Initialize a coroutine to execute the actions in the coroutineMain function
end

function sysCall_actuation()
    -- Control the movement of the robotic arm:
    if coroutine.status(corout)~='dead' then
        -- If the coroutine is not finished, resume it to execute the next action
        local ok,errorMsg=coroutine.resume(corout)
        if errorMsg then
            -- If there is an error, display the error message and traceback
            error(debug.traceback(corout,errorMsg),2)
        end
    end
end

function setFk()
    -- Set the IK element flags and joint modes to use forward kinematics:
    simIK.setIkElementFlags(ikEnv,ikGroup,tipTask,0) -- disable the tip and target element
    for i=1,#motors,1 do
        simIK.setJointMode(ikEnv,simToIkMapping[motors[i]],simIK.jointmode_passive) -- set the joint mode to passive
    end
end

function setIk()
    -- Set the IK element flags and joint modes to use inverse kinematics:
    simIK.setIkElementFlags(ikEnv,ikGroup,tipTask,1) -- enable the tip and target element
    for i=1,#motors,1 do
        simIK.setJointMode(ikEnv,simToIkMapping[motors[i]],simIK.jointmode_ik)
    end
end

function coroutineMain()
    -- Create a table to store handles to the motors
    motors={}
    -- Iterate over the indices 1 to 6
    for i=1,6,1 do
        -- Get the handle to the motor with index i and store it in the table
        motors[i]=sim.getObject('./motor'..i)
    end

    -- Get the handle to the graph object
    graph=sim.getObject('./graph')
    -- Create a table to store the handles to the graph streams
    graphStreams={}
    -- Add 6 graph streams to the graph object, one for each motor
    graphStreams[1]=sim.addGraphStream(graph,'joint 1','*-1, m',0,{1,1,0})
    graphStreams[2]=sim.addGraphStream(graph,'joint 2','m',0,{0,1,0})
    graphStreams[3]=sim.addGraphStream(graph,'joint 3','m',0,{0,1,1})
    graphStreams[4]=sim.addGraphStream(graph,'joint 4','m',0,{0,0.25,1})
    graphStreams[5]=sim.addGraphStream(graph,'joint 5','m',0,{1,0,1})
    graphStreams[6]=sim.addGraphStream(graph,'joint 6','m',0,{1,0,0})

    -- Create tables to store handles to the tips and targets of the arm
    local tips={}
    local targets={}
    -- Get the handle to the base of the arm
    local base=sim.getObject('.')
    -- Iterate over the indices 1 to 5
    for i=1,5,1 do
        -- Get the handles to the tip and target of the arm segment with index i
        tips[i]=sim.getObject('./downArm'..i..'Tip')
        targets[i]=sim.getObject('./downArm'..i..'Target')
    end
    -- Get the handle to the tip and target of the end effector
    local tip=sim.getObject('./tip')
    local target=sim.getObject('./target')
    -- Get the initial pose of the end effector
    local initTipMatrix=Matrix4x4:frompose(sim.getObjectPose(tip,base))
    
    -- Create an IK environment
    ikEnv=simIK.createEnvironment()
    -- Create an IK group within the environment
    ikGroup=simIK.createIkGroup(ikEnv)
    -- Add IK elements to the group representing the positions and orientations of the arm joints and end effector
    local ikElement
    for i=1,#tips,1 do
        ikElement,simToIkMapping=simIK.addIkElementFromScene(ikEnv,ikGroup,base,tips[i],targets[i],simIK.constraint_position)
    end
    tipTask=simIK.addIkElementFromScene(ikEnv,ikGroup,base,tip,target,simIK.constraint_pose)

    -- Disable automatic thread switching
    sim.setThreadAutomaticSwitch(false)

    -- Main loop
    while true do
        -- Forward kinematics (FK) example
        --[[
        -- Set the motor positions based on the forward kinematics (FK) of the arm
        setFk()

        -- Iterate over the values of t from 0 to 2*pi in increments of 2*pi/250
        for t=0,2*math.pi,2*math.pi/250 do
            -- Set the positions of the motors using sinusoidal functions of t
            sim.setJointPosition(motors[1],0.045-0.045*math.cos(t))
            sim.setJointPosition(motors[2],-0.045+0.045*math.cos(t*2))
            sim.setJointPosition(motors[3],-0.045+0.045*math.cos(t*3))
            sim.setJointPosition(motors[4],-0.045+0.045*math.cos(t*4))
            sim.setJointPosition(motors[5],-0.045+0.045*math.cos(t*5))
            sim.setJointPosition(motors[6],-0.045+0.045*math.cos(t*6))
            -- Apply IK to the arm based on the motor positions
            simIK.applyIkEnvironmentToScene(ikEnv,ikGroup)
            -- Switch to the next thread
            sim.switchThread()
        end
        --]]
        
        -- Inverse kinematics (IK) example
        
        -- Set the target pose based on the inverse kinematics (IK) of the arm
        setIk()

        -- Iterate over the values of t from 0 to 2*pi in increments of 2*pi/100
        for t=0,2*math.pi,2*math.pi/100 do
            -- Set the pose of the target using a sinusoidal function of t
            local m=initTipMatrix*Matrix4x4:fromeuler({25*math.pi*math.sin(t)/180,0,0})
            local p=Matrix4x4:topose(m)
            sim.setObjectPose(target,base,p)
            -- Apply IK to the arm based on the target pose
            simIK.applyIkEnvironmentToScene(ikEnv,ikGroup)
            -- Switch to the next thread
            sim.switchThread()
        end

        -- Iterate over the values of t from 0 to 2*pi in increments of 2*pi/100
        for t=0,2*math.pi,2*math.pi/100 do
            -- Set the position of the target using a sinusoidal function of t
            local p=Matrix4x4:topose(initTipMatrix)
            p[1]=initTipMatrix[1][4]+0.1*math.sin(t)
            sim.setObjectPose(target,base,p)
            -- Apply IK to the arm based on the target pose
            simIK.applyIkEnvironmentToScene(ikEnv,ikGroup)
            -- Switch to the next thread
            sim.switchThread()
        end
    end
end

-- Callback function called every time the simulation is run in "sensing" mode
function sysCall_sensing()
    -- Set the value of the first graph stream to the negative position of the first motor
    sim.setGraphStreamValue(graph,graphStreams[1],-sim.getJointPosition(motors[1]))
    -- Set the value of the second graph stream to the position of the second motor
    sim.setGraphStreamValue(graph,graphStreams[2],sim.getJointPosition(motors[2]))
    -- Set the value of the third graph stream to the position of the third motor
    sim.setGraphStreamValue(graph,graphStreams[3],sim.getJointPosition(motors[3]))
    -- Set the value of the fourth graph stream to the position of the fourth motor
    sim.setGraphStreamValue(graph,graphStreams[4],sim.getJointPosition(motors[4]))
    -- Set the value of the fifth graph stream to the position of the fifth motor
    sim.setGraphStreamValue(graph,graphStreams[5],sim.getJointPosition(motors[5]))
    -- Set the value of the sixth graph stream to the position of the sixth motor
    sim.setGraphStreamValue(graph,graphStreams[6],sim.getJointPosition(motors[6]))
end