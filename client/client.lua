local ESX = exports['es_extended']:getSharedObject()
local shops = {}
local creatingShop = false
local blips = {}

-- Fonction pour forcer le chargement des modèles de PNJ
function EnsureModelsLoaded()
    -- Précacher tous les modèles de PNJ au démarrage
    for _, modelData in ipairs(Config.NPCModels) do
        RequestModel(GetHashKey(modelData.model))
        while not HasModelLoaded(GetHashKey(modelData.model)) do
            Citizen.Wait(1)
        end
    end
end

-- Fonction utilitaire pour cloner une table
function table.clone(org)
    local copy = {}
    for k, v in pairs(org) do
        if type(v) == "table" then
            copy[k] = table.clone(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Appeler cette fonction au démarrage de la ressource
Citizen.CreateThread(function()
    EnsureModelsLoaded()
end)

-- Fonction pour charger les shops depuis le serveur
function LoadShops()
    ESX.TriggerServerCallback('shops_vendeur:getShops', function(serverShops)
        shops = serverShops
        RefreshBlips()
        RefreshAllNPCs() -- Appeler notre nouvelle fonction pour créer les PNJ
    end)
end
-- Fonction pour rafraîchir les blips sur la carte
function RefreshBlips()
    -- Supprimer les anciens blips
    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}
    
    -- Créer les nouveaux blips
    for i, shop in pairs(shops) do
        -- Vérifier si le blip doit être affiché (true par défaut si non spécifié)
        local showBlip = shop.showBlip
        if showBlip == nil then
            showBlip = true -- Valeur par défaut pour la compatibilité avec les anciens shops
        end
        
        if showBlip then
            local blip = AddBlipForCoord(shop.position.x, shop.position.y, shop.position.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(shop.name or Config.Blip.name)
            EndTextCommandSetBlipName(blip)
            
            table.insert(blips, blip)
        end
    end
end
-- Fonctions RageUI pour le menu admin
local RMenu = {}
local MainMenu = RageUI.CreateMenu(Config.MenuStyle.Text.Title, Config.MenuStyle.Text.SubTitle)
local CreateShopMenu = RageUI.CreateSubMenu(MainMenu, "Créer un point", "Paramétrez votre point de vente")
local EditShopMenu = RageUI.CreateSubMenu(MainMenu, "Modifier un point", "Modifiez les paramètres")
local ItemsMenu = RageUI.CreateSubMenu(MainMenu, "Gérer les objets", "Définissez les objets vendables")

local function OpenAdminMenu()
    local newShop = {
        name = "Point de vente",
        position = vector3(0.0, 0.0, 0.0),
        items = {},
        showBlip = Config.DefaultShowBlip,
        npc = table.clone(Config.DefaultNPC) -- Ajouter la configuration NPC par défaut
    }
    local selectedShop = nil
    local selectedShopIndex = nil
    
    RageUI.Visible(MainMenu, true)
    
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            
            if RageUI.Visible(MainMenu) then
                RageUI.DrawContent({ header = true, glare = true, instructionalButton = true }, function()
                    RageUI.Button("Créer un nouveau point de vente", nil, { RightLabel = "→" }, true, function(Hovered, Active, Selected)
                        if Selected then
                            newShop.position = GetEntityCoords(PlayerPedId())
                        end
                    end, CreateShopMenu)
                    
                    -- Remplacer le séparateur par un bouton sans fonction
                    RageUI.Button("------- Points de vente existants -------", nil, {}, false, function() end)
                    
                    for i, shop in pairs(shops) do
                        RageUI.Button(shop.name, "Position: " .. math.floor(shop.position.x) .. ", " .. math.floor(shop.position.y), { RightLabel = "→" }, true, function(Hovered, Active, Selected)
                            if Selected then
                                selectedShop = shop
                                selectedShopIndex = i
                            end
                        end, EditShopMenu)
                    end
                end)
            end
            
            if RageUI.Visible(CreateShopMenu) then
                RageUI.DrawContent({ header = true, glare = true, instructionalButton = true }, function()
                    RageUI.Button("Nom du point", nil, { RightLabel = newShop.name }, true, function(Hovered, Active, Selected)
                        if Selected then
                            local input = lib.inputDialog('Nom du point de vente', {'Nom:'})
                            if input then
                                newShop.name = input[1] or "Point de vente"
                            end
                        end
                    end)
                    
                    RageUI.Button("Position actuelle", nil, { RightLabel = "Définir" }, true, function(Hovered, Active, Selected)
                        if Selected then
                            newShop.position = GetEntityCoords(PlayerPedId())
                            ESX.ShowNotification("Position définie!")
                        end
                    end)

                    RageUI.Checkbox("Afficher le blip sur la carte", nil, newShop.showBlip, {}, function(Hovered, Active, Selected, Checked)
                        if Selected then
                            newShop.showBlip = Checked
                        end
                    end)

                    RageUI.Checkbox("Activer un PNJ", nil, newShop.npc.enabled, {}, function(Hovered, Active, Selected, Checked)
                        if Selected then
                            newShop.npc.enabled = Checked
                        end
                    end)

                    -- Afficher les options supplémentaires uniquement si le PNJ est activé
                    if newShop.npc.enabled then
                        RageUI.Button("Modèle de PNJ", nil, { RightLabel = newShop.npc.model }, true, function(Hovered, Active, Selected)
                            if Selected then
                                -- Créer un menu contextuel avec les modèles disponibles
                                local options = {}
                                for _, modelData in ipairs(Config.NPCModels) do
                                    table.insert(options, {
                                        title = modelData.name,
                                        description = "Modèle: " .. modelData.model,
                                        onSelect = function()
                                            newShop.npc.model = modelData.model
                                            ESX.ShowNotification("Modèle de PNJ défini: " .. modelData.name)
                                        end
                                    })
                                end
                                
                                lib.registerContext({
                                    id = 'npc_model_menu',
                                    title = 'Choisir un modèle de PNJ',
                                    options = options
                                })
                                
                                lib.showContext('npc_model_menu')
                            end
                        end)
                        
                        RageUI.Button("Orientation du PNJ", nil, { RightLabel = tostring(math.floor(newShop.npc.heading)) .. "°" }, true, function(Hovered, Active, Selected)
                            if Selected then
                                local playerHeading = GetEntityHeading(PlayerPedId())
                                newShop.npc.heading = playerHeading
                                ESX.ShowNotification("Orientation définie: " .. math.floor(playerHeading) .. "°")
                            end
                        end)
                        
                        -- Option pour ajouter un scénario/animation
                        RageUI.Button("Scénario/Animation", nil, { RightLabel = newShop.npc.scenario or "Aucun" }, true, function(Hovered, Active, Selected)
                            if Selected then
                                local scenarios = {
                                    {name = "Aucun", value = nil},
                                    {name = "Nettoyer", value = "WORLD_HUMAN_MAID_CLEAN"},
                                    {name = "Noter", value = "WORLD_HUMAN_CLIPBOARD"},
                                    {name = "Bras croisés", value = "WORLD_HUMAN_STAND_IMPATIENT"},
                                    {name = "Téléphone", value = "WORLD_HUMAN_STAND_MOBILE"}
                                }
                                
                                local options = {}
                                for _, scenario in ipairs(scenarios) do
                                    table.insert(options, {
                                        title = scenario.name,
                                        onSelect = function()
                                            newShop.npc.scenario = scenario.value
                                            ESX.ShowNotification("Scénario défini: " .. (scenario.name or "Aucun"))
                                        end
                                    })
                                end
                                
                                lib.registerContext({
                                    id = 'npc_scenario_menu',
                                    title = 'Choisir un scénario',
                                    options = options
                                })
                                
                                lib.showContext('npc_scenario_menu')
                            end
                        end)
                    end


                    
                    RageUI.Button("Sauvegarder le point", nil, { RightBadge = RageUI.BadgeStyle.Tick }, true, function(Hovered, Active, Selected)
                        if Selected then
                            TriggerServerEvent('shops_vendeur:createShop', newShop)
                            ESX.ShowNotification("Point de vente créé!")
                            Wait(500)
                            LoadShops()
                            RageUI.GoBack()
                        end
                    end)
                end)
            end
            
            if RageUI.Visible(EditShopMenu) then
                RageUI.DrawContent({ header = true, glare = true, instructionalButton = true }, function()
                    if selectedShop then
                        RageUI.Button("Nom: " .. selectedShop.name, nil, { RightLabel = "Modifier" }, true, function(Hovered, Active, Selected)
                            if Selected then
                                local input = lib.inputDialog('Modifier le nom', {'Nom:'})
                                if input then
                                    selectedShop.name = input[1] or selectedShop.name
                                    TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                    Wait(500)
                                    LoadShops()
                                end
                            end
                        end)
                        
                        RageUI.Button("Se téléporter au point", nil, {}, true, function(Hovered, Active, Selected)
                            if Selected then
                                SetEntityCoords(PlayerPedId(), selectedShop.position.x, selectedShop.position.y, selectedShop.position.z)
                            end
                        end)
                        
                        RageUI.Button("Mettre à jour la position", nil, {}, true, function(Hovered, Active, Selected)
                            if Selected then
                                selectedShop.position = GetEntityCoords(PlayerPedId())
                                TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                Wait(500)
                                LoadShops()
                                ESX.ShowNotification("Position mise à jour!")
                            end
                        end)

                        -- Initialiser la configuration NPC si elle n'existe pas
                        if not selectedShop.npc then
                            selectedShop.npc = table.clone(Config.DefaultNPC)
                        end

                        -- Option pour activer/désactiver le PNJ
                        RageUI.Checkbox("Activer un PNJ", nil, selectedShop.npc.enabled, {}, function(Hovered, Active, Selected, Checked)
                            if Selected then
                                selectedShop.npc.enabled = Checked
                                TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                Wait(500)
                                LoadShops()
                                ESX.ShowNotification("Paramètre de PNJ mis à jour!")
                            end
                        end)

                        -- Afficher les options supplémentaires uniquement si le PNJ est activé
                        if selectedShop.npc and selectedShop.npc.enabled then
                            RageUI.Button("Modèle de PNJ", nil, { RightLabel = selectedShop.npc.model or "s_m_m_linecook" }, true, function(Hovered, Active, Selected)
                                if Selected then
                                    -- Créer un menu contextuel avec les modèles disponibles
                                    local options = {}
                                    for _, modelData in ipairs(Config.NPCModels) do
                                        table.insert(options, {
                                            title = modelData.name,
                                            description = "Modèle: " .. modelData.model,
                                            onSelect = function()
                                                selectedShop.npc.model = modelData.model
                                                TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                Wait(500)
                                                LoadShops()
                                                ESX.ShowNotification("Modèle de PNJ mis à jour!")
                                            end
                                        })
                                    end
                                    
                                    lib.registerContext({
                                        id = 'npc_model_menu',
                                        title = 'Choisir un modèle de PNJ',
                                        options = options
                                    })
                                    
                                    lib.showContext('npc_model_menu')
                                end
                            end)
                            
                            RageUI.Button("Orientation du PNJ", nil, { RightLabel = tostring(math.floor(selectedShop.npc.heading or 0)) .. "°" }, true, function(Hovered, Active, Selected)
                                if Selected then
                                    local playerHeading = GetEntityHeading(PlayerPedId())
                                    selectedShop.npc.heading = playerHeading
                                    TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                    Wait(500)
                                    LoadShops()
                                    ESX.ShowNotification("Orientation du PNJ mise à jour!")
                                end
                            end)
                            
                            -- Option pour ajouter un scénario/animation
                            RageUI.Button("Scénario/Animation", nil, { RightLabel = selectedShop.npc.scenario or "Aucun" }, true, function(Hovered, Active, Selected)
                                if Selected then
                                    local scenarios = {
                                        {name = "Aucun", value = nil},
                                        {name = "Nettoyer", value = "WORLD_HUMAN_MAID_CLEAN"},
                                        {name = "Noter", value = "WORLD_HUMAN_CLIPBOARD"},
                                        {name = "Bras croisés", value = "WORLD_HUMAN_STAND_IMPATIENT"},
                                        {name = "Téléphone", value = "WORLD_HUMAN_STAND_MOBILE"}
                                    }
                                    
                                    local options = {}
                                    for _, scenario in ipairs(scenarios) do
                                        table.insert(options, {
                                            title = scenario.name,
                                            onSelect = function()
                                                selectedShop.npc.scenario = scenario.value
                                                TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                Wait(500)
                                                LoadShops()
                                                ESX.ShowNotification("Scénario du PNJ mis à jour!")
                                            end
                                        })
                                    end
                                    
                                    lib.registerContext({
                                        id = 'npc_scenario_menu',
                                        title = 'Choisir un scénario',
                                        options = options
                                    })
                                    
                                    lib.showContext('npc_scenario_menu')
                                end
                            end)
                        end

                        -- Initialiser la valeur si elle n'existe pas
                        if selectedShop.showBlip == nil then
                            selectedShop.showBlip = true
                        end

                        local blipStatus = selectedShop.showBlip and "Activé" or "Désactivé"
                        RageUI.Checkbox("Afficher le blip sur la carte", nil, selectedShop.showBlip, {}, function(Hovered, Active, Selected, Checked)
                            if Selected then
                                selectedShop.showBlip = Checked
                                TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                Wait(500)
                                LoadShops()
                                ESX.ShowNotification("Paramètre de blip mis à jour!")
                            end
                        end)


                                    
                        RageUI.Button("Gérer les objets", nil, { RightLabel = "→" }, true, function(Hovered, Active, Selected)
                        end, ItemsMenu)
                        
                        RageUI.Button("Supprimer ce point", nil, { RightBadge = RageUI.BadgeStyle.Alert }, true, function(Hovered, Active, Selected)
                            if Selected then
                                TriggerServerEvent('shops_vendeur:deleteShop', selectedShopIndex)
                                Wait(500)
                                LoadShops()
                                RageUI.GoBack()
                                ESX.ShowNotification("Point de vente supprimé!")
                            end
                        end)
                    end
                end)
            end
            
            if RageUI.Visible(ItemsMenu) then
                RageUI.DrawContent({ header = true, glare = true, instructionalButton = true }, function()
                    if selectedShop then
                        for item, configItem in pairs(Config.SellableItems) do
                            -- Vérifier si l'item est déjà dans le shop
                            local isEnabled = false
                            local itemData = nil
                            
                            if selectedShop.items[item] then
                                isEnabled = true
                                itemData = selectedShop.items[item]
                            end
                            
                            RageUI.Checkbox(item, "Prix normal: $" .. configItem.price .. " - Prix sale: $" .. configItem.dirty_price, isEnabled, {}, function(Hovered, Active, Selected, Checked)
                                if Selected then
                                    if Checked then
                                        -- Si l'item est activé, initialiser avec les valeurs de configuration
                                        selectedShop.items[item] = {
                                            price = configItem.price,
                                            dirty_price = configItem.dirty_price,
                                            payment_type = configItem.payment_type or Config.PaymentTypes.BOTH -- Valeur par défaut si non spécifiée
                                        }
                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                        ESX.ShowNotification("Objet ajouté!")
                                        
                                        -- Ouvrir un menu pour configurer le type de paiement
                                        local paymentOptions = {
                                            {label = "Argent propre uniquement", value = Config.PaymentTypes.CLEAN_ONLY},
                                            {label = "Argent sale uniquement", value = Config.PaymentTypes.DIRTY_ONLY},
                                            {label = "Les deux types acceptés", value = Config.PaymentTypes.BOTH}
                                        }
                                        
                                        lib.registerContext({
                                            id = 'payment_type_menu',
                                            title = 'Type de paiement pour ' .. item,
                                            options = {
                                                {
                                                    title = 'Argent propre uniquement',
                                                    description = 'Seulement le prix normal sera appliqué',
                                                    onSelect = function()
                                                        selectedShop.items[item].payment_type = Config.PaymentTypes.CLEAN_ONLY
                                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                        ESX.ShowNotification("Type de paiement mis à jour!")
                                                    end
                                                },
                                                {
                                                    title = 'Argent sale uniquement',
                                                    description = 'Seulement le prix argent sale sera appliqué',
                                                    onSelect = function()
                                                        selectedShop.items[item].payment_type = Config.PaymentTypes.DIRTY_ONLY
                                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                        ESX.ShowNotification("Type de paiement mis à jour!")
                                                    end
                                                },
                                                {
                                                    title = 'Les deux types acceptés',
                                                    description = 'Le client pourra choisir son mode de paiement',
                                                    onSelect = function()
                                                        selectedShop.items[item].payment_type = Config.PaymentTypes.BOTH
                                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                        ESX.ShowNotification("Type de paiement mis à jour!")
                                                    end
                                                }
                                            }
                                        })
                                        
                                        lib.showContext('payment_type_menu')
                                    else
                                        selectedShop.items[item] = nil
                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                        ESX.ShowNotification("Objet retiré!")
                                    end
                                end
                            end)
                            
                            -- Si l'item est activé, afficher un bouton pour configurer le type de paiement
                            if isEnabled then
                                local paymentTypeText = "Type de paiement: "
                                if itemData.payment_type == Config.PaymentTypes.CLEAN_ONLY then
                                    paymentTypeText = paymentTypeText .. "Argent propre uniquement"
                                elseif itemData.payment_type == Config.PaymentTypes.DIRTY_ONLY then
                                    paymentTypeText = paymentTypeText .. "Argent sale uniquement"
                                else
                                    paymentTypeText = paymentTypeText .. "Les deux types acceptés"
                                end
                                
                                RageUI.Button(paymentTypeText, nil, {RightLabel = "→"}, true, function(Hovered, Active, Selected)
                                    if Selected then
                                        -- Ouvrir le même menu de configuration que ci-dessus
                                        lib.registerContext({
                                            id = 'payment_type_menu',
                                            title = 'Type de paiement pour ' .. item,
                                            options = {
                                                {
                                                    title = 'Argent propre uniquement',
                                                    description = 'Seulement le prix normal sera appliqué',
                                                    onSelect = function()
                                                        selectedShop.items[item].payment_type = Config.PaymentTypes.CLEAN_ONLY
                                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                        ESX.ShowNotification("Type de paiement mis à jour!")
                                                    end
                                                },
                                                {
                                                    title = 'Argent sale uniquement',
                                                    description = 'Seulement le prix argent sale sera appliqué',
                                                    onSelect = function()
                                                        selectedShop.items[item].payment_type = Config.PaymentTypes.DIRTY_ONLY
                                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                        ESX.ShowNotification("Type de paiement mis à jour!")
                                                    end
                                                },
                                                {
                                                    title = 'Les deux types acceptés',
                                                    description = 'Le client pourra choisir son mode de paiement',
                                                    onSelect = function()
                                                        selectedShop.items[item].payment_type = Config.PaymentTypes.BOTH
                                                        TriggerServerEvent('shops_vendeur:updateShop', selectedShopIndex, selectedShop)
                                                        ESX.ShowNotification("Type de paiement mis à jour!")
                                                    end
                                                }
                                            }
                                        })
                                        
                                        lib.showContext('payment_type_menu')
                                    end
                                end)
                            end
                        end
                    end
                end)
            end
            
            if not RageUI.Visible(MainMenu) and not RageUI.Visible(CreateShopMenu) and not RageUI.Visible(EditShopMenu) and not RageUI.Visible(ItemsMenu) then
                break
            end
        end
    end)
