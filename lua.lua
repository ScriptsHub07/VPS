wait(0.4)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- ===== WEBHOOKS =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1418388829160607778/tLZjaLoSwiEJ5RpiJyIVxlSYtUfOXCXuw4ips0hNBuNRsK-Ukrch4NXxubi-o8K3-hoR"
local SPECIAL_WEBHOOK_URL = "https://discord.com/api/webhooks/1418386817820004403/-E0obGTbnxTFAfNTY_M06Ds05e1QEbQWtn3ROym1DETpE_Seo4sKnv--su-6oneCGaEu"
local ULTRA_HIGH_WEBHOOK_URL = "https://discord.com/api/webhooks/1422547483762102362/ivlTOC9GhUbPNh5d_Ors6LgQB7selinPIam8pmDOtXvjmpiVc9n4Zb3aH7_FFnjDowwd"

-- ===== CONFIGURAÇÃO =====
local SERVER_SWITCH_INTERVAL = 2 -- segundos

-- ===== VARIÁVEL PARA EVITAR DUPLICATAS =====
local sentBrainrots = {}

-- ========= FORMATAÇÃO =========
local function fmtShort(n)
    if not n then return "0" end
    local a = math.abs(n)
    if a >= 1e12 then
        local s = string.format("%.2fT", n/1e12)
        return (s:gsub("%.00",""))
    elseif a >= 1e9 then
        local s = string.format("%.1fB", n/1e9)
        return s:gsub("%.0B","B")
    elseif a >= 1e6 then
        local s = string.format("%.1fM", n/1e6)
        return s:gsub("%.0M","M")
    elseif a >= 1e3 then
        return string.format("%.0fk", n/1e3)
    else
        return tostring(n)
    end
end

-- ===== FUNÇÃO PARA OBTER TODAS AS PLOTS =====
local function getAllPlots()
    local plots = {}
    
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if plotsFolder then
        for _, plot in pairs(plotsFolder:GetChildren()) do
            if plot:FindFirstChild("AnimalPodiums") then
                table.insert(plots, plot)
            end
        end
    end
    
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name:find("Plot") or obj.Name:find("plot") then
            if not table.find(plots, obj) and obj:FindFirstChild("AnimalPodiums") then
                table.insert(plots, obj)
            end
        end
    end
    
    return plots
end

-- ===== FUNÇÃO PARA OBTER DONO DA PLOT =====
local function getOwner(plot)
    local success, result = pcall(function()
        local ov = plot:FindFirstChild("Owner", true)
        if ov and ov:IsA("ObjectValue") and ov.Value and ov.Value:IsA("Player") then return ov.Value end
        
        local uid = plot:GetAttribute("OwnerUserId")
        if uid then return Players:GetPlayerByUserId(uid) end
        
        local iv = plot:FindFirstChild("OwnerUserId", true)
        if iv and iv:IsA("IntValue") then return Players:GetPlayerByUserId(iv.Value) end
        
        local sv = plot:FindFirstChild("OwnerName", true)
        if sv and sv:IsA("StringValue") then
            for _,p in ipairs(Players:GetPlayers()) do 
                if p.Name == sv.Value then return p end 
            end
        end
        return nil
    end)
    return success and result or nil
end

