// js/cashiers_closings.js
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

    // --- RÉFÉRENCES DOM ---
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const logoutBtn = document.getElementById('logoutBtn');
    
    const closingsHistoryTableBody = document.getElementById('closingsHistoryTableBody');
    const closeCashForm = document.getElementById('closeCashForm');
    
    // Références pour les cartes de métriques
    const dbTotalCollected = document.getElementById('db-total-collected');
    const dbTotalExpenses = document.getElementById('db-total-expenses');
    const dbTotalWithdrawals = document.getElementById('db-total-withdrawals');
    const dbCashOnHand = document.getElementById('db-cash-on-hand');
    const dbPaidDebts = document.getElementById('db-paid-debts'); // NOUVEAU
    
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

    // --- FONCTIONS PRINCIPALES ---

    /**
     * Récupère les métriques globales de la caisse pour la période donnée et met à jour les cartes.
     * @param {string} startDate - Date de début.
     * @param {string} endDate - Date de fin.
     */
    const fetchCashMetrics = async (startDate, endDate) => {
        try {
            // L'API est supposée retourner les données des créances remboursées sous 'total_paid_debts'
            const res = await axios.get(`${API_BASE_URL}/cash/metrics`, { params: { startDate, endDate } });
            
            dbTotalCollected.textContent = formatAmount(res.data.total_collected);
            dbTotalExpenses.textContent = formatAmount(res.data.total_expenses);
            dbTotalWithdrawals.textContent = formatAmount(res.data.total_withdrawals);
            dbPaidDebts.textContent = formatAmount(res.data.total_paid_debts); // MISE À JOUR
            dbCashOnHand.textContent = formatAmount(res.data.cash_on_hand);

        } catch (error) {
            console.error("Erreur de chargement des métriques:", error);
            dbTotalCollected.textContent = "0 FCFA";
            dbTotalExpenses.textContent = "0 FCFA";
            dbTotalWithdrawals.textContent = "0 FCFA";
            dbPaidDebts.textContent = "0 FCFA";
            dbCashOnHand.textContent = "0 FCFA";
        }
    };
    
    /**
     * Récupère et affiche l'historique des clôtures de caisse.
     */
    const fetchClosingHistory = async () => {
        const historyStartDate = document.getElementById('historyStartDate').value;
        const historyEndDate = document.getElementById('historyEndDate').value;
        try {
            const res = await axios.get(`${API_BASE_URL}/cash/closing-history`, { params: { startDate: historyStartDate, endDate: historyEndDate } });
            closingsHistoryTableBody.innerHTML = '';
            if (res.data.length === 0) {
                closingsHistoryTableBody.innerHTML = `<tr><td colspan="5" class="text-center p-3">Aucun historique.</td></tr>`;
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
                    <td>
                        <button class="btn btn-sm btn-outline-success export-single-closing-btn" data-id="${item.id}" title="Exporter ce rapport"><i class="bi bi-file-earmark-spreadsheet"></i></button>
                    </td>
                `;
                closingsHistoryTableBody.appendChild(row);
            });
        } catch (error) {
            closingsHistoryTableBody.innerHTML = `<tr><td colspan="5" class="text-center text-danger">Erreur de chargement.</td></tr>`;
        }
    };

    /**
     * Initialise tous les écouteurs d'événements de l'interface.
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

        // Filtres et événements du tableau d'historique
        document.getElementById('historyStartDate').addEventListener('change', fetchClosingHistory);
        document.getElementById('historyEndDate').addEventListener('change', fetchClosingHistory);
        document.getElementById('exportHistoryBtn').addEventListener('click', () => {
            const startDate = document.getElementById('historyStartDate').value;
            const endDate = document.getElementById('historyEndDate').value;
            window.open(`${API_BASE_URL}/cash/closing-history/export?startDate=${startDate}&endDate=${endDate}`, '_blank');
        });

        // Soumission du formulaire de clôture
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
                fetchClosingHistory();
                const today = new Date().toISOString().slice(0, 10);
                fetchCashMetrics(today, today);
            } catch(error) { showNotification(error.response?.data?.message || "Erreur.", "danger"); }
        });
    };
    
    /**
     * Initialise l'application : met les dates par défaut, les écouteurs et charge les données.
     */
    const initializeApp = () => {
        const today = new Date().toISOString().slice(0, 10);
        document.getElementById('closeDate').value = today;
        // Plage d'historique par défaut : 30 derniers jours
        document.getElementById('historyStartDate').value = moment().subtract(30, 'days').format('YYYY-MM-DD');
        document.getElementById('historyEndDate').value = today;
        
        initializeEventListeners();
        highlightActiveLink();
        
        // Charger les métriques et l'historique pour la date du jour
        fetchCashMetrics(today, today);
        fetchClosingHistory();
    };

    initializeApp();
});