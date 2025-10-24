// src/controllers/suivis.controller.js
const messageModel = require('../models/message.model');
const orderModel = require('../models/order.model');
const userModel = require('../models/user.model');
// --- AJOUTÉ: Import du service WebSocket ---
const webSocketService = require('../services/websocket.service');

// --- Contrôleurs pour l'Onglet Suivis ---

/**
 * GET /api/suivis/conversations
 * Récupère la liste des conversations pour l'admin connecté.
 */
const getConversations = async (req, res) => {
    try {
        const adminUserId = req.user.id;
        const filters = {
            search: req.query.search || null,
            showArchived: req.query.showArchived === 'true',
            showUrgentOnly: req.query.showUrgentOnly === 'true'
        };
        const conversations = await messageModel.findConversationsForAdmin(adminUserId, filters);
        res.json(conversations);
    } catch (error) {
        console.error("Erreur getConversations:", error);
        res.status(500).json({ message: "Erreur serveur lors de la récupération des conversations." });
    }
};

/**
 * GET /api/suivis/unread-count
 * Récupère le nombre total de messages non lus pour l'utilisateur connecté.
 */
const getTotalUnreadCount = async (req, res) => {
    try {
        const userId = req.user.id;
        const userRole = req.user.role;
        const count = await messageModel.countAllUnreadMessages(userId, userRole);
        res.json({ unreadCount: count });
    } catch (error) {
        console.error("Erreur getTotalUnreadCount:", error);
        res.status(500).json({ message: "Erreur serveur lors du comptage des messages non lus." });
    }
};


/**
 * GET /api/orders/:orderId/messages
 * Récupère les messages pour une commande. Marque comme lus au passage.
 */
const getMessages = async (req, res) => {
    try {
        const orderId = parseInt(req.params.orderId);
        const userId = req.user.id;
        const userRole = req.user.role;
        const since = req.query.since || null;

        if (isNaN(orderId)) return res.status(400).json({ message: "ID commande invalide." });

        const messages = await messageModel.findMessagesByOrderId(orderId, userId, userRole, since);

        // Marquer comme lus après récupération (si ce n'est pas une requête 'since')
        // On marque comme lu même si la requête est 'since' pour s'assurer que tout ce qui est chargé est marqué
        if (messages.length > 0) {
             const lastMessageId = messages[messages.length - 1].id;
             const { markedCount } = await messageModel.markMessagesAsRead(orderId, userId, lastMessageId);
             // Optionnel: Notifier l'utilisateur via WebSocket que son compteur de non-lus a peut-être changé
             // if (markedCount > 0) {
             //     const newUnreadCount = await messageModel.countAllUnreadMessages(userId, userRole);
             //     webSocketService.sendNotification(userId, 'UNREAD_COUNT_UPDATE', { unreadCount: newUnreadCount });
             // }
        }

        res.json(messages);
    } catch (error) {
        console.error("Erreur getMessages:", error);
        if (error.message.includes("Accès non autorisé")) {
             return res.status(403).json({ message: error.message });
        }
        res.status(500).json({ message: "Erreur serveur lors de la récupération des messages." });
    }
};

/**
 * POST /api/orders/:orderId/messages
 * Ajoute un nouveau message utilisateur.
 * --- MODIFIÉ: Diffuse le message via WebSocket après enregistrement ---
 */
