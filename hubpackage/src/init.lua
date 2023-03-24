--[[
  Copyright 2023 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  PC Control Device - supports WOL and Windows Remote Shutdown Manager (https://github.com/karpach/remote-shutdown-pc)

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local log = require "log"

local wol = require "wakeonlan"
local comms = require "comms"

-- Module variables
local initialized = false
local device_num = 1


-- Custom Capabilities
local cap_createdev = capabilities["partyvoice23922.createanother"]
local cap_shutdowntype = capabilities["partyvoice23922.pcshutdown"]


local function create_vdevice(driver)

  local PROFILE = 'pccontrol.v1'

  local MFG_NAME = 'SmartThings Community'
  local MODEL = 'PCControlv1'
  local VEND_LABEL = 'PC Control V1'

  log.info ('Creating PC Control device')
  create_request = true

  -- Create virtual device
  local create_device_msg = {
                              type = "LAN",
                              device_network_id = 'PCControl_' .. tostring(socket.gettime()),
                              label = 'PC Control V1_' .. tostring(device_num),
                              profile = PROFILE,
                              manufacturer = MFG_NAME,
                              model = MODEL,
                              vendor_provided_label = VEND_LABEL,
                            }
                      
  assert (driver:try_create_device(create_device_msg), "failed to create device")
        
end

local function confirm_if_on(device)

  local endpoint
  if device.preferences.secret and (device.preferences.secret ~= 'null') and (device.preferences.secret ~= '') then
    endpoint = '/' .. device.preferences.secret .. '/ping'
  else
    endpoint = '/ping'
  end

  local ok, response = comms.issue_request('GET', device.preferences.pcaddr, endpoint, nil)
  
  if ok then
    return true
  else
    return false
  end
end

local function synch_PC_state(device)

  if confirm_if_on(device) then
    if device.state_cache.main.switch.switch.value == 'off' then
      device:emit_event(capabilities.switch.switch('on'))
    end
  else
    if device.state_cache.main.switch.switch.value == 'on' then
      device:emit_event(capabilities.switch.switch('off'))
    end
  end

end

local function setup_monitor(driver, device)

  local montimer = driver:call_on_schedule(device.preferences.monfreq, function()
      synch_PC_state(device)
    end)
  device:set_field('montimer', montimer)

end

-----------------------------------------------------------------------
--										COMMAND HANDLERS
-----------------------------------------------------------------------


local function handle_createdevice(driver, device, command)

  log.debug("Create device requested", command.args.value)
  
  create_vdevice(driver)
  
end



local function handle_switch(driver, device, command)

  log.info ('Virtual switch turned >> ' .. command.command .. ' <<')
  device:emit_event(capabilities.switch.switch(command.command))
  
  local pc_is_on = confirm_if_on(device)
  
  if command.command == 'on' then
    if pc_is_on == false then
      wol.do_wakeonlan(device.preferences.macaddr, device.preferences.bcastaddr)
    else
      log.info('PC seems to already be on')
    end

  elseif command.command == 'off' then
  
    if not pc_is_on then
      log.info('PC seems to be already off')

    else
      local endpoint = '/'
      if device.preferences.secret and (device.preferences.secret ~= 'null') and (device.preferences.secret ~= '') then
        endpoint = endpoint .. device.preferences.secret .. '/'
      end
      endpoint = endpoint .. device.state_cache.main[cap_shutdowntype.ID].shutdowntype.value

      comms.issue_request('GET', device.preferences.pcaddr, endpoint, nil)
      
      if (device.state_cache.main[cap_shutdowntype.ID].shutdowntype.value == 'turnscreenoff') or
         (device.state_cache.main[cap_shutdowntype.ID].shutdowntype.value == 'lock') then
        device:emit_event(capabilities.switch.switch('on'))
      end
    end
  end
  
end 


local function handle_shutdowntype(driver, device, command)

  log.info ('Shutdown type changed to', command.args.shutdowntype)
  
  device:emit_event(cap_shutdowntype.shutdowntype(command.args.shutdowntype))

end


local function handle_refresh(driver, device, command)

  log.info ('Manual refresh requested')
  
  synch_PC_state(device)

end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
  log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")
  
  synch_PC_state(device)
  
  if device.preferences.monitor == true then
    setup_monitor(driver, device)
  end
  
  initialized = true
  
end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")
  
  device_num = device_num + 1
  
  device:emit_event(capabilities.switch.switch('off'))
  
  device:emit_event(cap_shutdowntype.shutdowntype('shutdown'))
      
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  -- Nothing to do here!

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  if device:get_field('montimer') then
    driver:cancel_timer(device:get_field('montimer'))
  end
  
  local device_list = driver:get_devices()
  
  if #device_list == 0 then
    initialized = false
  end
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

  -- Did preferences change?
  if args.old_st_store.preferences then

    if args.old_st_store.preferences.macaddr ~= device.preferences.macaddr then 
      log.info ('WOL Mac Address changed to', device.preferences.macaddr)
    elseif args.old_st_store.preferences.bcastaddr ~= device.preferences.bcastaddr then 
      log.info ('WOL Broadcast Address changed to', device.preferences.bcastaddr)
    elseif args.old_st_store.preferences.pcaddr ~= device.preferences.pcaddr then 
      log.info ('PC Address changed to', device.preferences.pcaddr)
      synch_PC_state(device)
    elseif args.old_st_store.preferences.secret ~= device.preferences.secret then 
      log.info ('Secret changed to', device.preferences.secret)
      
    elseif (args.old_st_store.preferences.monfreq ~= device.preferences.monfreq) or 
           (args.old_st_store.preferences.monitor ~= device.preferences.monitor) then 
      log.info ('Monitor enabled?', device.preferences.monitor)
      log.info ('\tMonitor frequency:', device.preferences.monfreq)
      
      if device:get_field('montimer') then
        driver:cancel_timer(device:get_field('montimer'))
      end
      if device.preferences.monitor == true then
        setup_monitor(driver, device)
      end
    end
    
  end
end


-- Create Initial Device
local function discovery_handler(driver, _, should_continue)
  
  if not initialized then
  
    create_vdevice(driver)
    
    log.debug("Exiting device creation")
    
  else
    log.info ('Device already created')
  end
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  
  capability_handlers = {
    [cap_createdev.ID] = {
      [cap_createdev.commands.push.NAME] = handle_createdevice,
    },
    [cap_shutdowntype.ID] = {
      [cap_shutdowntype.commands.setShutdownType.NAME] = handle_shutdowntype,
    },
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = handle_switch,
      [capabilities.switch.commands.off.NAME] = handle_switch,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
  }
})

log.info ('PC Control Driver V1 Starting')


thisDriver:run()
