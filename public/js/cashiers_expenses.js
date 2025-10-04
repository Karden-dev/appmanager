// js/cashiers_expenses.js
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

    const expensesTableBody = document.getElementById('expensesTableBody');
    const withdrawalsTableBody = document.getElementById('withdrawalsTableBody');

    const addExpenseModal = new bootstrap.Modal(document.getElementById('addExpenseModal'));
    const manualWithdrawalModal = new bootstrap.Modal(document.getElementById('manualWithdrawalModal'));
    const editExpenseModal = new bootstrap.Modal(document.getElementById('editExpenseModal'));
    const editWithdrawalModal = new bootstrap.Modal(document.getElementById('editWithdrawalModal'));

    const expenseForm = document.getElementById('expenseForm');
    const expenseDateInput = document.getElementById('expenseDate');
    const expenseUserSelect = document.getElementById('expenseUserSelect');
    const expenseCategorySelect = document.getElementById('expenseCategorySelect');
    
    const withdrawalForm = document.getElementById('withdrawalForm');
    const withdrawalDateInput = document.getElementById('withdrawalDate');
    const editExpenseForm = document.getElementById('editExpenseForm');
    const editWithdrawalForm = document.getElementById('editWithdrawalForm');
    
    // Références Cartes Statistiques
    const dbTotalExpenses = document.getElementById('db-total-expenses');
    const dbTotalWithdrawals = document.getElementById('db-total-withdrawals');

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

    // --- FONCTIONS DE CHARGEMENT DES DONNÉES ---
    
    /**
     * Récupère et met à jour les métriques pour les cartes statistiques.
     * @param {string} startDate - Date de début.
     * @param {string} endDate - Date de fin.
     */
    const fetchExpenseMetrics = async (startDate, endDate) => {
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/metrics`, { params: { startDate, endDate } });
            
            dbTotalExpenses.textContent = formatAmount(res.data.total_expenses);
            dbTotalWithdrawals.textContent = formatAmount(res.data.total_withdrawals);
        } catch (error) {
            console.error("Erreur de chargement des métriques des dépenses:", error);
            dbTotalExpenses.textContent = "0 FCFA";
            dbTotalWithdrawals.textContent = "0 FCFA";
        }
    };


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
        
        // Mettre à jour les métriques pour la période sélectionnée (non-dynamique)
        fetchExpenseMetrics(startDate, endDate);

        if (targetPanelId === '#expenses-panel') {
            fetchAndRenderTransactions('expense', expensesTableBody, startDate, endDate, search);
        } else {
            fetchAndRenderTransactions('manual_withdrawal', withdrawalsTableBody, startDate, endDate, search);
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
            
            // Peupler la liste des utilisateurs
            expenseUserSelect.innerHTML = '<option value="">Sélectionner un utilisateur</option>';
            usersCache.forEach(u => expenseUserSelect.innerHTML += `<option value="${u.id}">${u.name}</option>`);

            // Peupler la liste des catégories
            expenseCategorySelect.innerHTML = '<option value="">Sélectionner une catégorie</option>';
            categoriesCache.forEach(cat => expenseCategorySelect.innerHTML += `<option value="${cat.id}">${cat.name}</option>`);
        } catch (error) {
            showNotification("Erreur de chargement des données de base.", "danger");
        }
    };
    
    // --- GESTION DES ÉVÉNEMENTS ---

    /**
     * Initialise les écouteurs d'événements de l'interface.
     */
    const initializeEventListeners = () => {
        // Menu latéral et déconnexion
        sidebarToggler.addEventListener('click', () => {
            sidebar.classList.toggle('collapsed');
            mainContent.classList.toggle('expanded');
        });
        
        logoutBtn.addEventListener('click', () => {
            localStorage.removeItem('user');
            sessionStorage.removeItem('user');
            window.location.href = 'index.html';
        });

        highlightActiveLink();
        
        // Filtres (déclenché par le bouton)
        filterBtn.addEventListener('click', applyFiltersAndRender);
        globalSearchInput.addEventListener('input', debounce(applyFiltersAndRender));
        
        document.querySelectorAll('#cashTabs .nav-link').forEach(tab => tab.addEventListener('shown.bs.tab', applyFiltersAndRender));
        
        // Soumission de formulaires d'ajout
        expenseForm.addEventListener('submit', async e => {
            e.preventDefault();
            try {
                await axios.post(`${API_BASE_URL}/cash/expense`, {
                    user_id: expenseUserSelect.value,
                    created_at: expenseDateInput.value,
                    category_id: expenseCategorySelect.value,
                    amount: document.getElementById('expenseAmountInput').value,
                    comment: document.getElementById('expenseCommentInput').value
                });
                showNotification("Dépense enregistrée.");
                addExpenseModal.hide();
                expenseForm.reset();
                resetModalDates();
                applyFiltersAndRender();
            } catch (error) { showNotification(error.response?.data?.message || "Erreur.", "danger"); }
        });

        withdrawalForm.addEventListener('submit', async e => {
            e.preventDefault();
            try {
                await axios.post(`${API_BASE_URL}/cash/withdrawal`, {
                    amount: document.getElementById('withdrawalAmountInput').value,
                    created_at: document.getElementById('withdrawalDate').value,
                    comment: document.getElementById('withdrawalCommentInput').value,
                    user_id: CURRENT_USER_ID
                });
                showNotification("Décaissement enregistré.");
                manualWithdrawalModal.hide();
                withdrawalForm.reset();
                resetModalDates();
                applyFiltersAndRender();
            } catch (error) { showNotification(error.response?.data?.message || "Erreur.", "danger"); }
        });
        
        // Soumission de formulaires d'édition
        editExpenseForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const amount = document.getElementById('editExpenseAmount').value;
            const comment = document.getElementById('editExpenseComment').value;
            try {
                await axios.put(`${API_BASE_URL}/cash/transactions/${transactionIdToEdit}`, { amount, comment });
                showNotification("Dépense modifiée.");
                editExpenseModal.hide();
                applyFiltersAndRender();
            } catch (error) { showNotification("Erreur de modification.", 'danger'); }
        });

        editWithdrawalForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const amount = document.getElementById('editWithdrawalAmount').value;
            const comment = document.getElementById('editWithdrawalComment').value;
            try {
                await axios.put(`${API_BASE_URL}/cash/transactions/${transactionIdToEdit}`, { amount, comment });
                showNotification("Décaissement modifié.");
                editWithdrawalModal.hide();
                applyFiltersAndRender();
            } catch (error) { showNotification("Erreur de modification.", 'danger'); }
        });

        // Actions du tableau (édition/suppression)
        document.body.addEventListener('click', async (e) => {
            const target = e.target.closest('button, a');
            if (!target) return;

            if (target.matches('.edit-tx-btn')) {
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
            }

            if (target.matches('.delete-tx-btn')) {
                const txId = target.dataset.id;
                if (confirm('Voulez-vous vraiment supprimer cette transaction ?')) {
                    try {
                        await axios.delete(`${API_BASE_URL}/cash/transactions/${txId}`);
                        showNotification('Transaction supprimée.');
                        applyFiltersAndRender();
                    } catch (error) { showNotification("Erreur de suppression.", "danger"); }
                }
            }
        });
        
        // Réinitialiser les dates modales à l'ouverture
        document.getElementById('addExpenseModal').addEventListener('show.bs.modal', resetModalDates);
        document.getElementById('manualWithdrawalModal').addEventListener('show.bs.modal', resetModalDates);
    };
    
    /**
     * Réinitialise les champs de date dans les formulaires modales à la date du jour.
     */
    const resetModalDates = () => {
        const today = new Date().toISOString().slice(0, 10);
        if (expenseDateInput) expenseDateInput.value = today;
        if (withdrawalDateInput) withdrawalDateInput.value = today;
    };
    
    // --- Lancement de la page ---
    const initializeApp = async () => {
        const today = new Date().toISOString().slice(0, 10);
        startDateInput.value = today;
        endDateInput.value = today;
        
        initializeEventListeners();
        
        await fetchInitialData();
        applyFiltersAndRender();
    };

    initializeApp();
});