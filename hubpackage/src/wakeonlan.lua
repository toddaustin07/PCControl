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
  
  Wake-on-LAN function

--]]

-- Edge libraries
local cosock = require "cosock"                   -- cosock used only for sleep timer in this module
local socket = require "cosock.socket"
local log = require "log"


local BROADCAST_ADDR = '255.255.255.255'
local BROADCAST_PORT = 0

return {
  do_wakeonlan = function(macaddr, broadcastaddr)

    -- Validate IP:port address
    
    local broadcast_ip_chunks = {broadcastaddr:match("^(%d+).(%d+).(%d+).(%d+)%:.")}
    local broadcast_ip = broadcastaddr:match("^(.+):")

    if #broadcast_ip_chunks ~= 4 then
      log.error ('Invalid Broadcast IP address:', broadcast_ip)
      return
    end

    for _, item in pairs(broadcast_ip_chunks) do
      if tonumber(item) > 255 then
        log.error ('Invalid Broadcast IP address:', broadcast_ip)
        return
      end
    end

    local broadcast_port = tonumber(broadcastaddr:match(":(%d+)$"))
    if not broadcast_port then
      log.error ('Invalid Broadcast port number:', broadcast_port)
      return
    end
    
    -- Validate MAC address

    if string.len(macaddr) == 17 then

      local chunks = {macaddr:match("^(%x%x)-(%x%x)-(%x%x)-(%x%x)-(%x%x)-(%x%x)$")}
      
      if #chunks == 0 then
        chunks = {macaddr:match("^(%x%x):(%x%x):(%x%x):(%x%x):(%x%x):(%x%x)$")}
      end
    
      if #chunks == 6 then
    
        -- Build magic package
        
        local macbytes = ''
        
        for _, byte in ipairs(chunks) do
          macbytes = macbytes .. string.char(tonumber('0x' .. byte))
        end

        local magic_packet = ''
        
        magic_packet = string.rep(string.char(0xff),6)
        magic_packet = magic_packet .. string.rep(macbytes, 16)

        -- Broadcast magic packet

        local sock = assert(socket.udp(), "WOL socket")
        sock:setoption('broadcast', true)
        
        log.info (string.format("Sending WOL magic packet for MAC address %s to %s", macaddr, broadcastaddr))
        sock:sendto(magic_packet, broadcast_ip, broadcast_port)
        sock:close()
        
        return

      end
      
    end
    
    log.error ('Invalid MAC Address')

  end

}
