// src/services/cash.service.js
const moment = require('moment');
const cashStatModel = require('../models/cash.stat.model'); 

let dbConnection;

const init = (connection) => {
    dbConnection = connection;
    cashStatModel.init(connection); 
};

/**
 * Crée une transaction de type 'remittance' en attente de confirmation.
 */
const createRemittanceTransaction = async (deliverymanId, amount, comment) => {
    const connection = await dbConnection.getConnection();
    try {
        const query = 'INSERT INTO cash_transactions (user_id, type, amount, comment, status) VALUES (?, ?, ?, ?, ?)';
        await connection.execute(query, [deliverymanId, 'remittance', amount, comment, 'pending']);
    } finally {
        connection.release();
    }
};

/**
 * Calcule le montant total que le livreur doit à l'entreprise.
 */
const getDeliverymanOwedAmount = async (deliverymanId) => {
    const connection = await dbConnection.getConnection();
    try {
        // 1. Calcul des gains nets du livreur (encaissements des commandes - frais de livraison)
        const [gainsResult] = await connection.execute(
            `
            SELECT
                COALESCE(SUM(
                    CASE
                        WHEN o.status = 'delivered' AND o.payment_status = 'cash' THEN o.article_amount
                        WHEN o.status = 'failed_delivery' THEN o.amount_received
                        ELSE 0
                    END
                ), 0) AS total_encaissements,
                COALESCE(SUM(o.delivery_fee), 0) AS total_frais_livraison
            FROM orders o
            WHERE o.deliveryman_id = ? AND o.status IN ('delivered', 'failed_delivery')
            `,
            [deliverymanId]
        );
        const netGains = parseFloat(gainsResult[0].total_encaissements || 0) - parseFloat(gainsResult[0].total_frais_livraison || 0);
        
        // 2. Calcul des dépenses du livreur validées
        const [expensesResult] = await connection.execute(
            `
            SELECT COALESCE(SUM(amount), 0) AS total_expenses
            FROM cash_transactions
            WHERE user_id = ? AND type = 'expense' AND status = 'confirmed'
            `,
            [deliverymanId]
        );
        const totalExpenses = parseFloat(expensesResult[0].total_expenses || 0);
        
        // 3. Calcul des versements déjà effectués et validés par le livreur
        const [remittancesResult] = await connection.execute(
            `
            SELECT COALESCE(SUM(amount), 0) AS total_remittances
            FROM cash_transactions
            WHERE user_id = ? AND type = 'remittance' AND status = 'confirmed'
            `,
            [deliverymanId]
        );
        const totalRemittances = parseFloat(remittancesResult[0].total_remittances || 0);

        const owedAmount = (netGains + totalExpenses) - totalRemittances;

        return owedAmount;
    } finally {
        connection.release();
    }
};

/**
 * Calcule la situation de la caisse complète en utilisant la formule demandée.
 * @param {string} startDate
 * @param {string} endDate
 * @returns {Promise<Object>}
 */
const getCashMetrics = async (startDate, endDate) => {
    try {
        // 1. Récupérer toutes les métriques en parallèle
        const [
            ca,
            cashCollected, // NOUVELLE MÉTRIQUE
            cashTransactions,
            debtMetrics,
            shortfallMetrics
        ] = await Promise.all([
            cashStatModel.getRevenue(startDate, endDate),
            cashStatModel.getCashCollected(startDate, endDate), // Appel à la nouvelle fonction
            cashStatModel.getExpensesAndWithdrawals(startDate, endDate),
            cashStatModel.getDebtMetrics(startDate, endDate),
            cashStatModel.getShortfallMetrics(startDate, endDate)
        ]);
        
        const { totalExpenses, totalWithdrawals } = cashTransactions;
        const { paidDebts, pendingDebts } = debtMetrics;
        const { paidShortfalls, pendingShortfalls } = shortfallMetrics;

        // 2. Formule du Montant en Caisse (Encaisse Théorique) :
        // Montant en Caisse = CA 
        //                    - (Dépenses + Décaissements + Créances non remboursées + Manquants non remboursés) 
        //                    + (Créances remboursées + Manquants remboursés)
        
        const sortiesNettes = totalExpenses + totalWithdrawals;
        // Créances et manquants non remboursés sont soustraits (car c'est de l'argent dû qui n'est PAS dans la caisse)
        const elementsNonRembourses = pendingDebts + pendingShortfalls;
        // Créances et manquants remboursés sont ajoutés (car c'est de l'argent qui est RENTRÉ dans la caisse pour payer ces dettes)
        const elementsRembourses = paidDebts + paidShortfalls;
        
        const montantEnCaisse = ca 
            - sortiesNettes 
            - elementsNonRembourses 
            + elementsRembourses;

        // 3. Retourner le résultat avec toutes les métriques détaillées
        return {
            // Montant principal calculé (Montant en Caisse)
            montant_en_caisse: parseFloat(montantEnCaisse.toFixed(2)), 

            // Composants du CA
            chiffre_affaire_ca: parseFloat(ca.toFixed(2)),

            // Encaissement (Versements Confirmés)
            encaisser: parseFloat(cashCollected.toFixed(2)),

            // Sorties de caisse (maintenant POSITIF grâce au Model)
            depenses: parseFloat(totalExpenses.toFixed(2)),
            decaissements: parseFloat(totalWithdrawals.toFixed(2)),
            
            // Créances
            creances_remboursees: parseFloat(paidDebts.toFixed(2)),
            creances_non_remboursees: parseFloat(pendingDebts.toFixed(2)),
            
            // Manquants Livreur
            manquants_rembourses: parseFloat(paidShortfalls.toFixed(2)),
            manquants_non_remboursees: parseFloat(pendingShortfalls.toFixed(2)),
        };

    } catch (error) {
        throw error;
    }
};

module.exports = {
    init,
    createRemittanceTransaction,
    getDeliverymanOwedAmount,
    getCashMetrics
};