// js/shops.js

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
    const shopsTableBody = document.getElementById('shopsTableBody');
    const shopModal = new bootstrap.Modal(document.getElementById('shopModal'));
    const detailsModal = new bootstrap.Modal(document.getElementById('detailsModal'));
    const shopForm = document.getElementById('shopForm');
    const searchInput = document.getElementById('searchInput');
    const shopModalLabel = document.getElementById('shopModalLabel');
    const shopSubmitBtn = document.getElementById('shopSubmitBtn');
    
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const logoutBtn = document.getElementById('logoutBtn');
    
    // Mise à jour de l'UI avec le nom de l'utilisateur
    if (document.getElementById('userName')) document.getElementById('userName').textContent = user.name;
    if (document.getElementById('headerUserName')) document.getElementById('headerUserName').textContent = user.name;
    
    // --- ÉTAT LOCAL ---
    let isEditMode = false;
    let currentShopId = null;

    // --- FONCTIONS UTILITAIRES ---
    
    /**
     * Affiche une notification toast stylisée (version simplifiée).
     * @param {string} message - Le message à afficher.
     * @param {string} [type='success'] - Le type d'alerte (success, danger, warning, info).
     */
    const showNotification = (message, type = 'success') => {
        const container = document.getElementById('notification-container');
        const alert = document.createElement('div');
        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.role = 'alert';
        alert.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;
        container.appendChild(alert);
        
        setTimeout(() => {
            const bsAlert = bootstrap.Alert.getOrCreateInstance(alert);
            bsAlert.close();
        }, 4000); 
    };

    /**
     * Formate une chaîne de date en format lisible (ex: 20 mai 2025).
     * @param {string} dateString - La date brute.
     * @returns {string} La date formatée.
     */
    const formatDate = (dateString) => new Date(dateString).toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' });
    
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
     * Récupère les statistiques et la liste des marchands, puis met à jour l'interface.
     */
    const fetchData = async () => {
        try {
            // 1. Fetch stats
            const statsResponse = await axios.get(`${API_BASE_URL}/shops/stats`);
            document.getElementById('totalShops').textContent = statsResponse.data.total || 0;
            document.getElementById('activeShops').textContent = statsResponse.data.active || 0;
            document.getElementById('inactiveShops').textContent = statsResponse.data.inactive || 0;

            // 2. Fetch shops list with filters
            const statusFilter = document.querySelector('input[name="statusFilter"]:checked').value;
            const searchQuery = searchInput.value;
            const params = new URLSearchParams();
            if (statusFilter) params.append('status', statusFilter);
            if (searchQuery) params.append('search', searchQuery);
            
            shopsTableBody.innerHTML = `<tr><td colspan="6" class="text-center p-4"><div class="spinner-border text-primary-custom" role="status"><span class="visually-hidden">Chargement...</span></div></td></tr>`;

            const response = await axios.get(`${API_BASE_URL}/shops?${params.toString()}`);
            renderTable(response.data);
        } catch (error) {
            console.error("Erreur lors de la récupération des données:", error);
            shopsTableBody.innerHTML = `<tr><td colspan="6" class="text-center text-danger p-4">Erreur de chargement des marchands.</td></tr>`;
            showNotification("Impossible de charger les données des marchands.", "danger");
        }
    };

    /**
     * Génère et affiche le contenu du tableau des marchands.
     * @param {Array<Object>} shops - Liste des objets marchands.
     */
    const renderTable = (shops) => {
        shopsTableBody.innerHTML = '';
        if (shops.length === 0) {
            shopsTableBody.innerHTML = `<tr><td colspan="6" class="text-center p-4">Aucun marchand ne correspond à votre recherche.</td></tr>`;
            return;
        }
        shops.forEach(shop => {
            const row = document.createElement('tr');
            row.className = shop.status === 'inactif' ? 'inactive-row' : '';

            const statusClass = shop.status === 'actif' ? 'active' : 'inactive';
            const statusText = shop.status === 'actif' ? 'Actif' : 'Inactif';
            const statusDisplay = `<span class="status-dot ${statusClass}"></span> ${statusText}`;

            const packagingIcon = shop.bill_packaging 
                ? '<i class="bi bi-check-circle-fill billing-icon active"></i>' 
                : '<i class="bi bi-x-circle-fill billing-icon inactive"></i>';
            const storageIcon = shop.bill_storage 
                ? '<i class="bi bi-check-circle-fill billing-icon active"></i>' 
                : '<i class="bi bi-x-circle-fill billing-icon inactive"></i>';

            const toggleStatusBtn = shop.status === 'actif'
                ? `<button class="btn btn-sm btn-outline-warning status-btn" data-id="${shop.id}" data-status="inactif" title="Désactiver"><i class="bi bi-toggle-off"></i></button>`
                : `<button class="btn btn-sm btn-outline-success status-btn" data-id="${shop.id}" data-status="actif" title="Activer"><i class="bi bi-toggle-on"></i></button>`;

            row.innerHTML = `
                <td>${shop.name}</td>
                <td>${shop.phone_number}</td>
                <td class="text-center">${packagingIcon}</td>
                <td class="text-center">${storageIcon}</td>
                <td class="text-center">${statusDisplay}</td>
                <td class="text-center">
                    <div class="d-flex justify-content-center gap-2">
                        <button class="btn btn-sm btn-outline-info details-btn" data-id="${shop.id}" title="Détails"><i class="bi bi-eye"></i></button>
                        <button class="btn btn-sm btn-outline-primary edit-btn" data-id="${shop.id}" title="Modifier"><i class="bi bi-pencil"></i></button>
                        ${toggleStatusBtn}
                    </div>
                </td>`;
            shopsTableBody.appendChild(row);
        });
        
        // Initialiser les tooltips Bootstrap
        const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
        tooltipTriggerList.map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));
    };

    // --- GESTION DES ÉVÉNEMENTS ---
    
    /**
     * Gère la soumission du formulaire d'ajout/modification de marchand.
     * @param {Event} e - L'événement de soumission.
     */
    const handleShopFormSubmit = async (e) => {
        e.preventDefault();
        
        const shopData = {
            name: document.getElementById('shopName').value,
            phone_number: document.getElementById('shopPhone').value,
            bill_packaging: document.getElementById('billPackaging').checked,
            bill_storage: document.getElementById('billStorage').checked,
            packaging_price: parseFloat(document.getElementById('packagingPrice').value),
            storage_price: parseFloat(document.getElementById('storagePrice').value),
            created_by: CURRENT_USER_ID
        };
        
        try {
            if (isEditMode) {
                await axios.put(`${API_BASE_URL}/shops/${currentShopId}`, shopData);
                showNotification("Marchand modifié avec succès !");
            } else {
                await axios.post(`${API_BASE_URL}/shops`, shopData);
                showNotification("Marchand ajouté avec succès !");
            }
            shopModal.hide();
            fetchData();
        } catch (error) {
            showNotification(error.response?.data?.message || "Une erreur est survenue lors de l'enregistrement.", "danger");
        }
    };
    
    /**
     * Gère les actions (modifier, désactiver, détails) effectuées sur les lignes du tableau.
     * @param {Event} e - L'événement de clic.
     */
    const handleTableActions = async (e) => {
        const target = e.target.closest('button');
        if (!target) return;
        const shopId = target.dataset.id;

        if (target.classList.contains('edit-btn')) {
            try {
                const response = await axios.get(`${API_BASE_URL}/shops/${shopId}`);
                const shop = response.data;
                isEditMode = true;
                currentShopId = shop.id;
                
                shopModalLabel.textContent = 'Modifier le marchand';
                shopSubmitBtn.textContent = 'Sauvegarder';
                document.getElementById('shopName').value = shop.name;
                document.getElementById('shopPhone').value = shop.phone_number;
                document.getElementById('billPackaging').checked = shop.bill_packaging;
                document.getElementById('billStorage').checked = shop.bill_storage;
                document.getElementById('packagingPrice').value = shop.packaging_price;
                document.getElementById('storagePrice').value = shop.storage_price;
                shopModal.show();
            } catch (error) {
                showNotification("Erreur lors du chargement des données du marchand.", "danger");
            }

        } else if (target.classList.contains('status-btn')) {
            const newStatus = target.dataset.status;
            const actionVerb = newStatus === 'inactif' ? 'désactiver' : 'activer';
            if (confirm(`Voulez-vous vraiment ${actionVerb} ce marchand ?`)) {
                try {
                    await axios.put(`${API_BASE_URL}/shops/${shopId}/status`, { status: newStatus });
                    showNotification(`Marchand ${actionVerb} avec succès.`);
                    fetchData();
                } catch (error) {
                     showNotification("Erreur lors du changement de statut.", "danger");
                }
            }
        } else if (target.classList.contains('details-btn')) {
            try {
                const response = await axios.get(`${API_BASE_URL}/shops/${shopId}`);
                const shop = response.data;
                
                document.getElementById('detailsModalBody').innerHTML = `
                    <p><strong>Nom:</strong> ${shop.name}</p>
                    <p><strong>Téléphone:</strong> ${shop.phone_number}</p>
                    <hr>
                    <p><strong>Statut:</strong> <span class="status-dot ${shop.status === 'actif' ? 'active' : 'inactive'}"></span> ${shop.status === 'actif' ? 'Actif' : 'Inactif'}</p>
                    <p><strong>Créé le:</strong> ${formatDate(shop.created_at)}</p>
                    <p><strong>Créé par:</strong> ${shop.creator_name || 'N/A'}</p>
                    <hr>
                    <p><strong>Facturation Emballage:</strong> ${shop.bill_packaging ? `Oui (${shop.packaging_price} FCFA)` : 'Non'}</p>
                    <p><strong>Facturation Stockage:</strong> ${shop.bill_storage ? `Oui (${shop.storage_price} FCFA/jour)` : 'Non'}</p>
                `;
                detailsModal.show();
            } catch (error) {
                showNotification("Erreur lors du chargement des détails.", "danger");
            }
        }
    };
    
    /**
     * Initialise la page lors du chargement complet du DOM.
     */
    const initializeApp = () => {
        // --- Événements de la Sidebar et déconnexion ---
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

        // Écouteurs de filtres et soumission de formulaire
        shopForm.addEventListener('submit', handleShopFormSubmit);
        shopsTableBody.addEventListener('click', handleTableActions);
        
        // Écouteurs de filtres radio et barre de recherche
        document.querySelectorAll('input[name="statusFilter"]').forEach(radio => radio.addEventListener('change', fetchData));
        searchInput.addEventListener('input', fetchData);

        // Réinitialisation de la modale d'ajout/modification à la fermeture
        document.getElementById('shopModal').addEventListener('hidden.bs.modal', () => {
            shopForm.reset();
            isEditMode = false;
            currentShopId = null;
            shopModalLabel.textContent = 'Ajouter un marchand';
            shopSubmitBtn.textContent = 'Ajouter';
            document.getElementById('packagingPrice').value = 50; 
            document.getElementById('storagePrice').value = 100;
        });
        
        // Premier chargement des données
        fetchData();
    };
    
    initializeApp();
});