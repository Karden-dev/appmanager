const cashiersRemittancesService = require('../services/cashiersremittances.service');
const cashiersRemittancesModel = require('../models/cashiersremittances.model');
const userModel = require('../models/user.model'); 

/**
 * Récupère le résumé consolidé des encaissements et les détails pour le front-end.
 * Route: GET /api/cashiers/remittances
 */
exports.getRemittanceSummary = async (req, res) => {
    const date = req.query.date || new Date().toISOString().split('T')[0];

    try {
        const summary = await cashiersRemittancesService.getDailyRemittanceSummaryWithBalance(date);
        
        // Récupérer les catégories de dépenses pour le formulaire
        const expenseCategories = await userModel.getExpenseCategoriesByType('deliveryman_charge');

        res.status(200).json({ summary, expenseCategories, selectedDate: date });
    } catch (error) {
        console.error('Erreur lors de la récupération du résumé des encaissements:', error);
        // Ajout du code d'erreur pour aider au débogage
        res.status(500).json({ message: 'Erreur serveur lors de la récupération du résumé des encaissements.', detail: error.message });
    }
};

/**
 * Récupère le détail des commandes et transactions pour un livreur spécifique.
 * Route: GET /api/cashiers/remittances/:deliverymanId/details
 */
exports.getDeliverymanDetails = async (req, res) => {
    const { deliverymanId } = req.params;
    const date = req.query.date || new Date().toISOString().split('T')[0];

    try {
        // CORRECTION: Utilisation de la nouvelle fonction qui retourne commandes ET transactions
        const data = await cashiersRemittancesModel.getDeliverymanTransactionsAndOrders(deliverymanId, date);
        res.status(200).json(data);
    } catch (error) {
        console.error('Erreur lors de la récupération des détails du livreur:', error);
        res.status(500).json({ message: 'Erreur serveur lors de la récupération des détails.', detail: error.message });
    }
};

/**
 * Confirme le versement d'un livreur (version simplifiée pour la caisse).
 * Route: POST /api/cashiers/remittances/confirm
 */
exports.confirmRemittance = async (req, res) => {
    // Dans ce modèle, nous enregistrons le versement global, 
    // l'association aux commandes n'est pas gérée ici, seule la caisse est impactée.
    const { deliverymanId, date, paidAmount, comment } = req.body;
    const userId = req.user.id; // ID de la caissière/admin connecté

    if (!deliverymanId || !date || typeof paidAmount !== 'number' || paidAmount <= 0) {
        return res.status(400).json({ message: 'Données de versement invalides.' });
    }

    try {
        const updatedSummary = await cashiersRemittancesService.confirmDeliverymanRemittance(
            deliverymanId,
            date,
            paidAmount,
            userId,
            comment
        );
        res.status(200).json({ message: 'Versement confirmé avec succès.', summary: updatedSummary });
    } catch (error) {
        console.error('Erreur lors de la confirmation du versement:', error);
        res.status(500).json({ message: 'Erreur serveur lors de la confirmation du versement.', detail: error.message });
    }
};

/**
 * Déclare une dépense pour un livreur (déduction sur l'encaissement).
 * Route: POST /api/cashiers/remittances/expense
 */
exports.declareExpense = async (req, res) => {
    const { deliverymanId, date, amount, categoryId, comment } = req.body;
    const userId = req.user.id; // ID de la caissière/admin connecté

    if (!deliverymanId || !date || typeof amount !== 'number' || amount <= 0 || !categoryId) {
        return res.status(400).json({ message: 'Données de dépense invalides.' });
    }

    try {
        const updatedSummary = await cashiersRemittancesService.declareDeliverymanExpense(
            deliverymanId,
            date,
            amount,
            categoryId,
            comment,
            userId
        );
        res.status(200).json({ message: 'Dépense enregistrée avec succès.', summary: updatedSummary });
    } catch (error) {
        console.error('Erreur lors de la déclaration de la dépense:', error);
        res.status(500).json({ message: 'Erreur serveur lors de la déclaration de la dépense.', detail: error.message });
    }
};