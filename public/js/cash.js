// js/cash.js
document.addEventListener('DOMContentLoaded', () => {

    // --- CONFIGURATION ---
    const API_BASE_URL = 'https://app.winkexpress.online';
    
    // Simuler l'utilisateur connecté (nécessaire pour l'ID et l'Authorization)
    const storedUser = localStorage.getItem('user') || sessionStorage.getItem('user');
    if (!storedUser) {
        // Redirection si non connecté (comportement préservé)
        // window.location.href = 'index.html';
        // return; 
    }
    const user = storedUser ? JSON.parse(storedUser) : { id: 1, name: 'Admin Test' };
    const CURRENT_USER_ID = user.id;
    if (user.token) {
        axios.defaults.headers.common['Authorization'] = `Bearer ${user.token}`;
    }
    // Mise à jour de l'UI avec le nom de l'utilisateur
    if (document.getElementById('userName')) {
        document.getElementById('userName').textContent = user.name;
    }

    // --- CACHES & ÉTAT ---
    let usersCache = [];
    let categoriesCache = [];
    let transactionIdToEdit = null;

    // --- RÉFÉRENCES DOM ---
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const logoutBtn = document.getElementById('logoutBtn');
    
    const startDateInput = document.getElementById('startDate');
    const endDateInput = document.getElementById('endDate');
    const globalSearchInput = document.getElementById('globalSearchInput');
    const filterBtn = document.getElementById('filterBtn');

    const summaryTableBody = document.getElementById('summaryTableBody');
    const shortfallsTableBody = document.getElementById('shortfallsTableBody');
    const expensesTableBody = document.getElementById('expensesTableBody');
    const withdrawalsTableBody = document.getElementById('withdrawalsTableBody');
    const closingsHistoryTableBody = document.getElementById('closingsHistoryTableBody');

    const addExpenseModal = new bootstrap.Modal(document.getElementById('addExpenseModal'));
    const manualWithdrawalModal = new bootstrap.Modal(document.getElementById('manualWithdrawalModal'));
    const remittanceDetailsModal = new bootstrap.Modal(document.getElementById('remittanceDetailsModal'));
    const closingManagerModal = new bootstrap.Modal(document.getElementById('closingManagerModal'));
    const editExpenseModal = new bootstrap.Modal(document.getElementById('editExpenseModal'));
    const editWithdrawalModal = new bootstrap.Modal(document.getElementById('editWithdrawalModal'));

    const expenseForm = document.getElementById('expenseForm');
    const expenseDateInput = document.getElementById('expenseDateInput');
    const expenseUserSearchInput = document.getElementById('expenseUserSearch');
    const expenseUserSearchResults = document.getElementById('expenseUserSearchResults');
    const expenseUserIdInput = document.getElementById('expenseUserId');
    const withdrawalForm = document.getElementById('withdrawalForm');
    const withdrawalDateInput = document.getElementById('withdrawalDateInput');
    const editExpenseForm = document.getElementById('editExpenseForm');
    const editWithdrawalForm = document.getElementById('editWithdrawalForm');
    const closeCashForm = document.getElementById('closeCashForm');
    
    const confirmBatchBtn = document.getElementById('confirmBatchBtn');
    
    // --- FONCTIONS UTILITAIRES ---
    
    /**
     * Affiche une notification toast stylisée.
     * @param {string} message - Le message à afficher.
     * @param {string} [type='success'] - Le type d'alerte (success, danger, warning, info).
     */
    const showNotification = (message, type = 'success') => {
        const container = document.getElementById('notification-container');
        if (!container) return;
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
        alertDiv.role = 'alert';
        alertDiv.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;
        container.appendChild(alertDiv);
        
        // Fermeture automatique pour l'effet "toast"
        setTimeout(() => {
            const bsAlert = bootstrap.Alert.getOrCreateInstance(alertDiv);
            bsAlert.close();
        }, 4000); 
    };

    /**
     * Formate un montant en FCFA avec séparateur de milliers.
     * @param {number|string} amount - Le montant à formater.
     * @returns {string} Le montant formaté.
     */
    const formatAmount = (amount) => `${Number(amount || 0).toLocaleString('fr-FR')} FCFA`;
    
    /**
     * Retarde l'exécution d'une fonction (debounce).
     * @param {Function} func - La fonction à exécuter.
     * @param {number} [delay=500] - Le délai d'attente en millisecondes.
     * @returns {Function} La fonction debounced.
     */
    const debounce = (func, delay = 500) => {
        let timeout;
        return (...args) => {
            clearTimeout(timeout);
            timeout = setTimeout(() => {
                func.apply(this, args);
            }, delay);
        };
    };

    // --- FONCTIONS DE CHARGEMENT DES DONNÉES ---

    /**
     * Détermine l'onglet actif et lance la récupération des données correspondantes.
     */
    const applyFiltersAndRender = () => {
        const activeTab = document.querySelector('#cashTabs .nav-link.active');
        if (!activeTab) return;
        
        const targetPanelId = activeTab.getAttribute('data-bs-target');
        const startDate = startDateInput.value;
        const endDate = endDateInput.value;
        const search = globalSearchInput.value;

        if (!startDate || !endDate) return showNotification("Période invalide.", "warning");
        
        fetchCashMetrics(startDate, endDate);

        switch (targetPanelId) {
            case '#remittances-panel':
                fetchAndRenderSummary(startDate, endDate, search);
                break;
            case '#shortfalls-panel':
                fetchAndRenderShortfalls(search);
                break;
            case '#expenses-panel':
                fetchAndRenderTransactions('expense', expensesTableBody, startDate, endDate, search);
                break;
            case '#withdrawals-panel':
                fetchAndRenderTransactions('manual_withdrawal', withdrawalsTableBody, startDate, endDate, search);
                break;
        }
    };

    /**
     * Récupère les métriques globales de la caisse pour la période donnée.
     * @param {string} startDate - Date de début.
     * @param {string} endDate - Date de fin.
     */
    const fetchCashMetrics = async (startDate, endDate) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/metrics`, { params: { startDate, endDate } });
            document.getElementById('db-total-collected').textContent = formatAmount(res.data.total_collected);
            document.getElementById('db-total-expenses').textContent = formatAmount(res.data.total_expenses);
            document.getElementById('db-total-withdrawals').textContent = formatAmount(res.data.total_withdrawals);
            document.getElementById('db-cash-on-hand').textContent = formatAmount(res.data.cash_on_hand);
        } catch (error) {
            console.error("Erreur de chargement des métriques:", error);
            document.getElementById('db-total-collected').textContent = "0 FCFA";
            document.getElementById('db-total-expenses').textContent = "0 FCFA";
            document.getElementById('db-total-withdrawals').textContent = "0 FCFA";
            document.getElementById('db-cash-on-hand').textContent = "0 FCFA";
        }
    };
    
    /**
     * Récupère et affiche le résumé des versements des livreurs.
     * @param {string} startDate - Date de début.
     * @param {string} endDate - Date de fin.
     * @param {string} search - Terme de recherche.
     */
    const fetchAndRenderSummary = async (startDate, endDate, search) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/remittance-summary`, { params: { startDate, endDate, search } });
            summaryTableBody.innerHTML = '';
            if (res.data.length === 0) {
                summaryTableBody.innerHTML = `<tr><td colspan="6" class="text-center p-3">Aucun versement à afficher.</td></tr>`;
                return;
            }
            res.data.forEach(item => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${item.user_name}</td>
                    <td>${item.pending_count || 0}</td>
                    <td class="text-warning fw-bold">${formatAmount(item.pending_amount)}</td>
                    <td>${item.confirmed_count || 0}</td>
                    <td class="text-success fw-bold">${formatAmount(item.confirmed_amount)}</td>
                    <td><button class="btn btn-sm btn-primary-custom details-btn" data-id="${item.user_id}" data-name="${item.user_name}">Gérer</button></td>
                `;
                summaryTableBody.appendChild(row);
            });
        } catch (error) {
            summaryTableBody.innerHTML = `<tr><td colspan="6" class="text-center text-danger p-4">Erreur de chargement.</td></tr>`;
        }
    };

    /**
     * Récupère et affiche la liste des manquants des livreurs (shortfalls).
     * @param {string} search - Terme de recherche.
     */
    const fetchAndRenderShortfalls = async (search) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/shortfalls`, { params: { search } });
            shortfallsTableBody.innerHTML = '';
            if (res.data.length === 0) {
                shortfallsTableBody.innerHTML = `<tr><td colspan="5" class="text-center p-3">Aucun manquant en attente.</td></tr>`;
                return;
            }
            res.data.forEach(item => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${item.deliveryman_name}</td>
                    <td class="text-danger fw-bold">${formatAmount(item.amount)}</td>
                    <td><span class="badge bg-warning text-dark">${item.status}</span></td>
                    <td>${moment(item.created_at).format('DD/MM/YYYY')}</td>
                    <td><button class="btn btn-sm btn-success settle-btn" data-id="${item.id}" data-amount="${item.amount}">Régler</button></td>
                `;
                shortfallsTableBody.appendChild(row);
            });
        } catch (error) {
            shortfallsTableBody.innerHTML = `<tr><td colspan="5" class="text-center text-danger p-4">Erreur de chargement.</td></tr>`;
        }
    };

    /**
     * Récupère et affiche les dépenses ou les décaissements manuels.
     * @param {string} type - Le type de transaction ('expense' ou 'manual_withdrawal').
     * @param {HTMLElement} tableBody - Le tbody où insérer les lignes.
     * @param {string} startDate - Date de début.
     * @param {string} endDate - Date de fin.
     * @param {string} search - Terme de recherche.
     */
    const fetchAndRenderTransactions = async (type, tableBody, startDate, endDate, search) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/transactions`, { params: { type, startDate, endDate, search } });
            tableBody.innerHTML = '';
            if (res.data.length === 0) {
                tableBody.innerHTML = `<tr><td colspan="6" class="text-center p-3">Aucune transaction.</td></tr>`;
                return;
            }
            res.data.forEach(tx => {
                const row = document.createElement('tr');
                const userDisplayName = type === 'expense' ? tx.user_name : (tx.validated_by_name || 'Admin');
                const category = tx.category_name || '';
                
                row.innerHTML = `
                    <td>${moment(tx.created_at).format('DD/MM/YYYY HH:mm')}</td>
                    <td>${userDisplayName}</td>
                    ${type === 'expense' ? `<td>${category}</td>` : ''}
                    <td class="text-danger fw-bold">${formatAmount(Math.abs(tx.amount))}</td>
                    <td>${tx.comment || ''}</td>
                    <td>
                        <button class="btn btn-sm btn-outline-info edit-tx-btn" data-id="${tx.id}" data-type="${type}" data-amount="${Math.abs(tx.amount)}" data-comment="${tx.comment || ''}" title="Modifier"><i class="bi bi-pencil"></i></button>
                        <button class="btn btn-sm btn-outline-danger delete-tx-btn" data-id="${tx.id}" title="Supprimer"><i class="bi bi-trash"></i></button>
                    </td>
                `;
                tableBody.appendChild(row);
            });
        } catch (error) {
            tableBody.innerHTML = `<tr><td colspan="6" class="text-center text-danger p-4">Erreur de chargement.</td></tr>`;
        }
    };
    
    /**
     * Récupère et affiche l'historique des clôtures de caisse.
     */
    const fetchClosingHistory = async () => {
        const startDate = document.getElementById('historyStartDate').value;
        const endDate = document.getElementById('historyEndDate').value;
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/closing-history`, { params: { startDate, endDate } });
            closingsHistoryTableBody.innerHTML = '';
            if (res.data.length === 0) {
                closingsHistoryTableBody.innerHTML = `<tr><td colspan="4" class="text-center p-3">Aucun historique.</td></tr>`;
                return;
            }
            res.data.forEach(item => {
                const difference = parseFloat(item.difference || 0);
                const diffClass = difference < 0 ? 'text-danger' : (difference > 0 ? 'text-success' : '');
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${moment(item.closing_date).format('DD/MM/YYYY')}</td>
                    <td>${formatAmount(item.expected_cash)}</td>
                    <td>${formatAmount(item.actual_cash_counted)}</td>
                    <td class="fw-bold ${diffClass}">${formatAmount(difference)}</td>
                `;
                closingsHistoryTableBody.appendChild(row);
            });
        } catch (error) {
            closingsHistoryTableBody.innerHTML = `<tr><td colspan="4" class="text-center text-danger">Erreur de chargement.</td></tr>`;
        }
    };
    
    /**
     * Récupère la liste des utilisateurs et les catégories de dépenses.
     */
    const fetchInitialData = async () => {
        try {
            const [usersRes, categoriesRes] = await Promise.all([
                axios.get(`${API_BASE_URL}/users`),
                axios.get(`${API_BASE_URL}/cash/expense-categories`)
            ]);
            usersCache = usersRes.data;
            categoriesCache = categoriesRes.data;
            
            const expenseCategorySelect = document.getElementById('expenseCategorySelect');
            expenseCategorySelect.innerHTML = '<option value="">Sélectionner une catégorie</option>';
            categoriesCache.forEach(cat => expenseCategorySelect.innerHTML += `<option value="${cat.id}">${cat.name}</option>`);
        } catch (error) {
            showNotification("Erreur de chargement des données de base.", "danger");
        }
    };
    
    // --- GESTION DES ÉVÉNEMENTS ---

    /**
     * Gère les événements des formulaires de transactions (dépense/décaissement).
     * @param {Event} e - L'événement de soumission.
     */
    const handleTransactionFormSubmit = (form, endpoint, successMsg) => async (e) => {
        e.preventDefault();
        const formData = {};
        
        try {
            if (form === expenseForm) {
                formData.user_id = expenseUserIdInput.value;
                formData.created_at = expenseDateInput.value;
                formData.category_id = document.getElementById('expenseCategorySelect').value;
                formData.amount = document.getElementById('expenseAmountInput').value;
                formData.comment = document.getElementById('expenseCommentInput').value;
                if (!formData.user_id) throw new Error("Veuillez sélectionner un utilisateur.");
            } else if (form === withdrawalForm) {
                formData.amount = document.getElementById('withdrawalAmountInput').value;
                formData.created_at = document.getElementById('withdrawalDateInput').value;
                formData.comment = document.getElementById('withdrawalCommentInput').value;
                formData.user_id = CURRENT_USER_ID;
            }
            
            await axios.post(`${API_BASE_URL}/cash/${endpoint}`, formData);
            showNotification(successMsg);
            
            if (form === expenseForm) addExpenseModal.hide();
            else if (form === withdrawalForm) manualWithdrawalModal.hide();
            
            form.reset();
            resetModalForms();
            applyFiltersAndRender();
        } catch (error) { 
            const message = error.response?.data?.message || error.message || "Erreur inconnue.";
            showNotification(message, "danger"); 
        }
    };

    /**
     * Gère la soumission des formulaires de modification (dépense/décaissement).
     * @param {Event} e - L'événement de soumission.
     */
    const handleEditFormSubmit = (type) => async (e) => {
        e.preventDefault();
        const amount = document.getElementById(`edit${type}Amount`).value;
        const comment = document.getElementById(`edit${type}Comment`).value;
        
        try {
            await axios.put(`${API_BASE_URL}/cash/transactions/${transactionIdToEdit}`, { amount, comment });
            showNotification(`${type} modifiée.`);
            if (type === 'Expense') editExpenseModal.hide();
            else if (type === 'Withdrawal') editWithdrawalModal.hide();
            applyFiltersAndRender();
        } catch (error) { 
            showNotification("Erreur de modification.", 'danger'); 
        }
    };

    /**
     * Gère l'affichage des détails de versement pour un livreur.
     * @param {string} deliverymanId - L'ID du livreur.
     * @param {string} deliverymanName - Le nom du livreur.
     */
    const handleRemittanceDetails = async (deliverymanId, deliverymanName) => {
        document.getElementById('modalDeliverymanName').textContent = deliverymanName;
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/remittance-details/${deliverymanId}`, { params: { startDate: startDateInput.value, endDate: endDateInput.value } });
            const tableBody = document.getElementById('modalTransactionsTableBody');
            tableBody.innerHTML = '';
            
            if (res.data.length === 0) {
                 tableBody.innerHTML = `<tr><td colspan="6" class="text-center p-3">Aucune transaction à gérer.</td></tr>`;
            } else {
                res.data.forEach(tx => {
                    const row = document.createElement('tr');
                    const statusBadge = tx.status === 'pending' ? `<span class="badge bg-warning text-dark">En attente</span>` : `<span class="badge bg-success">Confirmé</span>`;
                    row.innerHTML = `
                        <td><input type="checkbox" class="transaction-checkbox" data-id="${tx.id}" data-amount="${tx.amount}" ${tx.status !== 'pending' ? 'disabled' : ''}></td>
                        <td>${moment(tx.created_at).format('DD/MM HH:mm')}</td>
                        <td>${formatAmount(tx.amount)}</td>
                        <td>
                            <div>${tx.comment}</div>
                            <small class="text-muted">${tx.shop_name || 'Info'} - ${tx.item_names || 'non'} - ${tx.delivery_location || 'disponible'}</small>
                        </td>
                        <td>${statusBadge}</td>
                        <td>
                            <button class="btn btn-sm btn-outline-info edit-remittance-btn" title="Modifier le montant" data-id="${tx.id}" data-amount="${tx.amount}"><i class="bi bi-pencil"></i></button>
                            ${tx.status === 'pending' ? `<button class="btn btn-sm btn-outline-success confirm-single-remittance-btn" title="Confirmer ce versement" data-id="${tx.id}" data-amount="${tx.amount}"><i class="bi bi-check2"></i></button>` : ''}
                        </td>
                    `;
                    tableBody.appendChild(row);
                });
            }
            remittanceDetailsModal.show();
        } catch (error) {
            showNotification("Erreur au chargement des détails.", "danger");
        }
    };
    
    /**
     * Gère la confirmation des versements sélectionnés.
     */
    const handleConfirmBatch = async () => {
        const selectedCheckboxes = document.querySelectorAll('#modalTransactionsTableBody .transaction-checkbox:checked');
        const transactionIds = Array.from(selectedCheckboxes).map(cb => cb.dataset.id);

        if (transactionIds.length === 0) return showNotification("Sélectionnez au moins une transaction.", 'warning');

        const expectedAmount = Array.from(selectedCheckboxes).reduce((sum, cb) => sum + parseFloat(cb.dataset.amount), 0);
        const paidAmount = prompt(`Total sélectionné : ${formatAmount(expectedAmount)}. Montant total versé ?`, expectedAmount);

        if (paidAmount !== null && !isNaN(paidAmount)) {
            try {
                const res = await axios.put(`${API_BASE_URL}/cash/remittances/confirm`, { transactionIds, paidAmount: parseFloat(paidAmount), validated_by: CURRENT_USER_ID });
                showNotification(res.data.message);
                remittanceDetailsModal.hide();
                applyFiltersAndRender();
                fetchAndRenderShortfalls();
            } catch (error) { 
                showNotification(error.response?.data?.message || "Erreur.", "danger"); 
            }
        }
    };

    /**
     * Initialise tous les écouteurs d'événements de l'interface.
     */
    const initializeEventListeners = () => {
        // --- Sidebar et Déconnexion ---
        sidebarToggler.addEventListener('click', () => {
            sidebar.classList.toggle('collapsed');
            mainContent.classList.toggle('expanded');
        });
        
        logoutBtn.addEventListener('click', () => {
            localStorage.removeItem('user');
            sessionStorage.removeItem('user');
            window.location.href = 'index.html';
        });

        // --- Filtres et Navigation par Onglet ---
        filterBtn.addEventListener('click', applyFiltersAndRender);
        globalSearchInput.addEventListener('input', debounce(applyFiltersAndRender));
        document.querySelectorAll('#cashTabs .nav-link').forEach(tab => tab.addEventListener('shown.bs.tab', applyFiltersAndRender));

        // --- Clôture de Caisse ---
        document.getElementById('historyStartDate').addEventListener('change', fetchClosingHistory);
        document.getElementById('historyEndDate').addEventListener('change', fetchClosingHistory);
        document.getElementById('exportHistoryBtn').addEventListener('click', () => {
            const startDate = document.getElementById('historyStartDate').value;
            const endDate = document.getElementById('historyEndDate').value;
            window.open(`${API_BASE_URL}/cash/closing-history/export?startDate=${startDate}&endDate=${endDate}`, '_blank');
        });
        closeCashForm.addEventListener('submit', async e => {
            e.preventDefault();
            try {
                await axios.post(`${API_BASE_URL}/cash/close-cash`, {
                    closingDate: document.getElementById('closeDate').value,
                    actualCash: document.getElementById('actualAmount').value,
                    comment: document.getElementById('closeComment').value,
                    userId: CURRENT_USER_ID
                });
                showNotification("Caisse clôturée avec succès !");
                closingManagerModal.hide();
                fetchClosingHistory();
                applyFiltersAndRender();
            } catch(error) { showNotification(error.response?.data?.message || "Erreur.", "danger"); }
        });

        // --- Soumission de Formulaires de Transactions ---
        expenseForm.addEventListener('submit', handleTransactionFormSubmit(expenseForm, 'expense', "Dépense enregistrée."));
        withdrawalForm.addEventListener('submit', handleTransactionFormSubmit(withdrawalForm, 'withdrawal', "Décaissement enregistré."));
        editExpenseForm.addEventListener('submit', handleEditFormSubmit('Expense'));
        editWithdrawalForm.addEventListener('submit', handleEditFormSubmit('Withdrawal'));

        // --- Actions de la Table (Édition/Suppression/Règlement) ---
        document.body.addEventListener('click', async (e) => {
            const target = e.target.closest('button, a');
            if (!target) return;

            if (target.matches('.details-btn')) {
                const deliverymanId = target.dataset.id;
                const deliverymanName = target.dataset.name;
                handleRemittanceDetails(deliverymanId, deliverymanName);
            } else if (target.matches('.settle-btn')) {
                handleSettleShortfall(target);
            } else if (target.matches('.edit-tx-btn')) {
                handleEditTransaction(target);
            } else if (target.matches('.delete-tx-btn')) {
                handleDeleteTransaction(target);
            } else if (target.matches('.edit-remittance-btn')) {
                handleEditRemittanceAmount(target);
            } else if (target.matches('.confirm-single-remittance-btn')) {
                handleConfirmSingleRemittance(target);
            }
        });
        
        confirmBatchBtn.addEventListener('click', handleConfirmBatch);

        // --- Gestion de la recherche d'utilisateur pour Dépense ---
        setupUserSearchExpense();
    };

    /**
     * Gère le règlement d'un manquant.
     */
    const handleSettleShortfall = async (target) => {
        const shortfallId = target.dataset.id;
        const amountDue = target.dataset.amount;
        const amountPaid = prompt(`Montant à régler sur les ${formatAmount(amountDue)} ?`, amountDue);
        if (amountPaid && !isNaN(amountPaid) && amountPaid > 0) {
            try {
                await axios.put(`${API_BASE_URL}/cash/shortfalls/${shortfallId}/settle`, { amount: amountPaid, userId: CURRENT_USER_ID });
                showNotification("Règlement enregistré.");
                fetchAndRenderShortfalls();
            } catch (error) { showNotification(error.response?.data?.message || "Erreur.", "danger"); }
        }
    };

    /**
     * Ouvre la modale d'édition de transaction.
     */
    const handleEditTransaction = (target) => {
        transactionIdToEdit = target.dataset.id;
        const type = target.dataset.type;
        const amount = target.dataset.amount;
        const comment = target.dataset.comment;
        
        if(type === 'expense'){
            document.getElementById('editExpenseAmount').value = amount;
            document.getElementById('editExpenseComment').value = comment;
            editExpenseModal.show();
        } else {
            document.getElementById('editWithdrawalAmount').value = amount;
            document.getElementById('editWithdrawalComment').value = comment;
            editWithdrawalModal.show();
        }
    };

    /**
     * Supprime une transaction.
     */
    const handleDeleteTransaction = async (target) => {
        const txId = target.dataset.id;
        if (confirm('Voulez-vous vraiment supprimer cette transaction ?')) {
            try {
                await axios.delete(`${API_BASE_URL}/cash/transactions/${txId}`);
                showNotification('Transaction supprimée.');
                applyFiltersAndRender();
            } catch (error) { showNotification("Erreur de suppression.", "danger"); }
        }
    };

    /**
     * Modifie le montant d'un versement.
     */
    const handleEditRemittanceAmount = async (target) => {
        const txId = target.dataset.id;
        const oldAmount = target.dataset.amount;
        const newAmount = prompt(`Modifier le montant du versement :`, oldAmount);
        if(newAmount && !isNaN(newAmount)){
            try {
                await axios.put(`${API_BASE_URL}/cash/remittances/${txId}`, { amount: newAmount });
                showNotification("Montant mis à jour.");
                remittanceDetailsModal.hide(); // Force le rafraîchissement
            } catch (error) {
                showNotification(error.response?.data?.message || "Erreur.", "danger");
            }
        }
    };

    /**
     * Confirme un seul versement.
     */
    const handleConfirmSingleRemittance = async (target) => {
        const txId = target.dataset.id;
        const expectedAmount = target.dataset.amount;
        const paidAmount = prompt(`Montant attendu : ${formatAmount(expectedAmount)}. Montant versé ?`, expectedAmount);

        if (paidAmount !== null && !isNaN(paidAmount)) {
            try {
                const res = await axios.put(`${API_BASE_URL}/cash/remittances/confirm`, { transactionIds: [txId], paidAmount: parseFloat(paidAmount), validated_by: CURRENT_USER_ID });
                showNotification(res.data.message);
                remittanceDetailsModal.hide();
                applyFiltersAndRender();
                fetchAndRenderShortfalls();
            } catch (error) { showNotification(error.response?.data?.message || "Erreur.", "danger"); }
        }
    };

    /**
     * Réinitialise les champs de date dans les formulaires modales.
     */
    const resetModalForms = () => {
        const today = new Date().toISOString().slice(0, 10);
        if (expenseDateInput) expenseDateInput.value = today;
        if (withdrawalDateInput) withdrawalDateInput.value = today;
        if (expenseUserSearchResults) expenseUserSearchResults.classList.add('d-none');
    };
    
    /**
     * Configure la recherche dynamique d'utilisateur pour la modale de dépense.
     */
    const setupUserSearchExpense = () => {
        expenseUserSearchInput.addEventListener('input', () => {
            const searchTerm = expenseUserSearchInput.value.toLowerCase();
            expenseUserSearchResults.innerHTML = '';
            if (searchTerm.length > 1) {
                const filteredUsers = usersCache.filter(user => user.name.toLowerCase().includes(searchTerm));
                if (filteredUsers.length > 0) {
                    filteredUsers.forEach(user => {
                        const div = document.createElement('div');
                        div.className = 'p-2';
                        div.textContent = user.name;
                        div.dataset.id = user.id;
                        div.addEventListener('click', () => {
                            expenseUserSearchInput.value = user.name;
                            expenseUserIdInput.value = user.id;
                            expenseUserSearchResults.classList.add('d-none');
                        });
                        expenseUserSearchResults.appendChild(div);
                    });
                    expenseUserSearchResults.classList.remove('d-none');
                } else {
                    expenseUserSearchResults.innerHTML = '<div class="p-2 text-muted">Aucun résultat.</div>';
                    expenseUserSearchResults.classList.remove('d-none');
                }
            } else {
                expenseUserSearchResults.classList.add('d-none');
            }
        });
        
        expenseUserSearchResults.addEventListener('click', (e) => {
            if (e.target.dataset.id) {
                expenseUserSearchInput.value = e.target.textContent;
                expenseUserIdInput.value = e.target.dataset.id;
                expenseUserSearchResults.classList.add('d-none');
            }
        });
        
        // Assurer que le formulaire est réinitialisé lors de l'ouverture/fermeture de la modale
        document.getElementById('addExpenseModal').addEventListener('show.bs.modal', resetModalForms);
        document.getElementById('manualWithdrawalModal').addEventListener('show.bs.modal', resetModalForms);
        document.getElementById('addExpenseModal').addEventListener('hidden.bs.modal', () => {
            if (expenseUserSearchResults) expenseUserSearchResults.classList.add('d-none');
        });
    };
    
    // --- Lancement de la page ---
    const initializeApp = async () => {
        const today = new Date().toISOString().slice(0, 10);
        startDateInput.value = today;
        endDateInput.value = today;
        document.getElementById('closeDate').value = today;
        document.getElementById('historyStartDate').value = moment().subtract(30, 'days').format('YYYY-MM-DD');
        document.getElementById('historyEndDate').value = today;

        initializeEventListeners();
        
        await fetchInitialData();
        setupUserSearchExpense();
        applyFiltersAndRender();
        fetchClosingHistory();
    };

    initializeApp();
});