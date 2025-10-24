// public/js/rider.js
// Utilisation de Moment.js s'il est chargé globalement
const moment = (typeof window.moment === 'function') ? window.moment : (date) => new Date(date);

document.addEventListener('DOMContentLoaded', async () => {
    // --- CONFIGURATION ---
    const API_BASE_URL = '/api';
    // --- AJOUTÉ: URL WebSocket ---
    const WS_URL = `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}`;
    let currentUser; // Sera initialisé par checkAuthAndInit
    let currentOrderId; // Utilisé pour les modales d'action
    let chatOrderId = null; // ID spécifique pour la conversation ouverte dans la modale chat
    let lastPendingOrderCount = 0; // Gardé pour la logique de notification sonore
    let lastMessageTimestamp = null; // Pour le chargement initial du chat
    // --- SUPPRIMÉ: Constantes Polling ---

    // --- AJOUTÉ: Référence WebSocket ---
    let ws = null;

    // --- Références DOM ---
    const ordersContainer = document.getElementById('ordersContainer');
    const navLinks = document.querySelectorAll('.nav-link[data-tab]');
    const searchInput = document.getElementById('searchInput');
    const dateFilters = document.getElementById('dateFilters');
    const startDateFilter = document.getElementById('startDateFilter'); // Ajouté pour référence
    const endDateFilter = document.getElementById('endDateFilter');   // Ajouté pour référence
    const filterDateBtn = document.getElementById('filterDateBtn');     // Ajouté pour référence
    const globalNotificationBadge = document.getElementById('globalNotificationBadge');

    // Modales (Références des éléments principaux)
    const statusActionModalEl = document.getElementById('statusActionModal');
    const statusActionModal = statusActionModalEl ? new bootstrap.Modal(statusActionModalEl) : null;
    const deliveredPaymentModalEl = document.getElementById('deliveredPaymentModal');
    const deliveredPaymentModal = deliveredPaymentModalEl ? new bootstrap.Modal(deliveredPaymentModalEl) : null;
    const failedDeliveryModalEl = document.getElementById('failedDeliveryModal');
    const failedDeliveryModal = failedDeliveryModalEl ? new bootstrap.Modal(failedDeliveryModalEl) : null;
    const returnModalEl = document.getElementById('returnModal');
    const returnModal = returnModalEl ? new bootstrap.Modal(returnModalEl) : null;

    // Nouveaux éléments de chat
    const chatModalRiderEl = document.getElementById('chatModalRider');
    const chatModalRider = chatModalRiderEl ? new bootstrap.Modal(chatModalRiderEl) : null;
    const chatRiderOrderIdSpan = document.getElementById('chatRiderOrderId');
    const chatMessagesRider = document.getElementById('chatMessagesRider');
    const quickReplyButtonsRider = document.getElementById('quickReplyButtonsRider');
    const messageInputRider = document.getElementById('messageInputRider');
    const sendMessageBtnRider = document.getElementById('sendMessageBtnRider');
    const requestModificationBtn = document.getElementById('requestModificationBtn');

    // Spans / Boutons dans les modales existantes
    const actionModalOrderIdSpan = document.getElementById('actionModalOrderId');
    const statusSelectionDiv = document.getElementById('statusSelection');
    const deliveredModalOrderIdSpan = document.getElementById('deliveredModalOrderId');
    const failedModalOrderIdSpan = document.getElementById('failedModalOrderId');
    const failedDeliveryForm = document.getElementById('failedDeliveryForm'); // Ajouté pour référence
    const paymentCashBtn = document.getElementById('paymentCashBtn');       // Ajouté pour référence
    const paymentSupplierBtn = document.getElementById('paymentSupplierBtn');   // Ajouté pour référence
    const returnModalOrderIdSpan = document.getElementById('returnModalOrderId');
    const confirmReturnBtn = document.getElementById('confirmReturnBtn');     // Ajouté pour référence

    const notificationSound = new Audio('/sound.mp3'); // Assurez-vous que le chemin est correct

    // Constantes
    const statusTranslations = { 
        'pending': 'En attente', 
        'in_progress': 'Assignée', 
        'ready_for_pickup': 'Prête à prendre', // NOUVEAU STATUT
        'en_route': 'En route', // NOUVEAU STATUT
        'return_declared': 'Retour déclaré', // NOUVEAU STATUT
        'delivered': 'Livrée', 
        'cancelled': 'Annulée', 
        'failed_delivery': 'Livraison ratée', 
        'reported': 'À relancer' 
    };
    const paymentTranslations = { 'pending': 'En attente', 'cash': 'En espèces', 'paid_to_supplier': 'Mobile Money', 'cancelled': 'Annulé' };
    const unprocessedStatuses = ['pending', 'in_progress', 'ready_for_pickup', 'en_route', 'reported']; // Pour le tri

    // --- Fonctions Utilitaires ---

    const debounce = (func, delay = 300) => {
        let timeout;
        return (...args) => {
            clearTimeout(timeout);
            timeout = setTimeout(() => {
                func.apply(this, args);
            }, delay);
        };
    };

    const showNotification = (message, type = 'success') => {
        const container = document.body; // Modifier si vous avez un conteneur spécifique
        const alertId = `notif-${Date.now()}`;
        const alert = document.createElement('div');
        alert.id = alertId;
        // Styles pour affichage en haut
        alert.style.position = 'fixed';
        alert.style.top = '10px';
        alert.style.right = '10px';
        alert.style.zIndex = '1060'; // Au-dessus des modales
        alert.style.minWidth = '250px';
        alert.style.maxWidth = '90%';

        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.role = 'alert';
        alert.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;
        container.appendChild(alert);
        setTimeout(() => {
            const activeAlert = document.getElementById(alertId);
            if(activeAlert) { try { bootstrap.Alert.getOrCreateInstance(activeAlert)?.close(); } catch (e) { activeAlert.remove(); } }
        }, 5000);
    };

    const formatDate = (dateString) => dateString ? moment(dateString).format('DD MMM YYYY') : 'N/A';
    const formatAmount = (amount) => `${Number(amount || 0).toLocaleString('fr-FR')} FCFA`;

    const getAuthHeader = () => { const token = AuthManager.getToken(); return token ? { 'Authorization': `Bearer ${token}` } : null; };

    const handleAuthError = (error) => {
        console.error("Erreur API:", error);
        if (error.response?.status === 401 || error.response?.status === 403) {
            showNotification("Session expirée. Reconnexion...", "danger");
            if (ws) { ws.close(1008, "Session expirée"); } // Fermer WS avant logout
            AuthManager.logout();
        } else if (!navigator.onLine) {
            showNotification("Hors ligne. Actions mises en file d'attente si possible.", "warning");
        } else {
             const errMsg = error.response?.data?.message || error.message || "Erreur serveur.";
             if (error.response?.status !== 404) { showNotification(`Erreur: ${errMsg}`, "danger"); }
             else { console.warn("Ressource API non trouvée (404)"); }
        }
    };

    // --- AJOUTÉ: Initialisation et gestion WebSocket ---

    const initWebSocket = () => {
        const token = AuthManager.getToken();
        if (!token) {
            console.error("WebSocket Rider: Token non trouvé.");
            return;
        }
        if (ws && ws.readyState === WebSocket.OPEN) {
             console.log("WebSocket Rider: Déjà connecté.");
             return; // Déjà connecté
        }

        console.log(`WebSocket Rider: Tentative connexion à ${WS_URL}...`);
        ws = new WebSocket(`${WS_URL}?token=${token}`);

        ws.onopen = () => {
            console.log('WebSocket Rider: Connexion établie.');
            // Charger données initiales après connexion
            updateSidebarCounters(); // Mettre à jour les compteurs
            const activeTab = document.querySelector('.nav-link.active')?.dataset.tab || 'today';
            fetchOrders(activeTab); // Charger onglet par défaut
        };

        ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                console.log('WebSocket Rider: Message reçu:', data);
                handleWebSocketMessage(data);
            } catch (error) {
                console.error('WebSocket Rider: Erreur parsing message:', error);
            }
        };

        ws.onerror = (error) => {
            console.error('WebSocket Rider: Erreur connexion:', error);
        };

        ws.onclose = (event) => {
            console.log(`WebSocket Rider: Connexion fermée. Code: ${event.code}, Raison: ${event.reason}`);
            ws = null;
            if (event.code !== 1000 && event.code !== 1008) { // Ne pas retenter si déconnexion normale ou token invalide
                console.log("WebSocket Rider: Reconnexion dans 5s...");
                setTimeout(initWebSocket, 5000);
            } else if (event.code === 1008) {
                 showNotification("Authentification temps réel échouée.", "warning");
                 AuthManager.logout(); // Si le token est rejeté, déconnecter
            }
        };
    };

    const handleWebSocketMessage = (data) => {
        switch (data.type) {
            case 'AUTH_SUCCESS':
                console.log("WebSocket Rider: Auth confirmée.");
                break;
            case 'NEW_MESSAGE':
                if (data.payload && data.payload.order_id === chatOrderId && chatModalRiderEl?.classList.contains('show')) {
                    renderRiderMessages([data.payload], false);
                    if (document.visibilityState === 'visible') {
                        markMessagesAsRead(chatOrderId, data.payload.id); 
                    }
                } else if (data.payload) {
                    updateOrderCardBadge(data.payload.order_id);
                     if (currentUser && data.payload.user_id !== currentUser.id) {
                         notificationSound.play().catch(e => console.warn("Impossible jouer son:", e));
                     }
                }
                updateSidebarCounters(); 
                break;
            case 'UNREAD_COUNT_UPDATE':
                if (globalNotificationBadge && data.payload) {
                    const count = data.payload.unreadCount || 0;
                    globalNotificationBadge.textContent = count;
                    globalNotificationBadge.classList.toggle('d-none', count === 0);
                }
                break;
            case 'CONVERSATION_LIST_UPDATE': 
                 console.log("WebSocket Rider: Demande refresh liste reçue.");
                 const activeTab = document.querySelector('.nav-link.active')?.dataset.tab || 'today';
                 fetchOrders(activeTab); 
                 break;
            case 'NEW_ORDER_ASSIGNED': 
                 if (data.payload && data.payload.deliveryman_id === currentUser?.id) {
                     showNotification(`🔔 Nouvelle commande #${data.payload.order_id} assignée !`, 'info');
                     notificationSound.play().catch(e => console.warn("Impossible jouer son:", e));
                     updateSidebarCounters(); 
                     if (document.querySelector('.nav-link.active')?.dataset.tab === 'today') {
                         fetchOrders('today');
                     }
                 }
                 break;
            case 'ORDER_STATUS_UPDATE': 
                 if (data.payload && data.payload.deliveryman_id === currentUser?.id) {
                     console.log(`WebSocket Rider: MAJ statut Cde #${data.payload.order_id}`);
                     const activeTabRefresh = document.querySelector('.nav-link.active')?.dataset.tab || 'today';
                     fetchOrders(activeTabRefresh);
                     updateSidebarCounters();
                 }
                 break;
            case 'ERROR':
                 console.error("WebSocket Rider: Erreur serveur:", data.message);
                 break;
            default:
                console.warn(`WebSocket Rider: Type message non géré: ${data.type}`);
        }
    };

     const joinConversation = (orderId) => {
        if (ws && ws.readyState === WebSocket.OPEN && orderId) {
            ws.send(JSON.stringify({ type: 'JOIN_CONVERSATION', payload: { orderId } }));
            console.log(`WebSocket Rider: Envoi JOIN pour ${orderId}`);
        }
    };

    const leaveConversation = (orderId) => {
         if (ws && ws.readyState === WebSocket.OPEN && orderId) {
            ws.send(JSON.stringify({ type: 'LEAVE_CONVERSATION', payload: { orderId } }));
            console.log(`WebSocket Rider: Envoi LEAVE pour ${orderId}`);
         }
    };

     const markMessagesAsRead = async (orderId, lastMessageId) => {
         const headers = getAuthHeader();
         if (!headers || !orderId || !lastMessageId || !currentUser) return;
         try {
             await axios.get(`${API_BASE_URL}/orders/${orderId}/messages?triggerRead=${lastMessageId}`, { headers });
             console.log(`WebSocket Rider: Marqué lu Cde ${orderId} jusqu'à ${lastMessageId}`);
             updateSidebarCounters();
             updateOrderCardBadge(orderId, 0); 
         } catch (error) {
              if (error.response?.status !== 401 && error.response?.status !== 403) {
                 console.error(`Erreur marquage lu Cde ${orderId}:`, error);
              }
         }
     };

     const updateOrderCardBadge = (orderId, count = null) => {
         const chatButton = ordersContainer?.querySelector(`.order-card .chat-btn[data-order-id="${orderId}"]`);
         if (!chatButton) return; 

         let finalCount = count;
         if (finalCount === null) return;

         const badge = chatButton.querySelector('.badge');
         if (finalCount > 0) {
             if (badge) {
                 badge.textContent = finalCount;
                 badge.classList.remove('d-none');
             } else {
                 const newBadge = document.createElement('span');
                 newBadge.className = 'badge bg-danger rounded-pill';
                 newBadge.textContent = finalCount;
                 chatButton.appendChild(newBadge); 
             }
         } else {
             if (badge) {
                 badge.classList.add('d-none');
                 badge.textContent = '0';
             }
         }
     };

    // --- Fonctions de Rendu ---
    const sortRiderOrders = (orders) => {
         return orders.sort((a, b) => {
             const a_isUnprocessed = unprocessedStatuses.includes(a.status);
             const b_isUnprocessed = unprocessedStatuses.includes(b.status);

             if (a_isUnprocessed && !b_isUnprocessed) return -1;
             if (!a_isUnprocessed && b_isUnprocessed) return 1;

             if (a_isUnprocessed && b_isUnprocessed) {
                 if (a.is_urgent !== b.is_urgent) return a.is_urgent ? -1 : 1;
             }
             return moment(a.created_at).diff(moment(b.created_at));
         });
     };

    const renderOrders = (orders) => {
        const activeTab = document.querySelector('.nav-link.active')?.dataset.tab;

        if (activeTab === 'today') {
            orders = sortRiderOrders(orders);
        } else {
            orders.sort((a,b) => moment(b.created_at).diff(moment(a.created_at)));
        }

        if (!ordersContainer) return;

        if (!orders || !Array.isArray(orders) || orders.length === 0) {
            ordersContainer.innerHTML = `<p class="text-center text-muted mt-5">Aucune commande ici.</p>`;
            return;
        }

        ordersContainer.innerHTML = ''; // Vider avant de re-remplir
        orders.forEach(order => {
            const orderCard = document.createElement('div');
            orderCard.className = `order-card ${order.is_urgent ? 'urgent' : ''}`;

            const shopName = order.shop_name || 'N/A';
            const customerName = order.customer_name || 'Inconnu';
            const customerPhone = order.customer_phone || 'N/A';
            const deliveryLocation = order.delivery_location || 'Non spécifiée';
            const itemNames = order.items_list || 'Non spécifié';
            const clientInfo = customerName !== 'Inconnu' ? `${customerPhone} (${customerName})` : customerPhone;

            const amountToDisplay = (parseFloat(order.article_amount) || 0);

            const statusText = statusTranslations[order.status] || order.status;
            const paymentText = paymentTranslations[order.payment_status] || order.payment_status;
            const statusDotClass = `status-dot status-${order.status}`;
            const paymentDotClass = `payment-dot payment-${order.payment_status}`;
            const isFinalStatus = ['delivered', 'cancelled', 'returned'].includes(order.status);

            const unreadCount = order.unread_count || 0;
            const unreadBadgeHtml = unreadCount > 0 ? `<span class="badge bg-danger rounded-pill">${unreadCount}</span>` : '';
            const urgentIconHtml = order.is_urgent ? '<i class="bi bi-exclamation-triangle-fill text-danger ms-1" title="URGENT"></i>' : '';

            // --- NOUVELLE LOGIQUE D'ÉTAT ---
            const isReady = order.status === 'ready_for_pickup';
            const isPickedUp = !!order.picked_up_by_rider_at;
            const isEnRoute = order.status === 'en_route';
            const isReturnDeclared = order.status === 'return_declared';

            // Les boutons de statut final (Livrée, Ratée, Annulée, Relance, Retour) ne sont actifs que si EN_ROUTE
            const disableFinalStatusBtn = !isEnRoute && !isReturnDeclared; // Permet de statuer si retour déclaré aussi.
            
            // Logique du bouton principal d'action (Confirmation/Démarrer)
            let pickupStartBtnHtml = '';
            let isPickupStartBtnDisabled = false;
            let pickupStartBtnClass = 'btn-outline-secondary';
            let pickupStartBtnText = '';
            let actionType = 'none';

            if (isReady && !isPickedUp) {
                // 1. Prêt à prendre, pas encore confirmé par le livreur
                pickupStartBtnText = 'Confirmer Récupération Colis';
                pickupStartBtnClass = 'btn-warning pickup-btn';
                actionType = 'pickup';
            } else if (isReady && isPickedUp) {
                // 2. Colis récupéré, prêt à démarrer la course
                pickupStartBtnText = 'Démarrer Course';
                pickupStartBtnClass = 'btn-success start-delivery-btn';
                actionType = 'start';
            } else if (isEnRoute) {
                 // 3. En route (action principale est de statuer)
                 pickupStartBtnText = 'Course Démarrée';
                 pickupStartBtnClass = 'btn-success disabled';
                 isPickupStartBtnDisabled = true;
            } else if (order.status === 'in_progress') {
                 // 4. Assignée mais pas encore prête pour le pickup
                 pickupStartBtnText = 'En attente préparation admin';
                 pickupStartBtnClass = 'btn-outline-secondary disabled';
                 isPickupStartBtnDisabled = true;
            } else {
                 // 5. Autre statut (pending, reported, return_declared, etc.)
                 pickupStartBtnText = 'Action indisponible';
                 isPickupStartBtnDisabled = true;
                 pickupStartBtnClass = 'btn-outline-secondary disabled';
            }

            // Nous générons le HTML en utilisant la structure définie dans rider-app.html
            pickupStartBtnHtml = `
                <li>
                    <a class="dropdown-item ${pickupStartBtnClass}" 
                       data-order-id="${order.id}" 
                       data-action="${actionType}"
                       href="#" 
                       ${isPickupStartBtnDisabled ? 'disabled' : ''}>
                       <i class="bi bi-box-arrow-in-down me-2"></i> ${pickupStartBtnText}
                    </a>
                </li>
                <li><hr class="dropdown-divider"></li>
            `;
            // --- FIN NOUVELLE LOGIQUE D'ÉTAT ---


            orderCard.innerHTML = `
                <div class="order-card-header">
                    <h6 class="order-id mb-0">Commande #${order.id} ${urgentIconHtml}</h6>
                    <div class="order-actions">
                        <button class="btn chat-btn" data-order-id="${order.id}" type="button" title="Discussion">
                            <i class="bi bi-chat-dots"></i>
                            ${unreadBadgeHtml}
                        </button>
                        <div class="dropdown">
                            <button class="btn" type="button" data-bs-toggle="dropdown" title="Actions"><i class="bi bi-gear"></i></button>
                            <ul class="dropdown-menu dropdown-menu-end">
                                ${pickupStartBtnHtml}
                                <li>
                                    <a class="dropdown-item status-btn ${disableFinalStatusBtn ? 'disabled text-muted' : ''}"
                                       data-order-id="${order.id}" href="#"><i class="bi bi-check2-circle me-2"></i> Statuer la commande</a>
                                </li>
                                <li>
                                    <a class="dropdown-item return-btn ${disableFinalStatusBtn ? 'disabled text-muted' : ''}"
                                       data-order-id="${order.id}" href="#"><i class="bi bi-box-arrow-left me-2"></i> Déclarer un retour</a>
                                </li>
                            </ul>
                        </div>
                        <div class="dropdown">
                            <button class="btn btn-corail" type="button" data-bs-toggle="dropdown" title="Contacter"><i class="bi bi-telephone"></i></button>
                            <ul class="dropdown-menu dropdown-menu-end">
                                <li><a class="dropdown-item" href="tel:${customerPhone.replace(/\s/g, '')}"><i class="bi bi-telephone-outbound me-2"></i> Appeler Client</a></li>
                                <li><a class="dropdown-item" href="sms:${customerPhone.replace(/\s/g, '')}"><i class="bi bi-chat-text me-2"></i> Envoyer SMS Client</a></li>
                                <li><a class="dropdown-item" href="https://wa.me/${customerPhone.replace(/\D/g, '')}" target="_blank"><i class="bi bi-whatsapp me-2"></i> WhatsApp Client</a></li>
                            </ul>
                        </div>
                    </div>
                </div>
                <hr class="my-2">
                <div class="order-details">
                    <p><span class="detail-label">Marchand:</span> <span class="detail-value">${shopName}</span></p>
                    <p><span class="detail-label">Client:</span> <span class="detail-value">${clientInfo}</span></p>
                    <p><span class="detail-label">Adresse:</span> <span class="detail-value">${deliveryLocation}</span></p>
                    <p><span class="detail-label">Article(s):</span> <span class="detail-value">${itemNames}</span></p>
                    <p class="status-line">
                        <span class="detail-label">Statut:</span>
                        <span class="status-badge"><span class="${statusDotClass}"></span>${statusText}</span>
                        <span class="payment-badge"><span class="${paymentDotClass}"></span>${paymentText}</span>
                    </p>
                    <p><span class="detail-label">À récupérer:</span> <span class="detail-value fw-bold text-success">${formatAmount(amountToDisplay)}</span></p>
                    <p class="text-muted text-end" style="font-size: 0.75rem;">Créée le ${formatDate(order.created_at)}</p>
                </div>
            `;
            ordersContainer.appendChild(orderCard);
        });
    };


    // --- Logique de Polling du Chat (SUPPRIMÉE) ---

    // Rend les messages dans la modale chat
    const renderRiderMessages = (messages, replace = true) => {
        if (!chatMessagesRider) return;
        if (replace) chatMessagesRider.innerHTML = '';
        const isScrolledDown = chatMessagesRider.scrollHeight - chatMessagesRider.scrollTop - chatMessagesRider.clientHeight < 50;

        messages.forEach(msg => {
            if (!msg || typeof msg.id === 'undefined') {
                console.warn("Message ignoré car ID manquant ou message invalide.");
                return;
            }
            const currentUserIdValid = currentUser && typeof currentUser.id !== 'undefined';
            if (!replace && chatMessagesRider.querySelector(`[data-message-id="${msg.id}"]`)) return;

            const messageDiv = document.createElement('div');
            messageDiv.dataset.messageId = msg.id;
            const isSentByMe = currentUserIdValid ? (msg.user_id === currentUser.id) : false;
            const isSystem = msg.message_type === 'system';
            let messageClass = 'message';
            if (isSystem) messageClass += ' message-system';
            else if (isSentByMe) messageClass += ' message-sent';
            else messageClass += ' message-received';
            messageDiv.className = messageClass;
            const time = moment(msg.created_at).format('HH:mm');
            const author = isSystem ? '' : `<strong>${isSentByMe ? 'Moi' : (msg.user_name || 'Admin')}:</strong><br>`;
            const messageContent = (msg.message_content || '').replace(/#(\d+)/g, '<span class="text-info">#$1</span>'); // Simplement colorer le tag
            messageDiv.innerHTML = `${author}${messageContent}<div class="message-meta">${time}</div>`;
            chatMessagesRider.appendChild(messageDiv);
        });

        if (isScrolledDown || replace) {
            setTimeout(() => { if(chatMessagesRider) chatMessagesRider.scrollTop = chatMessagesRider.scrollHeight; }, 0); // Léger délai
        }
     };

    // Charge les messages initiaux pour une commande (appel API GET)
    const loadRiderMessages = async (orderId, since = null) => {
        if (since) { 
             console.warn("loadRiderMessages (Rider) appelé avec 'since'. Ignoré.");
             return;
        }
        const headers = getAuthHeader(); if (!headers) return;
        if (chatMessagesRider) chatMessagesRider.innerHTML = `<p class="text-center text-muted p-5"><div class="spinner-border spinner-border-sm"></div> Chargement...</p>`;

        try {
            const response = await axios.get(`${API_BASE_URL}/orders/${orderId}/messages`, { headers }); 
            const messages = response.data || [];

            if (messages.length > 0) {
                 renderRiderMessages(messages, true); 
                 lastMessageTimestamp = messages[messages.length - 1].created_at;
                 markMessagesAsRead(orderId, messages[messages.length - 1].id);
            } else if (chatMessagesRider) {
                 chatMessagesRider.innerHTML = `<p class="text-center text-muted p-5">Aucun message.</p>`;
            }
             updateSidebarCounters(); 
             const activeTabBg = document.querySelector('.nav-link.active')?.dataset.tab || 'today';
             fetchOrders(activeTabBg);


        } catch (error) {
            console.error(`Erreur messages Cde ${orderId}:`, error);
            if (error.response?.status === 403) { showNotification("Accès refusé à cette conversation.", "warning"); if(chatModalRider) chatModalRider.hide(); }
            else if (chatMessagesRider) { chatMessagesRider.innerHTML = `<p class="text-center text-danger p-5">Erreur chargement.</p>`; }
            handleAuthError(error); 
        }
    };

    // Charge les messages rapides
    const loadRiderQuickReplies = async () => {
        const headers = getAuthHeader(); if (!headers || !quickReplyButtonsRider) return;
        quickReplyButtonsRider.innerHTML = ''; 
        try {
            const response = await axios.get(`${API_BASE_URL}/suivis/quick-replies`, { headers });
            const quickReplies = response.data || [];

            quickReplies.forEach(replyText => {
                 const button = document.createElement('button');
                 button.className = 'btn btn-sm btn-outline-secondary';
                 button.textContent = replyText;
                 button.type = 'button';
                 button.addEventListener('click', () => {
                      if(messageInputRider) {
                          messageInputRider.value += (messageInputRider.value ? ' ' : '') + replyText;
                          messageInputRider.focus();
                          messageInputRider.dispatchEvent(new Event('input', { bubbles: true })); 
                      }
                 });
                 quickReplyButtonsRider.appendChild(button);
             });
        } catch (error) {
            console.error("Erreur chargement messages rapides:", error);
        }
    };

    // Envoie un message (utilise toujours axios.post, réception via WebSocket)
    const sendRiderMessage = async () => {
         const content = messageInputRider?.value.trim();
        if (!content || !chatOrderId) return;
        const headers = getAuthHeader(); if (!headers) return;
        if (!currentUser || typeof currentUser.id === 'undefined') {
            showNotification("Erreur d'utilisateur.", "danger"); return;
        }

        const tempId = `temp_${Date.now()}`;
        const optimisticMessage = { id: tempId, user_id: currentUser.id, user_name: currentUser.name, message_content: content, created_at: new Date().toISOString(), message_type: 'user' };

        renderRiderMessages([optimisticMessage], false); 
        if(messageInputRider) { messageInputRider.value = ''; messageInputRider.rows = 1; }
        if(sendMessageBtnRider) sendMessageBtnRider.disabled = true;

        try {
            await axios.post(`${API_BASE_URL}/orders/${chatOrderId}/messages`, { message_content: content }, { headers });

        } catch (error) {
            console.error(`Erreur envoi Cde ${chatOrderId}:`, error);
            showNotification("Erreur d'envoi.", 'danger');
            const msgElement = chatMessagesRider?.querySelector(`[data-message-id="${tempId}"]`);
            if (msgElement) { msgElement.style.opacity = '0.5'; msgElement.title = "Échec."; }
            handleAuthError(error);
        } finally { if(sendMessageBtnRider) sendMessageBtnRider.disabled = false; }
    };

    // Pré-remplit le message pour la demande de modification
    const requestOrderModification = () => {
         if(!messageInputRider) return;
         const prefix = "Demande de modification : ";
         const detailedMessage = prefix + "Veuillez préciser ici l'erreur (client, adresse, articles, montant...).";
         messageInputRider.value = detailedMessage;
         messageInputRider.focus();

         if (messageInputRider.setSelectionRange) {
             const startPos = prefix.length;
             messageInputRider.setSelectionRange(startPos, startPos);
         }
         showNotification("Précisez la modification et cliquez sur Envoyer.", 'info');
     };

    // --- NOUVELLES FONCTIONS DE FLUX ---

    /**
     * Confirme que le livreur a récupéré le colis.
     * @param {string} orderId
     */
    const confirmPickup = async (orderId) => {
        const headers = getAuthHeader(); if(!headers) return;
        const button = ordersContainer.querySelector(`[data-order-id="${orderId}"][data-action="pickup"]`);
        
        if (button) {
            button.disabled = true;
            button.innerHTML = `<i class="bi bi-check-lg me-2"></i> Confirmation...`;
        }
        
        try {
            // NOUVEL APPEL API
            await axios.put(`${API_BASE_URL}/rider/orders/${orderId}/confirm-pickup-rider`, {}, { headers });
            showNotification(`Colis #${orderId} confirmé récupéré ! Vous pouvez démarrer la course.`, 'success');
            
            const activeTabRefresh = document.querySelector('.nav-link.active')?.dataset.tab || 'today';
            fetchOrders(activeTabRefresh);

        } catch (error) {
            showNotification(error.response?.data?.message || 'Échec de la confirmation de récupération.', 'danger');
            if (button) {
                 button.disabled = false;
                 button.innerHTML = `<i class="bi bi-box-arrow-in-down me-2"></i> Confirmer Récupération Colis`;
            }
            handleAuthError(error);
        }
    };
    
    /**
     * Démarre la course (change le statut à en_route).
     * @param {string} orderId
     */
    const startDelivery = async (orderId) => {
        const headers = getAuthHeader(); if(!headers) return;
        const button = ordersContainer.querySelector(`[data-order-id="${orderId}"][data-action="start"]`);
        
        if (button) {
            button.disabled = true;
            button.innerHTML = `<i class="bi bi-play-fill me-2"></i> Démarrage...`;
        }

        try {
            // NOUVEL APPEL API
            await axios.put(`${API_BASE_URL}/rider/orders/${orderId}/start-delivery`, {}, { headers });
            showNotification(`Course #${orderId} démarrée !`, 'success');
            
            const activeTabRefresh = document.querySelector('.nav-link.active')?.dataset.tab || 'today';
            fetchOrders(activeTabRefresh);

        } catch (error) {
            showNotification(error.response?.data?.message || 'Échec du démarrage de la course.', 'danger');
            if (button) {
                 button.disabled = false;
                 button.innerHTML = `<i class="bi bi-play-circle me-2"></i> Démarrer Course`;
            }
            handleAuthError(error);
        }
    };


    // --- Logique Principale et Initialisation ---

    // Initialisation (modifiée pour WebSocket)
    const checkAuthAndInit = () => {
        currentUser = AuthManager.getUser();
        if (!currentUser || !currentUser.token || currentUser.role !== 'livreur') {
            console.error("Rider Auth échouée ou rôle incorrect. Redirection...");
            AuthManager.logout();
            return;
        }
        axios.defaults.headers.common['Authorization'] = `Bearer ${currentUser.token}`;
        if (document.getElementById('riderName')) document.getElementById('riderName').textContent = currentUser.name || 'Livreur';
        if (document.getElementById('riderRole')) document.getElementById('riderRole').textContent = 'Livreur';

        initWebSocket();
    };

    // Met à jour les compteurs (appelé par WebSocket ou au chargement)
    const updateSidebarCounters = async () => {
        const headers = getAuthHeader(); if(!headers) return;
        try {
            const [countsResponse, unreadResponse] = await Promise.all([
                 axios.get(`${API_BASE_URL}/rider/counts`, { headers }),
                 axios.get(`${API_BASE_URL}/suivis/unread-count`, { headers }) 
            ]);

            const counts = countsResponse.data || {};
            const unreadMsgCount = unreadResponse.data.unreadCount || 0;

            const totalToday = (counts.pending || 0) + (counts.in_progress || 0) + (counts.reported || 0) + (counts.ready_for_pickup || 0) + (counts.en_route || 0);

            // Mise à jour badges sidebar
            if(document.getElementById('todayCount')) document.getElementById('todayCount').textContent = totalToday;
            // MISE À JOUR: Compteur Retours (return_declared + returned)
            const totalReturns = (counts.return_declared || 0) + (counts.returned || 0) + (counts.return_pending || 0);
            if(document.getElementById('returnsCount')) document.getElementById('returnsCount').textContent = totalReturns;
            
            const totalMyRides = (counts.delivered || 0) + (counts.failed_delivery || 0) + (counts.cancelled || 0) + (counts.returned || 0) + totalToday + (counts.return_pending || 0);
            if(document.getElementById('myRidesCount')) document.getElementById('myRidesCount').textContent = totalMyRides;
            if(document.getElementById('relaunchCount')) document.getElementById('relaunchCount').textContent = counts.reported || 0;
            
            const totalGlobalBadgeCount = unreadMsgCount;
             if (globalNotificationBadge) {
                 globalNotificationBadge.textContent = totalGlobalBadgeCount;
                 globalNotificationBadge.classList.toggle('d-none', totalGlobalBadgeCount === 0);
             }

        } catch (error) {
            console.error('Erreur compteurs:', error);
            handleAuthError(error); 
        }
     };

    // Récupère et affiche les commandes (MODIFIÉ POUR FILTRAGE RETOURS)
    const fetchOrders = async (tabName, searchQuery = '') => {
        const headers = getAuthHeader(); if(!headers) return;
        const params = {}; const today = moment().format('YYYY-MM-DD');
        switch (tabName) {
            // Inclure ready_for_pickup et en_route dans "Aujourd'hui"
            case 'today': params.status = ['pending', 'in_progress', 'ready_for_pickup', 'en_route', 'reported']; params.startDate = today; params.endDate = today; break;
            case 'my-rides': 
                params.status = 'all'; 
                if(startDateFilter?.value) params.startDate = startDateFilter.value; 
                if(endDateFilter?.value) params.endDate = endDateFilter.value; 
                break;
            case 'relaunch': 
                params.status = 'reported'; 
                const oneWeekAgo = moment().subtract(7, 'days').format('YYYY-MM-DD'); 
                params.startDate = oneWeekAgo; params.endDate = today; 
                break;
            case 'returns': 
                // --- FILTRES DEMANDÉS POUR L'ONGLET RETOURS ---
                params.status = ['return_declared', 'returned', 'return_pending']; 
                // Utiliser les filtres de date de la section "Mes courses" (qui s'affiche sur cet onglet)
                const sDate = startDateFilter?.value;
                const eDate = endDateFilter?.value;

                if(sDate && eDate) {
                    params.startDate = sDate; 
                    params.endDate = eDate; 
                } else {
                    // Période par défaut pour l'onglet Retours si pas de filtre saisi
                    params.endDate = today; 
                    params.startDate = moment().subtract(30, 'days').format('YYYY-MM-DD');
                }
                // --- FIN MISE À JOUR RETOURS ---
                break; 
            default: params.status = 'all';
        }
        if (searchQuery) { params.search = searchQuery; }

        params.include_unread_count = true; 

        if (!ordersContainer) return;

        try {
            if(!ordersContainer.querySelector('.order-card')) {
                 ordersContainer.innerHTML = `<p class="text-center text-muted mt-5"><div class="spinner-border spinner-border-sm"></div> Chargement...</p>`;
            }
            const response = await axios.get(`${API_BASE_URL}/rider/orders`, { params, headers });
            renderOrders(response.data || []); 

        } catch (error) {
            console.error("Erreur récupération commandes:", error);
            if(ordersContainer) ordersContainer.innerHTML = `<p class="text-center text-danger mt-5">Erreur chargement. Vérifiez connexion.</p>`;
            handleAuthError(error);
        }
    };

    // Change l'onglet affiché (MODIFIÉ POUR LES FILTRES DE DATE SUR L'ONGLET RETOURS)
    const fetchAndRenderContent = (tabName) => {
        const offcanvasElement = document.getElementById('sidebar');
        const offcanvas = offcanvasElement ? bootstrap.Offcanvas.getInstance(offcanvasElement) || new bootstrap.Offcanvas(offcanvasElement) : null;
        if(offcanvas) offcanvas.hide();

        // Gérer affichage filtres date : Afficher pour Mes Courses et Retours
        if (tabName === 'my-rides' || tabName === 'returns') { 
            dateFilters?.classList.add('d-flex'); 
            dateFilters?.classList.remove('d-none'); 
        }
        else { 
            dateFilters?.classList.remove('d-flex'); 
            dateFilters?.classList.add('d-none'); 
        }

        fetchOrders(tabName, searchInput.value); 
        navLinks.forEach(link => link.classList.remove('active'));
        document.querySelector(`.nav-link[data-tab="${tabName}"]`)?.classList.add('active');
    };

    // Met à jour le statut (inchangé pour l'API, mais gestion offline améliorée)
    const updateOrderStatus = async (orderIdsInput, status, paymentStatus = null, amountReceived = 0) => {
        const headers = getAuthHeader(); if(!headers) return;
        const currentUser = AuthManager.getUser(); if(!currentUser) return;
        const payload = { status, userId: currentUser.id };
        if (paymentStatus) payload.payment_status = paymentStatus;
        if (status === 'failed_delivery') { payload.amount_received = parseFloat(amountReceived) || 0; }
        const url = `${API_BASE_URL}/orders/${orderIdsInput}/status`;

        try {
            if (!navigator.onLine) throw new Error("Offline"); 
            await axios.put(url, payload, { headers });
            showNotification(`Statut Cde #${orderIdsInput} mis à jour !`, 'success');
            const activeTabRefresh = document.querySelector('.nav-link.active')?.dataset.tab || 'today';
            fetchOrders(activeTabRefresh);
            updateSidebarCounters();
        } catch (error) {
            if (!navigator.onLine && typeof syncManager !== 'undefined') {
                 try {
                     const request = { url, method: 'PUT', payload, token: AuthManager.getToken() };
                     await syncManager.put(request); 
                     navigator.serviceWorker.ready.then(sw => sw.sync.register('sync-failed-requests'));
                     showNotification('Mode hors ligne. MAJ statut mise en attente.', 'info');
                 } catch (dbError) {
                      console.error("Erreur mise en file d'attente:", dbError);
                      showNotification("Erreur sauvegarde hors ligne.", 'danger');
                 }
            } else { 
                 showNotification(`Erreur MAJ Cde #${orderIdsInput}.`, 'danger');
                 handleAuthError(error);
            }
        }
    };


    // --- LISTENERS ---

    // Navigation Sidebar
    navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const href = e.currentTarget.getAttribute('href');
            if (href && href !== '#') { window.location.href = href; } 
            else { const tabName = e.currentTarget.dataset.tab; fetchAndRenderContent(tabName); } 
        });
    });
    // Recherche
    searchInput?.addEventListener('input', debounce(() => {
        const activeTab = document.querySelector('.nav-link.active')?.dataset.tab;
        if (activeTab) fetchOrders(activeTab, searchInput.value);
    }));
    // Filtres date (Déclenché par le bouton "Filtrer" sur Mes Courses et Retours)
    filterDateBtn?.addEventListener('click', () => { 
        const activeTab = document.querySelector('.nav-link.active')?.dataset.tab;
        if (activeTab === 'my-rides' || activeTab === 'returns') {
             fetchOrders(activeTab, searchInput.value); 
        }
    });

    // Déconnexion (modifiée pour fermer WebSocket)
    document.getElementById('logoutBtn')?.addEventListener('click', () => {
        if (ws) { ws.close(1000, "Déconnexion manuelle"); }
        AuthManager.logout();
    });

    // Clics sur cartes commandes (modifié pour gérer join WebSocket + NOUVEAU FLUX)
    ordersContainer?.addEventListener('click', async (e) => {
        const target = e.target.closest('a, button');
        if (!target) return;
        
        const isDropdownItem = target.closest('.dropdown-item');
        if(isDropdownItem) e.preventDefault();
        
        if (target.classList.contains('disabled')) return;
        currentOrderId = target.dataset.orderId; 

        if (target.classList.contains('chat-btn')) {
            if (chatModalRider && currentOrderId) {
                 chatOrderId = currentOrderId; 
                 if(chatRiderOrderIdSpan) chatRiderOrderIdSpan.textContent = chatOrderId;
                 lastMessageTimestamp = null; 
                 joinConversation(chatOrderId);
                 loadRiderMessages(chatOrderId, null); 
                 loadRiderQuickReplies();
                 chatModalRider.show();
             }
        } else if (target.closest('.dropdown-item')?.dataset.action === 'pickup') {
             // NOUVEAU : Confirmer récupération
             if (confirm(`Confirmez-vous avoir physiquement récupéré le colis #${currentOrderId} ?`)) {
                confirmPickup(currentOrderId);
             }
        } else if (target.closest('.dropdown-item')?.dataset.action === 'start') {
             // NOUVEAU : Démarrer la course
             startDelivery(currentOrderId);
        } else if (target.classList.contains('status-btn')) {
            if(actionModalOrderIdSpan) actionModalOrderIdSpan.textContent = currentOrderId;
            if(statusActionModal) statusActionModal.show();
        } else if (target.classList.contains('return-btn')) {
            if(returnModalOrderIdSpan) returnModalOrderIdSpan.textContent = currentOrderId;
            if(returnModal) returnModal.show();
        }
    });

    // Listeners Modale Chat (modifiés pour leave WebSocket)
    if (sendMessageBtnRider) sendMessageBtnRider.addEventListener('click', sendRiderMessage);
    if (messageInputRider) messageInputRider.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendRiderMessage(); } });
    if (requestModificationBtn) requestModificationBtn.addEventListener('click', requestOrderModification);
    if (chatModalRiderEl) chatModalRiderEl.addEventListener('hidden.bs.modal', () => {
        leaveConversation(chatOrderId);
        chatOrderId = null; // Réinitialiser
    });
    if(messageInputRider) messageInputRider.addEventListener('input', () => { if(messageInputRider){ messageInputRider.rows = 1; const lines = messageInputRider.value.split('\n').length; const neededRows = Math.max(1, Math.min(lines, 4)); messageInputRider.rows = neededRows; } });

    // Listeners autres modales (status, paiement, retour)
    if(statusSelectionDiv) {
        statusSelectionDiv.addEventListener('click', (e) => {
            const button = e.target.closest('.status-action-btn'); if(!button) return; const status = button.dataset.status; if(statusActionModal) statusActionModal.hide();
            const amountInput = document.getElementById('amountReceived');

            if (status === 'delivered') { if(deliveredModalOrderIdSpan) deliveredModalOrderIdSpan.textContent = currentOrderId; if(deliveredPaymentModal) deliveredPaymentModal.show(); }
            else if (status === 'failed_delivery') { if(failedModalOrderIdSpan) failedModalOrderIdSpan.textContent = currentOrderId; if(amountInput) amountInput.value = '0'; if(failedDeliveryModal) failedDeliveryModal.show(); }
            else { updateOrderStatus(currentOrderId, status); }
        });
    }

    if(paymentCashBtn) paymentCashBtn.addEventListener('click', () => { updateOrderStatus(currentOrderId, 'delivered', 'cash'); if(deliveredPaymentModal) deliveredPaymentModal.hide(); });
    if(paymentSupplierBtn) paymentSupplierBtn.addEventListener('click', () => { updateOrderStatus(currentOrderId, 'delivered', 'paid_to_supplier'); if(deliveredPaymentModal) deliveredPaymentModal.hide(); });
    if(failedDeliveryForm) failedDeliveryForm.addEventListener('submit', (e) => { e.preventDefault(); const amount = document.getElementById('amountReceived').value; updateOrderStatus(currentOrderId, 'failed_delivery', null, amount); if(failedDeliveryModal) failedDeliveryModal.hide(); });
    if(confirmReturnBtn) {
        confirmReturnBtn.addEventListener('click', async () => {
            const orderId = returnModalOrderIdSpan.textContent;
            const headers = getAuthHeader(); 
            const returnModalInstance = bootstrap.Modal.getInstance(returnModalEl); 
            
            // NOTE: Vous pourriez ajouter un champ de commentaire dans la modale et le lire ici
            const comment = null; 

            try {
                if (!navigator.onLine) throw new Error("Offline");

                // APPEL À LA NOUVELLE ROUTE DE DÉCLARATION DE RETOUR
                await axios.post(`${API_BASE_URL}/orders/${orderId}/declare-return`, { comment }, { headers });

                showNotification(`Retour Cde #${orderId} déclaré ! En attente de réception au Hub.`, 'info');
                
                // MISE À JOUR : Rechargement de l'onglet Retours
                fetchAndRenderContent('returns'); 

            } catch (error) {
                if (!navigator.onLine && typeof syncManager !== 'undefined') {
                     try {
                        const request = { url: `${API_BASE_URL}/orders/${orderId}/declare-return`, method: 'POST', payload: { comment }, token: AuthManager.getToken() };
                        await syncManager.put(request);
                        navigator.serviceWorker.ready.then(sw => sw.sync.register('sync-failed-requests'));
                        showNotification("Offline. Déclaration mise en attente.", 'info');
                     } catch (dbError) { console.error("Erreur file d'attente retour:", dbError); showNotification("Erreur sauvegarde hors ligne.", 'danger'); }
                } else {
                    showNotification(`Erreur: ${error.response?.data?.message || error.message}`, 'danger');
                    handleAuthError(error);
                }
            } finally {
                if(returnModalInstance) returnModalInstance.hide(); 
            }
        });
    }

    // --- INITIALISATION ---
    const initializeApp = () => {
        checkAuthAndInit(); 

         document.addEventListener('visibilitychange', () => {
             if (document.visibilityState === 'visible') {
                 if (!ws || ws.readyState !== WebSocket.OPEN) {
                     console.log("WebSocket Rider: Fenêtre visible, tentative reconnexion...");
                     initWebSocket();
                 } else if (chatOrderId && chatModalRiderEl?.classList.contains('show')) {
                     const lastMsgEl = chatMessagesRider?.lastElementChild;
                     if(lastMsgEl && lastMsgEl.dataset.messageId) {
                         markMessagesAsRead(chatOrderId, lastMsgEl.dataset.messageId);
                     }
                 }
                 updateSidebarCounters();
             }
         });
    };

    if (typeof AuthManager !== 'undefined') {
         document.addEventListener('authManagerReady', initializeApp);
         if ((document.readyState === 'complete' || document.readyState === 'interactive') && typeof AuthManager.getUser === 'function' ) {
             if (!currentUser && AuthManager.getUser()) { 
                initializeApp();
             }
         }
     } else {
         console.error("AuthManager n'est pas défini. Vérifiez l'inclusion de auth.js.");
         setTimeout(() => {
             if (typeof AuthManager !== 'undefined' && AuthManager.getUser()) {
                 if(!currentUser) initializeApp();
             } else if (!currentUser) {
                 showNotification("Erreur critique d'authentification.", "danger");
             }
         }, 1500);
     }
});