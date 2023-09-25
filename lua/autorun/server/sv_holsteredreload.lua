local activeTimers = {} -- stores all ongoing timers by key in table

RunConsoleCommand("sk_auto_reload_time", 10000) -- ensure unused(?) autoreload is not active

local function ReloadSound(ply, oldWeapon)
    
    if oldWeapon:IsValid() then
        weapon = tostring(oldWeapon:GetClass())
        volume = GetConVar("holsteredreload_feedback_volume"):GetInt()
        local snd
        if weapon == 'weapon_pistol' then
            snd = Sound("weapons/pistol/pistol_reload1.wav")
        elseif weapon == 'weapon_357' then
            snd = Sound("weapons/357/357_spin1.wav")
        elseif weapon == 'weapon_smg1' then
            snd = Sound("weapons/smg1/smg1_reload.wav")
        elseif weapon == 'weapon_ar2' then
            snd = Sound("weapons/ar2/ar2_reload_push.wav")
        elseif weapon == 'weapon_crossbow' then
            snd = Sound("weapons/crossbow/bolt_load1.wav")
        elseif weapon == 'weapon_rpg' then
            snd = Sound("weapons/slam/mine_mode.wav")
        else
            snd = Sound("weapons/shotgun/shotgun_cock.wav")
        end
        EmitSound(snd, ply:GetPos(), 1, CHAN_AUTO, volume/100, 120, 0, 100)
    end
end

