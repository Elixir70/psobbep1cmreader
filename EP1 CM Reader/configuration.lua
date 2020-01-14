-- EP1 CM Wave Reader Configuration -- Configuration window for the addon

local function ConfigurationWindow(configuration, addonName)
    local this = 
    {
        title = addonName .. " - Configuration",
        open = false,
        changed = true,
    }

    local _configuration = configuration

    local _showWindowSettings = function()
        local success
        local anchorList =
        {
            "Top Left (Disabled)", "Left", "Bottom Left",
            "Top", "Center", "Bottom",
            "Top Right", "Right", "Bottom Right",
        }

        if imgui.Checkbox("Enable", _configuration.enable) then
            _configuration.enable = not _configuration.enable
            this.changed = true
        end

        if imgui.Checkbox("No title bar", _configuration.noTitleBar == "NoTitleBar") then
            if _configuration.noTitleBar == "NoTitleBar" then
                _configuration.noTitleBar = ""
            else
                _configuration.noTitleBar = "NoTitleBar"
            end
            this.changed = true
        end
        
        if imgui.Checkbox("No resize", _configuration.noResize == "NoResize") then
            if _configuration.noResize == "NoResize" then
                _configuration.noResize = ""
            else
                _configuration.noResize = "NoResize"
            end
            this.changed = true
        end

        if imgui.Checkbox("No move", _configuration.noMove == "NoMove") then
            if _configuration.noMove == "NoMove" then
                _configuration.noMove = ""
            else
                _configuration.noMove = "NoMove"
            end
            this.changed = true
        end

        if imgui.Checkbox("Always Auto Resize", _configuration.AlwaysAutoResize == "AlwaysAutoResize") then
            if _configuration.AlwaysAutoResize == "AlwaysAutoResize" then
                _configuration.AlwaysAutoResize = ""
            else
                _configuration.AlwaysAutoResize = "AlwaysAutoResize"
            end
            this.changed = true
        end

        if imgui.Checkbox("Transparent window", _configuration.transparentWindow) then
            _configuration.transparentWindow = not _configuration.transparentWindow
            this.changed = true
        end
            
        imgui.Text("Position and Size")
        imgui.PushItemWidth(0.50 * imgui.GetWindowWidth())
        success, _configuration.anchor = imgui.Combo("Anchor", _configuration.anchor, anchorList, table.getn(anchorList))
        imgui.PopItemWidth()
        if success then
            _configuration.changed = true
            this.changed = true
        end

        imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
        success, _configuration.X = imgui.InputInt("X", _configuration.X)
        imgui.PopItemWidth()
        if success then
            _configuration.changed = true
            this.changed = true
        end

        imgui.SameLine(0, 0)
        imgui.SetCursorPosX(0.50 * imgui.GetWindowWidth())
        imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
        success, _configuration.Y = imgui.InputInt("Y", _configuration.Y)
        imgui.PopItemWidth()
        if success then
            _configuration.changed = true
            this.changed = true
        end

        imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
        success, _configuration.W = imgui.InputInt("Width", _configuration.W)
        imgui.PopItemWidth()
        if success then
            _configuration.changed = true
            this.changed = true
        end

        imgui.SameLine(0, 0)
        imgui.SetCursorPosX(0.50 * imgui.GetWindowWidth())
        imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
        success, _configuration.H = imgui.InputInt("Height", _configuration.H)
        imgui.PopItemWidth()
        if success then
            _configuration.changed = true
            this.changed = true
        end

        if imgui.TreeNodeEx("Monster Counts Window") then
            if imgui.Checkbox("Enable Monster Counts", _configuration.countsEnable) then
                _configuration.countsEnable = not _configuration.countsEnable
                this.changed = true
            end

            if imgui.Checkbox("Show Individual Monsters in Wave", _configuration.countsIndividual) then
                _configuration.countsIndividual = not _configuration.countsIndividual
                this.changed = true
            end

            if imgui.Checkbox("Enable Debug Mode", _configuration.countsDebug) then
                _configuration.countsDebug = not _configuration.countsDebug
                this.changed = true
            end
            
            if imgui.Checkbox("No title bar", _configuration.countsNoTitleBar == "NoTitleBar") then
                if _configuration.countsNoTitleBar == "NoTitleBar" then
                    _configuration.countsNoTitleBar = ""
                else
                    _configuration.countsNoTitleBar = "NoTitleBar"
                end
                this.changed = true
            end
            
            if imgui.Checkbox("No resize", _configuration.countsNoResize == "NoResize") then
                if _configuration.countsNoResize == "NoResize" then
                    _configuration.countsNoResize = ""
                else
                    _configuration.countsNoResize = "NoResize"
                end
                this.changed = true
            end
    
            if imgui.Checkbox("No move", _configuration.countsNoMove == "NoMove") then
                if _configuration.countsNoMove == "NoMove" then
                    _configuration.countsNoMove = ""
                else
                    _configuration.countsNoMove = "NoMove"
                end
                this.changed = true
            end
    
            if imgui.Checkbox("Always Auto Resize", _configuration.countsAlwaysAutoResize == "AlwaysAutoResize") then
                if _configuration.countsAlwaysAutoResize == "AlwaysAutoResize" then
                    _configuration.countsAlwaysAutoResize = ""
                else
                    _configuration.countsAlwaysAutoResize = "AlwaysAutoResize"
                end
                this.changed = true
            end
    
            if imgui.Checkbox("Transparent window", _configuration.countsTransparentWindow) then
                _configuration.countsTransparentWindow = not _configuration.countsTransparentWindow
                this.changed = true
            end
                
            imgui.Text("Position and Size")
            imgui.PushItemWidth(0.50 * imgui.GetWindowWidth())
            success, _configuration.countsAnchor = imgui.Combo("Anchor", _configuration.countsAnchor, anchorList, table.getn(anchorList))
            imgui.PopItemWidth()
            if success then
                _configuration.changed = true
                this.changed = true
            end
    
            imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
            success, _configuration.countsX = imgui.InputInt("X", _configuration.countsX)
            imgui.PopItemWidth()
            if success then
                _configuration.changed = true
                this.changed = true
            end
    
            imgui.SameLine(0, 0)
            imgui.SetCursorPosX(0.50 * imgui.GetWindowWidth())
            imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
            success, _configuration.countsY = imgui.InputInt("Y", _configuration.countsY)
            imgui.PopItemWidth()
            if success then
                _configuration.changed = true
                this.changed = true
            end
    
            imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
            success, _configuration.countsW = imgui.InputInt("Width", _configuration.countsW)
            imgui.PopItemWidth()
            if success then
                _configuration.changed = true
                this.changed = true
            end
    
            imgui.SameLine(0, 0)
            imgui.SetCursorPosX(0.50 * imgui.GetWindowWidth())
            imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
            success, _configuration.countsH = imgui.InputInt("Height", _configuration.countsH)
            imgui.PopItemWidth()
            if success then
                _configuration.changed = true
                this.changed = true
            end
        end
    end

    this.Update = function()
        if this.open == false then
            return
        end

        local success

        imgui.SetNextWindowSize(500, 400, 'FirstUseEver')
        success, this.open = imgui.Begin(this.title, this.open)

        _showWindowSettings()

        imgui.End()
    end

    return this
end

return 
{
    ConfigurationWindow = ConfigurationWindow,
}
