-- TDS:Multiplayer are unfinished

local TDS = shared.TDS_Table or getgenv().TDS_Table
getgenv().already = false
if not TDS then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")
local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local API = "https://playvora.vercel.app/tds"
local API_2 = "http://localhost:3000"

local PartyState = {
    Difficulty = nil,
    TotalPlayer = nil
}

local maps = {
    matchmaking_map = {
        ["Hardcore"] = "hardcore",
        ["Pizza Party"] = "halloween",
        ["Badlands"] = "badlands",
        ["Polluted"] = "polluted"
    }
}

local function Requests(Body)
    local Res = request({
        Url = API,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(Body)
    })
    if Res and Res.Body then
        return HttpService:JSONDecode(Res.Body)
    end
end

local function identify_game_state()
    local temp_gui = Player:WaitForChild("PlayerGui")
    
    while true do
        if temp_gui:FindFirstChild("LobbyGui") then
            return "LOBBY"
        elseif temp_gui:FindFirstChild("GameGui") then
            return "GAME"
        end
        task.wait(1)
    end
end

function TDS:Equip(Tower)
    if not Tower or Tower == "" then return end
    RemoteEvent:FireServer("Streaming", "SelectTower", Tower, "Default")
    task.wait()
    RemoteFunction:InvokeServer("Inventory", "Equip", "Skin", Tower, "Default")
    task.wait()
    RemoteFunction:InvokeServer("Inventory", "Equip", "tower", Tower)
end

function TDS:MultiMode(Difficulty, TotalPlayer)
    PartyState.Difficulty = Difficulty
    PartyState.TotalPlayer = TotalPlayer
    return true
end

function TDS:Multiplayer(Role, PartyCode)
    if identify_game_state() == "GAME" then return end

    if Role == "host" then
        if getgenv().already then return end
        getgenv().already = true

        Requests({
            Action = "Register",
            PartyCode = PartyCode,
            PlayerName = Player.Name,
            ServerJobId = game.JobId
        })

        RemoteFunction:InvokeServer("Party", "CreateParty")
        
        if PartyState.TotalPlayer then
            local Data
            repeat
                task.wait(1)
                Data = Requests({
                    Action = "GetPlayers",
                    PartyCode = PartyCode
                })
                
                local InGameCount = 1
                if Data and Data.Names then
                    for _, Name in next, Data.Names do
                        if Name ~= Player.Name and Players:FindFirstChild(Name) then
                            InGameCount = InGameCount + 1
                        end
                    end
                end
            until InGameCount >= PartyState.TotalPlayer

            task.wait(15)

            local ReactLobbyParty = Player:WaitForChild("PlayerGui"):WaitForChild("ReactLobbyParty")
            local PartyTitle = ReactLobbyParty:WaitForChild("party"):WaitForChild("currentParty"):WaitForChild("partyTitle")

            repeat
                if Data and Data.Names then
                    for _, Name in next, Data.Names do
                        if Name ~= Player.Name then
                            local TargetPlayer = Players:FindFirstChild(Name)
                            if TargetPlayer then
                                RemoteFunction:InvokeServer("Party", "InvitePlayer", TargetPlayer)
                            end
                        end
                    end
                end
                
                task.wait(5)
                
                local Text = PartyTitle.Text
                local CurrentCount = tonumber(string.match(Text, "%((%d+)/"))
            until CurrentCount and CurrentCount >= PartyState.TotalPlayer

            local mode = maps.matchmaking_map[PartyState.Difficulty]
            local payload

            if mode then
                payload = {
                    mode = mode,
                    count = PartyState.TotalPlayer
                }
            else
                payload = {
                    difficulty = PartyState.Difficulty,
                    mode = "survival",
                    count = PartyState.TotalPlayer
                }
            end

            RemoteFunction:InvokeServer("Multiplayer", "v2:start", payload)
        end

        return true
    end

    if Role == "client" then
        Requests({
            Action = "Join",
            PartyCode = PartyCode,
            PlayerName = Player.Name
        })

        local Data
        for _ = 1, 30 do
            Data = Requests({
                Action = "Resolve",
                PartyCode = PartyCode
            })
            if Data and Data.ServerJobId then break end
            task.wait(0.5)
        end

        if Data and Data.ServerJobId then
            if game.JobId == Data.ServerJobId then
                local HostPlayer = Players:WaitForChild(Data.PlayerName)
                task.spawn(function()
                    while true do
                        local args = {
                            "Party",
                            "AcceptInvite",
                            HostPlayer
                        }
                        RemoteFunction:InvokeServer(unpack(args))
                        task.wait(2)
                    end
                end)
            else
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    Data.ServerJobId,
                    Player
                )
            end
        end

        return true
    end

    return false
end

function TDS:JoinPrivateServer(Link)
    if not Link or Link == "" then return end
    if workspace:GetAttribute("IsPrivateServer") then return end
    if identify_game_state() == "GAME" then return end

    local Body = {
        Link = Link
    }

    request({
        Url = API_2,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(Body)
    })

    task.wait(3)

    game:Shutdown()
    
    while true do
        task.wait()
    end
end