hook.Add("PlayerSwitchWeapon", "HolsteredReload", function(ply, oldWeapon)
    if GetConVar("holsteredreload_enabled") ~= nil and GetConVar("holsteredreload_enabled"):GetInt() == 0 then return end
    timer.Simple(0.1, function()
        if IsValid(oldWeapon) and oldWeapon ~= nil then -- prevents console error
            local timerKey = ply:SteamID() .. "-" .. oldWeapon:GetClass()   -- setup key for regular holstered reload
            
            if activeTimers[timerKey] then          -- if the gun is pulled out before the timer has finished,
                timer.Remove(timerKey)              -- restart the timer
            end
            
            local reloadTime = GetConVar("holsteredreload_time_to_reload"):GetInt()
            -- TESTING:     local current_time = CurTime()
            timer.Create(timerKey, reloadTime, 1, function()        -- start reloading for the stowed gun timer
                if IsValid(ply) and IsValid(oldWeapon) and oldWeapon ~= nil and ply:GetActiveWeapon() ~= oldWeapon  then -- if the gun that was stowed is still stowed
                    -- TESTING: PrintMessage(HUD_PRINTTALK, 'reloaded '..oldWeapon:GetPrimaryAmmoType()..' '..oldWeapon:GetMaxClip1() - oldWeapon:Clip1())
                    if oldWeapon ~= nil and ply:GetAmmoCount(oldWeapon:GetPrimaryAmmoType()) > 0 and oldWeapon:Clip1() < oldWeapon:GetMaxClip1() then
                        -- reload the stowed weapon, using ammo
                        local clip, maxclip, ammotype, ammotypeCount = 0,0,0,0
                        clip = oldWeapon:Clip1()
                        maxClip = oldWeapon:GetMaxClip1()
                        ammoType = oldWeapon:GetPrimaryAmmoType()
                        ammoTypeCount = ply:GetAmmoCount(oldWeapon:GetPrimaryAmmoType())

                        local ammoNeeded = maxClip - clip
                        local ammoToConsume = math.min(ammoTypeCount, ammoNeeded)

                        oldWeapon:SetClip1(clip + ammoToConsume)
                        ply:RemoveAmmo(ammoToConsume, ammoType)

                        ReloadSound(ply, oldWeapon)
                        activeTimers[timerKey] = nil
                    else
                        timer.Remove(timerKey)
                        activeTimers[timerKey] = nil            
                    end
                end
            end)

            -- regen rpg and smg grenades stuff, timers from here are not reset if the gun is pulled out again
            if IsValid(ply) and IsValid(oldWeapon) and oldWeapon ~= nil then
                -- if rpg, regen rpg, rpg ammo < 3, and there is not already an ongoing rpg regen loop
                if oldWeapon:GetClass() == 'weapon_rpg' and oldWeapon ~= nil and GetConVar("holsteredreload_regen_rockets"):GetInt() == 1 and ply:GetAmmoCount(oldWeapon:GetPrimaryAmmoType()) < 3 and !activeTimers[timerKey..'regen'] then
                    -- start indefinite-loop count timer
                    timer.Create(timerKey..'regen', reloadTime*2, 0, function()
                        if oldWeapon ~= nil then
                            local rpgAmmo = oldWeapon:GetPrimaryAmmoType()
                            if GetConVar("ammokill_hidden") ~= nil and GetConVar("ammokill_hidden"):GetInt() == 0 then
                                ply:GiveAmmo(1, rpgAmmo, false)
                            else
                                ply:GiveAmmo(1, rpgAmmo, true)
                            end
                            ReloadSound(ply, oldWeapon)
                            if ply:GetAmmoCount(rpgAmmo) >= 3 then -- stop the timer and remove the ongoing timers table if rpg ammo >= 3
                                timer.Remove(timerKey..'regen')
                                activeTimers[timerKey..'regen'] = nil
                            end
                        else
                            timer.Remove(timerKey..'regen')
                            activeTimers[timerKey..'regen'] = nil    
                        end
                    end)
                    activeTimers[timerKey..'regen'] = true  -- a timer was created, so add it to the table
                elseif oldWeapon:GetClass() == 'weapon_smg1' and GetConVar("holsteredreload_regen_smg_grenades"):GetInt() == 1 and ply:GetAmmoCount(oldWeapon:GetSecondaryAmmoType()) < 3 and !activeTimers[timerKey..'regen'] then
                    timer.Create(timerKey..'regen', reloadTime*2, 0, function()
                        if oldWeapon ~= nil then
                            local smgGrenades = oldWeapon:GetSecondaryAmmoType()
                            if GetConVar("ammokill_hidden") ~= nil and GetConVar("ammokill_hidden"):GetInt() == 0 then
                                ply:GiveAmmo(1, smgGrenades, false)
                            else
                                ply:GiveAmmo(1, smgGrenades, true)
                            end
                            ReloadSound(ply, oldWeapon)
                            if ply:GetAmmoCount(smgGrenades) >= 3 then -- stop the timer and remove the ongoing timers table if smg grenade ammo >= 3
                                timer.Remove(timerKey..'regen')
                                activeTimers[timerKey..'regen'] = nil
                            end
                        else
                            timer.Remove(timerKey..'regen')
                            activeTimers[timerKey..'regen'] = nil    
                        end
                    end)
                    activeTimers[timerKey..'regen'] = true -- a timer was created, so add it to the table
                elseif oldWeapon:GetClass() == 'weapon_frag' and GetConVar("holsteredreload_regen_frag_grenades"):GetInt() == 1 and ply:GetAmmoCount(oldWeapon:GetPrimaryAmmoType()) < 3 and !activeTimers[timerKey..'regen'] then
                    timer.Create(timerKey..'regen', reloadTime*2, 0, function()
                        if oldWeapon ~= nil then
                            local fragGrenades = 10
                            if GetConVar("ammokill_hidden") ~= nil and GetConVar("ammokill_hidden"):GetInt() == 0 then
                                ply:GiveAmmo(1, fragGrenades, false)
                            else
                                ply:GiveAmmo(1, fragGrenades, true)
                            end
                            ReloadSound(ply, oldWeapon)
                            if ply:GetAmmoCount(fragGrenades) >= 3 then -- stop the timer and remove the ongoing timers table if frags >= 3
                                timer.Remove(timerKey..'regen')
                                activeTimers[timerKey..'regen'] = nil
                            end
                        else
                            timer.Remove(timerKey..'regen')
                            activeTimers[timerKey..'regen'] = nil    
                        end
                    end)
                    activeTimers[timerKey..'regen'] = true -- a timer was created, so add it to the table
                elseif oldWeapon:GetClass() == 'weapon_ar2' and GetConVar("holsteredreload_regen_combine_balls"):GetInt() == 1 and ply:GetAmmoCount(oldWeapon:GetSecondaryAmmoType()) < 3 and !activeTimers[timerKey..'regen'] then
                    timer.Create(timerKey..'regen', reloadTime*2, 0, function()
                        if oldWeapon ~= nil then
                            local combine_balls = oldWeapon:GetSecondaryAmmoType()
                            if GetConVar("ammokill_hidden") ~= nil and GetConVar("ammokill_hidden"):GetInt() == 0 then
                                ply:GiveAmmo(1, combine_balls, false)
                            else
                                ply:GiveAmmo(1, combine_balls, true)
                            end
                            ReloadSound(ply, oldWeapon)
                            if ply:GetAmmoCount(combine_balls) >= 3 then -- stop the timer and remove the ongoing timers table if smg grenade ammo >= 3
                                timer.Remove(timerKey..'regen')
                                activeTimers[timerKey..'regen'] = nil
                            end
                        else
                            timer.Remove(timerKey..'regen')
                            activeTimers[timerKey..'regen'] = nil    
                        end
                    end)
                    activeTimers[timerKey..'regen'] = true -- a timer was created, so add it to the table
                end
            end
            -- TESTING: PrintMessage(HUD_PRINTTALK, os.difftime(CurTime(),start_time))
            -- while the timer starts, add the timer's key to the timer list
            activeTimers[timerKey] = true
        end
    end)
end)

-- fix some console errors related to oldWeapon becoming nil when the player dies
hook.Add("PlayerDeath", "DestroyAllTimers", function( victim, inflictor, attacker )
    local userID = victim:SteamID() -- .. "-" .. oldWeapon:GetClass()
    for key, t in pairs(activeTimers) do
        _, index = string.find(key, "-")
        keyID = string.sub(key,1,index - 1)

        if tostring(keyID) == tostring(userID) then
            timer.Remove(key)
            activeTimers[key] = nil
        end
    end
end)