// src/models/rider.model.js
const moment = require('moment');

let dbConnection;

module.exports = {
    init: (connection) => { 
        dbConnection = connection;
    },
    
    findRiderOrders: async (filters) => {
        const connection = await dbConnection.getConnection();
        try {
            // **MISE À JOUR : Ajout de o.is_urgent, o.picked_up_by_rider_at et de la sous-requête pour unread_count**
            let query = `
                SELECT 
                    o.*, 
                    s.name AS shop_name, 
                    u.name AS deliveryman_name,
                    o.is_urgent, 
                    o.picked_up_by_rider_at, -- AJOUTÉ
                    (
                        SELECT GROUP_CONCAT(CONCAT(oi.item_name, ' (x', oi.quantity, ')') SEPARATOR ', ') 
                        FROM order_items oi WHERE oi.order_id = o.id
                    ) as items_list,
                    -- Calcul des messages non lus pour ce livreur (filters.deliverymanId)
                    (
                        SELECT COUNT(om.id) 
                        FROM order_messages om 
                        WHERE om.order_id = o.id 
                          AND om.user_id != ? -- Messages non envoyés par le livreur
                          AND NOT EXISTS (
                              SELECT 1 FROM message_read_status mrs 
                              WHERE mrs.message_id = om.id AND mrs.user_id = ?
                          )
                    ) as unread_count
                FROM orders o
                LEFT JOIN shops s ON o.shop_id = s.id
                LEFT JOIN users u ON o.deliveryman_id = u.id
                WHERE o.deliveryman_id = ?
            `;

            // **MISE À JOUR :** Les IDs pour les sous-requêtes 'unread_count' doivent être au début des params
            const params = [filters.deliverymanId, filters.deliverymanId, filters.deliverymanId];

            if (filters.status && filters.status !== 'all') {
                // Gérer le cas où 'status' est un tableau (ex: ['pending', 'in_progress', 'ready_for_pickup', 'en_route'])
                if (Array.isArray(filters.status)) {
                    query += ' AND o.status IN (?)'; // Utiliser IN (?) pour les tableaux
                    params.push(filters.status);
                } else {
                    query += ' AND o.status = ?';
                    params.push(filters.status);
                }
            }
            if (filters.search) {
                // Recherche sur ID, téléphone client, ou nom client (si fourni)
                query += ' AND (o.id LIKE ? OR o.customer_phone LIKE ? OR o.customer_name LIKE ?)';
                const searchTerm = `%${filters.search}%`;
                params.push(searchTerm, searchTerm, searchTerm);
            }
            if (filters.startDate && filters.endDate) {
                query += ' AND DATE(o.created_at) BETWEEN ? AND ?';
                params.push(filters.startDate, filters.endDate);
            }

            query += ` GROUP BY o.id ORDER BY o.created_at DESC`;

            const [rows] = await connection.execute(query, params);
            return rows;
        } catch (error) {
            console.error("Erreur SQL dans RiderModel.findRiderOrders:", error.message);
            throw error;
        } finally {
            connection.release();
        }
    },
    
    getOrdersCounts: async (riderId) => {
        const connection = await dbConnection.getConnection();
        try {
            // **MISE À JOUR :** Inclure les nouveaux statuts (ready_for_pickup, en_route)
            const [rows] = await connection.execute(
                `SELECT status, COUNT(*) as count FROM orders WHERE deliveryman_id = ? GROUP BY status`,
                [riderId]
            );
            
            // Initialiser tous les compteurs attendus à 0
            const counts = {
                'pending': 0,
                'in_progress': 0,
                'ready_for_pickup': 0,  
                'en_route': 0,          
                'delivered': 0,
                'cancelled': 0,
                'failed_delivery': 0,
                'reported': 0,
                'return_pending': 0, 
                'returned': 0         
            };
            
            // Remplir les compteurs avec les données de la BDD
            rows.forEach(row => {
                if (counts.hasOwnProperty(row.status)) {
                    counts[row.status] = row.count;
                }
            });
            
            return counts;
        } catch(error) {
            console.error("Erreur SQL dans RiderModel.getOrdersCounts:", error.message);
            throw error;
        } finally {
            connection.release();
        }
    },
    
    findRiderNotifications: async (riderId) => {
        // ... (Logique existante) ...
        const connection = await dbConnection.getConnection();
        try {
            // Requête existante (inchangée)
            const [rows] = await connection.execute(
                `SELECT 
                    oh.id, oh.action, oh.created_at, oh.order_id, o.id as tracking_id
                FROM 
                    order_history oh
                JOIN 
                    orders o ON oh.order_id = o.id
                WHERE 
                    oh.user_id = ? AND oh.action = 'assigned'
                ORDER BY oh.created_at DESC 
                LIMIT 10`,
                [riderId]
            );
            return rows;
        } catch(error) {
            console.error("Erreur SQL dans RiderModel.findRiderNotifications:", error.message);
            throw error;
        } finally {
            connection.release();
        }
    }
};