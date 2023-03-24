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
  
  PC Control Device - HTTP Communications module

--]]
local cosock = require "cosock"
local socket = require "cosock.socket"
local http = cosock.asyncify "socket.http"
http.TIMEOUT = 3
local ltn12 = require "ltn12"
local log = require "log"

local function validate_address(lanAddress)

  local valid = true
  
  local ip = lanAddress:match('^(%d.+):')
  local port = tonumber(lanAddress:match(':(%d+)$'))
  
  if ip then
    local chunks = {ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
    if #chunks == 4 then
      for _, v in pairs(chunks) do
        if tonumber(v) > 255 then 
          valid = false
          break
        end
      end
    else
      valid = false
    end
  else
    valid = false
  end
  
  if port then
    if type(port) == 'number' then
      if (port < 1) or (port > 65535) then 
        valid = false
      end
    else
      valid = false
    end
  else
    valid = false
  end
  
  if valid then
    return ip, port
  else
    return nil
  end
      
end


return {

	issue_request = function(req_method, ip, endpoint, sendbody)

		if validate_address(ip) == false then; return; end

		local responsechunks = {}

		local sendurl = 'http://' .. ip .. endpoint
		
		log.info ('Sending HTTP request:', sendurl)
		
		local ret, code, headers, status
	 
		if sendbody then
			local sendheaders = {
														["Acccept"] = '*/*',
														["Content-Length"] = #sendbody,
													}
			ret, code, headers, status = http.request {
				method = req_method,
				url = sendurl,
				headers = sendheaders,
				source = ltn12.source.string(sendbody),
				sink = ltn12.sink.table(responsechunks)
			}   
			
		else
			local sendheaders = {
														["Accept"] = '*/*'
													}
			
			ret, code, headers, status = http.request {
				method = req_method,
				url = sendurl,
				sink = ltn12.sink.table(responsechunks),
				headers = sendheaders
			}
			
			--log.debug ("HTTP ret:", ret)
			--log.debug ("HTTP code:", code) 
			
		end
		
		local response = table.concat(responsechunks)
		
		--log.debug ('HTTP response:', response)
		
		if ret then
			if code == 200 then
			
				return true, response
				
			end
		end
				
		log.warn (string.format('HTTP request failed: code=%s, status=%s, response=%s', code, status, response))
		return false, code
		
	end

}
