// public/js/auth.js

/**
 * Ce module gère l'authentification côté client.
 * Il vérifie si un utilisateur est connecté, met à jour l'interface utilisateur,
 * gère la déconnexion et fournit des informations sur l'utilisateur actuel.
 */
const AuthManager = (() => {
    let currentUser = null;

    /**
     * Tente de récupérer les informations de l'utilisateur depuis localStorage ou sessionStorage.
     */
    const loadUser = () => {
        const userJson = localStorage.getItem('user') || sessionStorage.getItem('user');
        if (userJson) {
            currentUser = JSON.parse(userJson);
        }
    };

    /**
     * Vérifie si l'utilisateur est connecté et le redirige vers la page de connexion si ce n'est pas le cas.
     * Met également à jour l'interface utilisateur avec les informations de l'utilisateur.
     */
    const init = () => {
        loadUser();
        
        if (!currentUser) {
            // Si l'utilisateur n'est pas connecté et qu'on n'est pas sur la page de connexion, rediriger.
            if (!window.location.pathname.endsWith('index.html') && !window.location.pathname.endsWith('/')) {
                window.location.href = 'index.html';
            }
            return;
        }

        // Mettre à jour le nom de l'utilisateur dans l'en-tête
        const userNameElement = document.getElementById('userName');
        if (userNameElement) {
            userNameElement.textContent = currentUser.name || 'Utilisateur';
        }

        // Configurer le bouton de déconnexion
        const logoutBtn = document.getElementById('logoutBtn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', (e) => {
                e.preventDefault();
                logout();
            });
        }
    };

    /**
     * Déconnecte l'utilisateur en supprimant ses informations de stockage et en le redirigeant.
     */
    const logout = () => {
        localStorage.removeItem('user');
        sessionStorage.removeItem('user');
        currentUser = null;
        window.location.href = 'index.html';
    };

    /**
     * Renvoie l'objet utilisateur actuellement connecté.
     * @returns {object|null} L'objet utilisateur ou null si personne n'est connecté.
     */
    const getUser = () => {
        if (!currentUser) {
            loadUser();
        }
        return currentUser;
    };

    /**
     * Renvoie l'ID de l'utilisateur actuellement connecté.
     * @returns {number|null} L'ID de l'utilisateur ou null.
     */
    const getUserId = () => {
        const user = getUser();
        return user ? user.id : null;
    };

    // Exposer les fonctions publiques
    return {
        init,
        getUser,
        getUserId,
        logout
    };
})();

// Initialiser le gestionnaire d'authentification dès que le DOM est prêt.
document.addEventListener('DOMContentLoaded', AuthManager.init);
