// js/remittances.js

document.addEventListener('DOMContentLoaded', () => {
    // --- CONFIGURATION ---
  const API_BASE_URL = 'http://localhost:3000';    
    // Simulation de la récupération de l'utilisateur connecté
    const storedUser = localStorage.getItem('user') || sessionStorage.getItem('user');
    const user = storedUser ? JSON.parse(storedUser) : { id: 1, name: 'Admin Test', token: 'mock-token' };
    const CURRENT_USER_ID = user.id;
    
    // Configuration d'axios
    if (user.token) {
        axios.defaults.headers.common['Authorization'] = `Bearer ${user.token}`;
    }

    // --- CACHES & ÉTAT ---
    let allRemittances = [];
    let filteredRemittances = [];
    let currentPage = 1;
    let itemsPerPage = 25;
    
    // --- RÉFÉRENCES DOM ---
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const logoutBtn = document.getElementById('logoutBtn');
    
    const remittanceTableBody = document.getElementById('remittanceTableBody');
    const searchInput = document.getElementById('searchInput');
    const remittanceDateInput = document.getElementById('remittanceDate');
    const statusFilter = document.getElementById('statusFilter');
    const resyncBtn = document.getElementById('resyncBtn'); 
    
    // Éléments de pagination et de stats
    const itemsPerPageSelect = document.getElementById('itemsPerPage');
    const paginationInfo = document.getElementById('paginationInfo');
    const currentPageDisplay = document.getElementById('currentPageDisplay');
    const firstPageBtn = document.getElementById('firstPage');
    const prevPageBtn = document.getElementById('prevPage');
    const nextPageBtn = document.getElementById('nextPage');
    const lastPageBtn = document.getElementById('lastPage');
    const bulkPayBtn = document.getElementById('bulkPayBtn');
    
    // Références Modales
    const editPaymentModal = new bootstrap.Modal(document.getElementById('editPaymentModal'));
    const payConfirmModal = new bootstrap.Modal(document.getElementById('payConfirmModal'));
    const editPaymentForm = document.getElementById('editPaymentForm');
    const confirmPayBtn = document.getElementById('confirmPayBtn');
    
    // Références pour la modale de confirmation
    const confirmShopName = document.getElementById('confirmShopName');
    const confirmAmount = document.getElementById('confirmAmount');
    const payConfirmShopId = document.getElementById('payConfirmShopId');
    const payConfirmAmount = document.getElementById('payConfirmAmount');
    
    // Références pour l'édition des infos de paiement
    const editShopIdInput = document.getElementById('editShopId');
    const paymentNameInput = document.getElementById('paymentNameInput');
    const phoneNumberInput = document.getElementById('phoneNumberInput');
    const paymentOperatorSelect = document.getElementById('paymentOperatorSelect');
    
    // Références pour les stats
    const orangeMoneyTotal = document.getElementById('orangeMoneyTotal');
    const orangeMoneyTransactions = document.getElementById('orangeMoneyTransactions');
    const mtnMoneyTotal = document.getElementById('mtnMoneyTotal');
    const mtnMoneyTransactions = document.getElementById('mtnMoneyTransactions');
    const totalRemittanceAmount = document.getElementById('totalRemittanceAmount');
    const totalTransactions = document.getElementById('totalTransactions');
    
    // --- TRADUCTIONS ET COULEURS ---
    const statusTranslations = { 'pending': 'En attente', 'paid': 'Payé' };
    const statusColors = { 'pending': 'status-pending', 'paid': 'status-paid' };
    const paymentOperatorsColors = {
        'Orange Money': 'bg-orange-money-dot',
        'MTN Mobile Money': 'bg-mtn-money-dot'
    };

    // Mise à jour de l'UI avec le nom de l'utilisateur
    if (document.getElementById('userName')) document.getElementById('userName').textContent = user.name;
    if (document.getElementById('headerUserName')) document.getElementById('headerUserName').textContent = user.name;

    // --- FONCTIONS UTILITAIRES ---
    
    /**
     * Affiche une notification toast stylisée.
     * @param {string} message - Le message à afficher.
     * @param {string} [type='success'] - Le type d'alerte (success, danger, warning, info).
     */
    const showNotification = (message, type = 'success') => {
        const container = document.getElementById('notification-container');
        if (!container) return;
        const alert = document.createElement('div');
        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert"></button>`;
        container.appendChild(alert);
        setTimeout(() => {
            const bsAlert = bootstrap.Alert.getOrCreateInstance(alert);
            bsAlert.close();
        }, 4000); 
    };

    /**
     * Ajoute un écouteur d'événement de manière sécurisée.
     * @param {HTMLElement} element - L'élément DOM.
     * @param {string} event - Le nom de l'événement.
     * @param {Function} handler - Le gestionnaire d'événement.
     */
    const addSafeEventListener = (element, event, handler) => {
        if (element) {
            element.addEventListener(event, handler);
        }
    };
     
    /**
     * Formate un montant en FCFA.
     * @param {number|string} amount - Le montant à formater.
     * @returns {string} Le montant formaté.
     */
    const formatAmount = (amount) => {
        return parseFloat(amount || 0).toLocaleString('fr-FR') + ' FCFA';
    };
    
    /**
     * Formate un numéro de téléphone pour l'affichage (mise en gras, séparateurs).
     * @param {string} phone - Le numéro de téléphone.
     * @returns {string} Le numéro formaté.
     */
    const formatPhoneNumber = (phone) => {
        if (!phone) return 'N/A';
        const cleaned = ('' + phone).replace(/\D/g, '');
        const match = cleaned.match(/^(\d{1})(\d{2})(\d{2})(\d{2})(\d{2})$/);
        if (match) {
            return `<strong>${match[1]} ${match[2]} ${match[3]} ${match[4]} ${match[5]}</strong>`;
        }
        return `<strong>${phone}</strong>`;
    };


    // --- FONCTIONS PRINCIPALES ---
     
    /**
     * Récupère les versements (et synchronise d'abord si la date est définie).
     */
    const fetchRemittances = async () => {
        try {
            const params = {};
            const date = remittanceDateInput.value;
            
            if (!date) {
                 remittanceTableBody.innerHTML = `<tr><td colspan="9" class="text-center p-3">Veuillez sélectionner une date de bilan.</td></tr>`;
                 updateStatsCards({ orangeMoneyTotal: 0, orangeMoneyTransactions: 0, mtnMoneyTotal: 0, mtnMoneyTransactions: 0, totalAmount: 0 });
                 return;
            }
            
            // Filtres envoyés au contrôleur (synchronise la date en cours, puis filtre par statut)
            params.date = date;
            params.search = searchInput.value;
            params.status = statusFilter.value;

            // Afficher un état de chargement
            remittanceTableBody.innerHTML = `<tr><td colspan="9" class="text-center p-4"><div class="spinner-border text-primary-custom" role="status"><span class="visually-hidden">Chargement...</span></div></td></tr>`;


            const response = await axios.get(`${API_BASE_URL}/remittances`, { params });
            allRemittances = response.data.remittances;
            filteredRemittances = [...allRemittances];
            updateStatsCards(response.data.stats);
             
            currentPage = 1; 
            applyPaginationAndRender();
        } catch (error) {
            console.error("Erreur fetchRemittances:", error);
            const errorMessage = error.response?.data?.message || "Erreur de chargement.";
            remittanceTableBody.innerHTML = `<tr><td colspan="9" class="text-center text-danger">${errorMessage}</td></tr>`;
            showNotification(errorMessage, "danger");
        }
    };

    /**
     * Applique les paramètres de pagination et lance le rendu du tableau.
     */
    const applyPaginationAndRender = () => {
        const totalItems = filteredRemittances.length;
        itemsPerPage = parseInt(itemsPerPageSelect.value);

        const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
        if (currentPage > totalPages) currentPage = totalPages;
         
        const startIndex = (currentPage - 1) * itemsPerPage;
        const remittancesToRender = filteredRemittances.slice(startIndex, startIndex + itemsPerPage);
         
        renderRemittanceTable(remittancesToRender);
        updatePaginationInfo();
    };

    /**
     * Génère et affiche les lignes du tableau des versements.
     * @param {Array<Object>} remittances - Les versements à afficher.
     */
    const renderRemittanceTable = (remittances) => {
        if (!remittanceTableBody) return;
        remittanceTableBody.innerHTML = '';
         
        if (remittances.length === 0) {
            remittanceTableBody.innerHTML = `<tr><td colspan="9" class="text-center p-3">Aucun versement à afficher pour les filtres sélectionnés.</td></tr>`;
            return;
        }
         
        const startIndex = (currentPage - 1) * itemsPerPage;

        remittances.forEach((rem, index) => {
            const row = document.createElement('tr');
            const operatorColor = paymentOperatorsColors[rem.payment_operator] || 'bg-secondary';
            const statusColor = statusColors[rem.status] || 'status-pending';
            const isPayable = rem.status === 'pending' && (rem.net_amount > 0 || !rem.net_amount); // net_amount > 0 ou non encore calculé (legacy)
            
            // Colonne fusionnée : Nom Versement (Téléphone en gras)
            const remittanceInfo = `
                ${rem.payment_name || 'N/A'}
                <br>
                ${formatPhoneNumber(rem.phone_number_for_payment)}
            `;
            
            const debtsAmount = formatAmount(rem.debts_consolidated || 0);
            const grossAmount = formatAmount(rem.gross_amount || 0);
            const formattedNetAmount = formatAmount(rem.net_amount || 0);

            const remittanceId = rem.id; 

            row.innerHTML = `
                <td>${startIndex + index + 1}</td>
                <td>${rem.shop_name}</td>
                <td>${remittanceInfo}</td>
                <td>${rem.payment_operator ? `<span class="operator-dot ${operatorColor}"></span>` : ''} ${rem.payment_operator || 'N/A'}</td>
                <td class="text-success fw-bold">${grossAmount}</td>
                <td class="text-danger fw-bold">${debtsAmount}</td>
                <td class="fw-bold">${formattedNetAmount}</td>
                <td>
                    <span class="d-flex align-items-center">
                        <span class="status-dot ${statusColor}"></span>
                        ${statusTranslations[rem.status]}
                    </span>
                </td>
                <td>
                    <div class="dropdown">
                        <button class="btn btn-sm btn-secondary dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false"><i class="bi bi-gear"></i></button>
                        <ul class="dropdown-menu">
                            <li><a class="dropdown-item edit-payment-details-btn" href="#" data-shop-id="${rem.shop_id}" title="Modifier infos de paiement"><i class="bi bi-pencil"></i> Modifier infos</a></li>
                            ${isPayable ? `<li><a class="dropdown-item pay-btn" href="#" data-remittance-id="${remittanceId}" data-shop-name="${rem.shop_name}" data-amount="${rem.net_amount || rem.gross_amount}"><i class="bi bi-check-circle"></i> Effectuer le versement</a></li>` : ''}
                        </ul>
                    </div>
                </td>
            `;
            remittanceTableBody.appendChild(row);
        });
    };

    /**
     * Met à jour les cartes de statistiques en haut de page.
     * @param {Object} stats - Les données statistiques.
     */
    const updateStatsCards = (stats) => {
        if (orangeMoneyTotal) orangeMoneyTotal.textContent = formatAmount(stats.orangeMoneyTotal);
        if (orangeMoneyTransactions) orangeMoneyTransactions.textContent = `${stats.orangeMoneyTransactions} trans.`;
        if (mtnMoneyTotal) mtnMoneyTotal.textContent = formatAmount(stats.mtnMoneyTotal);
        if (mtnMoneyTransactions) mtnMoneyTransactions.textContent = `${stats.mtnMoneyTransactions} trans.`;
        
        if (totalRemittanceAmount) totalRemittanceAmount.textContent = formatAmount(stats.totalAmount); 
        
        const pendingCount = allRemittances.filter(r => r.status === 'pending').length;
        if (totalTransactions) totalTransactions.textContent = `${pendingCount} trans. en attente`;
        
        // Le paiement groupé est possible si au moins 1 versement est en attente ET le montant total est positif.
        bulkPayBtn.disabled = pendingCount === 0 || stats.totalAmount <= 0;
    };
     
    /**
     * Met à jour l'affichage des informations de pagination.
     */
    const updatePaginationInfo = () => {
        const totalItems = filteredRemittances.length;
        const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
         
        if (paginationInfo) paginationInfo.textContent = `Page ${currentPage} sur ${totalPages} (${totalItems} entrées)`;
        if (currentPageDisplay) currentPageDisplay.textContent = currentPage;
         
        firstPageBtn?.classList.toggle('disabled', currentPage === 1);
        prevPageBtn?.classList.toggle('disabled', currentPage === 1);
        nextPageBtn?.classList.toggle('disabled', currentPage >= totalPages);
        lastPageBtn?.classList.toggle('disabled', currentPage >= totalPages);
    };
     
    /**
     * Gère le changement de page dans les contrôles de pagination.
     * @param {number} newPage - Le numéro de la nouvelle page.
     */
    const handlePageChange = (newPage) => {
        const totalPages = Math.ceil(filteredRemittances.length / itemsPerPage);
        if (newPage < 1 || newPage > totalPages) return;
        currentPage = newPage;
        applyPaginationAndRender();
    };

    /**
     * Ouvre la modale de confirmation pour un versement (individuel ou groupé).
     * @param {string} mode - 'individual' ou 'bulk'.
     * @param {number} totalAmount - Le montant total à payer.
     * @param {string} shopName - Le nom du marchand ou un résumé du lot.
     * @param {number} [remittanceId=null] - L'ID du versement individuel.
     */
    const openConfirmModal = (mode, totalAmount, shopName, remittanceId = null) => {
        confirmShopName.textContent = shopName;
        confirmAmount.textContent = formatAmount(totalAmount);
        payConfirmAmount.value = totalAmount;
        payConfirmShopId.value = mode === 'individual' ? remittanceId : 'BULK_PAYMENT'; 
        payConfirmModal.show();
    };
    
    /**
     * Gère la confirmation de paiement depuis la modale (Individuel ou Groupé).
     */
    const handleConfirmPayment = async () => {
        const targetId = payConfirmShopId.value;
        const isBulk = targetId === 'BULK_PAYMENT';

        confirmPayBtn.disabled = true;
        confirmPayBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Paiement...';

        try {
            const remittancesToPay = isBulk 
                ? allRemittances.filter(rem => rem.status === 'pending' && rem.net_amount > 0)
                : allRemittances.filter(rem => rem.id == targetId && rem.status === 'pending' && rem.net_amount > 0);

            if (remittancesToPay.length === 0) {
                 throw new Error("Aucun versement en attente à traiter.");
            }

            let successCount = 0;
            for (const rem of remittancesToPay) {
                // Utilise la route /:id/pay qui appelle markAsPaid et règle les dettes
                await axios.put(`${API_BASE_URL}/remittances/${rem.id}/pay`, {
                    userId: CURRENT_USER_ID
                });
                successCount++;
            }
            
            const message = isBulk 
                ? `${successCount} versement(s) marqué(s) comme payé(s) !`
                : `Versement pour ${remittancesToPay[0].shop_name} marqué comme payé.`;
            showNotification(message, 'success');

        } catch (error) {
            showNotification(error.response?.data?.message || 'Erreur lors du changement de statut.', 'danger');
        } finally {
            payConfirmModal.hide();
            confirmPayBtn.disabled = false;
            confirmPayBtn.innerHTML = '<i class="bi bi-check-circle me-2"></i> Confirmer';
            fetchRemittances();
        }
    };

    /**
     * Gère les actions sur les lignes du tableau (Paiement, Modification des détails).
     * @param {Event} e - L'événement de clic.
     */
    const handleTableActions = async (e) => {
        const target = e.target.closest('.dropdown-item');
        if (!target) return;

        const shopId = target.dataset.shopId;
        const remittanceId = target.dataset.remittanceId;
        
        if (target.classList.contains('edit-payment-details-btn')) {
            try {
                // Ouvre la modale d'édition.
                const { data: shop } = await axios.get(`${API_BASE_URL}/shops/${shopId}`);
                editShopIdInput.value = shop.id;
                paymentNameInput.value = shop.payment_name || '';
                phoneNumberInput.value = shop.phone_number_for_payment || '';
                paymentOperatorSelect.value = shop.payment_operator || '';
                
                document.getElementById('editPaymentModal').querySelector('.modal-title').textContent = `Modifier infos de ${shop.name}`;
                editPaymentModal.show();
            } catch (error) { 
                showNotification("Impossible de charger les détails de paiement.", "danger"); 
            }
        } else if (target.classList.contains('pay-btn')) {
            const shopName = target.dataset.shopName;
            const amount = parseFloat(target.dataset.amount);
            
            // Paiement individuel : Ouvre la modale de confirmation
            openConfirmModal('individual', amount, `Marchand: ${shopName}`, remittanceId);
        }
    };
    
    /**
     * Gère la soumission du formulaire de modification des infos de paiement du marchand.
     * @param {Event} e - L'événement de soumission.
     */
    const handleEditPaymentSubmit = async (e) => {
        e.preventDefault();
        const shopId = editShopIdInput.value;
        const paymentData = { 
            payment_name: paymentNameInput.value, 
            phone_number_for_payment: phoneNumberInput.value, 
            payment_operator: paymentOperatorSelect.value 
        };
        try {
            // NOTE: L'API du backend gère la mise à jour des détails du shop via cette route.
            await axios.put(`${API_BASE_URL}/remittances/shop-details/${shopId}`, paymentData);
            showNotification("Informations mises à jour !");
            editPaymentModal.hide();
            await fetchRemittances(); // Recharger pour voir les changements dans le tableau
        } catch (error) { 
            showNotification("Erreur de mise à jour.", "danger"); 
        }
    };
    
    /**
     * Gère l'action de paiement groupé.
     */
    const handleBulkPay = () => {
         const pending = allRemittances.filter(r => r.status === 'pending' && r.net_amount > 0);
         const totalAmount = pending.reduce((sum, rem) => sum + rem.net_amount, 0); 
         if (pending.length > 0 && totalAmount > 0) { 
             openConfirmModal('bulk', totalAmount, `${pending.length} Marchands`);
         } else {
             showNotification('Aucun versement en attente éligible au paiement groupé.', 'info');
         }
    };

    /**
     * Gère l'action de re-synchronisation forcée.
     */
    const handleReSync = async () => {
        const date = remittanceDateInput.value;
        if (!date) return showNotification('Veuillez sélectionner une date.', 'warning');
        
        resyncBtn.disabled = true;
        resyncBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Sync...';

        try {
            // L'appel à la route d'API pour la date force la synchronisation côté backend
            await axios.post(`${API_BASE_URL}/remittances/resync`, { date }); 
            showNotification('Synchronisation forcée réussie. Les montants sont à jour.', 'info');
            await fetchRemittances();
        } catch (error) {
            showNotification(`Erreur lors de la re-synchronisation.`, 'danger');
        } finally {
            resyncBtn.disabled = false;
            resyncBtn.innerHTML = '<i class="bi bi-arrow-repeat"></i> Re-sync';
        }
    };

    /**
     * Met en évidence le lien de navigation actif dans la barre latérale.
     */
    const highlightActiveLink = () => {
        const currentPath = window.location.pathname.split('/').pop();
        document.querySelectorAll('.sidebar .nav-link').forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === currentPath) {
                link.classList.add('active');
            }
        });
    };


    // --- INITIALISATION ---
    const initializeApp = () => {
        const today = new Date().toISOString().slice(0, 10);
        
        if (remittanceDateInput) remittanceDateInput.value = today;
        if (statusFilter) statusFilter.value = "pending"; // Filtre par défaut 'En attente'
        if (itemsPerPageSelect) itemsPerPage = parseInt(itemsPerPageSelect.value);

        // --- Sidebar et Déconnexion ---
        addSafeEventListener(sidebarToggler, 'click', () => {
            sidebar?.classList.toggle('collapsed');
            mainContent?.classList.toggle('expanded');
        });
        
        addSafeEventListener(logoutBtn, 'click', () => { 
            localStorage.removeItem('user');
            sessionStorage.removeItem('user');
            window.location.href = 'index.html'; 
        });
        
        highlightActiveLink();

        // Écouteurs pour le filtre et la recherche
        addSafeEventListener(remittanceDateInput, 'change', fetchRemittances);
        addSafeEventListener(searchInput, 'input', fetchRemittances);
        addSafeEventListener(statusFilter, 'change', fetchRemittances);
        addSafeEventListener(remittanceTableBody, 'click', handleTableActions);
        
        // Écouteurs Modale
        addSafeEventListener(editPaymentForm, 'submit', handleEditPaymentSubmit);
        addSafeEventListener(confirmPayBtn, 'click', handleConfirmPayment);
        
        // Écouteur pour les boutons d'actions
        addSafeEventListener(bulkPayBtn, 'click', handleBulkPay);
        addSafeEventListener(resyncBtn, 'click', handleReSync);
        
        // Pagination
        addSafeEventListener(itemsPerPageSelect, 'change', (e) => { 
            itemsPerPage = parseInt(e.target.value); 
            applyPaginationAndRender(); 
        });
        addSafeEventListener(firstPageBtn, 'click', (e) => { e.preventDefault(); handlePageChange(1); });
        addSafeEventListener(prevPageBtn, 'click', (e) => { e.preventDefault(); handlePageChange(currentPage - 1); });
        addSafeEventListener(nextPageBtn, 'click', (e) => { e.preventDefault(); handlePageChange(currentPage + 1); });
        addSafeEventListener(lastPageBtn, 'click', (e) => { e.preventDefault(); handlePageChange(Math.ceil(filteredRemittances.length / itemsPerPage)); });
        
        // Lancement du chargement initial
        fetchRemittances();
    };

    initializeApp();
});