end

-- Table pour stocker les PNJ créés
local shopNPCs = {}

-- Fonction pour créer un PNJ à un point de vente
function CreateShopNPC(shop, shopId)
    -- Vérifier si un PNJ doit être créé
    if not shop.npc or not shop.npc.enabled then
        return
    end

    -- Charger le modèle du PNJ
    local model = shop.npc.model or "s_m_m_linecook"
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Citizen.Wait(1)
    end

    -- Créer le PNJ
    local npc = CreatePed(4, GetHashKey(model), shop.position.x, shop.position.y, shop.position.z - 1.0, shop.npc.heading or 0.0, false, true)
    
    -- Configurer le PNJ pour qu'il reste en place
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    
    -- Appliquer des animations si nécessaires
    if shop.npc.scenario then
        TaskStartScenarioInPlace(npc, shop.npc.scenario, 0, true)
    end
    
    -- Stocker la référence du PNJ
    shopNPCs[shopId] = npc
end

-- Fonction pour supprimer un PNJ
function DeleteShopNPC(shopId)
    if shopNPCs[shopId] then
        DeleteEntity(shopNPCs[shopId])
        shopNPCs[shopId] = nil
    end
end

-- Fonction pour rafraîchir tous les PNJ
function RefreshAllNPCs()
    -- Supprimer tous les PNJ existants
    for shopId, _ in pairs(shopNPCs) do
        DeleteShopNPC(shopId)
    end
    
    -- Recréer les PNJ pour tous les shops
    for shopId, shop in pairs(shops) do
        CreateShopNPC(shop, shopId)
    end
