local ESX = exports['es_extended']:getSharedObject()
local shops = {}
local shopsFile = 'shops_vendeur/data/shops.json'

-- Fonction pour charger les shops depuis le fichier JSON
function LoadShopsFromFile()
    local fileExists = LoadResourceFile(GetCurrentResourceName(), 'data/shops.json')
    
    if fileExists then
        shops = json.decode(fileExists)
    else
        shops = {}
        SaveResourceFile(GetCurrentResourceName(), 'data/shops.json', json.encode(shops), -1)
    end
end

-- Fonction pour sauvegarder les shops dans le fichier JSON
function SaveShopsToFile()
    SaveResourceFile(GetCurrentResourceName(), 'data/shops.json', json.encode(shops), -1)
end

-- Charger les shops au démarrage du serveur
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LoadShopsFromFile()
        print('[Shops Vendeur] ' .. #shops .. ' shops chargés.')
    end
end)

-- Callback pour récupérer les shops
ESX.RegisterServerCallback('shops_vendeur:getShops', function(source, cb)
    cb(shops)
end)

-- Vérifier les permissions admin
ESX.RegisterServerCallback('shops_vendeur:checkPermission', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    local group = xPlayer.getGroup()
    if Config.AdminGroups[group] then
        cb(true)
    else
        cb(false)
    end
end)

-- Créer un nouveau shop
RegisterNetEvent('shops_vendeur:createShop')
AddEventHandler('shops_vendeur:createShop', function(shopData)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or not Config.AdminGroups[xPlayer.getGroup()] then
        return
    end
    
    table.insert(shops, shopData)
    SaveShopsToFile()
    
    TriggerClientEvent('esx:showNotification', source, 'Point de vente créé!')
end)

-- Mettre à jour un shop
RegisterNetEvent('shops_vendeur:updateShop')
AddEventHandler('shops_vendeur:updateShop', function(index, shopData)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or not Config.AdminGroups[xPlayer.getGroup()] then
        return
    end
    
    if shops[index] then
        shops[index] = shopData
        SaveShopsToFile()
        TriggerClientEvent('esx:showNotification', source, 'Point de vente mis à jour!')
    end
end)

-- Supprimer un shop
RegisterNetEvent('shops_vendeur:deleteShop')
AddEventHandler('shops_vendeur:deleteShop', function(index)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or not Config.AdminGroups[xPlayer.getGroup()] then
        return
    end
    
    if shops[index] then
        table.remove(shops, index)
        SaveShopsToFile()
        TriggerClientEvent('esx:showNotification', source, 'Point de vente supprimé!')
    end
end)

-- Vendre un item
RegisterNetEvent('shops_vendeur:sellItem')
AddEventHandler('shops_vendeur:sellItem', function(shopIndex, item, amount, paymentType)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    if not shops[shopIndex] or not shops[shopIndex].items[item] then return end
    
    local shop = shops[shopIndex]
    local shopItem = shop.items[item]
    local count = exports.ox_inventory:GetItem(source, item, nil, true)
    
    -- Vérifier si le type de paiement est autorisé
    local itemPaymentType = shopItem.payment_type or Config.PaymentTypes.BOTH
    
    if (itemPaymentType == Config.PaymentTypes.CLEAN_ONLY and paymentType ~= 'clean') or 
       (itemPaymentType == Config.PaymentTypes.DIRTY_ONLY and paymentType ~= 'dirty') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Point de vente',
            description = 'Type de paiement non autorisé pour cet objet!',
            type = 'error'
        })
        return
    end
    
    if count < amount then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Point de vente',
            description = 'Vous n\'avez pas assez de cet objet!',
            type = 'error'
        })
        return
    end
    
    local price = 0
    if paymentType == 'clean' then
        price = shopItem.price * amount
    else
        price = shopItem.dirty_price * amount
    end
    
    -- Retirer les objets
    if exports.ox_inventory:RemoveItem(source, item, amount) then
        -- Ajouter l'argent
        if paymentType == 'clean' then
            xPlayer.addMoney(price)
        else
            xPlayer.addAccountMoney('black_money', price)
        end
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Point de vente',
            description = 'Vous avez vendu ' .. amount .. 'x ' .. exports.ox_inventory:Items()[item].label .. ' pour $' .. price,
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Point de vente',
            description = 'Erreur lors de la vente!',
            type = 'error'
        })
    end
end)