-- ===== FUNÇÃO CORRIGIDA PARA CONVERTER APENAS VALORES VÁLIDOS =====
local function textToNumber(text)
    if not text then return 0 end
    
    print("🔍 Analisando: '" .. tostring(text) .. "'")
    
    -- Verificar se é um formato válido de geração (deve ter /s ou k/M/B)
    local hasValidFormat = text:find("/s") or text:find("k") or text:find("M") or text:find("B") or text:find("T")
    if not hasValidFormat then
        print("❌ Formato inválido para geração")
        return 0
    end
    
    -- Limpar o texto
    local cleanText = tostring(text):gsub("%$", ""):gsub("/s", ""):gsub(" ", ""):gsub(",", "")
    
    print("🔍 Texto limpo: '" .. cleanText .. "'")
    
    -- Verificar padrões na ordem de prioridade (do maior para o menor)
    
    -- 1. Padrão com "T" (Trilhões)
    if cleanText:find("T") then
        local numStr = cleanText:gsub("T", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000000000000
            print("💰 Convertido T: " .. numStr .. "T → " .. result)
            return result
        end
    end
    
    -- 2. Padrão com "B" (Bilhões)
    if cleanText:find("B") then
        local numStr = cleanText:gsub("B", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000000000
            print("💰 Convertido B: " .. numStr .. "B → " .. result)
            return result
        end
    end
    
    -- 3. Padrão com "M" (Milhões)
    if cleanText:find("M") then
        local numStr = cleanText:gsub("M", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000000
            print("💰 Convertido M: " .. numStr .. "M → " .. result)
            return result
        end
    end
    
    -- 4. Padrão com "k" (Milhares)
    if cleanText:find("k") then
        local numStr = cleanText:gsub("k", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000
            print("💰 Convertido k: " .. numStr .. "k → " .. result)
            return result
        end
    end
    
    -- 5. Se chegou aqui e tem /s, tentar número direto
    if text:find("/s") then
        local num = tonumber(cleanText)
        if num then
            print("💰 Número direto com /s: " .. num)
            return num
        end
    end
    
    print("❌ Não foi possível converter valor de geração")
    return 0
end

-- ===== FUNÇÃO MELHORADA PARA ENCONTRAR APENAS GERAÇÕES REAIS =====
local function getBrainrotGeneration(animalOverhead)
    if not animalOverhead then return 0, "0" end
    
    -- PRIMEIRO: Procurar apenas pelo label "Generation" (mais confiável)
    local generationLabel = animalOverhead:FindFirstChild("Generation")
    if generationLabel and generationLabel:IsA("TextLabel") and generationLabel.Text and generationLabel.Text ~= "" then
        local text = generationLabel.Text
        print("🏷️ Label 'Generation' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ Geração real encontrada: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- SEGUNDO: Procurar por "ValuePerSecond" 
    local valueLabel = animalOverhead:FindFirstChild("ValuePerSecond")
    if valueLabel and valueLabel:IsA("TextLabel") and valueLabel.Text and valueLabel.Text ~= "" then
        local text = valueLabel.Text
        print("🏷️ Label 'ValuePerSecond' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ Valor por segundo encontrado: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- TERCEIRO: Procurar por "GPS" 
    local gpsLabel = animalOverhead:FindFirstChild("GPS")
    if gpsLabel and gpsLabel:IsA("TextLabel") and gpsLabel.Text and gpsLabel.Text ~= "" then
        local text = gpsLabel.Text
        print("🏷️ Label 'GPS' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ GPS encontrado: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- QUARTO: Procurar por "MoneyPerSecond"
    local moneyLabel = animalOverhead:FindFirstChild("MoneyPerSecond")
    if moneyLabel and moneyLabel:IsA("TextLabel") and moneyLabel.Text and moneyLabel.Text ~= "" then
        local text = moneyLabel.Text
        print("🏷️ Label 'MoneyPerSecond' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ MoneyPerSecond encontrado: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- NÃO procurar em labels genéricos para evitar falsos positivos
    print("❌ Nenhum label de geração válido encontrado")
    return 0, "0"
end

-- ===== FUNÇÃO PRINCIPAL DE SCAN =====
local function scanAllPlots()
    local allBrainrots = {}
    
    print("🔍 Iniciando scan do servidor...")
    local plots = getAllPlots()
    
    print("📊 Plots encontradas: " .. #plots)
    
    for _, plot in pairs(plots) do
        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            for i = 1, 20 do
                local success, errorMsg = pcall(function()
                    local podium = animalPodiums:FindFirstChild(tostring(i))
                    if podium then
                        local base = podium:FindFirstChild("Base")
                        if base then
                            local spawn = base:FindFirstChild("Spawn")
                            if spawn then
                                local attachment = spawn:FindFirstChild("Attachment")
                                if attachment then
                                    local animalOverhead = attachment:FindFirstChild("AnimalOverhead")
                                    if animalOverhead then
                                        local brainrotName = "Unknown"
                                        local displayName = animalOverhead:FindFirstChild("DisplayName")
                                        if displayName and displayName:IsA("TextLabel") then
                                            brainrotName = displayName.Text or "Unknown"
                                        end
                                        
                                        local genValue, genText = getBrainrotGeneration(animalOverhead)
                                        local owner = getOwner(plot)
                                        local ownerName = owner and owner.Name or "Unknown"
                                        
                                        -- VALIDAÇÃO ADICIONAL: só aceitar se for um valor realista
                                        if brainrotName ~= "Unknown" and brainrotName ~= "" and genValue > 0 then
                                            -- Verificar se o valor é realista (não muito alto para evitar falsos positivos)
                                            if genValue <= 1000000000000 then -- Máximo 1T (evitar valores absurdos)
                                                local brainrotInfo = {
                                                    name = brainrotName,
                                                    generation = genText,
                                                    valuePerSecond = genText,
                                                    numericGen = genValue,
                                                    plotName = plot.Name,
                                                    ownerName = ownerName,
                                                    podiumNumber = i
                                                }
                                                
                                                table.insert(allBrainrots, brainrotInfo)
                                                print("    ✅ " .. brainrotName .. " - " .. genText .. " (Valor: " .. genValue .. ")")
                                            else
                                                print("    ⚠️ " .. brainrotName .. " - VALOR MUITO ALTO (possível falso positivo): " .. genValue)
                                            end
                                        else
                                            print("    ⚠️ " .. brainrotName .. " - SEM GERAÇÃO VÁLIDA")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                
                if not success then
                    print("    ❌ ERRO no podium " .. i .. ": " .. tostring(errorMsg))
                end
            end
        end
    end
    
    -- Ordenar por geração
    table.sort(allBrainrots, function(a, b)
        return a.numericGen > b.numericGen
    end)
    
    print("✅ Scan completo! Total válidos: " .. #allBrainrots)
    
    return allBrainrots
end

-- ====== HELPER: envio robusto da webhook ======
local function _tryWebhookSend(jsonBody, webhookUrl)
    local success = false
    
    local requestFunctions = {
        function() return syn and syn.request end,
        function() return http_request end,
        function() return request end,
        function() return http and http.request end
    }
    
    for _, getRequestFunc in ipairs(requestFunctions) do
        local req = getRequestFunc()
        if req then
            local ok, res = pcall(function()
                return req({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = jsonBody
                })
            end)
            
            if ok and res and (res.StatusCode or res.Status) and tonumber(res.StatusCode or res.Status) < 400 then
                success = true
                break
            end
        end
    end
    
    return success
end

-- ===== FUNÇÃO PARA DETERMINAR WEBHOOK BASEADO NO VALOR =====
local function getWebhookForValue(value)
    print("🎯 Classificando: " .. value .. " (" .. fmtShort(value) .. ")")
    
    if value >= 100000000 then -- 100M+
        print("💎 ULTRA_HIGH (100M+)")
        return ULTRA_HIGH_WEBHOOK_URL, "ULTRA_HIGH"
    elseif value >= 10000000 then -- 10M-99M
        print("🔥 SPECIAL (10M-99M)")
        return SPECIAL_WEBHOOK_URL, "SPECIAL"
    elseif value >= 1000000 then -- 1M-9M
        print("⭐ NORMAL (1M-9M)")
        return WEBHOOK_URL, "NORMAL"
    else
        print("📭 LOW")
        return nil, "LOW"
    end
end

-- ===== FUNÇÃO PARA VERIFICAR SE JÁ FOI ENVIADO =====
local function wasAlreadySent(brainrot)
    local key = brainrot.name .. "_" .. brainrot.ownerName .. "_" .. brainrot.numericGen
    return sentBrainrots[key] == true
end

-- ===== FUNÇÃO PARA MARCAR COMO ENVIADO =====
local function markAsSent(brainrot)
    local key = brainrot.name .. "_" .. brainrot.ownerName .. "_" .. brainrot.numericGen
    sentBrainrots[key] = true
end

-- ===== FUNÇÃO PARA OBTER DATA E HORA ATUAL =====
local function getCurrentDateTime()
    local dateTable = os.date("*t")
    return string.format("%02d/%02d/%04d %02d:%02d:%02d", 
        dateTable.day, dateTable.month, dateTable.year,
        dateTable.hour, dateTable.min, dateTable.sec)
end

-- ===== ENVIO SIMPLIFICADO DE BRAINROTS =====
local function sendBrainrotToCorrectWebhook(brainrot)
    if wasAlreadySent(brainrot) then
        print("📭 Já enviado: " .. brainrot.name .. " - " .. brainrot.valuePerSecond)
        return
    end
    
    local webhookUrl, category = getWebhookForValue(brainrot.numericGen)
    
    if not webhookUrl then
        print("❌ Não qualificado: " .. brainrot.name .. " - " .. brainrot.valuePerSecond)
        return
    end
    
    -- Informações da categoria
    local categoryInfo = {
        ULTRA_HIGH = {color = 10181046, emoji = "💎"},
        SPECIAL = {color = 16766720, emoji = "🔥"}, 
        NORMAL = {color = 5793266, emoji = "⭐"}
    }
    
    local info = categoryInfo[category]
    local currentDateTime = getCurrentDateTime()
    
    -- Embed com as informações solicitadas
    local embed = {
        title = info.emoji .. " " .. brainrot.name,
        color = info.color,
        fields = {
            {
                name = "📊 Informações",
                value = string.format("**Geração:** %s/s\n**Job ID:** ```%s```\n**Jogadores:** %d/%d\n**Enviado em:** %s",
                    brainrot.valuePerSecond,
                    game.JobId, 
                    #Players:GetPlayers(), Players.MaxPlayers,
                    currentDateTime),
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    -- Payload
    local payload = {
        embeds = {embed}
    }
    
    local success, json = pcall(HttpService.JSONEncode, HttpService, payload)
    
    if success then
        print("📤 Enviando: " .. brainrot.name .. " - " .. brainrot.valuePerSecond)
        local sendSuccess = _tryWebhookSend(json, webhookUrl)
        if sendSuccess then
            markAsSent(brainrot)
            print("✅ Enviado com sucesso!")
        else
            print("❌ Falha no envio")
        end
    else
        print("❌ Erro no JSON")
    end
end

-- ===== ENVIAR TODOS OS BRAINROTS QUALIFICADOS =====
local function sendAllQualifiedBrainrots(allBrainrots)
    local sentCount = 0
    local qualifiedCount = 0
    
    for _, brainrot in ipairs(allBrainrots) do
        if brainrot.numericGen >= 1000000 then -- 1M+
            qualifiedCount = qualifiedCount + 1
            sendBrainrotToCorrectWebhook(brainrot)
            sentCount = sentCount + 1
            wait(0.5)
        end
    end
    
    print("🎯 Enviados: " .. sentCount .. "/" .. qualifiedCount)
end

-- ===== SISTEMA MELHORADO DE TROCA DE SERVIDOR =====
local function switchServer()
    print("🔄 Iniciando troca de servidor...")
    
    -- Método 1: Server Hop externo
    local success, errorMsg = pcall(function()
        local module = loadstring(game:HttpGet("https://raw.githubusercontent.com/LeoKholYt/roblox/main/lk_serverhop.lua"))()
        module:Teleport(game.PlaceId)
    end)
    
    if success then
        print("✅ Server Hop executado com sucesso")
        return true
    else
        print("❌ Falha no Server Hop: " .. tostring(errorMsg))
    end
    
    -- Método 2: TeleportService direto
    local success2, errorMsg2 = pcall(function()
        TeleportService:Teleport(game.PlaceId)
    end)
    
    if success2 then
        print("✅ TeleportService executado com sucesso")
        return true
    else
        print("❌ Falha no TeleportService: " .. tostring(errorMsg2))
    end
    
    -- Método 3: Teleport para um servidor específico
    local success3, errorMsg3 = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end)
    
    if success3 then
        print("✅ Teleport para instância executado")
        return true
    else
        print("❌ Falha no teleport para instância: " .. tostring(errorMsg3))
    end
    
    -- Método 4: Tentar reiniciar o script se nada funcionar
    print("⚠️ Todos os métodos falharam, aguardando e tentando novamente...")
    wait(5)
    return false
end

-- ========= EXECUÇÃO PRINCIPAL =========
local function main()
    local consecutiveFailures = 0
    local maxConsecutiveFailures = 3
    
    while true do
        print("\n" .. string.rep("=", 50))
        print("🔄 INICIANDO NOVO SCAN - " .. os.date("%X"))
        print(string.rep("=", 50))
        
        wait(3)
        
        local success, allBrainrots = pcall(scanAllPlots)
        
        if success then
            sendAllQualifiedBrainrots(allBrainrots)
            consecutiveFailures = 0 -- Resetar falhas consecutivas se o scan foi bem-sucedido
        else
            print("❌ Erro no scan")
            consecutiveFailures = consecutiveFailures + 1
        end
        
        if SERVER_SWITCH_INTERVAL > 0 then
            print("⏰ Aguardando " .. SERVER_SWITCH_INTERVAL .. "s para trocar de servidor...")
            wait(SERVER_SWITCH_INTERVAL)
            
            -- Verificar se atingiu muitas falhas consecutivas
            if consecutiveFailures >= maxConsecutiveFailures then
                print("⚠️ Muitas falhas consecutivas, reiniciando o ciclo...")
                consecutiveFailures = 0
                wait(5)
            end
            
            print("🔄 Trocando de servidor...")
            local switchSuccess = switchServer()
            
            if switchSuccess then
                print("✅ Troca de servidor iniciada com sucesso")
                consecutiveFailures = 0
            else
                print("❌ Falha na troca de servidor")
                consecutiveFailures = consecutiveFailures + 1
            end
            
            -- Esperar a teleportação acontecer
            print("⏳ Aguardando teleportação...")
            wait(5)
        else
            print("⏸️  Troca de servidor desativada")
            break
        end
    end
end

print("✅ Sistema iniciado!")
coroutine.wrap(main)()