end

-- Fonction utilitaire pour obtenir la description du prix selon le type de paiement
function GetItemPriceDescription(itemData, paymentType)
    if paymentType == Config.PaymentTypes.CLEAN_ONLY then
        return 'Prix: $' .. itemData.price .. ' (Argent propre uniquement)'
    elseif paymentType == Config.PaymentTypes.DIRTY_ONLY then
        return 'Prix: $' .. itemData.dirty_price .. ' (Argent sale uniquement)'
    else
        return 'Prix: $' .. itemData.price .. ' | Prix argent sale: $' .. itemData.dirty_price
    end
end

-- Fonction pour ouvrir le menu de vente pour les joueurs
-- 3. Enfin, modifions la fonction OpenSellMenu pour respecter les types de paiement configurés
-- Fonction pour ouvrir le menu de vente pour les joueurs
function OpenSellMenu(shopId)
    local shop = shops[shopId]
    if not shop then return end
    
    local options = {}
    
    for itemName, itemData in pairs(shop.items) do
        -- Si le type de paiement n'est pas défini, utiliser BOTH par défaut pour compatibilité
        local paymentType = itemData.payment_type or Config.PaymentTypes.BOTH
        
        -- Récupérer le nombre d'objets que le joueur possède
        local count = exports.ox_inventory:GetItemCount(itemName)
        
        -- Ajouter le nombre d'objets à l'étiquette
        local itemLabel = exports.ox_inventory:Items()[itemName].label
        local displayLabel = itemLabel .. " (" .. count .. ")"
        
        table.insert(options, {
            title = displayLabel,
            description = GetItemPriceDescription(itemData, paymentType),
            onSelect = function()
                -- Définir les options de paiement selon le type configuré
                local inputOptions = {
                    {type = 'number', label = 'Quantité', min = 1, max = count, default = 1}
                }
                
                -- Ajouter le sélecteur de type de paiement uniquement si les deux types sont acceptés
                if paymentType == Config.PaymentTypes.BOTH then
                    table.insert(inputOptions, {
                        type = 'select', 
                        label = 'Type de paiement', 
                        options = {
                            {label = 'Argent propre', value = 'clean'},
                            {label = 'Argent sale', value = 'dirty'}
                        }
                    })
                end
                
                local input = lib.inputDialog('Vendre ' .. exports.ox_inventory:Items()[itemName].label, inputOptions)
                
                if input then
                    local amount = math.max(1, math.floor(input[1] or 1))
                    amount = math.min(amount, count) -- S'assurer que le montant ne dépasse pas ce que le joueur possède
                    
                    local selectedPaymentType
                    
                    -- Déterminer le type de paiement selon la configuration
                    if paymentType == Config.PaymentTypes.CLEAN_ONLY then
                        selectedPaymentType = 'clean'
                    elseif paymentType == Config.PaymentTypes.DIRTY_ONLY then
                        selectedPaymentType = 'dirty'
                    else
                        selectedPaymentType = input[2] -- Si BOTH, utiliser le choix du joueur
                    end
                    
                    TriggerServerEvent('shops_vendeur:sellItem', shopId, itemName, amount, selectedPaymentType)
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'shop_sell_menu',
        title = shop.name,
        options = options
    })
    
    lib.showContext('shop_sell_menu')
