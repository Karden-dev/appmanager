// src/models/user.model.js

let dbConnection;

/**
 * Initialise le modèle avec la connexion à la base de données.
 * @param {object} connection - Le pool de connexion à la base de données.
 */
const init = (connection) => {
    dbConnection = connection;
};

// --- Fonctions pour la gestion des UTILISATEURS ---

const create = async (phone_number, pin, name, role) => {
    const query = 'INSERT INTO users (phone_number, pin, name, role, status) VALUES (?, ?, ?, ?, ?)';
    const [result] = await dbConnection.execute(query, [phone_number, pin, name, role, 'actif']);
    return result;
};

const findByPhoneNumber = async (phone_number) => {
    // Correction: utilisation de .trim() pour enlever les espaces
    const cleanedPhoneNumber = phone_number.trim();
    const query = 'SELECT * FROM users WHERE phone_number = ?';
    const [rows] = await dbConnection.execute(query, [cleanedPhoneNumber]);
    return rows[0];
};

const findById = async (id) => {
    const query = 'SELECT id, name, phone_number, role, status, created_at FROM users WHERE id = ?';
    const [rows] = await dbConnection.execute(query, [id]);
    return rows[0];
};

const findAll = async (filters = {}) => {
    let query = "SELECT id, name, phone_number, role, status, created_at FROM users WHERE 1=1";
    const params = [];

    if (filters.role) {
        query += " AND role = ?";
        params.push(filters.role);
    }
    if (filters.status) {
        query += " AND status = ?";
        params.push(filters.status);
    }

    query += " ORDER BY name ASC";
    const [rows] = await dbConnection.execute(query, params);
    return rows;
};

const update = async (id, data) => {
    const fields = [];
    const values = [];

    for (const key in data) {
        fields.push(`${key} = ?`);
        values.push(data[key]);
    }

    if (fields.length === 0) {
        return { affectedRows: 0 };
    }

    const query = `UPDATE users SET ${fields.join(', ')} WHERE id = ?`;
    values.push(id);

    const [result] = await dbConnection.execute(query, values);
    return result;
};

const remove = async (id) => {
    // Simule une suppression logique (status 'inactif')
    const result = await update(id, { status: 'inactif' });
    return result;
};

const getDeliverymanStats = async (startDate, endDate) => {
    // 1. Compter le nombre total de livreurs actifs
    const [totalRows] = await dbConnection.execute("SELECT COUNT(id) as total FROM users WHERE role = 'livreur' AND status = 'actif'");
    const totalDeliverymen = Number(totalRows[0].total);

    // 2. Calculer les statistiques de livraison
    let statsQuery = `
        SELECT 
            COALESCE(COUNT(DISTINCT deliveryman_id), 0) as working,
            COALESCE(SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END), 0) as in_progress,
            COALESCE(SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END), 0) as cancelled,
            COALESCE(SUM(CASE WHEN status IN ('delivered', 'failed_delivery') THEN 1 ELSE 0 END), 0) as delivered,
            COALESCE(COUNT(id), 0) as received
        FROM orders`;
        
    const params = [];
    if (startDate && endDate) {
        statsQuery += ' WHERE DATE(created_at) BETWEEN ? AND ?';
        params.push(startDate, endDate);
    }

    const [statsRows] = await dbConnection.execute(statsQuery, params);
    const stats = statsRows[0];
    const workingDeliverymen = Number(stats.working);

    return {
        total: totalDeliverymen,
        working: workingDeliverymen,
        absent: totalDeliverymen - workingDeliverymen,
        availability_rate: totalDeliverymen > 0 ? ((workingDeliverymen / totalDeliverymen) * 100) : 0,
        in_progress: Number(stats.in_progress),
        delivered: Number(stats.delivered),
        received: Number(stats.received),
        cancelled: Number(stats.cancelled)
    };
};

const getAllDeliverymen = async () => {
    const query = "SELECT id, name, phone_number, status, created_at FROM users WHERE role = 'livreur' ORDER BY name ASC";
    const [rows] = await dbConnection.execute(query);
    return rows;
};

/**
 * Récupère les catégories de dépenses par type (pour le formulaire du caissier).
 * @param {string} type - 'company_charge' ou 'deliveryman_charge'.
 * @returns {Promise<Array>} Tableau des catégories de dépenses.
 */
const getExpenseCategoriesByType = async (type) => {
    const query = 'SELECT id, name FROM expense_categories WHERE type = ? ORDER BY name';
    const [rows] = await dbConnection.execute(query, [type]);
    return rows;
};


module.exports = {
    init,
    create,
    findByPhoneNumber,
    findById,
    findAll,
    update,
    delete: remove,
    getDeliverymanStats,
    getAllDeliverymen,
    getExpenseCategoriesByType
};