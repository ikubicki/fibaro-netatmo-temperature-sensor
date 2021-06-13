--[[
Netatmo authentication class
@author ikubicki
]]
class 'Auth'

function Auth:new(config)
    -- QuickApp:debug('Auth:new')
    self.config = config
    self:init()
    return self
end

function Auth:getHeaders(headers)
    local token = self:getToken()
    if string.len(token) > 0 then
        headers['Authorization'] = 'Bearer ' .. token
    end
    return headers
end

function Auth:getToken()
    local timestamp = os.time(os.date("!*t"))
    local cache = Globals:get('netatmo_token')
    -- QuickApp:debug(json.encode(cache))
    if cache then
        if cache and cache.token and (cache.expire < timestamp or cache.clientID ~= self.config:getClientID()) then
            QuickApp:debug('Regenerating auth token')
            self:authenticate()
            local cache = Globals:get('netatmo_token')
            if cache and cache.token and cache.expire > timestamp and cache.clientID == self.config:getClientID() then
                return cache.token
            else
                QuickApp:error('Cached auth token seems to be invalid!')
                QuickApp:debug(json.encode(cache))
            end
        end
        QuickApp:debug('Using cached token')
        return cache.token
    end
    return ""
end

function Auth:init()
    
    -- QuickApp:debug('Auth:init')
    local timestamp = os.time(os.date("!*t"))
    local cache = Globals:get('netatmo_token')
    if cache and cache.token and cache.expire > timestamp and cache.clientID == self.config:getClientID() then
        QuickApp:debug('Reusing auth token')
        return true
    end
    
    self:authenticate()
    fibaro.setTimeout(300000, function() self:init() end)
end

function Auth:authenticate()
    -- QuickApp:debug('Auth:authenticate')
    local timestamp = os.time(os.date("!*t"))
    local http = HTTPClient:new()
    local data = {
        ["grant_type"] = 'password',
        ["scope"] = 'read_station',
        ["client_id"] = self.config:getClientID(),
        ["client_secret"] = self.config:getClientSecret(),
        ["username"] = self.config:getUsername(),
        ["password"] = self.config:getPassword(),
    }
    -- QuickApp:debug(json.encode(data))
    local callback = function(response)
        local data = json.decode(response.data)
        QuickApp:debug('Authenticated (' .. string.sub(data.access_token, -8) .. ')')
        Globals:set('netatmo_token', {
            clientID = self.config:getClientID(),
            expire = timestamp + data.expires_in - 1000,
            token = data.access_token,
        })
    end
    local err = function(response)
        QuickApp:error('Authentication error: ' .. json.encode(response))
        Globals:set('netatmo_token', {
            clientID = '',
            expire = os.time(os.date("!*t")) - 1000,
            token = '',
        })
    end
    http:postForm('https://api.netatmo.net/oauth2/token', data, callback, err)
end