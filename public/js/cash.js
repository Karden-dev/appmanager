// js/cash.js
document.addEventListener('DOMContentLoaded', () => {

    // --- CONFIGURATION ---
    const API_BASE_URL = 'http://localhost:3000/api';
    
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
    let remittanceDataToConfirm = null; // État pour la confirmation de versement (ids, expectedAmount)
    let shortfallToSettle = null; // État pour le règlement de manquant (id, amountDue)
    let currentRemittanceDetails = []; // Cache pour les détails dans la modale

    // --- RÉFÉRENCES DOM ---
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const logoutBtn = document.getElementById('logoutBtn');
    
    const startDateInput = document.getElementById('startDate');
    const endDateInput = document.getElementById('endDate');
    const globalSearchInput = document.getElementById('globalSearchInput');
    const filterBtn = document.getElementById('filterBtn');
    // Le bouton refreshBtn n'est plus utilisé

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

    const confirmAmountModal = new bootstrap.Modal(document.getElementById('confirmAmountModal'));
    const confirmAmountForm = document.getElementById('confirmAmountForm');
    const confirmAmountInput = document.getElementById('confirmAmountInput');
    const expectedAmountDisplay = document.getElementById('expectedAmountDisplay');
    const amountError = document.getElementById('amountError');
    
    const editRemittanceAmountModal = new bootstrap.Modal(document.getElementById('editRemittanceAmountModal'));
    const editRemittanceForm = document.getElementById('editRemittanceForm');
    const editRemittanceAmountInput = document.getElementById('editRemittanceAmountInput');

    const settleShortfallModal = new bootstrap.Modal(document.getElementById('settleShortfallModal'));
    const settleShortfallForm = document.getElementById('settleShortfallForm');
    const settleShortfallAmountInput = document.getElementById('settleShortfallAmountInput');
    const shortfallDueDisplay = document.getElementById('shortfallDueDisplay');


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
    
    const showNotification = (message, type = 'success') => {
        const container = document.getElementById('notification-container');
        if (!container) return;
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
        alertDiv.role = 'alert';
        alertDiv.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;
        container.appendChild(alertDiv);
        
        setTimeout(() => {
            const bsAlert = bootstrap.Alert.getOrCreateInstance(alertDiv);
            bsAlert.close();
        }, 4000); 
    };

    const formatAmount = (amount) => `${Number(amount || 0).toLocaleString('fr-FR')} FCFA`;
    
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

    const applyFiltersAndRender = async () => {
        const originalText = filterBtn.innerHTML;
        filterBtn.disabled = true;
        filterBtn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Filtrage...';

        try {
            const activeTab = document.querySelector('#cashTabs .nav-link.active');
            if (!activeTab) return;
            
            const targetPanelId = activeTab.getAttribute('data-bs-target');
            const startDate = startDateInput.value;
            const endDate = endDateInput.value;
            const search = globalSearchInput.value;

            if (!startDate || !endDate) {
                showNotification("Période invalide.", "warning");
                return;
            }
            
            // 1. Mise à jour des métriques de caisse
            await fetchCashMetrics(startDate, endDate);

            // 2. Rendu des données de l'onglet actif
            switch (targetPanelId) {
                case '#remittances-panel':
                    await fetchAndRenderSummary(startDate, endDate, search);
                    break;
                case '#shortfalls-panel':
                    await fetchAndRenderShortfalls(search);
                    break;
                case '#expenses-panel':
                    await fetchAndRenderTransactions('expense', expensesTableBody, startDate, endDate, search);
                    break;
                case '#withdrawals-panel':
                    await fetchAndRenderTransactions('manual_withdrawal', withdrawalsTableBody, startDate, endDate, search);
                    break;
            }
            
            showNotification("Données actualisées.", "success");

        } catch (error) {
             console.error("Erreur lors de l'actualisation des données:", error);
             showNotification("Erreur lors de l'actualisation des données.", "danger");
        } finally {
            filterBtn.disabled = false;
            filterBtn.innerHTML = originalText;
        }
    };

    // MISE À JOUR COMPLÈTE DE CETTE FONCTION POUR UTILISER LES NOUVELLES MÉTRIQUES
    const fetchCashMetrics = async (startDate, endDate) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/metrics`, { params: { startDate, endDate } });
            
            // Mappage des nouvelles métriques (montant_en_caisse, chiffre_affaire_ca, etc.)
            // aux IDs HTML existants pour la section "Situation de la caisse"
            
            // Montant en Caisse (Résultat Final)
            document.getElementById('db-cash-on-hand').textContent = formatAmount(res.data.montant_en_caisse);
            
            // Encaissement (Versements confirmés - OUI, cash_transactions)
            document.getElementById('db-total-collected').textContent = formatAmount(res.data.encaisser);
            
            // Créances Remboursées (Somme des créances remboursées + manquants remboursés)
            const totalRemittedFlow = res.data.creances_remboursees + res.data.manquants_rembourses;
            document.getElementById('db-total-debts-settled').textContent = formatAmount(totalRemittedFlow);

            // Dépenses
            document.getElementById('db-total-expenses').textContent = formatAmount(res.data.depenses);
            
            // Décaissements
            document.getElementById('db-total-withdrawals').textContent = formatAmount(res.data.decaissements);
            
        } catch (error) {
            console.error("Erreur de chargement des métriques:", error);
            // Réinitialisation des cartes en cas d'erreur
            ['db-total-collected', 'db-total-debts-settled', 'db-total-expenses', 'db-total-withdrawals', 'db-cash-on-hand'].forEach(id => {
                const element = document.getElementById(id);
                if(element) element.textContent = "0 FCFA";
            });
            // On ne lève pas l'erreur pour ne pas bloquer les autres chargements de données
            // throw error; 
        }
    };
    
    const fetchAndRenderSummary = async (startDate, endDate, search) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/remittance-summary`, { params: { startDate, endDate, search } });
            summaryTableBody.innerHTML = res.data.length === 0 ? `<tr><td colspan="6" class="text-center p-3">Aucun versement à afficher.</td></tr>` : '';
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
            throw error;
        }
    };

    /**
     * MISE À JOUR : Affiche les manquants avec le nouveau format de date et de statut.
     */
    const fetchAndRenderShortfalls = async (search) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/shortfalls`, { params: { search } });
            shortfallsTableBody.innerHTML = res.data.length === 0 ? `<tr><td colspan="6" class="text-center p-3">Aucun manquant en attente.</td></tr>` : '';
            res.data.forEach(item => {
                const row = document.createElement('tr');
                const settledDate = item.settled_at ? moment(item.settled_at).format('DD/MM/YYYY HH:mm') : '—';
                
                const statusInfo = {
                    pending: { text: 'En attente', class: 'text-warning', icon: 'bi-clock-history' },
                    settled: { text: 'Réglé', class: 'text-success', icon: 'bi-check-circle-fill' },
                };
                const currentStatus = statusInfo[item.status] || { text: item.status, class: '', icon: 'bi-question-circle' };
                const statusBadge = `<span class="${currentStatus.class}"><i class="bi ${currentStatus.icon} me-1"></i>${currentStatus.text}</span>`;

                row.innerHTML = `
                    <td>${item.deliveryman_name}</td>
                    <td class="text-danger fw-bold">${formatAmount(item.amount)}</td>
                    <td>${statusBadge}</td>
                    <td>${moment(item.created_at).format('DD/MM/YYYY')}</td>
                    <td>${settledDate}</td>
                    <td>
                        ${item.status === 'pending' ? `<button class="btn btn-sm btn-success settle-btn" data-id="${item.id}" data-amount="${item.amount}">Régler</button>` : ''}
                    </td>
                `;
                shortfallsTableBody.appendChild(row);
            });
        } catch (error) {
            shortfallsTableBody.innerHTML = `<tr><td colspan="6" class="text-center text-danger p-4">Erreur de chargement.</td></tr>`;
            throw error;
        }
    };

    const fetchAndRenderTransactions = async (type, tableBody, startDate, endDate, search) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/transactions`, { params: { type, startDate, endDate, search } });
            tableBody.innerHTML = res.data.length === 0 ? `<tr><td colspan="6" class="text-center p-3">Aucune transaction.</td></tr>` : '';
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
            throw error;
        }
    };
    
    const fetchClosingHistory = async () => {
        const startDate = document.getElementById('historyStartDate').value;
        const endDate = document.getElementById('historyEndDate').value;
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/closing-history`, { params: { startDate, endDate } });
            // MISE À JOUR : Vérifier que res.data est bien un tableau
            if (!Array.isArray(res.data)) {
                 closingsHistoryTableBody.innerHTML = `<tr><td colspan="4" class="text-center text-danger">Format de données invalide.</td></tr>`;
                 return;
            }
            closingsHistoryTableBody.innerHTML = res.data.length === 0 ? `<tr><td colspan="4" class="text-center p-3">Aucun historique.</td></tr>` : '';
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
            throw error;
        }
    };
    
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
            throw error;
        }
    };
    
    // --- GESTION DES ÉVÉNEMENTS ---

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

    const renderRemittanceDetails = (filter = 'all') => {
        const tableBody = document.getElementById('modalTransactionsTableBody');
        tableBody.innerHTML = '';

        const filteredData = currentRemittanceDetails.filter(tx => {
            if (filter === 'all') return true;
            return tx.status === filter;
        });

        if (filteredData.length === 0) {
            tableBody.innerHTML = `<tr><td colspan="6" class="text-center p-3">Aucune transaction pour ce filtre.</td></tr>`;
            return;
        }

        const groupedByDate = filteredData.reduce((acc, tx) => {
            const date = moment(tx.created_at).format('YYYY-MM-DD');
            if (!acc[date]) {
                acc[date] = [];
            }
            acc[date].push(tx);
            return acc;
        }, {});

        for (const date in groupedByDate) {
            const dateRow = document.createElement('tr');
            dateRow.innerHTML = `<td colspan="6" class="bg-light text-dark fw-bold">${moment(date).format('dddd D MMMM YYYY')}</td>`;
            tableBody.appendChild(dateRow);

            groupedByDate[date].forEach(tx => {
                const row = document.createElement('tr');
                
                const displayAmount = tx.status === 'pending' ? 0 : Math.abs(tx.amount);
                
                const orderTotal = parseFloat(tx.order_total_amount || 0);
                const shippingCost = parseFloat(tx.expedition_fee || 0); 
                const netAmountDue = orderTotal - shippingCost; 

                const statusInfo = {
                    pending: { text: 'En attente', class: 'text-warning', icon: 'bi-clock-history' },
                    confirmed: { text: 'Confirmé', class: 'text-success', icon: 'bi-check-circle-fill' },
                };
                const currentStatus = statusInfo[tx.status] || { text: tx.status, class: '', icon: 'bi-question-circle' };
                const statusBadge = `<span class="${currentStatus.class}"><i class="bi ${currentStatus.icon} me-1"></i>${currentStatus.text}</span>`;
                
                const commentHtml = `
                    <div>${tx.comment}</div>
                    <small class="text-muted">
                        Total Commande: <strong>${formatAmount(orderTotal)}</strong> | 
                        ${tx.shop_name || 'N/A'} - ${tx.item_names || 'N/A'}
                    </small>
                `;
                
                const actionsHtml = `
                    <div class="dropdown">
                        <button class="btn btn-sm btn-light" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                            <i class="bi bi-three-dots"></i>
                        </button>
                        <ul class="dropdown-menu">
                            ${tx.status === 'pending' ? `
                            <li><a class="dropdown-item confirm-single-remittance-btn" href="#" data-id="${tx.id}" data-amount="${netAmountDue}"><i class="bi bi-check2 me-2"></i>Confirmer</a></li>
                            <li><a class="dropdown-item edit-remittance-btn" href="#" data-id="${tx.id}" data-amount="${orderTotal}"><i class="bi bi-pencil me-2"></i>Modifier Montant CDE</a></li>
                            ` : `<li><span class="dropdown-item-text">Déjà confirmé</span></li>`}
                        </ul>
                    </div>
                `;

                row.innerHTML = `
                    <td><input type="checkbox" class="transaction-checkbox" data-id="${tx.id}" data-amount="${netAmountDue}" ${tx.status !== 'pending' ? 'disabled' : ''}></td>
                    <td>${moment(tx.created_at).format('HH:mm')}</td>
                    <td class="fw-bold">${formatAmount(displayAmount)}</td>
                    <td>${commentHtml}</td>
                    <td>${statusBadge}</td>
                    <td>${actionsHtml}</td>
                `;
                tableBody.appendChild(row);
            });
        }
    };

    const handleRemittanceDetails = async (deliverymanId, deliverymanName) => {
        document.getElementById('modalDeliverymanName').textContent = deliverymanName;
        const filterRadio = document.querySelector('input[name="detailsFilter"][value="all"]');
        if (filterRadio) {
            filterRadio.checked = true;
        }
        
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/remittance-details/${deliverymanId}`, { params: { startDate: startDateInput.value, endDate: endDateInput.value } });
            currentRemittanceDetails = res.data;
            renderRemittanceDetails('all');
            remittanceDetailsModal.show();
        } catch (error) {
            showNotification("Erreur au chargement des détails.", "danger");
        }
    };
    
    const handleConfirmBatch = () => {
        const selectedCheckboxes = document.querySelectorAll('#modalTransactionsTableBody .transaction-checkbox:checked');
        const transactionIds = Array.from(selectedCheckboxes).map(cb => cb.dataset.id);

        if (transactionIds.length === 0) return showNotification("Sélectionnez au moins une transaction.", 'warning');

        const expectedAmount = Array.from(selectedCheckboxes).reduce((sum, cb) => sum + parseFloat(cb.dataset.amount), 0);

        remittanceDataToConfirm = { transactionIds, expectedAmount, isSingle: false };
        
        expectedAmountDisplay.textContent = formatAmount(expectedAmount);
        confirmAmountInput.value = expectedAmount.toFixed(2);
        amountError.classList.add('d-none');
        confirmAmountModal.show();
    };
    
    const handleConfirmSingleRemittance = (target) => {
        const txId = target.dataset.id;
        const expectedAmount = parseFloat(target.dataset.amount);

        remittanceDataToConfirm = { transactionIds: [txId], expectedAmount, isSingle: true };
        
        expectedAmountDisplay.textContent = formatAmount(expectedAmount);
        confirmAmountInput.value = expectedAmount.toFixed(2);
        amountError.classList.add('d-none');
        confirmAmountModal.show();
    };

    const handleAmountConfirmationSubmit = async (e) => {
        e.preventDefault();
        
        const paidAmountValue = confirmAmountInput.value.trim();
        
        if (paidAmountValue === '' || isNaN(paidAmountValue) || parseFloat(paidAmountValue) < 0) {
            amountError.classList.remove('d-none');
            return;
        }
        
        amountError.classList.add('d-none');
        const paidAmount = parseFloat(paidAmountValue);

        if (!remittanceDataToConfirm) return;

        const cleanTransactionIds = remittanceDataToConfirm.transactionIds
            .map(id => Number(id))
            .filter(id => !isNaN(id) && id > 0);

        if (cleanTransactionIds.length === 0) {
             showNotification("Erreur: Aucune transaction valide sélectionnée pour la confirmation.", "danger");
             return;
        }

        try {
            const res = await axios.put(`${API_BASE_URL}/cash/remittances/confirm`, { 
                transactionIds: cleanTransactionIds,
                paidAmount: paidAmount, 
                validated_by: CURRENT_USER_ID 
            });
            showNotification(res.data.message);
            confirmAmountModal.hide();
            remittanceDetailsModal.hide();
            applyFiltersAndRender();
        } catch (error) { 
            showNotification(error.response?.data?.message || "Erreur.", "danger"); 
        }
    };
    
    const handleEditRemittanceAmount = (target) => {
        transactionIdToEdit = target.dataset.id;
        const oldAmount = target.dataset.amount;
        editRemittanceAmountInput.value = oldAmount;
        editRemittanceAmountModal.show();
    };

    const handleEditRemittanceSubmit = async (e) => {
        e.preventDefault();
        const newAmount = editRemittanceAmountInput.value;
        
        if (newAmount === '' || isNaN(newAmount) || parseFloat(newAmount) < 0) {
            showNotification("Veuillez entrer un montant valide.", "warning");
            return;
        }

        try {
            await axios.put(`${API_BASE_URL}/orders/${transactionIdToEdit}/amount`, { amount: newAmount });
            showNotification("Montant de la commande mis à jour.");
            editRemittanceAmountModal.hide(); 
            remittanceDetailsModal.hide();
            applyFiltersAndRender();
        } catch (error) {
            showNotification(error.response?.data?.message || "Erreur lors de la modification.", "danger");
        }
    };

    const handleSettleShortfall = (target) => {
        shortfallToSettle = { id: target.dataset.id, amountDue: parseFloat(target.dataset.amount) };
        shortfallDueDisplay.textContent = formatAmount(shortfallToSettle.amountDue);
        settleShortfallAmountInput.value = shortfallToSettle.amountDue;
        settleShortfallModal.show();
    };
    
    const handleSettleShortfallSubmit = async (e) => {
        e.preventDefault();
        const amountPaid = settleShortfallAmountInput.value;
        
        if (!shortfallToSettle || amountPaid === '' || isNaN(amountPaid) || parseFloat(amountPaid) <= 0) {
            showNotification("Veuillez entrer un montant de règlement valide.", "warning");
            return;
        }

        try {
            await axios.put(`${API_BASE_URL}/cash/shortfalls/${shortfallToSettle.id}/settle`, { amount: parseFloat(amountPaid), userId: CURRENT_USER_ID });
            showNotification("Règlement enregistré.");
            settleShortfallModal.hide();
            applyFiltersAndRender();
            shortfallToSettle = null;
        } catch (error) { 
            showNotification(error.response?.data?.message || "Erreur lors du règlement.", "danger"); 
        }
    };

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

    const resetModalForms = () => {
        const today = new Date().toISOString().slice(0, 10);
        if (expenseDateInput) expenseDateInput.value = today;
        if (withdrawalDateInput) withdrawalDateInput.value = today;
        if (expenseUserSearchResults) expenseUserSearchResults.classList.add('d-none');
    };
    
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
        
        document.body.addEventListener('click', (e) => {
            if (!expenseUserSearchResults.contains(e.target) && e.target !== expenseUserSearchInput) {
                expenseUserSearchResults.classList.add('d-none');
            }
        });
    };
    
    const initializeEventListeners = () => {
        sidebarToggler.addEventListener('click', () => {
            sidebar.classList.toggle('collapsed');
            mainContent.classList.toggle('expanded');
        });
        
        logoutBtn.addEventListener('click', () => {
            localStorage.removeItem('user');
            sessionStorage.removeItem('user');
            window.location.href = 'index.html';
        });

        filterBtn.addEventListener('click', applyFiltersAndRender);
        globalSearchInput.addEventListener('input', debounce(applyFiltersAndRender));
        document.querySelectorAll('#cashTabs .nav-link').forEach(tab => tab.addEventListener('shown.bs.tab', applyFiltersAndRender));

        if (confirmAmountForm) confirmAmountForm.addEventListener('submit', handleAmountConfirmationSubmit);
        if (editRemittanceForm) editRemittanceForm.addEventListener('submit', handleEditRemittanceSubmit);
        if (settleShortfallForm) settleShortfallForm.addEventListener('submit', handleSettleShortfallSubmit);

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

        expenseForm.addEventListener('submit', handleTransactionFormSubmit(expenseForm, 'expense', "Dépense enregistrée."));
        withdrawalForm.addEventListener('submit', handleTransactionFormSubmit(withdrawalForm, 'withdrawal', "Décaissement enregistré."));
        editExpenseForm.addEventListener('submit', handleEditFormSubmit('Expense'));
        editWithdrawalForm.addEventListener('submit', handleEditFormSubmit('Withdrawal'));

        document.body.addEventListener('click', (e) => {
            const target = e.target.closest('button, a');
            if (!target) return;

            const actions = {
                '.details-btn': () => handleRemittanceDetails(target.dataset.id, target.dataset.name),
                '.settle-btn': () => handleSettleShortfall(target),
                '.edit-tx-btn': () => handleEditTransaction(target),
                '.delete-tx-btn': () => handleDeleteTransaction(target),
                '.edit-remittance-btn': () => handleEditRemittanceAmount(target),
                '.confirm-single-remittance-btn': () => handleConfirmSingleRemittance(target),
            };

            for (const selector in actions) {
                if (target.matches(selector)) {
                    if (target.tagName === 'A' && target.getAttribute('href') === '#') {
                        e.preventDefault();
                    }
                    actions[selector]();
                    break;
                }
            }
        });
        
        confirmBatchBtn.addEventListener('click', handleConfirmBatch);

        document.querySelectorAll('input[name="detailsFilter"]').forEach(radio => {
            radio.addEventListener('change', (e) => {
                renderRemittanceDetails(e.target.value);
            });
        });
        
        setupUserSearchExpense();
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
        
        try {
            await fetchInitialData();
            applyFiltersAndRender();
            fetchClosingHistory();
        } catch (error) {
            console.error("Erreur à l'initialisation de l'application", error);
        }
    };

    initializeApp();
});