// src/models/order.model.js
const moment = require('moment');
const balanceService = require('../services/balance.service');
const cashModel = require('./cash.model'); // Importation du modèle de caisse

let dbConnection;

module.exports = {
    init: (connection) => { 
        dbConnection = connection;
    },
    
    create: async (orderData) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const orderQuery = `INSERT INTO orders (shop_id, customer_name, customer_phone, delivery_location, article_amount, delivery_fee, expedition_fee, status, payment_status, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`;
            const [orderResult] = await connection.execute(orderQuery, [
                orderData.shop_id, orderData.customer_name, orderData.customer_phone,
                orderData.delivery_location, orderData.article_amount, orderData.delivery_fee,
                orderData.expedition_fee, 'pending', 'pending', orderData.created_by
            ]);
            const orderId = orderResult.insertId;
            const itemQuery = 'INSERT INTO order_items (order_id, item_name, quantity, amount) VALUES (?, ?, ?, ?)';
            for (const item of orderData.items) {
                await connection.execute(itemQuery, [orderId, item.item_name, item.quantity, item.amount]);
            }
            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, 'Commande créée', orderData.created_by]);
            
            const orderDate = moment().format('YYYY-MM-DD');
            await balanceService.updateDailyBalance(connection, {
                shop_id: orderData.shop_id,
                date: orderDate,
                orders_sent: 1,
                expedition_fees: parseFloat(orderData.expedition_fee || 0)
            });

            await balanceService.syncBalanceDebt(connection, orderData.shop_id, orderDate);

            await connection.commit();
            return { success: true, orderId };
        } catch (error) {
            await connection.rollback(); throw error;
        } finally {
            connection.release();
        }
    },
    
    update: async (orderId, orderData, userId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [oldOrderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            if (oldOrderRows.length === 0) throw new Error("Commande non trouvée.");
            const oldOrder = oldOrderRows[0];
            const oldDate = moment(oldOrder.created_at).format('YYYY-MM-DD');

            // 1. SYNCHRONISATION INVERSE: Supprimer l'ancienne transaction de versement PENDING
            await cashModel.removeRemittanceByOrderId(orderId);
            
            // Annuler l'impact de l'ancienne version sur les bilans marchands
            const oldImpact = balanceService.getBalanceImpactForStatus(oldOrder);
            await balanceService.updateDailyBalance(connection, {
                shop_id: oldOrder.shop_id, date: oldDate,
                orders_sent: -1,
                orders_delivered: -oldImpact.orders_delivered,
                revenue_articles: -oldImpact.revenue_articles,
                delivery_fees: -oldImpact.delivery_fees,
                packaging_fees: -oldImpact.packaging_fees,
                expedition_fees: -parseFloat(oldOrder.expedition_fee || 0)
            });

            const { items, ...orderFields } = orderData;
            const fieldsToUpdate = Object.keys(orderFields).map(key => `${key} = ?`).join(', ');
            const params = [...Object.values(orderFields), userId, orderId];
            await connection.execute(`UPDATE orders SET ${fieldsToUpdate}, updated_by = ?, updated_at = NOW() WHERE id = ?`, params);

            if (items) {
                await connection.execute('DELETE FROM order_items WHERE order_id = ?', [orderId]);
                const itemQuery = 'INSERT INTO order_items (order_id, item_name, quantity, amount) VALUES (?, ?, ?, ?)';
                for (const item of items) {
                    await connection.execute(itemQuery, [orderId, item.item_name, item.quantity, item.amount]);
                }
            }
            
            const [newOrderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            const newOrder = newOrderRows[0];
            const newDate = moment(newOrder.created_at).format('YYYY-MM-DD');

            // 2. LOGIQUE DE VERSEMENT APRÈS MISE À JOUR (Recréer la transaction si statut valide)
            if (newOrder.status === 'delivered' && newOrder.payment_status === 'cash') {
                const collectedAmount = parseFloat(newOrder.article_amount);
                await cashModel.create({
                    user_id: newOrder.deliveryman_id,
                    type: 'remittance',
                    category_id: null,
                    amount: collectedAmount,
                    comment: `Versement en attente pour la commande n°${orderId}`,
                    created_at: moment().format('YYYY-MM-DD HH:mm:ss')
                });
            }

            // 3. Appliquer le nouvel impact sur les bilans marchands
            const newImpact = balanceService.getBalanceImpactForStatus(newOrder);
            await balanceService.updateDailyBalance(connection, {
                shop_id: newOrder.shop_id, date: newDate,
                orders_sent: 1,
                orders_delivered: newImpact.orders_delivered,
                revenue_articles: newImpact.revenue_articles,
                delivery_fees: newImpact.delivery_fees,
                packaging_fees: newImpact.packaging_fees,
                expedition_fees: parseFloat(newOrder.expedition_fee || 0)
            });
            
            // Synchroniser les dettes pour l'ancien et le nouveau bilan si la date ou le marchand ont changé
            await balanceService.syncBalanceDebt(connection, oldOrder.shop_id, oldDate);
            if (oldOrder.shop_id != newOrder.shop_id || oldDate != newDate) {
                await balanceService.syncBalanceDebt(connection, newOrder.shop_id, newDate);
            }

            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, 'Mise à jour de la commande', userId]);
            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback(); throw error;
        } finally {
            connection.release();
        }
    },

    updateStatus: async (orderId, newStatus, amountReceived = null, newPaymentStatus = null, userId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const [orderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            const order = orderRows[0];
            if (!order) throw new Error("Commande non trouvée.");
            const orderDate = moment(order.created_at).format('YYYY-MM-DD');

            // 1. SYNCHRONISATION INVERSE: Supprimer toute transaction remittance PENDING existante pour cette commande
            await cashModel.removeRemittanceByOrderId(orderId);

            // Annuler l'impact de l'ancien statut sur le bilan quotidien
            const oldImpact = balanceService.getBalanceImpactForStatus(order);
            await balanceService.updateDailyBalance(connection, {
                shop_id: order.shop_id, date: orderDate,
                orders_delivered: -oldImpact.orders_delivered,
                revenue_articles: -oldImpact.revenue_articles,
                delivery_fees: -oldImpact.delivery_fees,
                packaging_fees: -oldImpact.packaging_fees
            });

            const updatedOrderData = { ...order, status: newStatus };
            
            if (newStatus === 'delivered') { 
                updatedOrderData.payment_status = newPaymentStatus; 
                
                // LOGIQUE DE CRÉATION : Si delivered et cash, recréer le versement
                if (updatedOrderData.payment_status === 'cash') {
                    const collectedAmount = parseFloat(order.article_amount);
                    await cashModel.create({
                        user_id: order.deliveryman_id,
                        type: 'remittance',
                        category_id: null,
                        amount: collectedAmount,
                        comment: `Versement en attente pour la commande n°${orderId}`,
                        created_at: moment().format('YYYY-MM-DD HH:mm:ss')
                    });
                }
            } 
            else if (newStatus === 'cancelled') {
                updatedOrderData.payment_status = 'cancelled';
                amountReceived = null; 
            }
            else if (newStatus === 'failed_delivery') {
                updatedOrderData.amount_received = amountReceived;
                updatedOrderData.payment_status = (amountReceived > 0) ? 'cash' : 'paid_to_supplier';

                // NOUVEAU: Si livraison ratée mais argent reçu (cas rare, mais possible pour frais),
                // ON CRÉE LA TRANSACTION DE CAISSE
                if (amountReceived > 0) {
                     const collectedAmount = parseFloat(order.article_amount);
                    await cashModel.create({
                        user_id: order.deliveryman_id,
                        type: 'remittance',
                        category_id: null,
                        amount: collectedAmount,
                        comment: `Versement en attente (Échec) pour la commande n°${orderId}`,
                        created_at: moment().format('YYYY-MM-DD HH:mm:ss')
                    });
                }
            }
            
            // 2. Appliquer l'impact du nouveau statut sur le bilan quotidien
            const newImpact = balanceService.getBalanceImpactForStatus(updatedOrderData);
            await balanceService.updateDailyBalance(connection, {
                shop_id: order.shop_id, date: orderDate,
                orders_delivered: newImpact.orders_delivered,
                revenue_articles: newImpact.revenue_articles,
                delivery_fees: newImpact.delivery_fees,
                packaging_fees: newImpact.packaging_fees
            });
            
            // 3. Mise à jour finale de la commande dans la base de données
            await connection.execute('UPDATE orders SET status = ?, payment_status = ?, amount_received = ?, updated_by = ?, updated_at = NOW() WHERE id = ?', [newStatus, updatedOrderData.payment_status, amountReceived, userId, orderId]);
            await balanceService.syncBalanceDebt(connection, order.shop_id, orderDate);
            
            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, `Statut changé en ${newStatus}`, userId]);
            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback(); throw error;
        } finally {
            connection.release();
        }
    },
    
    remove: async (orderId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const [orderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            if (orderRows.length === 0) throw new Error("Commande non trouvée.");
            const order = orderRows[0];
            const orderDate = moment(order.created_at).format('YYYY-MM-DD');

            // SYNCHRONISATION INVERSE: Supprimer la transaction de versement PENDING
            await cashModel.removeRemittanceByOrderId(orderId);

            const impact = balanceService.getBalanceImpactForStatus(order);
            await balanceService.updateDailyBalance(connection, {
                shop_id: order.shop_id, date: orderDate,
                orders_sent: -1,
                orders_delivered: -impact.orders_delivered,
                revenue_articles: -impact.revenue_articles,
                delivery_fees: -impact.delivery_fees,
                packaging_fees: -impact.packaging_fees,
                expedition_fees: -parseFloat(order.expedition_fee || 0)
            });

            await balanceService.syncBalanceDebt(connection, order.shop_id, orderDate);

            await connection.execute('DELETE FROM order_history WHERE order_id = ?', [orderId]);
            await connection.execute('DELETE FROM order_items WHERE order_id = ?', [orderId]);
            const [result] = await connection.execute('DELETE FROM orders WHERE id = ?', [orderId]);
            
            await connection.commit();
            return result;
        } catch (error) {
            await connection.rollback(); throw error;
        } finally {
            connection.release();
        }
    },
    
    findAll: async (filters) => {
        const connection = await dbConnection.getConnection();
        try {
            let query = `SELECT o.*, s.name AS shop_name, u.name AS deliveryman_name FROM orders o LEFT JOIN shops s ON o.shop_id = s.id LEFT JOIN users u ON o.deliveryman_id = u.id WHERE 1=1`;
            const params = [];
            if (filters.search) {
                query += ` AND (o.customer_name LIKE ? OR o.customer_phone LIKE ? OR o.delivery_location LIKE ? OR s.name LIKE ? OR u.name LIKE ?)`;
                const searchTerm = `%${filters.search}%`;
                params.push(searchTerm, searchTerm, searchTerm, searchTerm, searchTerm);
            }
            if (filters.startDate) query += ` AND o.created_at >= ?`, params.push(moment(filters.startDate).startOf('day').format('YYYY-MM-DD HH:mm:ss'));
            if (filters.endDate) query += ` AND o.created_at <= ?`, params.push(moment(filters.endDate).endOf('day').format('YYYY-MM-DD HH:mm:ss'));
            if (filters.status) query += ` AND o.status = ?`, params.push(filters.status);
            query += ` ORDER BY o.created_at DESC`;

            const [rows] = await connection.execute(query, params);
            const ordersWithDetails = await Promise.all(rows.map(async (order) => {
                const [items] = await connection.execute('SELECT * FROM order_items WHERE order_id = ?', [order.id]);
                return { ...order, items };
            }));
            return ordersWithDetails;
        } finally {
            connection.release();
        }
    },
    
    findById: async (id) => {
        const connection = await dbConnection.getConnection();
        try {
            const orderQuery = 'SELECT o.*, u.name AS deliveryman_name, s.name AS shop_name FROM orders o LEFT JOIN users u ON o.deliveryman_id = u.id LEFT JOIN shops s ON o.shop_id = s.id WHERE o.id = ?';
            const [orders] = await connection.execute(orderQuery, [id]);
            const order = orders[0];
            if (!order) return null;
            const itemsQuery = 'SELECT * FROM order_items WHERE order_id = ?';
            const [items] = await connection.execute(itemsQuery, [id]);
            order.items = items;
            const historyQuery = 'SELECT oh.*, u.name AS user_name FROM order_history oh LEFT JOIN users u ON oh.user_id = u.id WHERE oh.order_id = ? ORDER BY oh.created_at DESC';
            const [history] = await connection.execute(historyQuery, [id]);
            order.history = history;
            return order;
        } finally {
            connection.release();
        }
    },
        
    assignDeliveryman: async (orderId, deliverymanId, userId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const [deliverymanRows] = await connection.execute('SELECT name FROM users WHERE id = ?', [deliverymanId]);
            const deliverymanName = deliverymanRows[0]?.name || 'Inconnu';
            const query = 'UPDATE orders SET deliveryman_id = ?, status = ?, payment_status = ?, updated_by = ?, updated_at = NOW() WHERE id = ?';
            await connection.execute(query, [deliverymanId, 'in_progress', 'pending', userId, orderId]);
            const historyQuery = 'INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)';
            const historyMessage = `Commande assignée au livreur : ${deliverymanName}`;
            await connection.execute(historyQuery, [orderId, historyMessage, userId]);
            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }
};