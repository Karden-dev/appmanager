// js/dashboard.js
document.addEventListener('DOMContentLoaded', () => {
    // --- CONFIGURATION ---
    const API_BASE_URL = 'http://localhost:3000';
    // Simulation de la récupération de l'utilisateur connecté
    const storedUser = localStorage.getItem('user') || sessionStorage.getItem('user');
    const user = storedUser ? JSON.parse(storedUser) : { id: 1, name: 'Admin Test', token: 'mock-token' };
    
    // Configuration d'axios (si nécessaire, ici l'appel n'est pas fait car cet ID n'est pas nécessaire pour le script, mais conservé pour la cohérence)
    if (user.token) {
        axios.defaults.headers.common['Authorization'] = `Bearer ${user.token}`;
    }

    // --- État des graphiques ---
    let revenueChart, statusChart;
    
    // --- Références DOM ---
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const logoutBtn = document.getElementById('logoutBtn');
    const applyFilterBtn = document.getElementById('applyFilterBtn');

    const startDateInput = document.getElementById('startDate');
    const endDateInput = document.getElementById('endDate');

    // Références pour les cartes
    const caNetDisplay = document.getElementById('caNet');
    const totalExpensesDisplay = document.getElementById('totalExpenses');
    const soldeNetDisplay = document.getElementById('soldeNet');
    const totalDeliveryFeesDisplay = document.getElementById('totalDeliveryFees');
    const totalCoursesSentDisplay = document.getElementById('totalCoursesSentDisplay');
    const rankingTableBody = document.getElementById('rankingTableBody');
    
    // Mise à jour de l'UI avec le nom de l'utilisateur
    if (document.getElementById('userName')) document.getElementById('userName').textContent = user.name;
    if (document.getElementById('headerUserName')) document.getElementById('headerUserName').textContent = user.name;


    // --- FONCTIONS UTILITAIRES ---
    
    /**
     * Formate un montant en FCFA avec séparateur de milliers.
     * @param {number|string} amount - Le montant à formater.
     * @returns {string} Le montant formaté.
     */
    const formatAmount = (amount) => {
        return parseFloat(amount || 0).toLocaleString('fr-FR') + ' FCFA';
    };

    /**
     * Définit la plage de dates par défaut (7 derniers jours).
     */
    const setDefaultDateRange = () => {
        const today = moment().format('YYYY-MM-DD');
        const lastWeek = moment().subtract(7, 'days').format('YYYY-MM-DD');
        
        startDateInput.value = lastWeek;
        endDateInput.value = today;
    };
    
    /**
     * Affiche les données du classement des marchands dans le tableau.
     * @param {Array<Object>} ranking - Liste des marchands.
     */
    const renderRankingTable = (ranking) => {
        rankingTableBody.innerHTML = '';
        if (ranking.length === 0) {
            rankingTableBody.innerHTML = `<tr><td colspan="5" class="text-center p-3">Aucun marchand classé pour cette période.</td></tr>`;
            return;
        }

        ranking.forEach((shop, index) => {
            const row = document.createElement('tr');
            let rankIcon;
            if (index === 0) rankIcon = '<i class="bi bi-trophy-fill rank-icon text-warning-dark"></i>';
            else if (index === 1) rankIcon = '<i class="bi bi-award-fill rank-icon text-info-dark"></i>';
            else if (index === 2) rankIcon = '<i class="bi bi-gem rank-icon text-success-dark"></i>';
            else rankIcon = `<span class="rank-icon text-muted">${index + 1}</span>`;

            row.innerHTML = `
                <td>${rankIcon}</td>
                <td>${shop.shop_name}</td>
                <td>${shop.orders_sent_count}</td>
                <td>${shop.orders_processed_count}</td>
                <td class="text-end fw-bold">${formatAmount(shop.total_delivery_fees_generated)}</td>
            `;
            rankingTableBody.appendChild(row);
        });
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

    // --- FONCTIONS PRINCIPALES ---
    
    /**
     * Récupère les données agrégées du backend et met à jour les cartes/graphiques.
     */
    const updateDashboard = async () => {
        const startDate = startDateInput.value;
        const endDate = endDateInput.value;

        if (!startDate || !endDate) return;

        try {
            // Afficher le chargement
            caNetDisplay.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
            totalExpensesDisplay.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
            soldeNetDisplay.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
            totalDeliveryFeesDisplay.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
            
            const response = await axios.get(`${API_BASE_URL}/dashboard/stats`, { 
                params: { startDate, endDate } 
            });
            
            const { metrics, ranking } = response.data;

            // 1. Mise à jour des cartes de Métriques Financières
            caNetDisplay.innerHTML = `<i class="bi bi-cash-stack card-stat-icon text-primary-dark"></i> ${formatAmount(metrics.ca_net)}`;
            totalExpensesDisplay.innerHTML = `<i class="bi bi-arrow-down-left-square card-stat-icon text-danger-dark"></i> ${formatAmount(metrics.total_expenses)}`;
            soldeNetDisplay.innerHTML = `<i class="bi bi-wallet2 card-stat-icon text-success-dark"></i> ${formatAmount(metrics.solde_net)}`;
            totalDeliveryFeesDisplay.innerHTML = `<i class="bi bi-truck card-stat-icon text-info-dark"></i> ${formatAmount(metrics.total_delivery_fees)}`;
            
            // 2. Mise à jour du classement des partenaires
            renderRankingTable(ranking);

            // 3. Mise à jour du graphique des statuts
            updateStatusChart(metrics);

            // 4. Mettre à jour le graphique (Revenu Journalier)
            // Simulation de données journalières pour l'exemple
            const simulatedDates = [];
            const simulatedRevenue = [];
            let currentDate = moment(startDate);
            const stopDate = moment(endDate);
            let totalDays = 0;
            while (currentDate.isSameOrBefore(stopDate, 'day')) {
                totalDays++;
                currentDate.add(1, 'days');
            }

            currentDate = moment(startDate);
            while (currentDate.isSameOrBefore(stopDate, 'day')) {
                simulatedDates.push(currentDate.format('YYYY-MM-DD'));
                // Simuler un revenu quotidien variant autour d'une moyenne
                simulatedRevenue.push((metrics.total_delivery_fees / totalDays) + (Math.random() * metrics.total_delivery_fees * 0.1 / totalDays));
                currentDate.add(1, 'days');
            }

            updateRevenueChart(simulatedDates, simulatedRevenue);


        } catch (error) {
            console.error("Erreur lors de la récupération des données du tableau de bord:", error);
            caNetDisplay.innerHTML = `
                <i class="bi bi-exclamation-triangle-fill text-danger"></i> Erreur
            `;
            // Affichage d'erreur pour les autres cartes (simplifié)
            totalExpensesDisplay.innerHTML = 'Erreur';
            soldeNetDisplay.innerHTML = 'Erreur';
            totalDeliveryFeesDisplay.innerHTML = 'Erreur';
        }
    };
    
    /**
     * Met à jour le graphique circulaire de distribution des statuts.
     * @param {Object} metrics - Les données métriques.
     */
    const updateStatusChart = (metrics) => {
        if (statusChart) statusChart.destroy();
        
        const totalSent = metrics.total_sent;
        totalCoursesSentDisplay.textContent = `Total : ${totalSent} commandes envoyées`;

        if (totalSent === 0) return;

        const data = {
            labels: ['Livrée', 'En Cours', 'Annulée/Échouée/Reportée'],
            datasets: [{
                data: [metrics.total_delivered, metrics.total_in_progress, metrics.total_failed_cancelled],
                backgroundColor: [
                    'rgba(40, 167, 69, 0.8)', // Vert
                    'rgba(255, 193, 7, 0.8)',  // Jaune
                    'rgba(220, 53, 69, 0.8)'   // Rouge
                ],
                hoverOffset: 4
            }]
        };

        statusChart = new Chart(document.getElementById('statusChart'), {
            type: 'doughnut',
            data: data,
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                    },
                    title: {
                        display: true,
                        text: 'Taux de Traitement des Courses'
                    }
                }
            }
        });
    };

    /**
     * Met à jour le graphique d'évolution du revenu.
     * @param {Array<string>} labels - Étiquettes de date (jours).
     * @param {Array<number>} data - Données de revenu par jour.
     */
    const updateRevenueChart = (labels, data) => {
         if (revenueChart) revenueChart.destroy();

        const corailColor = 'rgb(255, 127, 80)';

        revenueChart = new Chart(document.getElementById('revenueChart'), {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Frais de Livraison (XAF)',
                    data: data,
                    borderColor: corailColor,
                    backgroundColor: 'rgba(255, 127, 80, 0.2)',
                    tension: 0.3,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    };
    
    /**
     * Initialise les écouteurs d'événements et la vue de départ.
     */
    const initializeApp = () => {
        // Définir la plage de dates par défaut (7 derniers jours)
        setDefaultDateRange();
        
        highlightActiveLink();

        // Logique du menu rétractable et de la déconnexion
        sidebarToggler.addEventListener('click', () => {
            sidebar.classList.toggle('collapsed');
            mainContent.classList.toggle('expanded');
        });

        logoutBtn.addEventListener('click', () => {
            localStorage.removeItem('user');
            sessionStorage.removeItem('user');
            window.location.href = 'index.html';
        });

        // Écouteur pour le bouton Appliquer les filtres
        applyFilterBtn.addEventListener('click', updateDashboard);
        
        // Lancement du chargement initial
        updateDashboard();
    };
    
    initializeApp();
});