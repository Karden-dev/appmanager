const cashiersRemittancesModel = require('../models/cashiersremittances.model.js');
const cashModel = require('../models/cash.model'); 
const debtModel = require('../models/debt.model'); 

/**
 * Prépare les données consolidées pour le tableau de bord des encaissements livreurs.
 * @param {string} date - Date au format 'YYYY-MM-DD'.
 * @returns {Promise<Array>} Tableau des résumés avec les calculs de solde.
 */
exports.getDailyRemittanceSummaryWithBalance = async (date) => {
    const rawSummaries = await cashiersRemittancesModel.getDailyRemittanceSummary(date);

    const summaryWithBalance = rawSummaries.map(summary => {
        // Montant encaissé auprès des clients (Art. + F.Liv.)
        const expectedCashCollected = parseFloat(summary.total_cash_collected);
        
        // Dépenses Livreur confirmées (déduites du Montant Attendu) - Le montant est négatif dans la BD
        const confirmedExpenses = parseFloat(summary.total_expenses_confirmed);

        // Montant total que le livreur doit théoriquement reverser (Encaissement Brut - Dépenses Validées)
        const expectedRemittanceNet = expectedCashCollected + confirmedExpenses; 
        
        // Montant réellement versé et confirmé par la caisse
        const confirmedRemittance = parseFloat(summary.total_remitted_confirmed);

        // Calcul du Solde Actuel (En attente de versement si positif)
        const currentBalance = expectedRemittanceNet - confirmedRemittance;
        
        // Compter les commandes livrées dont le versement n'est pas couvert.
        // Puisque nous gérons le solde de trésorerie de manière agrégée, 
        // le statut sera "En cours" si le solde est positif.
        const isSettled = currentBalance <= 0;
        
        // Compteur de commandes en attente (Approximation : le nombre de commandes livrées en espèces si non réglé)
        const pendingRemittanceOrders = isSettled ? 0 : parseInt(summary.delivered_cash_orders_count);

        return {
            deliveryman_id: summary.deliveryman_id,
            deliveryman_name: summary.deliveryman_name,
            // total_daily_orders: parseInt(summary.delivered_cash_orders_count) + parseInt(summary.non_cash_orders_count), // Total des commandes gérées
            
            // Montants pour l'UI
            expected_remittance: expectedRemittanceNet.toFixed(2), // Montant Attendu Net
            confirmed_remittance: confirmedRemittance.toFixed(2), // Montant Confirmé
            
            // Règle 1: NE PAS afficher Manquant/Excédent directement, 
            // mais un statut simple basé sur le Solde Courant
            status: isSettled ? 'Réglé' : 'En Cours', // 'En Cours' ou 'Manquant' à la clôture
            current_balance: currentBalance.toFixed(2), // Pour le calcul côté client si besoin, mais surtout pour le statut.
            
            // Indicateurs de comptage pour l'UI
            pending_remittance_orders: pendingRemittanceOrders,
            confirmed_remittance_orders: summary.delivered_cash_orders_count - pendingRemittanceOrders,

            // Montant total collecté brut (pour info)
            total_cash_collected_raw: expectedCashCollected.toFixed(2),
            total_expenses_confirmed: Math.abs(confirmedExpenses).toFixed(2)
        };
    });

    return summaryWithBalance;
};


/**
 * Confirme un versement du livreur.
 * @param {number} deliverymanId - ID du livreur.
 * @param {string} date - Date du versement.
 * @param {number} amount - Montant versé.
 * @param {number} userId - ID de l'utilisateur (caissier) qui confirme.
 * @param {string} comment - Commentaire (optionnel).
 * @returns {Promise<object>} Le résumé mis à jour du livreur.
 */
exports.confirmDeliverymanRemittance = async (deliverymanId, date, amount, userId, comment) => {
    // 1. Enregistre le versement dans cash_transactions
    await cashModel.createCashTransaction({
        user_id: deliverymanId,
        type: 'remittance',
        amount: amount,
        comment: `Versement confirmé par la caisse pour le ${date}. ${comment || ''}`,
        status: 'confirmed',
        validated_by: userId,
        validated_at: new Date()
    });

    // Règle 4: Le manquant n'est généré qu'en fin de journée (clôture)
    // Nous ne faisons AUCUNE modification à deliveryman_shortfalls ici.
    
    // 2. Retourne le summary recalculé pour l'UI
    return exports.getDailyRemittanceSummaryWithBalance(date);
};


/**
 * Déclare une dépense et l'enregistre comme 'expense' confirmée.
 * @param {number} deliverymanId - ID du livreur.
 * @param {string} date - Date de la dépense.
 * @param {number} amount - Montant de la dépense (positif).
 * @param {number} categoryId - ID de la catégorie de dépense.
 * @param {string} comment - Commentaire.
 * @param {number} userId - ID de l'utilisateur (caissier) qui confirme.
 * @returns {Promise<object>} Le résumé mis à jour du livreur.
 */
exports.declareDeliverymanExpense = async (deliverymanId, date, amount, categoryId, comment, userId) => {
    // 1. Enregistre la dépense dans cash_transactions
    // Le montant doit être négatif pour un expense
    await cashModel.createCashTransaction({
        user_id: deliverymanId,
        type: 'expense',
        category_id: categoryId,
        amount: -Math.abs(amount), // Assurer que le montant est négatif
        comment: `Dépense déclarée pour le ${date} par la caisse. ${comment || ''}`,
        status: 'confirmed',
        validated_by: userId,
        validated_at: new Date()
    });

    // 2. Retourne le summary recalculé pour l'UI
    return exports.getDailyRemittanceSummaryWithBalance(date);
};