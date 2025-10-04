const express = require('express');
const router = express.Router();
const { isLoggedIn, isAdmin } = require('../middleware/auth.middleware');
const cashiersRemittancesController = require('../controllers/cashiersremittances.controller');

// Middleware d'autorisation général pour la caisse (Admin requis)
router.use(isLoggedIn, isAdmin);

// GET /api/cashiers/remittances - Récupère le résumé journalier des encaissements livreurs
router.get('/', cashiersRemittancesController.getRemittanceSummary);

// GET /api/cashiers/remittances/:deliverymanId/details - Récupère le détail des commandes
router.get('/:deliverymanId/details', cashiersRemittancesController.getDeliverymanDetails);

// POST /api/cashiers/remittances/confirm - Confirme un versement du livreur
router.post('/confirm', cashiersRemittancesController.confirmRemittance);

// POST /api/cashiers/remittances/expense - Déclare une dépense (réduction sur l'encaissement)
router.post('/expense', cashiersRemittancesController.declareExpense);

module.exports = router;