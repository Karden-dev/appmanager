// src/models/cash.model.js
const moment = require('moment');
let db;

const init = (dbPool) => {
    db = dbPool;
};

const create = async (transactionData) => {
    const { user_id, type, category_id, amount, comment, created_at } = transactionData;
    const query = `
        INSERT INTO cash_transactions (user_id, type, category_id, amount, comment, status, created_at, validated_by) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;
    const status = (type === 'remittance') ? 'pending' : 'confirmed';
    const validatedBy = (type === 'remittance') ? null : user_id;
    const createdAt = created_at ? moment(created_at).format('YYYY-MM-DD HH:mm:ss') : moment().format('YYYY-MM-DD HH:mm:ss');
    const [result] = await db.execute(query, [user_id, type, category_id, amount, comment, status, createdAt, validatedBy]);
    return result.insertId;
};

const update = async (id, data) => {
    const query = 'UPDATE cash_transactions SET amount = ?, comment = ? WHERE id = ?';
    const [result] = await db.execute(query, [data.amount, data.comment, id]);
    return result;
};

const remove = async (id) => {
    const query = 'DELETE FROM cash_transactions WHERE id = ?';
    const [result] = await db.execute(query, [id]);
    return result;
};

const removeRemittanceByOrderId = async (orderId) => {
    const query = 'DELETE FROM cash_transactions WHERE comment LIKE ? AND type = "remittance" AND status = "pending"';
    const [result] = await db.execute(query, [`%commande n°${orderId}`]);
    return result;
};


const findAll = async (filters) => {
    let query = `
        SELECT ct.*, u.name as user_name, ec.name as category_name, val.name as validated_by_name
        FROM cash_transactions ct
        LEFT JOIN users u ON ct.user_id = u.id
        LEFT JOIN users val ON ct.validated_by = val.id
        LEFT JOIN expense_categories ec ON ct.category_id = ec.id
        WHERE 1=1 `;
    const params = [];
    if (filters.type) {
        query += ' AND ct.type = ?';
        params.push(filters.type);
    }
    
    if (filters.startDate && filters.endDate) {
        const startDateTime = moment(filters.startDate).startOf('day').format('YYYY-MM-DD HH:mm:ss');
        const endDateTime = moment(filters.endDate).endOf('day').format('YYYY-MM-DD HH:mm:ss');
        query += ' AND ct.created_at BETWEEN ? AND ?';
        params.push(startDateTime, endDateTime);
    }
    
    if (filters.search) {
        query += ' AND (u.name LIKE ? OR ct.comment LIKE ? OR ec.name LIKE ?)';
        const searchTerm = `%${filters.search}%`;
        params.push(searchTerm, searchTerm, searchTerm);
    }
    query += ' ORDER BY ct.created_at DESC';
    const [rows] = await db.execute(query, params);
    return rows;
};

const getExpenseCategories = async () => {
    const [rows] = await db.execute('SELECT * FROM expense_categories ORDER BY name ASC');
    return rows;
};

const findRemittanceSummary = async (startDate, endDate, search) => {
    const startDateTime = moment(startDate).startOf('day').format('YYYY-MM-DD HH:mm:ss');
    const endDateTime = moment(endDate).endOf('day').format('YYYY-MM-DD HH:mm:ss');
    
    let query = `
        SELECT
            u.id as user_id,
            u.name as user_name,
            (COALESCE(remittances.pending_amount, 0) + COALESCE(shortfalls.pending_amount, 0)) as pending_amount,
            COALESCE(remittances.confirmed_amount, 0) as confirmed_amount,
            COALESCE(remittances.pending_count, 0) as pending_count,
            COALESCE(remittances.confirmed_count, 0) as confirmed_count
        FROM
            users u
        LEFT JOIN (
            SELECT
                user_id,
                SUM(CASE WHEN status = 'pending' AND type = 'remittance' THEN 1 ELSE 0 END) as pending_count,
                SUM(CASE WHEN status = 'confirmed' AND type = 'remittance' THEN 1 ELSE 0 END) as confirmed_count,
                SUM(CASE WHEN status = 'pending' AND type = 'remittance' THEN ABS(amount) ELSE 0 END) as pending_amount,
                SUM(CASE WHEN status = 'confirmed' AND type IN ('remittance', 'remittance_correction') THEN amount ELSE 0 END) as confirmed_amount
            FROM cash_transactions
            WHERE (type = 'remittance' AND created_at BETWEEN ? AND ?) OR type = 'remittance_correction'
            GROUP BY user_id
        ) as remittances ON u.id = remittances.user_id
        LEFT JOIN (
            SELECT
                deliveryman_id,
                SUM(amount) as pending_amount
            FROM deliveryman_shortfalls
            WHERE status = 'pending'
            GROUP BY deliveryman_id
        ) as shortfalls ON u.id = shortfalls.deliveryman_id
        WHERE
            u.role = 'livreur'
    `;
    const params = [startDateTime, endDateTime];
    
    if (search) {
        query += ' AND u.name LIKE ?';
        params.push(`%${search}%`);
    }
    
    query += ` HAVING pending_amount > 0 OR confirmed_amount > 0 ORDER BY u.name ASC`;
    
    const [rows] = await db.execute(query, params);
    return rows;
};

const findRemittanceDetails = async (deliverymanId, startDate, endDate) => {
    const startDateTime = moment(startDate).startOf('day').format('YYYY-MM-DD HH:mm:ss');
    const endDateTime = moment(endDate).endOf('day').format('YYYY-MM-DD HH:mm:ss');
    
    let query = `
        SELECT 
            ct.*, o.id as order_id, o.delivery_location, o.expedition_fee, s.name as shop_name,
            o.article_amount as order_total_amount, 
            GROUP_CONCAT(oi.item_name SEPARATOR ', ') as item_names
        FROM cash_transactions ct
        LEFT JOIN orders o ON ct.comment LIKE CONCAT('%', o.id) 
        LEFT JOIN shops s ON o.shop_id = s.id
        LEFT JOIN order_items oi ON o.id = oi.order_id
        WHERE ct.user_id = ? AND ct.type LIKE 'remittance%'
    `;
    const params = [deliverymanId];
    if (startDate && endDate) {
        query += ' AND ct.created_at BETWEEN ? AND ?';
        params.push(startDateTime, endDateTime);
    }
    query += ` GROUP BY ct.id ORDER BY ct.status ASC, ct.created_at DESC`;
    const [rows] = await db.execute(query, params);
    return rows;
};

const updateRemittanceAmount = async (transactionId, newAmount) => {
    const query = 'UPDATE cash_transactions SET amount = ? WHERE id = ? AND status = "pending" AND type = "remittance"';
    const [result] = await db.execute(query, [newAmount, transactionId]);
    return result;
};

const confirmRemittance = async (transactionIds, paidAmount, validatedBy) => {
    const connection = await db.getConnection();
    try {
        await connection.beginTransaction();
        const placeholders = transactionIds.map(() => '?').join(',');
        
        const [transactions] = await connection.execute(`SELECT * FROM cash_transactions WHERE id IN (${placeholders}) AND status = 'pending'`, transactionIds);
        if (transactions.length === 0) throw new Error("Aucune transaction en attente sélectionnée.");
        
        if (transactions.length > 1 && parseFloat(paidAmount) < transactions.reduce((sum, tx) => sum + parseFloat(tx.amount), 0)) {
            throw new Error("Un manquant ne peut pas être généré lors de la confirmation d'un lot. Veuillez confirmer chaque versement individuellement.");
        }
        
        const deliverymanId = transactions[0].user_id;
        
        const [netAmounts] = await connection.execute(`
            SELECT COALESCE(SUM(ABS(ct.amount) - COALESCE(o.expedition_fee, 0)), 0) as expected_net_amount
            FROM cash_transactions ct
            LEFT JOIN orders o ON ct.comment LIKE CONCAT('%', o.id)
            WHERE ct.id IN (${placeholders}) AND ct.status = 'pending'
        `, transactionIds);
        
        const expectedAmount = parseFloat(netAmounts[0].expected_net_amount); 
        const difference = expectedAmount - paidAmount; 

        await connection.execute(
            `UPDATE cash_transactions SET status = 'confirmed', amount = ?, validated_by = ?, validated_at = NOW() WHERE id IN (${placeholders})`, 
            [Math.abs(paidAmount), validatedBy, ...transactionIds]
        );

        if (difference > 0) {
            await connection.execute(`INSERT INTO deliveryman_shortfalls (deliveryman_id, amount, comment, created_by_user_id) VALUES (?, ?, ?, ?)`, [deliverymanId, difference, `Manquant sur versement(s) ID: ${transactionIds.join(', ')}`, validatedBy]);
        }
        
        await connection.commit();
        return { success: true, expected: expectedAmount, paid: paidAmount, shortfall: difference };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
};

const findShortfalls = async (filters = {}) => {
    let query = `
        SELECT ds.*, u.name as deliveryman_name
        FROM deliveryman_shortfalls ds
        JOIN users u ON ds.deliveryman_id = u.id
        WHERE 1=1
    `;
    const params = [];
    if (filters.status) {
        query += ' AND ds.status = ?';
        params.push(filters.status);
    }
    if (filters.search) {
        query += ' AND u.name LIKE ?';
        params.push(`%${filters.search}%`);
    }
    query += ' ORDER BY ds.created_at DESC';
    const [rows] = await db.execute(query, params);
    return rows;
};

/**
 * NOUVELLE FONCTION settleShortfall : Gère les règlements partiels.
 */
const settleShortfall = async (shortfallId, amountPaid, userId) => {
    const connection = await db.getConnection();
    try {
        await connection.beginTransaction();
        
        // 1. Récupérer le manquant
        const [shortfallRows] = await connection.execute('SELECT * FROM deliveryman_shortfalls WHERE id = ? FOR UPDATE', [shortfallId]);
        if (shortfallRows.length === 0) throw new Error("Manquant non trouvé.");
        const shortfall = shortfallRows[0];
        if (shortfall.status === 'settled') throw new Error("Ce manquant est déjà réglé.");

        const amountToSettle = parseFloat(amountPaid);
        const remainingAmount = parseFloat(shortfall.amount) - amountToSettle;

        // 2. Créer une transaction de caisse pour tracer l'argent reçu
        await connection.execute(
            `INSERT INTO cash_transactions (user_id, type, amount, comment, status, validated_by) VALUES (?, 'shortfall_settlement', ?, ?, 'confirmed', ?)`,
            [shortfall.deliveryman_id, amountToSettle, `Règlement partiel/total du manquant #${shortfallId}`, userId]
        );

        // 3. Mettre à jour le manquant
        if (remainingAmount > 0) {
            // S'il reste un montant, on met juste à jour le solde
            await connection.execute('UPDATE deliveryman_shortfalls SET amount = ? WHERE id = ?', [remainingAmount, shortfallId]);
        } else {
            // S'il ne reste rien (ou si le livreur a trop payé), on clôture le manquant
            await connection.execute('UPDATE deliveryman_shortfalls SET amount = 0, status = "settled", settled_at = NOW() WHERE id = ?', [shortfallId]);
        }
        
        await connection.commit();
        return { success: true };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
};

const performCashClosing = async (closingDate, actualCash, comment, userId) => { /* ... (Code inchangé) ... */ };
const findClosingHistory = async (filters = {}) => { /* ... (Code inchangé) ... */ };
const getCashMetrics = async (startDate, endDate) => { /* ... (Code inchangé) ... */ };


module.exports = {
    init,
    create,
    update,
    remove,
    findAll,
    getExpenseCategories,
    findRemittanceSummary,
    findRemittanceDetails,
    updateRemittanceAmount,
    confirmRemittance,
    findShortfalls,
    settleShortfall,
    removeRemittanceByOrderId,
    performCashClosing,
    findClosingHistory,
    getCashMetrics
};