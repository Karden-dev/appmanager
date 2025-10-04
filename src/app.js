// src/app.js
require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');

// --- Import des Routes ---
const userRoutes = require('./routes/users.routes');
const shopRoutes = require('./routes/shops.routes');
const orderRoutes = require('./routes/orders.routes');
const deliverymenRoutes = require('./routes/deliverymen.routes');
const reportsRoutes = require('./routes/reports.routes');
const authRoutes = require('./routes/auth.routes');
const remittanceRoutes = require('./routes/remittances.routes');
const debtRoutes = require('./routes/debt.routes');
const cashRoutes = require('./routes/cash.routes');
const dashboardRoutes = require('./routes/dashboard.routes'); // AJOUTÉ : Nouvelle route Dashboard

// --- Import des Modèles et Services ---
const userModel = require('./models/user.model');
const shopModel = require('./models/shop.model');
const orderModel = require('./models/order.model');
const reportModel = require('./models/report.model');
const remittanceModel = require('./models/remittance.model');
const debtModel = require('./models/debt.model');
const cashModel = require('./models/cash.model');
const dashboardModel = require('./models/dashboard.model'); // AJOUTÉ : Nouveau modèle Dashboard

// Services
const remittanceService = require('./services/remittances.service.js');
const debtService = require('./services/debt.service.js');
const cashService = require('./services/cash.service.js');
const balanceService = require('./services/balance.service.js');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Middleware pour servir les fichiers statiques (HTML, CSS, JS du frontend)
app.use(express.static(path.join(__dirname, '..', 'public')));

const dbConfig = {
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
};

let dbPool;

async function connectToDatabase() {
    try {
        dbPool = mysql.createPool(dbConfig);
        console.log('Pool de connexions à la base de données créé avec succès !');
    } catch (error) {
        console.error('Erreur de création du pool de connexions :', error);
        process.exit(1);
    }
}

async function startServer() {
    await connectToDatabase();
    
    // --- Initialisation des Services et Modèles ---
    // 1. Initialiser les services qui n'ont pas de dépendances complexes
    cashService.init(dbPool);
    remittanceService.init(dbPool);
    debtService.init(dbPool);
    
    // 2. Initialiser le service de bilan central
    balanceService.init(dbPool);
    
    // 3. Initialiser les modèles simples
    userModel.init(dbPool);
    shopModel.init(dbPool);
    remittanceModel.init(dbPool);
    cashModel.init(dbPool);
    dashboardModel.init(dbPool); // AJOUTÉ : Initialisation du Modèle Dashboard
    reportModel.init(dbPool);
    
    // 4. Initialiser les modèles complexes en leur passant leurs dépendances
    debtModel.init(dbPool);
    orderModel.init(dbPool);

    // --- Déclaration des Routes API ---
    // Note : la route de login est déjà préfixée dans son propre fichier
    app.use('/api', authRoutes); 

    app.use('/users', userRoutes);
    app.use('/shops', shopRoutes);
    app.use('/orders', orderRoutes);
    app.use('/deliverymen', deliverymenRoutes);
    app.use('/reports', reportsRoutes);
    app.use('/remittances', remittanceRoutes);
    app.use('/debts', debtRoutes);
    app.use('/cash', cashRoutes);
    app.use('/dashboard', dashboardRoutes); // AJOUTÉ : Montage de la nouvelle route Dashboard

    app.listen(port, () => {
        console.log(`Le serveur WINK EXPRESS est en cours d'exécution sur le port ${port}`);
    });
}

startServer();