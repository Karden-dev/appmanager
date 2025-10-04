// js/login.js

document.addEventListener('DOMContentLoaded', () => {
    // --- CONFIGURATION ---
    const API_BASE_URL = 'http://localhost:3000';
    
    // --- RÉFÉRENCES DOM ---
    const pinInputs = document.querySelectorAll('.pin-input');
    const hiddenPinInput = document.getElementById('pin');
    const loginForm = document.getElementById('login-form');
    const submitButton = loginForm.querySelector('button[type="submit"]');
    const spinner = submitButton.querySelector('.spinner-border');
    const loginMessage = document.getElementById('login-message');
    const rememberMeCheckbox = document.getElementById('rememberMe');
    const phoneNumberInput = document.getElementById('phoneNumber');

    // --- FONCTIONS UTILITAIRES ---

    /**
     * Affiche un message de feedback à l'utilisateur.
     * @param {string} message - Le message à afficher.
     * @param {string} [type='error'] - Le type de message ('error' ou 'success').
     */
    const showMessage = (message, type = 'error') => {
        loginMessage.textContent = message;
        loginMessage.className = `login-feedback d-block ${type === 'success' ? 'success' : 'error'}`;
    };

    /**
     * Masque le message de feedback.
     */
    const hideMessage = () => {
        loginMessage.classList.add('d-none');
    };
    
    /**
     * Met à jour le champ caché 'pin' avec la valeur agrégée des inputs de PIN.
     */
    const updateHiddenPin = () => {
        hiddenPinInput.value = Array.from(pinInputs).map(input => input.value).join('');
    };

    /**
     * Réinitialise l'état des inputs PIN (bordures, classes).
     */
    const resetPinState = () => {
        pinInputs.forEach(input => {
            input.classList.remove('error', 'filled');
            input.value = '';
        });
        hiddenPinInput.value = '';
    };

    // --- LOGIQUE DE SAISIE PIN ---
    
    /**
     * Configure la navigation et la saisie des champs PIN.
     */
    const setupPinInputs = () => {
        pinInputs.forEach((input, index) => {
            
            // Écouteur principal pour la saisie et le changement
            const inputHandler = function() {
                // Supprimer la classe d'erreur lors de la saisie
                this.classList.remove('error'); 

                if (this.value.length === 1) {
                    this.classList.add('filled');
                    if (index < pinInputs.length - 1) {
                        pinInputs[index + 1].focus();
                    }
                } else {
                    this.classList.remove('filled');
                }
                updateHiddenPin(); // S'assurer que le champ caché est mis à jour
            };

            input.addEventListener('input', inputHandler);
            
            // Écouteur pour la gestion du retour arrière (si on efface)
            input.addEventListener('keyup', function(e) {
                if (e.key === 'Backspace' && this.value === '' && index > 0) {
                     // Si l'utilisateur efface, on retire la classe filled
                    this.classList.remove('filled');
                    pinInputs[index - 1].focus();
                    updateHiddenPin(); // S'assurer que le champ caché est mis à jour
                }
            });

            // Navigation clavier (Flèches)
            input.addEventListener('keydown', function(e) {
                if (e.key === 'ArrowLeft' && index > 0) {
                    pinInputs[index - 1].focus();
                } else if (e.key === 'ArrowRight' && index < pinInputs.length - 1) {
                    pinInputs[index + 1].focus();
                }
            });
            
            // Coller le PIN
            input.addEventListener('paste', function(e) {
                e.preventDefault();
                const pasteData = e.clipboardData.getData('text').slice(0, 4);
                
                for (let i = 0; i < pasteData.length; i++) {
                    if (index + i < pinInputs.length) {
                        pinInputs[index + i].value = pasteData[i];
                        pinInputs[index + i].classList.add('filled');
                        pinInputs[index + i].classList.remove('error');
                    }
                }
                
                // Focus sur le dernier champ rempli ou le suivant
                const lastFilledIndex = index + pasteData.length - 1;
                if (lastFilledIndex < pinInputs.length - 1) {
                    pinInputs[lastFilledIndex + 1].focus();
                } else {
                    pinInputs[pinInputs.length - 1].focus();
                }
                
                updateHiddenPin();
            });
        });

        // Avancer au PIN quand on appuie sur Entrée dans le numéro de téléphone
        phoneNumberInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                pinInputs[0].focus();
            }
        });
    };

    // --- LOGIQUE DE CONNEXION ---

    /**
     * Gère la soumission du formulaire de connexion.
     * @param {Event} e - L'événement de soumission.
     */
    const handleLoginSubmit = async (e) => {
        e.preventDefault();
        
        hideMessage();
        spinner.classList.remove('d-none');
        submitButton.disabled = true;

        // Mettre à jour le PIN caché une dernière fois pour être sûr
        updateHiddenPin(); 
        const pin = hiddenPinInput.value;

        if (pin.length !== 4) {
             showMessage('Veuillez entrer un code PIN à 4 chiffres.');
             spinner.classList.add('d-none');
             submitButton.disabled = false;
             pinInputs.forEach(input => input.classList.add('error'));
             loginForm.classList.add('shake');
             setTimeout(() => {
                loginForm.classList.remove('shake');
            }, 1000);
             return;
        }
        
        const phoneNumber = phoneNumberInput.value;

        try {
            const response = await axios.post(`${API_BASE_URL}/api/login`, { phoneNumber, pin });
            
            if (response.status === 200) {
                const storage = rememberMeCheckbox.checked ? localStorage : sessionStorage;
                storage.setItem('user', JSON.stringify(response.data.user));

                showMessage('Connexion réussie ! Redirection...', 'success');
                
                window.location.href = 'dashboard.html';
            }
        } catch (error) {
            spinner.classList.add('d-none');
            submitButton.disabled = false;

            const message = error.response?.data?.message || 'Identifiants incorrects ou erreur inattendue.';
            showMessage(message);

            // Effet visuel d'erreur
            pinInputs.forEach(input => input.classList.add('error'));
            loginForm.classList.add('shake');
            setTimeout(() => {
                loginForm.classList.remove('shake');
            }, 1000);
        }
    };
    
    // --- INITIALISATION ---
    setupPinInputs();
    loginForm.addEventListener('submit', handleLoginSubmit);
});