const postMessage = async (req, res) => {
     try {
        const orderId = parseInt(req.params.orderId);
        const userId = req.user.id;
        const userRole = req.user.role;
        const { message_content } = req.body;

        if (isNaN(orderId)) return res.status(400).json({ message: "ID commande invalide." });
        if (!message_content || message_content.trim() === '') {
             return res.status(400).json({ message: "Le contenu du message ne peut pas être vide." });
        }

        // Vérification d'accès et dé-archivage si besoin
        const order = await orderModel.findById(orderId);
        if (!order) {
            return res.status(404).json({ message: "Commande non trouvée." });
        }
        if (userRole !== 'admin' && order.deliveryman_id != userId) {
            return res.status(403).json({ message: "Accès non autorisé à poster dans cette conversation." });
        }
        if(order.is_archived) {
            // Dé-archiver si un message est envoyé dans une conversation archivée
            await messageModel.setOrderArchived(orderId, false);
            // Optionnel: Notifier l'admin via WebSocket que la liste doit être mise à jour
            // webSocketService.sendNotification(adminUserId, 'CONVERSATION_LIST_UPDATE', {});
        }

        // 1. Enregistrer le message en BDD
        const newMessage = await messageModel.createMessage(orderId, userId, message_content.trim(), 'user');

        // 2. --- AJOUTÉ: Diffuser le nouveau message via WebSocket ---
        // On envoie l'objet `newMessage` complet (qui contient user_name, etc.)
        webSocketService.broadcastMessage(orderId, newMessage, userId);

        // 3. Répondre à la requête HTTP initiale (succès)
        res.status(201).json(newMessage);

        // 4. Mettre à jour le compteur global non lu pour les *autres* participants (Admin ou Livreur)
        const recipientUserId = (userRole === 'admin') ? order.deliveryman_id : 1; // Supposons ID 1 = Admin principal
         if (recipientUserId) {
             const recipientRole = (userRole === 'admin') ? 'livreur' : 'admin';
             const newUnreadCount = await messageModel.countAllUnreadMessages(recipientUserId, recipientRole);
             webSocketService.sendNotification(recipientUserId, 'UNREAD_COUNT_UPDATE', { unreadCount: newUnreadCount });
             // Notifier aussi que la liste des conversations doit être rafraîchie (pour l'ordre/dernier message)
             webSocketService.sendNotification(recipientUserId, 'CONVERSATION_LIST_UPDATE', {});
         }
         // Notifier l'expéditeur aussi que sa liste doit être rafraîchie (si admin)
         if(userRole === 'admin'){
            webSocketService.sendNotification(userId, 'CONVERSATION_LIST_UPDATE', {});
         }


    } catch (error) {
        console.error("Erreur postMessage:", error);
        res.status(500).json({ message: "Erreur serveur lors de l'envoi du message." });
    }
};


// --- Contrôleurs Actions Admin ---

/**
 * PUT /api/suivis/orders/:orderId/reassign-from-chat
 * --- MODIFIÉ: Diffuse un message système via WebSocket ---
 */
const reassignFromChat = async (req, res) => {
    try {
        const orderId = parseInt(req.params.orderId);
        const adminUserId = req.user.id;
        const { newDeliverymanId } = req.body;

        if (isNaN(orderId) || !newDeliverymanId) {
             return res.status(400).json({ message: "ID commande et ID nouveau livreur requis." });
        }

        const [adminUser, newDeliveryman] = await Promise.all([
            userModel.findById(adminUserId),
            userModel.findById(newDeliverymanId)
        ]);
        if (!newDeliveryman || newDeliveryman.role !== 'livreur') {
             return res.status(400).json({ message: "ID livreur invalide ou utilisateur n'est pas livreur." });
        }

        // Assignation via orderModel (gère l'historique standard, annule transaction pending, met à jour order)
        await orderModel.assignDeliveryman(orderId, newDeliverymanId, adminUserId);

        // Créer ET diffuser le message système via WebSocket
        const systemMessageContent = `Admin ${adminUser.name || 'Admin'} a réassigné la commande au livreur ${newDeliveryman.name}.`;
        const systemMessage = await messageModel.createMessage(orderId, adminUserId, systemMessageContent, 'system');
        webSocketService.broadcastMessage(orderId, systemMessage, adminUserId);

        // Dé-archiver et démarquer urgent (géré dans assignDeliveryman maintenant)
        // await Promise.all([
        //      messageModel.setOrderArchived(orderId, false),
        //      messageModel.setOrderUrgency(orderId, false)
        // ]);

        // Notifier les utilisateurs concernés que leur liste doit être mise à jour
        webSocketService.sendNotification(adminUserId, 'CONVERSATION_LIST_UPDATE', {});
        webSocketService.sendNotification(newDeliverymanId, 'CONVERSATION_LIST_UPDATE', {});
        // Optionnel : Notifier l'ancien livreur aussi

        res.json({ message: "Commande réassignée avec succès." });

    } catch (error) {
        console.error("Erreur reassignFromChat:", error);
        res.status(500).json({ message: error.message || "Erreur serveur lors de la réassignation." });
    }
};

/**
 * PUT /api/suivis/orders/:orderId/reset-status-from-chat
 * --- MODIFIÉ: Diffuse un message système via WebSocket ---
 */
