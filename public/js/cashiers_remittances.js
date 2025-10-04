// js/cashiers_remittances.js
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

  const startDateInput = document.getElementById('startDate');
  const endDateInput = document.getElementById('endDate');
  const globalSearchInput = document.getElementById('globalSearchInput');
  const filterBtn = document.getElementById('filterBtn');

  const summaryTableBody = document.getElementById('summaryTableBody');
  const shortfallsTableBody = document.getElementById('shortfallsTableBody');

  const remittanceDetailsModal = new bootstrap.Modal(document.getElementById('remittanceDetailsModal'));
  const settleShortfallModal = new bootstrap.Modal(document.getElementById('settleShortfallModal'));

  const settleShortfallForm = document.getElementById('settleShortfallForm');
  const confirmBatchBtn = document.getElementById('confirmBatchBtn');
  
  // Nouveaux éléments de la modale pour le filtrage
  const modalTransactionsTableBody = document.getElementById('modalTransactionsTableBody');
  const modalDateElement = document.getElementById('modalTransactionDate'); 
  
  // Mise à jour de l'UI avec le nom de l'utilisateur
  if (document.getElementById('userName')) document.getElementById('userName').textContent = user.name;
  if (document.getElementById('headerUserName')) document.getElementById('headerUserName').textContent = user.name;


  // --- ÉTAT GLOBAL DE LA MODALE ---
  let currentModalOrders = [];
  let currentFilter = 'all'; // all, pending, confirmed
  let currentDeliverymanId = null;


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
   * Formate la date pour l'affichage (DD/MM HH:mm).
   * @param {string} dateString - La chaîne de date.
   * @returns {string} La date formatée.
   */
  const formatDate = (dateString) => moment(dateString).format('DD/MM HH:mm');

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
   * Applique le filtre et met à jour le rendu de la modale.
   */
  const filterAndRenderModalOrders = () => {
    const tableBody = modalTransactionsTableBody;
    tableBody.innerHTML = '';

    const filteredOrders = currentModalOrders.filter(order => {
        if (currentFilter === 'all') return true;
        
        const isPending = order.remittance_status === 'En Attente';
        
        if (currentFilter === 'pending') return isPending;
        if (currentFilter === 'confirmed') return !isPending;
        return true;
    });

    if (filteredOrders.length === 0) {
        tableBody.innerHTML = `<tr><td colspan="5" class="text-center p-3">Aucune commande ${currentFilter === 'pending' ? 'en attente' : (currentFilter === 'confirmed' ? 'confirmée' : '')} à afficher.</td></tr>`;
        return;
    }
    
    filteredOrders.forEach(order => {
        const isPaid = order.remittance_status !== 'En Attente'; 
        const remittanceStatusText = isPaid ? 'Versé' : 'En Attente';
        const statusBadgeClass = isPaid ? 'badge bg-success' : 'badge bg-warning text-dark';
        
        // Montant lu correctement pour l'affichage
        const collectedAmount = parseFloat(order.total_collected_by_deliveryman) || 0.00;
        const orderNumber = `C${String(order.order_id).padStart(4, '0')}`;

        const row = document.createElement('tr');
        // CORRECTION DE L'ALIGNEMENT VERTICAL ET DE LA STRUCTURE DU COMMENTAIRE
        row.classList.add('align-middle'); 
        
        row.innerHTML = `
            <td class="text-center"><input type="checkbox" class="order-checkbox" data-id="${order.order_id}" data-amount="${collectedAmount}" ${isPaid ? 'disabled' : ''}></td>
            <td><span class="${statusBadgeClass}">${remittanceStatusText}</span></td>
            <td class="text-dark fw-bold">${formatAmount(collectedAmount)}</td>
            <td>
              <div class="fw-bold">${order.shop_name} - N° ${orderNumber}</div>
              <div class="text-muted">${order.delivery_location}</div>
              <small class="text-info">${formatDate(order.created_at)}</small>
              <small class="text-muted d-block fst-italic mt-1">${order.item_names || 'Articles non spécifiés'}</small>
            </td>
            <td class="text-center">
                <div class="dropdown">
                    <button class="btn btn-sm btn-secondary dropdown-toggle" type="button" 
                            data-bs-toggle="dropdown" aria-expanded="false" 
                            ${isPaid ? 'disabled' : ''}>
                        Actions
                    </button>
                    <ul class="dropdown-menu">
                        <li>
                            <button class="dropdown-item btn btn-sm btn-success confirm-single-order-btn" title="Confirmer l'encaissement" 
                                    data-amount="${collectedAmount}" 
                                    data-order-id="${order.order_id}">
                                <i class="bi bi-cash-stack"></i> Encaisser
                            </button>
                        </li>
                        <li>
                            <button class="dropdown-item btn btn-sm btn-outline-info edit-amount-btn" title="Modifier le montant" 
                                    data-id="${order.order_id}" 
                                    data-amount="${collectedAmount}">
                                <i class="bi bi-pencil"></i> Modifier Montant
                            </button>
                        </li>
                    </ul>
                </div>
            </td>
        `;
        tableBody.appendChild(row);
    });

    // Mettre à jour l'affichage de l'état du filtre
    document.querySelectorAll('.modal-filter-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.filter === currentFilter) {
            btn.classList.add('active');
        }
    });
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

    if (targetPanelId === '#remittances-panel') {
      fetchAndRenderSummary(startDate, search); 
    } else if (targetPanelId === '#shortfalls-panel') {
      fetchAndRenderShortfalls(search);
    }
  };

  /**
   * Récupère et affiche le résumé des versements des livreurs.
   * @param {string} date - Date du jour (Utilisé comme date unique pour la vue journalière).
   * @param {string} search - Terme de recherche.
   */
  const fetchAndRenderSummary = async (date, search) => {
    try {
      const res = await axios.get(`${API_BASE_URL}/cashiers/remittances`, { params: { date, search } });
      const { summary, expenseCategories, selectedDate } = res.data;
      
      startDateInput.value = selectedDate;
      endDateInput.value = selectedDate;
      
      summaryTableBody.innerHTML = '';
      if (summary.length === 0) {
        summaryTableBody.innerHTML = `<tr><td colspan="6" class="text-center p-3">Aucun encaissement à gérer pour le ${selectedDate}.</td></tr>`;
        return;
      }
      
      summary.forEach(item => {
        const row = document.createElement('tr');
        
        row.innerHTML = `
          <td>${item.deliveryman_name || 'N/A'}</td>
          <td>${item.pending_remittance_orders || 0}</td>
          <td class="text-warning fw-bold">${formatAmount(item.expected_remittance)}</td>
          <td>${item.confirmed_remittance_orders || 0}</td>
          <td class="text-success fw-bold">${formatAmount(item.confirmed_remittance)}</td>
          <td class="text-center"> 
             <button class="btn btn-sm btn-primary-custom details-btn" 
                      data-id="${item.deliveryman_id}" 
                      data-name="${item.deliveryman_name}"
                      data-date="${selectedDate}">Gérer</button>
          </td>
        `;
        summaryTableBody.appendChild(row);
      });
      
      // Assurez-vous d'avoir une fonction populateExpenseCategorySelect
      // populateExpenseCategorySelect(expenseCategories); 
      
    } catch (error) {
      console.error("Erreur de chargement du résumé:", error);
      summaryTableBody.innerHTML = `<tr><td colspan="6" class="text-center text-danger p-4">Erreur de chargement.</td></tr>`;
    }
  };

  /**
   * Récupère et affiche la liste des manquants des livreurs (shortfalls).
   * @param {string} search - Terme de recherche.
   */
  const fetchAndRenderShortfalls = async (search) => {
    try {
      const res = await axios.get(`${API_BASE_URL}/debt/shortfalls`, { params: { search } });
      shortfallsTableBody.innerHTML = '';
      if (res.data.length === 0) {
        shortfallsTableBody.innerHTML = `<tr><td colspan="5" class="text-center p-3">Aucun manquant en attente.</td></tr>`;
        return;
      }
      res.data.forEach(item => {
        const row = document.createElement('tr');
        row.innerHTML = `
          <td>${item.deliveryman_name || 'N/A'}</td>
          <td class="text-danger fw-bold">${formatAmount(item.amount)}</td>
          <td><span class="badge bg-warning text-dark">${item.status}</span></td>
          <td>${moment(item.created_at).format('DD/MM/YYYY')}</td>
          <td><button class="btn btn-sm btn-success settle-btn" data-id="${item.id}" data-amount="${item.amount}">Régler</button></td>
        `;
        shortfallsTableBody.appendChild(row);
      });
    } catch (error) {
        console.error("Erreur de chargement des manquants:", error);
      shortfallsTableBody.innerHTML = `<tr><td colspan="5" class="text-center text-danger p-4">Erreur de chargement.</td></tr>`;
    }
  };

  // --- LOGIQUE DE LA MODALE ET DU FLUX D'ENCAISSEMENT ---

  /**
   * Gère l'affichage des détails de versement pour un livreur.
   * @param {string} deliverymanId - L'ID du livreur.
   * @param {string} deliverymanName - Le nom du livreur.
   * @param {string} date - Date des transactions.
   */
  const handleRemittanceDetails = async (deliverymanId, deliverymanName, date) => {
    document.getElementById('modalDeliverymanName').textContent = deliverymanName;
    if (modalDateElement) modalDateElement.textContent = ` (Journée du ${moment(date).format('DD/MM/YYYY')})`;
    
    currentDeliverymanId = deliverymanId;
    currentFilter = 'all'; 

    try {
      const res = await axios.get(`${API_BASE_URL}/cashiers/remittances/${deliverymanId}/details`, {
        params: { date: date }
      });
      
      const { orders, totalConfirmedRemittance } = res.data;
      
      let totalAmountDue = orders.reduce((sum, order) => sum + parseFloat(order.total_collected_by_deliveryman), 0);
      let remainingBalance = totalAmountDue - totalConfirmedRemittance;
      const isFullySettled = remainingBalance <= 0;
      
      // Prépare les données pour le rendu et le filtre
      currentModalOrders = orders.map(order => {
          const isOrderSettled = isFullySettled; 
          return {
              ...order,
              remittance_status: isOrderSettled ? 'Versé' : 'En Attente',
              is_paid: isOrderSettled,
          };
      });

      // Affiche les commandes avec le filtre 'all'
      filterAndRenderModalOrders();
      
      remittanceDetailsModal.show();
    } catch (error) {
      showNotification("Erreur au chargement des détails de la journée.", "danger");
      console.error(error);
    }
  };

  /**
   * Gère la confirmation d'un lot de versements (par lot de commandes sélectionnées).
   */
  const handleConfirmBatch = async () => {
    const selectedCheckboxes = document.querySelectorAll('#modalTransactionsTableBody .order-checkbox:checked');
    
    if (selectedCheckboxes.length === 0) return showNotification("Sélectionnez au moins une commande à encaisser.", 'warning');

    const amountToConfirm = Array.from(selectedCheckboxes).reduce((sum, cb) => sum + parseFloat(cb.dataset.amount), 0);
    
    const paidAmount = prompt(`Montant total des commandes sélectionnées : ${formatAmount(amountToConfirm)}. Confirmez le montant à encaisser :`, amountToConfirm);

    if (paidAmount !== null && !isNaN(paidAmount) && currentDeliverymanId) {
      try {
        // Enregistrement d'un versement global
        const res = await axios.post(`${API_BASE_URL}/cashiers/remittances/confirm`, {
          deliverymanId: currentDeliverymanId,
          date: startDateInput.value,
          paidAmount: parseFloat(paidAmount),
          validated_by: CURRENT_USER_ID,
          comment: `Encaissement de ${selectedCheckboxes.length} commandes.`
        });
        
        showNotification(res.data.message);
        remittanceDetailsModal.hide();
        // Recharge le résumé
        applyFiltersAndRender();
        fetchAndRenderShortfalls(); 
      } catch (error) {
        showNotification(error.response?.data?.message || "Erreur lors de la confirmation du lot.", "danger");
        console.error(error);
      }
    }
  };
  
  /**
   * Gère la confirmation unitaire d'un encaissement (équivaut à handleConfirmBatch pour une seule commande).
   */
  const handleConfirmSingleOrder = async (target) => {
    const amountToConfirm = parseFloat(target.dataset.amount);
    const orderId = target.dataset.orderId;
    
    const paidAmount = prompt(`Montant de la commande n°${orderId} : ${formatAmount(amountToConfirm)}. Confirmez le montant à encaisser :`, amountToConfirm);
    
    if (paidAmount !== null && !isNaN(paidAmount) && currentDeliverymanId) {
        try {
            // Enregistrement d'un versement global pour le montant de cette commande
            await axios.post(`${API_BASE_URL}/cashiers/remittances/confirm`, { 
                deliverymanId: currentDeliverymanId,
                date: startDateInput.value,
                paidAmount: parseFloat(paidAmount), 
                validated_by: CURRENT_USER_ID,
                comment: `Encaissement unitaire pour la commande n°${orderId}.`
            });
            showNotification("Encaissement confirmé.");
            remittanceDetailsModal.hide();
            // Recharge le résumé
            applyFiltersAndRender();
            fetchAndRenderShortfalls();
        } catch (error) { 
            showNotification(error.response?.data?.message || "Erreur lors de l'encaissement unitaire.", "danger"); 
            console.error(error);
        }
    }
  };


  /**
   * Gère le règlement d'un manquant.
   */
  const handleSettleShortfallSubmit = async (e) => {
    e.preventDefault();
    const shortfallId = e.target.dataset.shortfallId;
    const amount = document.getElementById('settleAmountInput').value;
    try {
      await axios.put(`${API_BASE_URL}/debt/shortfalls/${shortfallId}/settle`, { 
        amount: parseFloat(amount), 
        userId: CURRENT_USER_ID 
      });
      showNotification("Manquant réglé avec succès.");
      settleShortfallModal.hide();
      fetchAndRenderShortfalls();
    } catch (error) {
      showNotification(error.response?.data?.message || "Erreur lors du règlement.", "danger");
      console.error(error);
    }
  };
  
  /**
   * Gère le clic sur les actions du tableau et les boutons de la modale.
   */
  const handleTableActions = async (e) => {
    const target = e.target.closest('button, a');
    if (!target) return;

    if (target.matches('.details-btn')) {
      handleRemittanceDetails(target.dataset.id, target.dataset.name, target.dataset.date); 
    } else if (target.matches('.settle-btn')) {
      const shortfallId = target.dataset.id;
      const amountDue = target.dataset.amount;
      document.getElementById('settleShortfallInfo').textContent = `Montant du manquant: ${formatAmount(amountDue)}`;
      document.getElementById('settleAmountInput').value = amountDue;
      settleShortfallForm.dataset.shortfallId = shortfallId;
      settleShortfallModal.show();
    } else if (target.matches('.confirm-single-order-btn')) {
        handleConfirmSingleOrder(target);
    } else if (target.matches('.edit-amount-btn')) {
        showNotification("La modification du montant est désactivée pour l'encaissement direct. Veuillez contacter l'administrateur.", "info");
    } else if (target.matches('.modal-filter-btn')) {
        currentFilter = target.dataset.filter;
        filterAndRenderModalOrders();
    }
  };


  // --- INITIALISATION ---

  const initializeApp = () => {
    const today = new Date().toISOString().slice(0, 10);
    startDateInput.value = today;
    endDateInput.value = today;

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
    filterBtn.addEventListener('click', () => applyFiltersAndRender());
    globalSearchInput.addEventListener('input', debounce(applyFiltersAndRender));
    document.querySelectorAll('#cashTabs .nav-link').forEach(tab => tab.addEventListener('shown.bs.tab', applyFiltersAndRender));

    // Ajout des écouteurs d'événements pour les boutons de filtre de la modale
    document.querySelectorAll('.modal-filter-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            currentFilter = e.target.dataset.filter;
            filterAndRenderModalOrders();
        });
    });

    // --- Actions globales ---
    document.body.addEventListener('click', handleTableActions);
    confirmBatchBtn.addEventListener('click', handleConfirmBatch);
    settleShortfallForm.addEventListener('submit', handleSettleShortfallSubmit);
    
    // Appliquer le filtre initial
    applyFiltersAndRender();
  };

  initializeApp();
});