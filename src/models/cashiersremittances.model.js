let dbConnection;

/**
 * Initialise le modèle avec la connexion à la base de données.
 * @param {object} connection - Le pool de connexion à la base de données.
 */
exports.init = (connection) => {
    dbConnection = connection;
};

/**
 * Récupère le résumé journalier des encaissements et dépenses des livreurs.
 *
 * @param {string} date - Date au format 'YYYY-MM-DD'.
 * @returns {Promise<Array>} Tableau de résumés par livreur.
 */
exports.getDailyRemittanceSummary = async (date) => {
    const sql = `
        SELECT
            U.id AS deliveryman_id,
            U.name AS deliveryman_name,
            -- 1. Encaissements Bruts (Total collecté par le livreur sur les commandes 'delivered' en 'cash')
            COALESCE(SUM(CASE 
                WHEN O.status = 'delivered' AND O.payment_status = 'cash' 
                THEN O.article_amount + O.delivery_fee 
                ELSE 0.00 
            END), 0.00) AS total_cash_collected,
            
            -- 2. Dépenses Validées (Réduction sur le montant à remettre, enregistrées comme 'expense' confirmées)
            COALESCE(SUM(CASE 
                WHEN CT.type = 'expense' AND CT.status = 'confirmed' 
                AND DATE(CT.created_at) = ? 
                THEN CT.amount 
                ELSE 0.00 
            END), 0.00) AS total_expenses_confirmed,

            -- 3. Montant Versé Confirmé (Versements 'remittance' confirmés)
            COALESCE(SUM(CASE 
                WHEN CT.type = 'remittance' AND CT.status = 'confirmed' 
                AND DATE(CT.created_at) = ? 
                THEN CT.amount 
                ELSE 0.00 
            END), 0.00) AS total_remitted_confirmed,

            -- 4. Compter les commandes qui DOIVENT être versées (livrées en cash)
            SUM(CASE 
                WHEN O.status = 'delivered' AND O.payment_status = 'cash' 
                THEN 1 
                ELSE 0 
            END) AS delivered_cash_orders_count,

            -- 5. Commandes ratées/annulées pour le détail
            SUM(CASE 
                WHEN O.status IN ('failed_delivery', 'cancelled') AND DATE(O.updated_at) = ?
                THEN 1 
                ELSE 0 
            END) AS non_cash_orders_count
            
        FROM
            users U
        LEFT JOIN 
            orders O ON U.id = O.deliveryman_id AND DATE(O.updated_at) = ? 
        LEFT JOIN 
            cash_transactions CT ON U.id = CT.user_id 
                                    AND CT.type IN ('remittance', 'expense')
                                    AND CT.status = 'confirmed' 
                                    AND DATE(CT.created_at) = ? 
        WHERE
            U.role = 'livreur'
            AND U.status = 'actif'
        GROUP BY
            U.id, U.name
        HAVING
            delivered_cash_orders_count > 0 OR total_remitted_confirmed != 0 OR total_expenses_confirmed != 0;
    `;
    const [rows] = await dbConnection.execute(sql, [date, date, date, date, date]);
    return rows;
};

/**
 * Récupère le détail de TOUTES les transactions et commandes pour le pop-up 'Gérer'.
 *
 * @param {number} deliverymanId
 * @param {string} date - Date au format 'YYYY-MM-DD'.
 * @returns {Promise<Array>} Tableau d'objets combinés (transactions et commandes).
 */
exports.getDeliverymanTransactionsAndOrders = async (deliverymanId, date) => {
    // 1. Récupérer les commandes livrées/manquées du jour (sources du cash)
    const ordersSql = `
        SELECT
            O.id AS id,
            'order' AS type,
            O.article_amount,
            O.delivery_fee,
            O.expedition_fee,
            O.status,
            O.payment_status,
            O.delivery_location AS comment,
            (O.article_amount + O.delivery_fee) AS cash_collected,
            NULL AS amount,
            O.created_at,
            S.name AS shop_name,
            (SELECT GROUP_CONCAT(item_name SEPARATOR ', ') FROM order_items WHERE order_id = O.id) AS item_names
        FROM
            orders O
        LEFT JOIN
            shops S ON O.shop_id = S.id
        WHERE
            O.deliveryman_id = ?
            AND DATE(O.updated_at) = ?
            AND O.status IN ('delivered', 'failed_delivery', 'cancelled')
        ORDER BY
            O.created_at ASC;
    `;
    
    // 2. Récupérer les versements (remittance) et dépenses (expense) du jour
    const transactionsSql = `
        SELECT
            CT.id AS id,
            CT.type,
            CT.amount,
            CT.comment,
            CT.status,
            CT.created_at
        FROM
            cash_transactions CT
        WHERE
            CT.user_id = ?
            AND DATE(CT.created_at) = ?
            AND CT.type IN ('remittance', 'expense', 'manual_withdrawal')
        ORDER BY
            CT.created_at ASC;
    `;

    const [orders] = await dbConnection.execute(ordersSql, [deliverymanId, date]);
    const [transactions] = await dbConnection.execute(transactionsSql, [deliverymanId, date]);

    // Combiner les résultats pour le frontend (le frontend filtrera pour l'affichage)
    // Ici, le but est de donner une vue complète des mouvements du livreur pour le caissier.
    return { orders: orders, transactions: transactions };
};

// NOTE: Renommage de l'export pour qu'il corresponde à la fonction mise à jour
exports.getDeliverymanOrderDetails = exports.getDeliverymanTransactionsAndOrders;