// src/app.js
require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');

// Définition d'un port par défaut
const PORT = process.env.PORT || 3000;
// Définition de la base de données par défaut (CORRECTION ER_NO_DB_ERROR)
const DATABASE_NAME = process.env.DB_NAME || 'winkdb'; 

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
const cashiersRemittancesRoutes = require('./routes/cashiersremittances.routes');

// --- Import des Modèles et Services ---
const userModel = require('./models/user.model');
const shopModel = require('./models/shop.model');
const orderModel = require('./models/order.model');
const reportModel = require('./models/report.model');
const remittanceModel = require('./models/remittance.model');
const debtModel = require('./models/debt.model');
const cashModel = require('./models/cash.model');
const dashboardModel = require('./models/dashboard.model'); 
const balanceService = require('./services/balance.service.js');
const cashService = require('./services/cash.service.js');
const debtService = require('./services/debt.service.js');
const remittanceService = require('./services/remittances.service.js');
const cashiersRemittancesModel = require('./models/cashiersremittances.model'); 


const app = express();
let dbPool; // Pour stocker le pool de connexion

// Fonction asynchrone pour connecter à la base de données
const connectToDatabase = async () => {
    try {
        dbPool = await mysql.createPool({
            host: process.env.DB_HOST,
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            database: DATABASE_NAME, // Utilisation de la constante corrigée
            waitForConnections: true,
            connectionLimit: 10,
            queueLimit: 0
        });
        console.log(`Connexion à la base de données MySQL [${DATABASE_NAME}] établie.`);
        return dbPool;
    } catch (error) {
        console.error('Erreur de connexion à la base de données :', error);
    }
};

// Fonction d'initialisation des modèles et services
const initModelsAndServices = async (pool) => {
    // 1. Initialiser les services
    cashService.init(pool);
    remittanceService.init(pool);
    debtService.init(pool);
    balanceService.init(pool);

    // 2. Initialiser les modèles
    userModel.init(pool);
    shopModel.init(pool);
    remittanceModel.init(pool);
    cashModel.init(pool);
    dashboardModel.init(pool); 
    reportModel.init(pool);
    
    // Modèles avec dépendances ou logiques spécifiques
    debtModel.init(pool);
    orderModel.init(pool);
    cashiersRemittancesModel.init(pool);
};


// Middleware pour initialiser la connexion à la base de données et les modèles
app.use(async (req, res, next) => {
    if (!dbPool) {
        dbPool = await connectToDatabase();
    }
    if (dbPool) {
        // Le test sur userModel.dbConnection n'est pas possible si la variable n'est pas exportée.
        // Laissons le code dupliquer la vérification, la connexion à la base est prioritaire.
        if (!global.dbInitialized) { 
            await initModelsAndServices(dbPool);
            global.dbInitialized = true;
        }
    }
    next();
});


// Configuration de CORS
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir les fichiers statiques (le frontend)
app.use(express.static(path.join(__dirname, '..', 'public')));


// DÉCLARATION DES ROUTES
app.use('/api', authRoutes); 
app.use('/users', userRoutes);
app.use('/shops', shopRoutes);
app.use('/orders', orderRoutes);
app.use('/deliverymen', deliverymenRoutes);
app.use('/reports', reportsRoutes);
app.use('/remittances', remittanceRoutes);
app.use('/debts', debtRoutes);
app.use('/cash', cashRoutes);
app.use('/dashboard', dashboardRoutes); 
app.use('/cashiers/remittances', cashiersRemittancesRoutes); 

// Middleware de gestion des erreurs
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).send('Something broke!');
});


// Lancer l'initialisation des modèles et DÉMARRER le serveur
(async () => {
    if (!dbPool) {
        dbPool = await connectToDatabase();
    }
    if (dbPool) {
        // Démarrage du serveur HTTP
        app.listen(PORT, () => {
            console.log(`\n🎉 WINK EXPRESS API est en cours d'exécution et écoute sur le port ${PORT}`);
            console.log(`Accès local : http://localhost:${PORT}\n`);
        });
    }
})();

module.exports = app;