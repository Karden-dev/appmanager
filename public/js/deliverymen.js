// js/deliverymen.js
document.addEventListener('DOMContentLoaded', () => {
    // --- CONSTANTES ET VARIABLES ---
  const API_BASE_URL = 'http://localhost:3000';    
    // Simulation de la récupération de l'utilisateur connecté
    const storedUser = localStorage.getItem('user') || sessionStorage.getItem('user');
    const user = storedUser ? JSON.parse(storedUser) : { id: 1, name: 'Admin Test', token: 'mock-token' };
    
    // Configuration d'axios
    if (user.token) {
        axios.defaults.headers.common['Authorization'] = `Bearer ${user.token}`;
    }

    // Références DOM
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const logoutBtn = document.getElementById('logoutBtn');
    
    const tableBody = document.getElementById('deliverymenTableBody');
    const startDateInput = document.getElementById('startDate');
    const endDateInput = document.getElementById('endDate');
    const searchInput = document.getElementById('searchInput');
    const filterBtn = document.getElementById('filterBtn');

    // Mise à jour de l'UI avec le nom de l'utilisateur
    if (document.getElementById('userName')) document.getElementById('userName').textContent = user.name;
    if (document.getElementById('headerUserName')) document.getElementById('headerUserName').textContent = user.name;


    // --- FONCTIONS UTILITAIRES ---

    /**
     * Retourne la date du jour au format AAAA-MM-JJ.
     * @returns {string} La date du jour.
     */
    const getTodayDate = () => new Date().toISOString().split('T')[0];
    
    /**
     * Formate un montant en FCFA avec séparateur de milliers.
     * @param {number|string} amount - Le montant à formater.
     * @returns {string} Le montant formaté.
     */
    const formatAmount = (amount) => {
        return parseFloat(amount || 0).toLocaleString('fr-FR') + ' FCFA';
    };

    /**
     * Fonction Debounce : retarde l'exécution d'une fonction.
     * @param {Function} func - La fonction à exécuter après le délai.
     * @param {number} [delay=400] - Le délai d'attente en millisecondes.
     * @returns {Function} La nouvelle fonction "debounced".
     */
    const debounce = (func, delay = 400) => {
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

    // --- FONCTIONS PRINCIPALES ---

    /**
     * Récupère les données de performance et met à jour l'interface (cartes et tableau).
     */
    const updateData = async () => {
        const startDate = startDateInput.value;
        const endDate = endDateInput.value;
        const searchQuery = searchInput.value;
        
        const params = new URLSearchParams();
        if (startDate) params.append('startDate', startDate);
        if (endDate) params.append('endDate', endDate);
        if (searchQuery) params.append('search', searchQuery);
        
        try {
            tableBody.innerHTML = '<tr><td colspan="6" class="text-center p-5"><div class="spinner-border text-primary-custom" role="status"><span class="visually-hidden">Chargement...</span></div></td></tr>';

            const [statsRes, perfRes] = await Promise.all([
                axios.get(`${API_BASE_URL}/deliverymen/stats?${params.toString()}`),
                axios.get(`${API_BASE_URL}/deliverymen/performance?${params.toString()}`)
            ]);

            // Mise à jour des cartes de statistiques
            const stats = statsRes.data;
            document.getElementById('total-deliverymen').textContent = stats.total || 0;
            document.getElementById('working-deliverymen').textContent = stats.working || 0;
            document.getElementById('absent-deliverymen').textContent = stats.absent || 0;
            document.getElementById('availability-rate').textContent = `${parseFloat(stats.availability_rate || 0).toFixed(0)}%`;
            document.getElementById('received-courses').textContent = stats.received || 0;
            document.getElementById('inprogress-courses').textContent = stats.in_progress || 0;
            document.getElementById('delivered-courses').textContent = stats.delivered || 0;
            document.getElementById('canceled-courses').textContent = stats.cancelled || 0;

            // Mise à jour du tableau de performance
            renderDeliverymenTable(perfRes.data);

        } catch (error) {
            console.error("Erreur lors de la mise à jour des données:", error);
            tableBody.innerHTML = '<tr><td colspan="6" class="text-center text-danger p-4">Erreur lors du chargement des données.</td></tr>';
        }
    };

    /**
     * Génère et affiche les lignes du tableau de performance des livreurs.
     * @param {Array<Object>} deliverymen - Liste des livreurs avec leurs statistiques.
     */
    const renderDeliverymenTable = (deliverymen) => {
        tableBody.innerHTML = '';
        if (deliverymen.length === 0) {
            tableBody.innerHTML = '<tr><td colspan="6" class="text-center p-4">Aucun livreur trouvé pour les filtres sélectionnés.</td></tr>';
            return;
        }
        
        deliverymen.forEach((livreur, index) => {
            const row = document.createElement('tr');
            const revenue = formatAmount(livreur.total_revenue);
            
            let distinction = '';
            if (index === 0) distinction = '<span class="distinction"><i class="bi bi-trophy-fill distinction-icon gold"></i></span>';
            else if (index === 1) distinction = '<span class="distinction"><i class="bi bi-trophy-fill distinction-icon silver"></i></span>';
            else if (index === 2) distinction = '<span class="distinction"><i class="bi bi-trophy-fill distinction-icon bronze"></i></span>';
            else distinction = `<span class="distinction text-muted">#${index + 1}</span>`;
            
            row.innerHTML = `
                <td>${distinction}${livreur.name}</td>
                <td>${livreur.received_orders || 0}</td>
                <td class="text-warning fw-bold">${livreur.in_progress_orders || 0}</td>
                <td class="text-danger fw-bold">${livreur.cancelled_orders || 0}</td>
                <td class="text-success fw-bold">${livreur.delivered_orders || 0}</td>
                <td class="text-end">${revenue}</td>`;
            tableBody.appendChild(row);
        });
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
        
        // Filtres
        filterBtn.addEventListener('click', updateData);
        searchInput.addEventListener('input', debounce(updateData));
        startDateInput.addEventListener('change', updateData);
        endDateInput.addEventListener('change', updateData);
    };

    // --- INITIALISATION ---
    
    /**
     * Initialise l'application.
     */
    const initializeApp = () => {
        // Initialisation des filtres de date par défaut (aujourd'hui)
        startDateInput.value = getTodayDate();
        endDateInput.value = getTodayDate();
        
        initializeEventListeners();
        highlightActiveLink();
        updateData();
    };

    initializeApp();
});