const resetStatusFromChat = async (req, res) => {
    try {
        const orderId = parseInt(req.params.orderId);
        const adminUserId = req.user.id;
        const adminUser = await userModel.findById(adminUserId);

        if (isNaN(orderId)) return res.status(400).json({ message: "ID commande invalide." });

        // Réinitialise statut/paiement, amount_received via orderModel (gère aussi is_archived)
        await orderModel.updateStatus(orderId, 'pending', null, 'pending', adminUserId);

        // Démarquer urgent (géré dans updateStatus maintenant si besoin, sinon ajouter ici)
        // await messageModel.setOrderUrgency(orderId, false);

        // Créer ET diffuser le message système via WebSocket
        const systemMessageContent = `Admin ${adminUser.name || 'Admin'} a réinitialisé le statut de la commande.`;
        const systemMessage = await messageModel.createMessage(orderId, adminUserId, systemMessageContent, 'system');
        webSocketService.broadcastMessage(orderId, systemMessage, adminUserId);

        // Notifier les utilisateurs concernés que leur liste doit être mise à jour
        webSocketService.sendNotification(adminUserId, 'CONVERSATION_LIST_UPDATE', {});
        const order = await orderModel.findById(orderId); // Pour trouver le livreur
        if (order && order.deliveryman_id) {
             webSocketService.sendNotification(order.deliveryman_id, 'CONVERSATION_LIST_UPDATE', {});
        }


        res.json({ message: "Statut de la commande réinitialisé avec succès." });

    } catch (error) {
        console.error("Erreur resetStatusFromChat:", error);
        res.status(500).json({ message: error.message || "Erreur serveur lors de la réinitialisation du statut." });
    }
};

/**
 * PUT /api/suivis/orders/:orderId/toggle-urgency
 * --- MODIFIÉ: Diffuse un message système via WebSocket ---
 */
const toggleUrgency = async (req, res) => {
    try {
        const orderId = parseInt(req.params.orderId);
        const adminUserId = req.user.id;
        const { is_urgent } = req.body;

        if (isNaN(orderId) || typeof is_urgent !== 'boolean') {
             return res.status(400).json({ message: "ID commande et statut 'is_urgent' (boolean) requis." });
        }

        const success = await messageModel.setOrderUrgency(orderId, is_urgent);
        if (!success) return res.status(404).json({ message: "Commande non trouvée." });

        // Créer ET diffuser le message système via WebSocket
        const adminUser = await userModel.findById(adminUserId);
        const systemMessageContent = `Admin ${adminUser.name || 'Admin'} a ${is_urgent ? 'marqué' : 'démarqué'} la commande comme urgente.`;
        const systemMessage = await messageModel.createMessage(orderId, adminUserId, systemMessageContent, 'system');
        webSocketService.broadcastMessage(orderId, systemMessage, adminUserId);

        // Notifier les utilisateurs concernés que leur liste doit être mise à jour
        webSocketService.sendNotification(adminUserId, 'CONVERSATION_LIST_UPDATE', {});
        const order = await orderModel.findById(orderId); // Pour trouver le livreur
        if (order && order.deliveryman_id) {
             webSocketService.sendNotification(order.deliveryman_id, 'CONVERSATION_LIST_UPDATE', {});
        }

        res.json({ message: `Urgence ${is_urgent ? 'activée' : 'désactivée'}.` });

    } catch (error) {
        console.error("Erreur toggleUrgency:", error);
        res.status(500).json({ message: "Erreur serveur lors de la modification de l'urgence." });
    }
};

// --- Contrôleurs pour Messages Rapides ---

/**
 * GET /api/suivis/quick-replies
 */
const getQuickReplies = async (req, res) => {
    try {
        const role = req.user.role;
        const replies = await messageModel.findQuickRepliesByRole(role);
        res.json(replies);
    } catch (error) {
        console.error("Erreur getQuickReplies:", error);
        res.status(500).json({ message: "Erreur serveur lors de la récupération des messages rapides." });
    }
};

module.exports = {
    getConversations,
    getTotalUnreadCount,
    getMessages,
    postMessage,
    reassignFromChat,
    resetStatusFromChat,
    toggleUrgency,
    getQuickReplies
};