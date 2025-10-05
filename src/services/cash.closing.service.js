// src/services/cash.closing.service.js

const moment = require('moment');
const cashStatModel = require('../models/cash.stat.model'); 
let db;

const init = (dbConnection) => {
    db = dbConnection;
    // IMPORTANT: Assurez-vous d'initialiser cashStatModel également dans votre app.js
};

/**
 * Récupère l'historique des clôtures.
 * @param {Object} filters - Contient startDate et endDate.
 * @returns {Promise<Array>} Retourne toujours un tableau, même vide, pour le frontend.
 */
const findClosingHistory = async (filters = {}) => {
    const connection = await db.getConnection();
    try {
        const { startDate, endDate } = filters;
        let query = `
            SELECT 
                cc.*, u.name AS closed_by_user_name
            FROM cash_closings cc
            LEFT JOIN users u ON cc.closed_by_user_id = u.id
            WHERE 1=1
        `;

        if (startDate && endDate) {
            query += ` AND cc.closing_date BETWEEN '${moment(startDate).format('YYYY-MM-DD')}' AND '${moment(endDate).format('YYYY-MM-DD')}'`;
        }

        query += ` ORDER BY cc.closing_date DESC`;

        const [history] = await connection.execute(query);
        
        // CORRECTION DU BUG "Format de données invalide" : Assure que l'on retourne un tableau.
        return Array.isArray(history) ? history : [];

    } catch (error) {
        throw error;
    } finally {
        connection.release();
    }
};

/**
 * Enregistre la clôture de caisse pour une date donnée.
 * Calcule l'encaisse théorique (expected_cash) pour la période.
 * @param {string} closingDate - Date de la clôture (YYYY-MM-DD).
 * @param {number} actualCash - Montant réel compté en caisse.
 * @param {string} comment
 * @param {number} userId
 * @returns {Promise<{expected_cash: number, actual_cash: number, difference: number}>}
 */
const performCashClosing = async (closingDate, actualCash, comment, userId) => {
    const connection = await db.getConnection();
    await connection.beginTransaction();

    try {
        // 1. Vérification d'unicité de la date de clôture
        const [existingClosing] = await connection.execute('SELECT id FROM cash_closings WHERE closing_date = ?', [closingDate]);
        if (existingClosing.length > 0) {
            throw new Error(`La caisse est déjà clôturée pour la date du ${moment(closingDate).format('DD/MM/YYYY')}.`);
        }
        
        // 2. Calcul de l'Encaisse Théorique (Expected Cash)
        // Note: Nous utilisons getCashMetrics (du service cash.service) qui appelle toutes les stats.
        // Puisque nous sommes dans un nouveau service, nous devons recréer la logique de métriques ou l'importer si possible.
        // Pour éviter une dépendance circulaire, nous importons directement le cashStatModel.
        
        const [
            ca,
            cashCollected,
            cashTransactions,
            debtMetrics,
            shortfallMetrics
        ] = await Promise.all([
            cashStatModel.getRevenue(closingDate, closingDate),
            cashStatModel.getCashCollected(closingDate, closingDate),
            cashStatModel.getExpensesAndWithdrawals(closingDate, closingDate),
            cashStatModel.getDebtMetrics(closingDate, closingDate),
            cashStatModel.getShortfallMetrics(closingDate, closingDate)
        ]);

        const { totalExpenses, totalWithdrawals } = cashTransactions;
        const { paidDebts, pendingDebts } = debtMetrics;
        const { paidShortfalls, pendingShortfalls } = shortfallMetrics;

        // Formule de l'Encaisse Théorique (Montant en Caisse)
        const sortiesNettes = totalExpenses + totalWithdrawals;
        const elementsNonRembourses = pendingDebts + pendingShortfalls;
        const elementsRembourses = paidDebts + paidShortfalls;
        
        const expectedCash = ca 
            - sortiesNettes 
            - elementsNonRembourses 
            + elementsRembourses;
        
        const difference = parseFloat(actualCash) - expectedCash;
        
        // 3. Insertion du snapshot complet dans cash_closings
        const insertQuery = `
            INSERT INTO cash_closings (
                closing_date, 
                total_cash_collected, 
                total_delivery_fees, 
                total_expenses, 
                total_remitted, 
                total_withdrawals, 
                expected_cash, 
                actual_cash_counted, 
                difference, 
                comment, 
                closed_by_user_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;
        
        await connection.execute(insertQuery, [
            closingDate,
            cashCollected,              // total_cash_collected (Versements Confirmés)
            ca,                         // total_delivery_fees (CA - Fees)
            totalExpenses,              // total_expenses
            elementsRembourses,         // total_remitted (Versements reçus/réglés pour les dettes)
            totalWithdrawals,           // total_withdrawals
            expectedCash,
            parseFloat(actualCash),
            difference,
            comment,
            userId
        ]);

        await connection.commit();
        
        return { 
            expected_cash: expectedCash, 
            actual_cash: parseFloat(actualCash), 
            difference: difference 
        };

    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
};

module.exports = {
    init,
    findClosingHistory,
    performCashClosing
};