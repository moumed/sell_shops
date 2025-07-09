Config = {}

-- Permissions pour utiliser la commande admin
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true,
    ['mod'] = false
}

-- Type de blip sur la carte
Config.Blip = {
    sprite = 605,
    color = 2,
    scale = 0.7,
    name = "Point de vente"
}

-- Configuration par défaut pour les PNJ
Config.DefaultNPC = {
    enabled = false,
    model = "s_m_m_linecook",
    heading = 0.0
}

-- Types de PNJ disponibles pour les points de vente
Config.NPCModels = {
    {name = "Commerçant", model = "s_m_m_linecook"},
    {name = "Vendeuse", model = "s_f_y_shop_mid"},
    {name = "Coursier", model = "s_m_m_postal_01"},
    {name = "Barman", model = "s_m_y_barman_01"}
}

-- Distance pour interagir avec le point de vente
Config.InteractionDistance = 1.0
Config.DefaultShowBlip = true

Config.PaymentTypes = {
    CLEAN_ONLY = 1,    -- Uniquement argent propre
    DIRTY_ONLY = 2,    -- Uniquement argent sale
    BOTH = 3           -- Les deux types d'argent acceptés
}

-- Objets qui peuvent être vendus (avec leur prix)
Config.SellableItems = {
    -- Format: ['item_name'] = {price = prix_normal, dirty_price = prix_argent_sale, payment_type = type_de_paiement}
    ['x_antique_watch'] = {price = 0, dirty_price = 500, payment_type = Config.PaymentTypes.DIRTY_ONLY},
    ['x_gold_necklace'] = {price = 0, dirty_price = 750, payment_type = Config.PaymentTypes.DIRTY_ONLY},
    ['x_gold_ring'] = {price = 0, dirty_price = 920, payment_type = Config.PaymentTypes.DIRTY_ONLY},
    ['x_ring_silver'] = {price = 0, dirty_price = 300, payment_type = Config.PaymentTypes.DIRTY_ONLY},
    ['weed_pooch'] = {price = 0, dirty_price = 850, payment_type = Config.PaymentTypes.DIRTY_ONLY},
    
    -- Ajoutez vos objets ici
}


-- Menu options
Config.MenuStyle = {
    Text = {
        Title = "Gestion des Points de Vente",
        SubTitle = "Créer ou modifier des points de vente"
    }
}