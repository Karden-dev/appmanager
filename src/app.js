// src/app.js
require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');
const http = require('http'); // Module HTTP natif de Node.js

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
const dashboardRoutes = require('./routes/dashboard.routes');
const riderRoutes = require('./routes/rider.routes.js');
const performanceRoutes = require('./routes/performance.routes');
const scheduleRoutes = require('./routes/schedule.routes');
const suivisRoutes = require('./routes/suivis.routes.js');
const returnsRoutes = require('./routes/returns.routes'); // <-- CORRECTION: AJOUT DE L'IMPORT MANQUANT

// --- Import des Modèles et Services ---
const userModel = require('./models/user.model');
const shopModel = require('./models/shop.model');
const orderModel = require('./models/order.model');
const reportModel = require('./models/report.model');
const remittanceModel = require('./models/remittance.model');
const debtModel = require('./models/debt.model');
const cashModel = require('./models/cash.model');
const dashboardModel = require('./models/dashboard.model');
const riderModel = require('./models/rider.model');
const ridersCashModel = require('./models/riderscash.model');
const performanceModel = require('./models/performance.model');
const scheduleModel = require('./models/schedule.model');
const messageModel = require('./models/message.model.js');
const cashStatModel = require('./models/cash.stat.model');
const cashClosingService = require('./services/cash.closing.service');

// Services
const remittanceService = require('./services/remittances.service.js');
const debtService = require('./services/debt.service.js');
const cashService = require('./services/cash.service.js');
const balanceService = require('./services/balance.service.js');
// --- AJOUTÉ: Import du service WebSocket ---
const webSocketService = require('./services/websocket.service.js');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir les fichiers statiques du dossier public
app.use(express.static(path.join(__dirname, '..', 'public')));

// Configuration de la base de données
const dbConfig = {
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
};

let dbPool; // Variable pour stocker le pool de connexions

// Fonction pour établir la connexion à la base de données
async function connectToDatabase() {
    try {
        dbPool = mysql.createPool(dbConfig);
        console.log('Pool de connexions à la base de données créé avec succès !');
        const connection = await dbPool.getConnection();
        console.log('Connexion testée avec succès.');
        connection.release();
    } catch (error) {
        console.error('Erreur de création du pool ou de connexion test :', error);
        process.exit(1);
    }
}

// Fonction pour démarrer le serveur après la connexion à la BDD
async function startServer() {
    await connectToDatabase();

    // --- Initialisation des Services et Modèles ---
    cashStatModel.init(dbPool);
    cashClosingService.init(dbPool);
    cashService.init(dbPool);
    remittanceService.init(dbPool);
    debtService.init(dbPool);
    balanceService.init(dbPool);

    userModel.init(dbPool);
    shopModel.init(dbPool);
    remittanceModel.init(dbPool);
    cashModel.init(dbPool);
    dashboardModel.init(dbPool);
    reportModel.init(dbPool);
    debtModel.init(dbPool);
    riderModel.init(dbPool);
    ridersCashModel.init(dbPool);
    performanceModel.init(dbPool);
    scheduleModel.init(dbPool);
    messageModel.init(dbPool);
    orderModel.init(dbPool, messageModel);

    // --- Déclaration des Routes API ---
    app.use('/api', authRoutes);
    app.use('/api/users', userRoutes);
    app.use('/api/shops', shopRoutes);
    app.use('/api/orders', orderRoutes);
    app.use('/api/deliverymen', deliverymenRoutes);
    app.use('/api/reports', reportsRoutes);
    app.use('/api/remittances', remittanceRoutes);
    app.use('/api/debts', debtRoutes);
    app.use('/api/cash', cashRoutes);
    app.use('/api/dashboard', dashboardRoutes);
    app.use('/api/rider', riderRoutes);
    app.use('/api/performance', performanceRoutes);
    app.use('/api/schedule', scheduleRoutes);
    app.use('/api', suivisRoutes);
    app.use('/api/returns', returnsRoutes); // <-- UTILISATION DE LA ROUTE

    // --- MISE À JOUR: Démarrage du serveur HTTP et WebSocket ---
    // 1. Créer un serveur HTTP standard à partir de l'application Express
    const server = http.createServer(app);

    // 2. Initialiser le serveur WebSocket en lui passant le serveur HTTP
    //    Le service WebSocket s'attachera à ce serveur.
    webSocketService.initWebSocketServer(server);

    // 3. Faire écouter le serveur HTTP (qui gère Express ET WebSocket)
    server.listen(port, () => {
        console.log(`📡 Le serveur WINK EXPRESS (HTTP & WebSocket) est en cours d'exécution sur le port ${port} 📡`);
    });
    // --- FIN MISE À JOUR ---

}

// Lancer le serveur
startServer();