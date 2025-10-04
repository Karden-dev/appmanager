// src/models/report.model.js
const moment = require('moment');
const balanceService = require('../services/balance.service'); // Assurez-vous que cet import est présent si vous avez la fonction recalculate

let dbConnection;

module.exports = {
    init: (connection) => { dbConnection = connection; },

    findReportsByDate: async (date) => {
        const connection = await dbConnection.getConnection();
        try {
            // MODIFICATION CLÉ : Aucun filtre appliqué ici pour que toutes les données soient envoyées au frontend.
            const query = `
                SELECT
                    dsb.shop_id,
                    s.name as shop_name,
                    dsb.total_orders_sent,
                    dsb.total_orders_delivered,
                    dsb.total_revenue_articles,
                    dsb.total_delivery_fees,
                    dsb.total_expedition_fees,
                    dsb.total_packaging_fees,
                    dsb.total_storage_fees,
                    dsb.remittance_amount
                FROM shops s
                JOIN daily_shop_balances dsb ON s.id = dsb.shop_id
                WHERE dsb.report_date = ?
                ORDER BY s.name ASC;
            `;
            const [rows] = await connection.execute(query, [date]);
            
            // On s'assure que le champ 'expedition_fee' est bien présent pour la compatibilité
            return rows.map(row => ({ 
                ...row, 
                amount_to_remit: row.remittance_amount,
                expedition_fee: row.total_expedition_fees
            }));
        } finally {
            connection.release();
        }
    },
    
    findDetailedReport: async (date, shopId) => {
        const connection = await dbConnection.getConnection();
        try {
            const [summaries] = await connection.execute(
                `SELECT dsb.*, s.name as shop_name 
                 FROM daily_shop_balances dsb
                 JOIN shops s ON s.id = dsb.shop_id 
                 WHERE dsb.report_date = ? AND dsb.shop_id = ?`, 
                [date, shopId]
            );
            const summary = summaries[0];
            if (!summary) return null;
            
            summary.amount_to_remit = summary.remittance_amount;

            const ordersQuery = `
                SELECT
                    o.id, o.delivery_location, o.customer_phone, o.article_amount,
                    o.delivery_fee, o.status, o.amount_received,
                    GROUP_CONCAT(CONCAT(oi.item_name, ' (', oi.quantity, ')') SEPARATOR ', ') as products_list
                FROM orders o
                LEFT JOIN order_items oi ON o.id = oi.order_id
                WHERE o.shop_id = ? AND DATE(o.created_at) = ? AND o.status IN ('delivered', 'failed_delivery')
                GROUP BY o.id
                ORDER BY o.created_at ASC;
            `;
            const [orders] = await connection.execute(ordersQuery, [shopId, date]);

            return { ...summary, orders: orders };
        } finally {
            connection.release();
        }
    },
    
    /**
     * NOUVEAU : Recalcule et reconstruit le bilan journalier et les créances associées pour une date donnée.
     * Imite la logique de reconstruction totale, mais limitée à une seule journée.
     */
    recalculateDailyReport: async (date) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const dateString = moment(date).format('YYYY-MM-DD');

            // 1. SUPPRIMER l'ancien bilan et la créance de bilan associée
            await connection.execute('DELETE FROM daily_shop_balances WHERE report_date = ?', [dateString]);
            await connection.execute("DELETE FROM debts WHERE DATE(created_at) = ? AND type = 'daily_balance'", [dateString]);
            
            // 2. Récupérer toutes les commandes (avec les données de shop pour le calcul d'impact)
            const [orders] = await connection.execute(`
                SELECT o.*, s.bill_packaging, s.packaging_price 
                FROM orders o 
                JOIN shops s ON o.shop_id = s.id
                WHERE DATE(o.created_at) = ?
                ORDER BY o.created_at ASC
            `, [dateString]);
            
            // 3. Recalculer l'impact de chaque commande et reconstruire le bilan
            for (const order of orders) {
                // a) Appliquer l'impact de l'envoi initial (orders_sent et expedition_fee)
                await balanceService.updateDailyBalance(connection, {
                    shop_id: order.shop_id,
                    date: dateString,
                    orders_sent: 1,
                    expedition_fees: parseFloat(order.expedition_fee || 0)
                });

                // b) Appliquer l'impact de l'état final (livrée, ratée, etc.)
                if (order.status !== 'pending' && order.status !== 'in_progress' && order.status !== 'cancelled') {
                    const statusImpact = balanceService.getBalanceImpactForStatus(order);
                    await balanceService.updateDailyBalance(connection, {
                        shop_id: order.shop_id,
                        date: dateString,
                        ...statusImpact
                    });
                }
            }
            
            // 4. SYCHRONISER toutes les créances de bilan pour la date
            const [distinctBalances] = await connection.execute(
                'SELECT DISTINCT shop_id FROM daily_shop_balances WHERE report_date = ?',
                [dateString]
            );

            for (const balance of distinctBalances) {
                await balanceService.syncBalanceDebt(connection, balance.shop_id, dateString);
            }

            await connection.commit();
            return { success: true, date: dateString };
        } catch (error) {
            await connection.rollback(); 
            throw error;
        } finally {
            connection.release();
        }
    }
};