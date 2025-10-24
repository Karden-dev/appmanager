// src/models/order.model.js
const moment = require('moment');
// Import du service de bilan
const balanceService = require('../services/balance.service');
// Le messageModel sera injecté au démarrage via init()
let localMessageModel;

let dbConnection;

module.exports = {
    /**
     * Initialise le modèle avec la connexion BDD et la référence au modèle message.
     */
    init: (connection, msgModel) => {
        dbConnection = connection;
        localMessageModel = msgModel; // Stocke la référence à messageModel
        module.exports.dbConnection = connection; // Expose la connexion si besoin
    },

    /**
     * Crée une nouvelle commande et ses articles associés.
     */
    create: async (orderData) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const orderQuery = `INSERT INTO orders (shop_id, customer_name, customer_phone, delivery_location, article_amount, delivery_fee, expedition_fee, status, payment_status, created_by, created_at, is_urgent, is_archived) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 0, 0)`;
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
            await connection.rollback();
            console.error("Erreur create order:", error);
            throw error;
        } finally {
            connection.release();
        }
    },

    /**
     * Met à jour une commande existante et ses articles.
     */
    update: async (orderId, orderData, userId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [oldOrderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            if (oldOrderRows.length === 0) throw new Error("Commande non trouvée.");
            const oldOrder = oldOrderRows[0];
            const oldOrderDate = moment(oldOrder.created_at).format('YYYY-MM-DD');

            // Annuler l'ancien impact sur le bilan
            if (oldOrder.status !== 'pending') {
                const oldImpact = balanceService.getBalanceImpactForStatus(oldOrder);
                await balanceService.updateDailyBalance(connection, {
                    shop_id: oldOrder.shop_id, date: oldOrderDate,
                    orders_delivered: -oldImpact.orders_delivered,
                    revenue_articles: -oldImpact.revenue_articles,
                    delivery_fees: -oldImpact.delivery_fees,
                    packaging_fees: -oldImpact.packaging_fees
                });
            }
            await balanceService.updateDailyBalance(connection, {
                 shop_id: oldOrder.shop_id, date: oldOrderDate,
                 orders_sent: -1,
                 expedition_fees: -parseFloat(oldOrder.expedition_fee || 0)
            });


            const { items, ...orderFields } = orderData;
            // S'assurer que les champs is_urgent et is_archived sont inclus s'ils sont passés
            const fieldsToUpdate = Object.keys(orderFields).map(key => `${key} = ?`).join(', ');
             // S'assurer que les valeurs null/undefined sont bien gérées
            const fieldValues = Object.values(orderFields).map(val => val === '' ? null : val);
            const params = [...fieldValues, userId, orderId];
            
            if(fieldsToUpdate.length > 0) {
                await connection.execute(`UPDATE orders SET ${fieldsToUpdate}, updated_by = ?, updated_at = NOW() WHERE id = ?`, params);
            } else {
                // Si on met à jour uniquement les items, on met quand même à jour 'updated_by'
                 await connection.execute(`UPDATE orders SET updated_by = ?, updated_at = NOW() WHERE id = ?`, [userId, orderId]);
            }

            // Mise à jour des articles
            if (items) {
                await connection.execute('DELETE FROM order_items WHERE order_id = ?', [orderId]);
                const itemQuery = 'INSERT INTO order_items (order_id, item_name, quantity, amount) VALUES (?, ?, ?, ?)';
                for (const item of items) {
                    await connection.execute(itemQuery, [orderId, item.item_name, item.quantity, item.amount]);
                }
            }

            // Récupérer la commande mise à jour pour recalculer l'impact
            const [newOrderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            const newOrder = newOrderRows[0];
            const newDate = moment(newOrder.created_at).format('YYYY-MM-DD');

            // Appliquer le nouvel impact sur le bilan
             await balanceService.updateDailyBalance(connection, {
                 shop_id: newOrder.shop_id, date: newDate,
                 orders_sent: 1,
                 expedition_fees: parseFloat(newOrder.expedition_fee || 0)
             });
            if (newOrder.status !== 'pending') {
                 const newImpact = balanceService.getBalanceImpactForStatus(newOrder);
                 await balanceService.updateDailyBalance(connection, {
                     shop_id: newOrder.shop_id, date: newDate,
                     ...newImpact
                 });
             }

            // Synchroniser les dettes
            await balanceService.syncBalanceDebt(connection, oldOrder.shop_id, oldOrderDate);
            if (oldOrder.shop_id != newOrder.shop_id || oldOrderDate != newDate) {
                await balanceService.syncBalanceDebt(connection, newOrder.shop_id, newDate);
            } else {
                 await balanceService.syncBalanceDebt(connection, newOrder.shop_id, newDate);
            }

            // Historique (seulement si des champs ou items ont été modifiés)
             if (items || Object.keys(orderFields).length > 0) {
                await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, 'Mise à jour de la commande', userId]);
             }

            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur update order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },

    /**
     * Met à jour le statut et le statut de paiement d'une commande.
     */
    updateStatus: async (orderId, newStatus, amountReceived = null, newPaymentStatus = null, userId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const [orderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            const order = orderRows[0];
            if (!order) throw new Error("Commande non trouvée.");
            const orderDate = moment(order.created_at).format('YYYY-MM-DD');
            const oldStatus = order.status;

            const finalStatusesForArchive = ['delivered', 'cancelled', 'failed_delivery', 'returned'];

            // 1. Annuler l'ancien impact (sauf si 'pending')
            if (oldStatus !== 'pending') {
                 const oldImpact = balanceService.getBalanceImpactForStatus(order);
                 await balanceService.updateDailyBalance(connection, {
                     shop_id: order.shop_id, date: orderDate,
                     orders_delivered: -oldImpact.orders_delivered,
                     revenue_articles: -oldImpact.revenue_articles,
                     delivery_fees: -oldImpact.delivery_fees,
                     packaging_fees: -oldImpact.packaging_fees
                 });
             }

            // 2. Déterminer les nouvelles valeurs
            const updatedOrderData = { ...order, status: newStatus };
            let finalPaymentStatus = order.payment_status;
            let finalAmountReceived = order.amount_received;

            if (newStatus === 'delivered') {
                finalPaymentStatus = newPaymentStatus || 'cash';
                finalAmountReceived = order.article_amount;
            } else if (newStatus === 'cancelled') {
                finalPaymentStatus = 'cancelled';
                finalAmountReceived = null;
            } else if (newStatus === 'failed_delivery') {
                finalAmountReceived = (amountReceived !== null && !isNaN(parseFloat(amountReceived))) ? parseFloat(amountReceived) : null;
                finalPaymentStatus = (finalAmountReceived !== null && finalAmountReceived > 0) ? 'cash' : 'pending';
            } else if (['pending', 'in_progress', 'reported', 'ready_for_pickup', 'en_route', 'return_declared'].includes(newStatus)) {
                 finalPaymentStatus = 'pending';
                 finalAmountReceived = null;
            }

            // 3. Appliquer l'impact (sauf si statut intermédiaire)
            if (!['pending', 'in_progress', 'reported', 'ready_for_pickup', 'en_route', 'return_declared'].includes(newStatus)) {
                 updatedOrderData.payment_status = finalPaymentStatus;
                 updatedOrderData.amount_received = finalAmountReceived;
                 const newImpact = balanceService.getBalanceImpactForStatus(updatedOrderData);
                 await balanceService.updateDailyBalance(connection, {
                     shop_id: order.shop_id, date: orderDate,
                     ...newImpact
                 });
            }

            // 4. Mettre à jour la commande
            const isFinal = finalStatusesForArchive.includes(newStatus);
            const wasFinal = finalStatusesForArchive.includes(oldStatus);
            let archiveUpdateSql = '';
            if (isFinal && !wasFinal) {
                archiveUpdateSql = ', is_archived = 1';
            } else if (!isFinal && wasFinal) {
                archiveUpdateSql = ', is_archived = 0';
            }
            
            await connection.execute(
                `UPDATE orders SET status = ?, payment_status = ?, amount_received = ?, updated_by = ?, updated_at = NOW() ${archiveUpdateSql} WHERE id = ?`,
                [newStatus, finalPaymentStatus, finalAmountReceived, userId, orderId]
            );

            // 5. Synchroniser la dette
            await balanceService.syncBalanceDebt(connection, order.shop_id, orderDate);

            // 6. Historique
            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, `Statut changé en ${newStatus}`, userId]);
            
            await connection.commit();
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur updateStatus pour Order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },

    /**
     * Supprime une commande et ses dépendances.
     */
    remove: async (orderId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();
            const [orderRows] = await connection.execute('SELECT o.*, s.bill_packaging, s.packaging_price FROM orders o JOIN shops s ON o.shop_id = s.id WHERE o.id = ?', [orderId]);
            if (orderRows.length === 0) {
                 await connection.rollback();
                 return { affectedRows: 0 };
            }
            const order = orderRows[0];
            const orderDate = moment(order.created_at).format('YYYY-MM-DD');

            // Annuler l'impact sur le bilan
            if (order.status !== 'pending') {
                const impact = balanceService.getBalanceImpactForStatus(order);
                await balanceService.updateDailyBalance(connection, {
                    shop_id: order.shop_id, date: orderDate,
                    orders_delivered: -impact.orders_delivered,
                    revenue_articles: -impact.revenue_articles,
                    delivery_fees: -impact.delivery_fees,
                    packaging_fees: -impact.packaging_fees
                });
            }
             await balanceService.updateDailyBalance(connection, {
                 shop_id: order.shop_id, date: orderDate,
                 orders_sent: -1,
                 expedition_fees: -parseFloat(order.expedition_fee || 0)
             });


            await balanceService.syncBalanceDebt(connection, order.shop_id, orderDate);

            // Supprimer dépendances
            await connection.execute('DELETE FROM order_history WHERE order_id = ?', [orderId]);
            await connection.execute('DELETE FROM order_items WHERE order_id = ?', [orderId]);
            await connection.execute('DELETE FROM order_messages WHERE order_id = ?', [orderId]);

            // Supprimer la commande
            const [result] = await connection.execute('DELETE FROM orders WHERE id = ?', [orderId]);

            await connection.commit();
            return result;
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur remove order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },

    /**
     * Récupère toutes les commandes avec filtres et jointures.
     * CORRIGÉ (v3): Assure l'ordre correct des paramètres pour éviter l'erreur MySQL 1210.
     */
    findAll: async (filters) => {
        const connection = await dbConnection.getConnection();
        let query = `SELECT o.*, s.name AS shop_name, u.name AS deliveryman_name, o.is_urgent, o.is_archived
                         FROM orders o
                         LEFT JOIN shops s ON o.shop_id = s.id
                         LEFT JOIN users u ON o.deliveryman_id = u.id
                         WHERE 1=1`;
        let params = [];
        const excludedStatuses = ['return_declared', 'returned'];

        try {
            // --- CORRECTION DE L'ORDRE DES PARAMÈTRES ---
            
            // 1. Ajouter le filtre de recherche (s'il existe)
            if (filters.search) {
                query += ` AND (CAST(o.id AS CHAR) LIKE ? OR o.customer_name LIKE ? OR o.customer_phone LIKE ? OR o.delivery_location LIKE ? OR s.name LIKE ? OR u.name LIKE ?)`;
                const searchTerm = `%${filters.search}%`;
                params.push(searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchTerm);
            }

            // 2. Ajouter les filtres de date (s'ils existent)
            if (filters.startDate) {
                query += ` AND DATE(o.created_at) >= ?`;
                params.push(filters.startDate);
            }
            if (filters.endDate) {
                 query += ` AND DATE(o.created_at) <= ?`;
                 params.push(filters.endDate);
            }

            // 3. Ajouter le filtre de statut (À LA FIN)
            if (filters.status) {
                // Si un statut spécifique est demandé
                query += ` AND o.status = ?`;
                params.push(filters.status);
            } else {
                // Comportement par défaut : exclure les retours
                query += ` AND o.status NOT IN (?)`;
                params.push(excludedStatuses); // Le tableau est maintenant le dernier paramètre
            }
            // --- FIN CORRECTION ---

            query += ` ORDER BY o.created_at DESC`;

            const [rows] = await connection.execute(query, params);
            // Récupérer les items pour chaque commande
            const ordersWithDetails = await Promise.all(rows.map(async (order) => {
                const [items] = await connection.execute('SELECT * FROM order_items WHERE order_id = ?', [order.id]);
                return { ...order, items };
            }));
            return ordersWithDetails;
        } catch (error) {
             console.error("Erreur détaillée dans findAll:", { 
                 message: error.message, code: error.code, errno: error.errno, 
                 sqlState: error.sqlState, sqlMessage: error.sqlMessage,
                 query: query, params: params 
             });
             throw error; 
        }
        finally {
            connection.release();
        }
    },

    /**
     * Récupère une commande par ID avec ses items et son historique.
     */
    findById: async (id) => {
        const connection = await dbConnection.getConnection();
        try {
            let orderQuery = `SELECT o.*, u.name AS deliveryman_name, s.name AS shop_name, o.is_urgent, o.is_archived, preparer.name AS prepared_by_name 
                                FROM orders o
                                LEFT JOIN users u ON o.deliveryman_id = u.id
                                LEFT JOIN users preparer ON o.prepared_by = preparer.id
                                LEFT JOIN shops s ON o.shop_id = s.id
                                WHERE o.id = ?`;
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

    /**
     * Assigne un livreur.
     */
    assignDeliveryman: async (orderId, deliverymanId, userId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [orderData] = await connection.execute('SELECT deliveryman_id FROM orders WHERE id = ?', [orderId]);
            if (orderData.length === 0) { throw new Error("Commande non trouvée."); }
            const oldDeliverymanId = orderData[0]?.deliveryman_id;
            const assigningUserId = userId;

            const [deliverymanRows] = await connection.execute('SELECT name FROM users WHERE id = ? AND role = "livreur"', [deliverymanId]);
            if (deliverymanRows.length === 0) { throw new Error("Nouveau livreur non trouvé ou rôle incorrect."); }
            const deliverymanName = deliverymanRows[0].name;

            const historyQuery = 'INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)';
            const historyMessage = `Commande assignée au livreur : ${deliverymanName}`;
            await connection.execute(historyQuery, [orderId, historyMessage, assigningUserId]);

            if (oldDeliverymanId && oldDeliverymanId != deliverymanId) {
                 await connection.execute(
                    `DELETE FROM cash_transactions WHERE user_id = ? AND type = 'remittance' AND status = 'pending' AND comment LIKE ?`,
                    [oldDeliverymanId, `%${orderId}%`]
                 );
            }

            if (localMessageModel && typeof localMessageModel.createMessage === 'function') {
                 const systemMessageContent = `La commande a été assignée au livreur ${deliverymanName}. Le suivi commence.`;
                 await connection.execute(
                     `INSERT INTO order_messages (order_id, user_id, message_content, message_type, created_at) VALUES (?, ?, ?, 'system', NOW(3))`,
                     [orderId, assigningUserId, systemMessageContent]
                 );
            } else { console.warn(`[assignDeliveryman Order ${orderId}] localMessageModel indisponible.`); }

            const updateQuery = `UPDATE orders SET
                                    deliveryman_id = ?, status = 'in_progress', payment_status = 'pending',
                                    is_urgent = 0, is_archived = 0,
                                    updated_by = ?, updated_at = NOW()
                                 WHERE id = ?`;
            await connection.execute(updateQuery, [deliverymanId, assigningUserId, orderId]);

            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur assignDeliveryman pour Order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },
    
    /**
     * Récupère les commandes à préparer.
     */
    findOrdersToPrepare: async () => {
        const connection = await dbConnection.getConnection();
        try {
            let query = `
                SELECT 
                    o.id, o.shop_id, o.deliveryman_id, o.customer_phone, o.delivery_location, o.status,
                    o.prepared_at, o.picked_up_by_rider_at,
                    s.name AS shop_name, u.name AS deliveryman_name
                FROM orders o
                LEFT JOIN shops s ON o.shop_id = s.id
                LEFT JOIN users u ON o.deliveryman_id = u.id
                WHERE o.status IN ('in_progress', 'ready_for_pickup')
                ORDER BY o.deliveryman_id ASC, o.prepared_at DESC, o.created_at ASC
            `;
            
            const [rows] = await connection.execute(query);
            
            const ordersWithDetails = await Promise.all(rows.map(async (order) => {
                const [items] = await connection.execute('SELECT * FROM order_items WHERE order_id = ?', [order.id]); // Renvoie tous les champs d'items
                return { ...order, items };
            }));
            
            return ordersWithDetails;
        } finally {
            connection.release();
        }
    },
    
    /**
     * Marque une commande comme prête.
     */
    markAsReadyForPickup: async (orderId, preparedByUserId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [updateResult] = await connection.execute(
                `UPDATE orders SET 
                    status = 'ready_for_pickup', prepared_by = ?, prepared_at = NOW(),
                    updated_at = NOW(), updated_by = ?
                 WHERE id = ? AND status = 'in_progress'`,
                [preparedByUserId, preparedByUserId, orderId]
            );

            if (updateResult.affectedRows === 0) {
                 await connection.rollback();
                 const [orderCheck] = await connection.execute('SELECT id, status FROM orders WHERE id = ?', [orderId]);
                 if (orderCheck.length === 0) throw new Error("Commande non trouvée.");
                 if (orderCheck[0].status !== 'in_progress') throw new Error(`Statut invalide pour la préparation. Statut actuel: ${orderCheck[0].status}.`);
                 throw new Error("Échec de la mise à jour: Ligne non modifiée.");
            }

            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, 'Colis marqué comme prêt pour la récupération.', preparedByUserId]);
            
            if (localMessageModel && typeof localMessageModel.createMessage === 'function') {
                 const systemMessageContent = `Le colis est prêt pour la récupération.`;
                 await connection.execute(
                     `INSERT INTO order_messages (order_id, user_id, message_content, message_type, created_at) VALUES (?, ?, ?, 'system', NOW(3))`,
                     [orderId, preparedByUserId, systemMessageContent]
                 );
            }

            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur markAsReadyForPickup pour Order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },
    
    /**
     * Confirme la récupération par le livreur.
     */
    confirmPickupByRider: async (orderId, riderUserId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [orderCheck] = await connection.execute('SELECT deliveryman_id, status FROM orders WHERE id = ?', [orderId]);
            if (orderCheck.length === 0) throw new Error("Commande non trouvée.");
            if (orderCheck[0].deliveryman_id !== riderUserId) throw new Error("Accès non autorisé: Cette commande ne vous est pas assignée.");
            if (orderCheck[0].status !== 'ready_for_pickup') throw new Error(`Statut invalide pour la confirmation de récupération. Statut actuel: ${orderCheck[0].status}.`);

            const [updateResult] = await connection.execute(
                `UPDATE orders SET 
                    picked_up_by_rider_at = NOW(), updated_at = NOW(), updated_by = ?
                 WHERE id = ?`,
                [riderUserId, orderId]
            );

            if (updateResult.affectedRows === 0) { throw new Error("Échec de la mise à jour: Ligne non modifiée."); }

            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, 'Confirmation de récupération du colis par le livreur.', riderUserId]);
            
            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur confirmPickupByRider pour Order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },

    /**
     * Démarre la course.
     */
    startDelivery: async (orderId, riderUserId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [orderCheck] = await connection.execute('SELECT deliveryman_id, status, picked_up_by_rider_at FROM orders WHERE id = ?', [orderId]);
            if (orderCheck.length === 0) throw new Error("Commande non trouvée.");
            if (orderCheck[0].deliveryman_id !== riderUserId) throw new Error("Accès non autorisé: Cette commande ne vous est pas assignée.");
            if (orderCheck[0].status !== 'ready_for_pickup') throw new Error(`Statut invalide pour démarrer la course. Statut actuel: ${orderCheck[0].status}.`);
            if (!orderCheck[0].picked_up_by_rider_at) throw new Error("Veuillez confirmer la récupération du colis avant de démarrer la course.");

            const [updateResult] = await connection.execute(
                `UPDATE orders SET 
                    status = 'en_route', started_at = NOW(), updated_at = NOW(), updated_by = ?
                 WHERE id = ?`,
                [riderUserId, orderId]
            );

            if (updateResult.affectedRows === 0) { throw new Error("Échec de la mise à jour: Ligne non modifiée."); }

            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, 'Course démarrée (En route).', riderUserId]);
            
            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur startDelivery pour Order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },

    /**
     * Déclare un retour.
     */
    declareReturn: async (orderId, riderUserId, comment = null) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [orderCheck] = await connection.execute('SELECT deliveryman_id, shop_id, status FROM orders WHERE id = ?', [orderId]);
            if (orderCheck.length === 0) throw new Error("Commande non trouvée.");
            if (orderCheck[0].deliveryman_id !== riderUserId) throw new Error("Accès non autorisé: Cette commande ne vous est pas assignée.");
            const currentStatus = orderCheck[0].status;
            
            if (!['en_route', 'failed_delivery', 'cancelled'].includes(currentStatus)) {
                 throw new Error(`Statut invalide pour déclarer un retour. Statut actuel: ${currentStatus}.`);
            }
            
            const [existingReturn] = await connection.execute(
                'SELECT id FROM returned_stock_tracking WHERE order_id = ? AND return_status IN (?, ?)', 
                [orderId, 'pending_return_to_hub', 'received_at_hub']
            );
            if (existingReturn.length > 0) {
                 throw new Error("Un retour est déjà en cours ou déclaré pour cette commande.");
            }

            const insertTrackingQuery = `
                INSERT INTO returned_stock_tracking 
                (order_id, deliveryman_id, shop_id, return_status, declaration_date, comment)
                VALUES (?, ?, ?, 'pending_return_to_hub', NOW(), ?)
            `;
            const [trackingResult] = await connection.execute(insertTrackingQuery, [
                orderId, riderUserId, orderCheck[0].shop_id, comment
            ]);

            const newStatus = 'return_declared';
            await connection.execute(
                `UPDATE orders SET status = ?, updated_at = NOW(), updated_by = ? WHERE id = ?`,
                [newStatus, riderUserId, orderId]
            );

            await connection.execute('INSERT INTO order_history (order_id, action, user_id) VALUES (?, ?, ?)', [orderId, `Retour déclaré : En attente de réception au Hub.`, riderUserId]);

            await connection.commit();
            return { success: true, trackingId: trackingResult.insertId };
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur declareReturn pour Order ${orderId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    },
    
    /**
     * Récupère les retours en attente/confirmés avec filtres.
     */
    findPendingReturns: async (filters = {}) => {
        const connection = await dbConnection.getConnection();
        try {
            let query = `
                SELECT 
                    rst.id AS tracking_id, rst.declaration_date, rst.return_status, rst.comment,
                    o.id AS order_id, o.customer_phone,
                    s.name AS shop_name, u.name AS deliveryman_name
                FROM returned_stock_tracking rst
                JOIN orders o ON rst.order_id = o.id
                JOIN shops s ON rst.shop_id = s.id
                JOIN users u ON rst.deliveryman_id = u.id
                WHERE 1=1
            `;
            const params = [];

            if (filters.status && filters.status !== 'all') {
                query += ` AND rst.return_status = ?`;
                params.push(filters.status);
            }
            if (filters.deliverymanId) {
                query += ` AND rst.deliveryman_id = ?`;
                params.push(filters.deliverymanId);
            }
            if (filters.startDate) {
                query += ` AND DATE(rst.declaration_date) >= ?`; // Utiliser DATE() pour comparer la date seulement
                params.push(filters.startDate);
            }
            if (filters.endDate) {
                 query += ` AND DATE(rst.declaration_date) <= ?`; // Utiliser DATE() pour comparer la date seulement
                 params.push(filters.endDate);
            }

            query += ` ORDER BY rst.declaration_date DESC`;
            const [rows] = await connection.execute(query, params);
            return rows;
        } finally {
            connection.release();
        }
    },
    
    /**
     * Confirme la réception d'un retour au Hub. (Admin)
     */
    confirmHubReception: async (trackingId, adminUserId) => {
        const connection = await dbConnection.getConnection();
        try {
            await connection.beginTransaction();

            const [trackingRow] = await connection.execute('SELECT order_id FROM returned_stock_tracking WHERE id = ? AND return_status = ?', [trackingId, 'pending_return_to_hub']);
            if (trackingRow.length === 0) throw new Error("Retour non trouvé ou déjà réceptionné.");
            const orderId = trackingRow[0].order_id;

            await connection.execute(
                `UPDATE returned_stock_tracking 
                 SET return_status = 'received_at_hub', hub_reception_date = NOW(), stock_received_by_user_id = ? 
                 WHERE id = ?`,
                [adminUserId, trackingId]
            );

            // Appel à updateStatus pour mettre le statut final 'returned' et archiver
            await module.exports.updateStatus(orderId, 'returned', null, null, adminUserId); 

            await connection.commit();
            return { success: true };
        } catch (error) {
            await connection.rollback();
            console.error(`Erreur confirmHubReception pour Tracking ID ${trackingId}:`, error);
            throw error;
        } finally {
            connection.release();
        }
    }
};