end
-- Vérification de la proximité des points de vente
Citizen.CreateThread(function()
    local waitTime = 500
    local isNearShop = false
    local canInteract = true -- Variable pour contrôler le délai entre les interactions
    local cooldownTime = 1000 -- 1 seconde de cooldown entre les pressions de touche

    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local closestShop = nil
        local closestDistance = Config.InteractionDistance + 1.0
        local closestIndex = nil
        
        for i, shop in pairs(shops) do
            local distance = #(playerCoords - vector3(shop.position.x, shop.position.y, shop.position.z))
            if distance < closestDistance then
                closestShop = shop
                closestDistance = distance
                closestIndex = i
            end
        end
        
        if closestShop and closestDistance <= Config.InteractionDistance then
            waitTime = 0 -- Réduit le temps d'attente quand près d'un shop
            
            if not isNearShop then
                lib.showTextUI('[E] - Vendre des objets à ' .. closestShop.name)
                isNearShop = true
            end
            
            -- Vérifier si le bouton E est pressé et si le cooldown est terminé
            if IsControlJustPressed(0, 38) and canInteract then -- E key
                canInteract = false -- Désactiver l'interaction pendant le cooldown
                OpenSellMenu(closestIndex)
                
                -- Démarrer le minuteur pour le cooldown
                Citizen.SetTimeout(cooldownTime, function()
                    canInteract = true -- Réactiver l'interaction après le cooldown
                end)
            end
        else
            if isNearShop then
                lib.hideTextUI()
                isNearShop = false
            end
            waitTime = 500 -- Augmente le temps d'attente quand loin des shops
        end
        
        Citizen.Wait(waitTime)
    end
end)

-- Commande pour ouvrir le menu admin
RegisterCommand('createshop', function()
    ESX.TriggerServerCallback('shops_vendeur:checkPermission', function(hasPermission)
        if hasPermission then
            OpenAdminMenu()
        else
            ESX.ShowNotification("Vous n'avez pas la permission d'utiliser cette commande!")
        end
    end)
end)

-- Charger les shops au démarrage
Citizen.CreateThread(function()
    while ESX == nil do
        Wait(100)
    end
    
    LoadShops()
end)

-- S'assurer que les PNJ sont supprimés quand la ressource s'arrête
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for shopId, _ in pairs(shopNPCs) do
            DeleteShopNPC(shopId)
        end
    end
end)