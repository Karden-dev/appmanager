// public/js/preparation.js
document.addEventListener('DOMContentLoaded', () => {
    const API_BASE_URL = '/api';
    let currentUser = null;
    let deliverymenCache = []; // Cache des livreurs pour le filtre de retour

    // --- Références DOM ---
    const userNameDisplay = document.getElementById('userName');
    
    // Onglet Préparation
    const preparationContainer = document.getElementById('preparation-container');
    const loadingPrep = document.getElementById('loading-prep');
    const prepCountSpan = document.getElementById('prepCount');
    const refreshPrepBtn = document.getElementById('refreshPrepBtn');

    // Onglet Retours
    const returnsTableBody = document.getElementById('returnsTableBody');
    const returnCountSpan = document.getElementById('returnCount');
    const returnFiltersForm = document.getElementById('returnFiltersForm');
    const returnDeliverymanFilter = document.getElementById('returnDeliverymanFilter');
    const returnStartDateInput = document.getElementById('returnStartDate');
    const returnEndDateInput = document.getElementById('returnEndDate');

    // Modale Édition Articles
    const editItemsModalEl = document.getElementById('editItemsModal');
    const editItemsModal = editItemsModalEl ? new bootstrap.Modal(editItemsModalEl) : null;
    const editItemsForm = document.getElementById('editItemsForm');
    const editItemsOrderIdSpan = document.getElementById('editItemsOrderId');
    const editItemsOrderIdHidden = document.getElementById('editItems_OrderId_Hidden');
    const modalItemsContainer = document.getElementById('modalItemsContainer');
    const modalAddItemBtn = document.getElementById('modalAddItemBtn');
    const modalDeliveryFeeInput = document.getElementById('modalDeliveryFee');
    const modalExpeditionFeeInput = document.getElementById('modalExpeditionFee');
    const saveItemsAndMarkReadyBtn = document.getElementById('saveItemsAndMarkReadyBtn');
    
    // --- Constantes ---
    const statusReturnTranslations = {
        'pending_return_to_hub': 'En attente Hub',
        'received_at_hub': 'Confirmé Hub',
    };
    
    // --- Fonctions Utilitaires ---
    const showNotification = (message, type = 'success') => {
        const container = document.getElementById('notification-container');
        if (!container) return;
        const alertId = `notif-${Date.now()}`;
        const alert = document.createElement('div');
        alert.id = alertId;
        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.role = 'alert';
        alert.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;
        container.appendChild(alert);
        setTimeout(() => {
            const activeAlert = document.getElementById(alertId);
            if(activeAlert) { try { bootstrap.Alert.getOrCreateInstance(activeAlert)?.close(); } catch (e) { activeAlert.remove(); } }
        }, 5000);
    };

    const getAuthHeader = () => {
        if (typeof AuthManager === 'undefined' || !AuthManager.getToken) { return null; }
        const token = AuthManager.getToken();
        if (!token) { AuthManager.logout(); return null; }
        return { 'Authorization': `Bearer ${token}` };
    };
    
    const showLoadingState = (element, isLoading) => {
        if (!element) return;

        if (element.tagName === 'TBODY') {
            element.innerHTML = isLoading ? `<tr><td colspan="7" class="text-center p-3"><div class="spinner-border spinner-border-sm"></div></td></tr>` : '';
        } else if (element.tagName === 'DIV' && element.id !== 'preparation-container') {
            element.style.display = isLoading ? 'block' : 'none';
        }
        
        // Gérer le cas du conteneur de cartes (préparation)
        if (element.id === 'preparation-container') {
             if (isLoading) {
                 element.innerHTML = `<div id="loading-prep" class="text-center p-5"><div class="spinner-border text-primary" role="status"><span class="visually-hidden">Chargement...</span></div></div>`;
             } else if (element.querySelector('#loading-prep')) {
                 element.innerHTML = ''; // Nettoyer le spinner après le chargement
             }
        }
    };
    
    // Charger les livreurs pour le filtre des retours
    const fetchDeliverymen = async () => {
        const headers = getAuthHeader();
        if (!headers) return;
        try {
            // Récupère TOUS les livreurs (actifs et inactifs) pour l'historique
            const res = await axios.get(`${API_BASE_URL}/deliverymen?status=all`, { headers }); 
            deliverymenCache = res.data;
            renderDeliverymanFilterOptions();
        } catch (error) {
            console.error("Erreur chargement livreurs:", error);
        }
    };
    
    const renderDeliverymanFilterOptions = () => {
        if(!returnDeliverymanFilter) return;
        returnDeliverymanFilter.innerHTML = '<option value="">Tous les livreurs</option>';
        deliverymenCache.forEach(dm => {
            const option = document.createElement('option');
            option.value = dm.id;
            option.textContent = dm.name;
            returnDeliverymanFilter.appendChild(option);
        });
    };
    
    const formatAmount = (amount) => `${Number(amount || 0).toLocaleString('fr-FR')} FCFA`;

    // --- Fonctions PRINCIPALES ---

    // --- PRÉPARATION (Onglet 1) ---

    /**
     * Récupère les commandes en attente de préparation ou déjà prêtes.
     */
    const fetchOrdersToPrepare = async () => {
        showLoadingState(preparationContainer, true);

        const headers = getAuthHeader();
        if (!headers) { showNotification("Erreur d'authentification.", "danger"); showLoadingState(loadingPrep, false); return; }

        try {
            // Appel à la route (inclut in_progress ET ready_for_pickup)
            const response = await axios.get(`${API_BASE_URL}/orders/pending-preparation`, { headers });
            const orders = response.data || [];
            renderOrders(orders);
            if(prepCountSpan) prepCountSpan.textContent = orders.length;
        } catch (error) {
            console.error("Erreur fetchOrdersToPrepare:", error);
            showNotification("Erreur lors du chargement des commandes à préparer.", "danger");
             if (error.response?.status === 401 || error.response?.status === 403) AuthManager.logout();
        } 
    };

    /**
     * Affiche les commandes groupées par livreur.
     */
    const renderOrders = (orders) => {
        if (!preparationContainer) return;
        preparationContainer.innerHTML = ''; // Vider le conteneur

        const groupedByDeliveryman = orders.reduce((acc, order) => {
            const deliverymanId = order.deliveryman_id || 0; 
            const deliverymanName = order.deliveryman_name || 'Non Assigné';
            if (!acc[deliverymanId]) {
                acc[deliverymanId] = { name: deliverymanName, orders: [] };
            }
            acc[deliverymanId].orders.push(order);
            return acc;
        }, {});

        const sortedGroupIds = Object.keys(groupedByDeliveryman).sort((a, b) => {
             if (a === '0') return -1; 
             if (b === '0') return 1;
             return groupedByDeliveryman[a].name.localeCompare(groupedByDeliveryman[b].name);
        });

        if (sortedGroupIds.length === 0) {
             preparationContainer.innerHTML = '<div class="alert alert-secondary text-center">Aucune commande en attente de préparation ou prête.</div>';
             return;
        }

        sortedGroupIds.forEach(deliverymanId => {
            const group = groupedByDeliveryman[deliverymanId];
            const groupDiv = document.createElement('div');
            groupDiv.className = 'deliveryman-group';

            const headerDiv = document.createElement('div');
            headerDiv.className = 'deliveryman-header';
            headerDiv.innerHTML = `<i class="bi bi-person-fill me-2"></i>${group.name} (${group.orders.length} colis) <span class="badge bg-light text-dark">${group.orders.filter(o => o.status === 'ready_for_pickup').length} Prêts</span>`;
            groupDiv.appendChild(headerDiv);

            const gridDiv = document.createElement('div');
            gridDiv.className = 'orders-grid';

            group.orders.sort((a, b) => {
                 if (a.status === 'in_progress' && b.status === 'ready_for_pickup') return -1;
                 if (a.status === 'ready_for_pickup' && b.status === 'in_progress') return 1;
                 return moment(a.created_at).diff(moment(b.created_at));
            });

            group.orders.forEach(order => {
                const isReady = order.status === 'ready_for_pickup';
                const isPickedUp = !!order.picked_up_by_rider_at; 
                const card = document.createElement('div');
                card.className = `order-card-prep ${isReady ? 'is-ready' : ''}`;
                card.dataset.orderId = order.id; 
                card.dataset.orderData = JSON.stringify(order); // Stocker les données complètes pour la modale

                const itemsListHtml = (order.items && order.items.length > 0)
                    ? `<ul class="items-list list-unstyled">${order.items.map(item => `<li>- ${item.quantity} x ${item.item_name || 'Article inconnu'}</li>`).join('')}</ul>`
                    : '<p class="text-muted small">Aucun article détaillé.</p>';
                    
                const pickupStatus = isReady 
                    ? (isPickedUp 
                        ? `<span class="badge bg-success small"><i class="bi bi-check-circle me-1"></i> Récupéré: ${moment(order.picked_up_by_rider_at).format('HH:mm')}</span>`
                        : `<span class="badge bg-warning text-dark small"><i class="bi bi-x-circle me-1"></i> Non Récupéré</span>`)
                    : '';
                    
                const readyBadge = isReady
                    ? `<span class="badge bg-info text-white"><i class="bi bi-check-lg"></i> Prêt</span>`
                    : `<span class="badge bg-secondary"><i class="bi bi-clock"></i> À préparer</span>`;

                card.innerHTML = `
                    <div class="order-id">
                        #${order.id}
                        ${readyBadge}
                    </div>
                    <div class="shop-name"><i class="bi bi-shop me-1"></i> ${order.shop_name || 'Marchand inconnu'}</div>
                    <div class="customer-info"><i class="bi bi-telephone me-1"></i> ${order.customer_phone || 'Tél inconnu'}</div>
                    <div class="customer-info"><i class="bi bi-geo-alt me-1"></i> ${order.delivery_location || 'Lieu inconnu'}</div>
                    <div class="customer-info">${pickupStatus}</div> 
                    <h6>Articles :</h6>
                    ${itemsListHtml}
                    <button class="btn btn-sm btn-outline-secondary btn-edit-items mb-2" data-order-id="${order.id}">
                        <i class="bi bi-pencil me-1"></i> Vérifier Articles
                    </button>
                `;
                gridDiv.appendChild(card);
            });

            groupDiv.appendChild(gridDiv);
            preparationContainer.appendChild(groupDiv);
        });

        attachButtonListeners();
    };

    /**
     * Ouvre la modale d'édition des articles d'une commande.
     */
    const openEditItemsModal = (orderData) => {
        if (!editItemsModal || !orderData) return;
        
        editItemsOrderIdSpan.textContent = orderData.id;
        editItemsOrderIdHidden.value = orderData.id;
        modalDeliveryFeeInput.value = orderData.delivery_fee || 0;
        modalExpeditionFeeInput.value = orderData.expedition_fee || 0;

        modalItemsContainer.innerHTML = '';
        if (orderData.items && orderData.items.length > 0) {
            orderData.items.forEach(item => addItemRowModal(modalItemsContainer, item));
        } else {
            addItemRowModal(modalItemsContainer); // Ajouter une ligne vide
        }
        
        // Gérer le texte du bouton : si déjà prêt, le bouton doit être "Sauvegarder les modifications"
        const isReady = orderData.status === 'ready_for_pickup';
        saveItemsAndMarkReadyBtn.innerHTML = isReady 
            ? '<i class="bi bi-save me-1"></i> Sauvegarder Articles' 
            : '<i class="bi bi-check-lg me-1"></i> Sauvegarder et Marquer Prête';
            
        editItemsModal.show();
    };

    // Ajout/Suppression de lignes dans la modale
    const addItemRowModal = (container, item = {}) => {
        const itemRow = document.createElement('div');
        itemRow.className = 'row g-2 item-row-modal mb-2';
        const isFirst = container.children.length === 0;
        
        itemRow.innerHTML = `
            <div class="col-md-5">
                <label class="form-label mb-1 ${!isFirst ? 'visually-hidden' : ''}">Nom article</label>
                <input type="text" class="form-control form-control-sm item-name-input" value="${item.item_name || ''}" placeholder="Article" required>
                <input type="hidden" class="item-id-input" value="${item.id || ''}"> 
            </div>
            <div class="col-md-3">
                <label class="form-label mb-1 ${!isFirst ? 'visually-hidden' : ''}">Qté</label>
                <input type="number" class="form-control form-control-sm item-quantity-input" value="${item.quantity || 1}" min="1" required>
            </div>
            <div class="col-md-4">
                <label class="form-label mb-1 ${!isFirst ? 'visually-hidden' : ''}">Montant (Total Ligne)</label>
                <div class="input-group input-group-sm">
                    <input type="number" class="form-control item-amount-input" value="${item.amount || 0}" min="0" required>
                    <button class="btn btn-outline-danger remove-item-btn-modal" type="button"><i class="bi bi-trash"></i></button>
                </div>
            </div>`;
        container.appendChild(itemRow);
        
         if (container.children.length > 1) {
             itemRow.querySelectorAll('label').forEach(label => label.classList.add('visually-hidden'));
         } else {
             itemRow.querySelectorAll('label').forEach(label => label.classList.remove('visually-hidden'));
         }
    };


    /**
     * Gère la soumission du formulaire d'édition d'articles (Sauvegarde + Marque Prête).
     */
    const handleEditItemsSubmit = async (event) => {
        event.preventDefault();
        const headers = getAuthHeader();
        if (!headers) return;
        
        const orderId = editItemsOrderIdHidden.value;
        const button = saveItemsAndMarkReadyBtn;

        button.disabled = true;
        button.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Sauvegarde...';
        
        const items = Array.from(modalItemsContainer.querySelectorAll('.item-row-modal')).map(row => ({
            // id: row.querySelector('.item-id-input').value || null, // L'ID de l'item n'est pas nécessaire pour update (on supprime et recrée)
            item_name: row.querySelector('.item-name-input').value,
            quantity: parseInt(row.querySelector('.item-quantity-input').value),
            amount: parseFloat(row.querySelector('.item-amount-input').value)
        }));

        if (items.some(item => !item.item_name || item.quantity <= 0)) {
            showNotification("Veuillez vérifier que tous les articles ont un nom et une quantité valide.", "warning");
            button.disabled = false;
            button.innerHTML = button.innerHTML.includes('Sauvegarder') ? '<i class="bi bi-save me-1"></i> Sauvegarder Articles' : '<i class="bi bi-check-lg me-1"></i> Sauvegarder et Marquer Prête';
            return;
        }

        const totalArticleAmount = items.reduce((sum, item) => sum + item.amount, 0);

        const updateData = {
            items: items,
            article_amount: totalArticleAmount, // Mettre à jour le montant total
            delivery_fee: parseFloat(modalDeliveryFeeInput.value) || 0,
            expedition_fee: parseFloat(modalExpeditionFeeInput.value) || 0,
        };

        try {
            // 1. Mettre à jour la commande (items et frais) via la route PUT /orders/:id
            await axios.put(`${API_BASE_URL}/orders/${orderId}`, updateData, { headers });
            
            // 2. Marquer comme prête
            await axios.put(`${API_BASE_URL}/orders/${orderId}/ready`, {}, { headers });
            
            showNotification(`Commande #${orderId} modifiée et marquée comme prête !`, 'success');
            
            editItemsModal.hide();
            fetchOrdersToPrepare(); // Rafraîchir la liste
            
        } catch (error) {
            console.error(`Erreur sauvegarde articles Cde ${orderId}:`, error);
            showNotification(error.response?.data?.message || `Erreur lors de la sauvegarde.`, 'danger');
            if (error.response?.status === 401 || error.response?.status === 403) AuthManager.logout();
        } finally {
             button.disabled = false;
             // Rétablir le texte original du bouton
             button.innerHTML = button.innerHTML.includes('Sauvegarde') 
                 ? '<i class="bi bi-save me-1"></i> Sauvegarder Articles' 
                 : '<i class="bi bi-check-lg me-1"></i> Sauvegarder et Marquer Prête';
        }
    };


    // --- RETOURS (Onglet 2) ---

    /**
     * Récupère la liste des retours en attente de gestion (Admin).
     */
    const fetchPendingReturns = async () => {
        showLoadingState(returnsTableBody, true);
        
        const headers = getAuthHeader();
        if (!headers) { showLoadingState(returnsTableBody, false); return; }
        
        const filters = {
            status: document.getElementById('returnStatusFilter').value,
            deliverymanId: returnDeliverymanFilter.value,
            startDate: returnStartDateInput.value,
            endDate: returnEndDateInput.value
        };

        try {
            const response = await axios.get(`${API_BASE_URL}/returns/pending-hub`, { params: filters, headers });
            const returns = response.data || [];
            renderReturnsTable(returns);
            // Compter uniquement les retours en attente de confirmation pour le badge
            if(returnCountSpan) returnCountSpan.textContent = returns.filter(r => r.return_status === 'pending_return_to_hub').length;
        } catch (error) {
            console.error("Erreur fetchPendingReturns:", error);
            returnsTableBody.innerHTML = `<tr><td colspan="7" class="text-center text-danger p-3">Erreur lors du chargement des retours.</td></tr>`;
             if (error.response?.status === 401 || error.response?.status === 403) AuthManager.logout();
        }
    };

    /**
     * Affiche les retours dans le tableau.
     */
    const renderReturnsTable = (returns) => {
        if (!returnsTableBody) return;
        returnsTableBody.innerHTML = '';
        
        if (returns.length === 0) {
             returnsTableBody.innerHTML = `<tr><td colspan="7" class="text-center p-3">Aucun retour trouvé pour ces filtres.</td></tr>`;
             return;
        }

        returns.forEach(returnItem => {
            const isConfirmed = returnItem.return_status === 'received_at_hub';
            const row = document.createElement('tr');
            
            const statusText = statusReturnTranslations[returnItem.return_status] || returnItem.return_status;
            const statusClass = isConfirmed ? 'badge bg-success' : 'badge bg-warning text-dark';
            
            const actionsHtml = isConfirmed
                ? `<span class="badge bg-success"><i class="bi bi-check-circle-fill me-1"></i> Confirmé</span>`
                : `<button class="btn btn-sm btn-danger btn-confirm-return" data-tracking-id="${returnItem.tracking_id}"><i class="bi bi-box-arrow-in-down me-1"></i> Confirmer Réception</button>`;
                
            const commentTooltip = returnItem.comment ? `title="${returnItem.comment}"` : `title="Aucun commentaire"`;

            row.innerHTML = `
                <td>${returnItem.tracking_id}</td>
                <td><a href="orders.html?search=#${returnItem.order_id}" target="_blank">#${returnItem.order_id}</a></td>
                <td>${returnItem.deliveryman_name}</td>
                <td>${returnItem.shop_name}</td>
                <td>${moment(returnItem.declaration_date).format('DD/MM HH:mm')}</td>
                <td><span class="${statusClass}">${statusText}</span></td>
                <td>
                    ${actionsHtml}
                    <i class="bi bi-chat-left-text text-muted ms-2" data-bs-toggle="tooltip" data-bs-placement="top" ${commentTooltip}></i>
                </td>
            `;
            returnsTableBody.appendChild(row);
        });
        
         const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
         tooltipTriggerList.forEach(function(tooltipTriggerEl) {
              const existingTooltip = bootstrap.Tooltip.getInstance(tooltipTriggerEl);
              if (existingTooltip) existingTooltip.dispose();
              new bootstrap.Tooltip(tooltipTriggerEl);
         });
         
         attachButtonListeners();
    };

    /**
     * Gère la confirmation de réception d'un retour au Hub (Admin).
     */
    const handleConfirmHubReception = async (event) => {
        const button = event.currentTarget;
        const trackingId = button.dataset.trackingId;
        if (!trackingId || !confirm(`Confirmer la réception physique du retour #${trackingId} ?\nCeci marquera la commande comme "Retournée".`)) return;
        
        button.disabled = true;
        button.innerHTML = '<span class="spinner-border spinner-border-sm"></span> ...';

        const headers = getAuthHeader();
        if (!headers) { button.disabled = false; return; }
        
        try {
            await axios.put(`${API_BASE_URL}/returns/${trackingId}/confirm-hub`, {}, { headers });
            showNotification(`Retour #${trackingId} confirmé avec succès.`, 'success');
            fetchPendingReturns(); 
        } catch (error) {
            console.error(`Erreur confirmation retour ${trackingId}:`, error);
            showNotification(error.response?.data?.message || `Erreur lors de la confirmation.`, 'danger');
            button.disabled = false; 
            button.innerHTML = '<i class="bi bi-box-arrow-in-down me-1"></i> Confirmer Réception';
             if (error.response?.status === 401 || error.response?.status === 403) AuthManager.logout();
        }
    };

    // --- Attachement des Listeners ---
    
    function attachButtonListeners() {
         // Préparation
         preparationContainer.querySelectorAll('.btn-edit-items, .btn-ready').forEach(button => {
            button.removeEventListener('click', openEditItemsModalFromButton);
            // Si le bouton est "Déjà Prêt", il ouvre quand même la modale pour édition
            button.addEventListener('click', openEditItemsModalFromButton);
         });

         // Retours
         returnsTableBody.querySelectorAll('.btn-confirm-return').forEach(button => {
             button.removeEventListener('click', handleConfirmHubReception);
             if (!button.disabled) {
                 button.addEventListener('click', handleConfirmHubReception);
             }
         });
    }

    // Fonction intermédiaire pour ouvrir la modale depuis les boutons
    function openEditItemsModalFromButton(event) {
        const button = event.currentTarget;
        const card = button.closest('.order-card-prep');
        if (card && card.dataset.orderData) {
            try {
                const orderData = JSON.parse(card.dataset.orderData);
                openEditItemsModal(orderData);
            } catch (e) {
                console.error("Impossible de parser les données de la commande :", e);
                showNotification("Erreur de données de la commande.", "danger");
            }
        }
    }

    // --- Initialisation et Listeners ---
    const initializeApp = async () => {
         if (typeof AuthManager === 'undefined' || !AuthManager.getUser) {
             showNotification("Erreur critique d'initialisation.", "danger"); return;
         }
        currentUser = AuthManager.getUser();
        if (!currentUser) return; 

        if (userNameDisplay) userNameDisplay.textContent = currentUser.name;

        // Définir la date du jour par défaut pour les filtres de retour
        const today = moment().format('YYYY-MM-DD');
        if(returnStartDateInput) returnStartDateInput.value = today;
        if(returnEndDateInput) returnEndDateInput.value = today;

        await fetchDeliverymen(); 

        // Listeners pour la section PRÉPARATION
        refreshPrepBtn?.addEventListener('click', fetchOrdersToPrepare);
        
        // Listeners pour la section RETOURS
        returnFiltersForm?.addEventListener('submit', (e) => {
             e.preventDefault();
             fetchPendingReturns();
        });
        
        // Listeners pour la MODALE D'ÉDITION D'ARTICLES
        modalAddItemBtn?.addEventListener('click', () => addItemRowModal(modalItemsContainer));
        modalItemsContainer?.addEventListener('click', (e) => {
             if (e.target.closest('.remove-item-btn-modal')) {
                 if (modalItemsContainer.children.length > 1) {
                     e.target.closest('.item-row-modal').remove();
                     if (modalItemsContainer.children.length === 1) {
                         modalItemsContainer.children[0].querySelectorAll('label').forEach(label => label.classList.remove('visually-hidden'));
                     }
                 } else {
                     showNotification("Vous devez avoir au moins un article.", "warning");
                 }
             }
        });
        editItemsForm?.addEventListener('submit', handleEditItemsSubmit);

        // Charger les deux sections au démarrage
        fetchOrdersToPrepare();
        fetchPendingReturns();

        // Listeners Globaux (Logout)
        document.getElementById('logoutBtn')?.addEventListener('click', () => AuthManager.logout());
        
        // Gérer l'affichage des onglets (pour le rafraîchissement des données)
        document.querySelectorAll('button[data-bs-toggle="tab"]').forEach(tabEl => {
            tabEl.addEventListener('shown.bs.tab', event => {
                const targetId = event.target.getAttribute('data-bs-target');
                if (targetId === '#preparation-panel') {
                    fetchOrdersToPrepare(); // Rafraîchir les préparations
                } else if (targetId === '#returns-panel') {
                    fetchPendingReturns(); // Rafraîchir les retours
                }
            });
        });
    };

     if (typeof AuthManager !== 'undefined' && AuthManager.getToken()) {
         initializeApp();
     } else {
         document.addEventListener('authManagerReady', initializeApp);
         setTimeout(() => { if (!currentUser && typeof AuthManager !== 'undefined' && AuthManager.getUser()) initializeApp(); else if (!currentUser) console.error("AuthManager toujours pas prêt."); }, 1000);
     }
});