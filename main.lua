--[[
Netatmo Temperature Sensor
@author ikubicki
]]

function QuickApp:onInit()
    self.config = Config:new(self)
    self.auth = Auth:new(self.config)
    self.http = HTTPClient:new({
        baseUrl = 'https://api.netatmo.com/api'
    })
    self.i18n = i18n:new(api.get("/settings/info").defaultLanguage)
    self:trace('')
    self:trace('Netatmo temperature sensor')
    self:trace('User:', self.config:getUsername())
    self:updateProperty('manufacturer', 'Netatmo')
    self:updateProperty('manufacturer', 'Temperature sensor')
    self:run()
    self:updateView("label2", "text", string.format(self.i18n:get('temperature'), 0))
    self.prompted = false
end

function QuickApp:run()
    self:pullNetatmoData()
    local interval = self.config:getTimeoutInterval()
    if (interval > 0) then
        fibaro.setTimeout(interval, function() self:run() end)
    end
end

function QuickApp:pullNetatmoData()
    local url = '/getstationsdata'
    self:updateView("button1", "text", self.i18n:get('please-wait'))
    if string.len(self.config:getDeviceID()) > 3 then
        -- QuickApp:debug('Pulling data for device ' .. self.config:getDeviceID())
        url = url .. '?device_id=' .. self.config:getDeviceID()
    else
        -- QuickApp:debug('Pulling data')
    end
    local callback = function(response)
        local data = json.decode(response.data)
        if data.error and data.error.message then
            QuickApp:error(data.error.message)
            return false
        end

        local device = data.body.devices[1]
        local sensor = nil
        local sensors = {}
        device.moduleID = nil
        device.name = string.format(self.i18n:get('station'), device.station_name)
        sensors[#sensors + 1] = device

        for _, deviceModule in pairs(device.modules) do
            if deviceModule.type == "NAModule1" or deviceModule.type == "NAModule4" then
                if string.len(self.config:getModuleID()) > 3 and self.config:getModuleID() == deviceModule["_id"] then
                    sensor = deviceModule
                end
                deviceModule.moduleID = deviceModule['_id']
                deviceModule.name = string.format(self.i18n:get('module'), deviceModule.module_name)
                sensors[#sensors + 1] = deviceModule
            end
        end
        if sensor == nil then
            sensor = device
        end

        if self.prompted == false and #sensors > 1 then 
            self.prompted = true
            self:warning(string.format(self.i18n:get('detected_devices'), #sensors))
            for _, sensorInfo in pairs(sensors) do
                local moduleInfo = ' [leave module ID empty]'
                if sensorInfo.moduleID then
                    moduleInfo = ' [module ID: ' .. sensorInfo.moduleID .. ']'
                end
                self:trace(sensorInfo.name .. moduleInfo)
            end
        end

        if sensor ~= nil then

            self:trace('[' .. sensor['_id'] .. '] Temperature sensor information updated')
            self:updateView("label1", "text", string.format(self.i18n:get('last-update'), os.date('%Y-%m-%d %H:%M:%S')))
            self:updateView("label2", "text", string.format(self.i18n:get('temperature'), sensor.dashboard_data.Temperature))
            self:updateView("label3", "text", string.format(self.i18n:get('sensor'), sensor.name))
            self:updateView("button1", "text", self.i18n:get('refresh'))

            self:updateProperty('value', sensor.dashboard_data.Temperature)
            self:updateProperty('unit', '°')
            
            if string.len(self.config:getDeviceID()) < 4 then
                self.config:setDeviceID(device["_id"])
            end
        else
            self:error('Unable to retrieve sensor data')
        end
    end
    
    self.http:get(url, callback, nil, self.auth:getHeaders({}))
    
    return {}
end

function QuickApp:button1Event()
    self:pullNetatmoData()
end
