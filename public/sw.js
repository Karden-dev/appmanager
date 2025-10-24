// public/sw.js
// Version 2.3 - Mise à jour du nom du cache pour déclencher la mise à jour

// Import du script helper pour la base de données locale (IndexedDB)
importScripts('https://cdn.jsdelivr.net/npm/idb@7/build/umd.js');

// --- MISE À JOUR ICI ---
const STATIC_CACHE_NAME = 'wink-express-static-v15'; // Cache pour les fichiers de l'application (HTML, CSS, JS)
// --- FIN MISE À JOUR ---
const DATA_CACHE_NAME = 'wink-express-data-v4';   // Cache pour les données des requêtes API (GET)

// Liste complète des fichiers essentiels pour le fonctionnement hors ligne
const URLS_TO_CACHE = [
  '/',
  '/index.html',
  '/dashboard.html',
  '/orders.html',
  '/deliverymen.html',
  '/shops.html',
  '/reports.html',
  '/remittances.html',
  '/debts.html',
  '/cash.html',
  '/users.html',
  '/rider-app.html',
  '/ridercash.html',
  // Ajout des nouvelles pages Livreur
  '/rider-performance.html',
  '/js/auth.js',
  '/js/login.js',
  '/js/pwa-loader.js',
  '/js/db-helper.js',
  '/js/rider.js',
  '/js/reports.js',
  '/js/cash.js',
  '/js/ridercash.js',
  '/js/orders.js',
  '/js/shops.js',
  '/js/users.js',
  // Utiliser le nouveau fichier JS pour la gestion des livreurs
  '/js/deliverymenManager.js',
  // Ajout du nouveau JS de performance
  '/js/rider-performance.js',
  '/js/remittances.js',
  '/js/debts.js',
  'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css',
  'https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css',
  'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js',
  'https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js',
  'https://cdn.jsdelivr.net/npm/idb@7/build/umd.js',
  'https://cdn.jsdelivr.net/npm/moment@2.29.1/moment.min.js',
   'https://cdn.jsdelivr.net/npm/chart.js', // Ajouté car utilisé dans la page performance
  '/wink.png',
  '/wink-logo.png',
  '/favicon.ico',
  '/icons/wink-icon-192x192.png',
  '/icons/wink-icon-512x512.png',
  '/sound.mp3'
];

const DB_NAME = 'wink-sync-db';
const STORE_NAME = 'sync-requests';

// --- Événements du Cycle de Vie du Service Worker ---

// 1. Installation : Met en cache tous les fichiers de l'App Shell.
self.addEventListener('install', event => {
  console.log('[Service Worker] Tentative d\'installation (v9)...'); // Log version mise à jour
  // force l'installation immédiate d'une nouvelle version
  self.skipWaiting();
  event.waitUntil(
    caches.open(STATIC_CACHE_NAME).then(cache => {
      console.log('[Service Worker] Mise en cache des fichiers de l\'application (v9).');
       return cache.addAll(URLS_TO_CACHE);
    }).catch(error => {
        console.error('[Service Worker] Échec de la mise en cache lors de l\'installation:', error);
    })
  );
});

// 2. Activation : Nettoie les anciens caches statiques.
self.addEventListener('activate', event => {
  console.log('[Service Worker] Activation (v9)...');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          // Supprimer les anciens caches STATIQUES seulement
          .filter(name => name.startsWith('wink-express-static-') && name !== STATIC_CACHE_NAME)
          .map(name => {
            console.log(`[Service Worker] Suppression de l'ancien cache statique: ${name}`);
            return caches.delete(name);
          })
      );
    }).then(() => {
        // Prend le contrôle immédiat des clients (onglets ouverts)
        console.log('[Service Worker] Contrôle des clients revendiqué.');
        return self.clients.claim();
    })
  );
});

// 3. Fetch : Intercepte toutes les requêtes réseau.
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  // Stratégie pour les requêtes API (GET uniquement) : Network First, then Cache
  if (url.origin === self.location.origin && url.pathname.startsWith('/api/')) {
    if (request.method !== 'GET') {
      return; // Ne pas mettre en cache POST, PUT, DELETE etc.
    }

    event.respondWith(
      caches.open(DATA_CACHE_NAME).then(cache => {
        return fetch(request)
          .then(networkResponse => {
            // Si la requête réseau réussit, mettre à jour le cache API
            if (networkResponse.ok) {
              cache.put(request, networkResponse.clone());
            }
            return networkResponse;
          })
          .catch(async () => {
            // Si le réseau échoue, essayer de servir depuis le cache API
            const cachedResponse = await cache.match(request);
            if (cachedResponse) {
              console.log(`[Service Worker] Ressource API servie depuis le cache: ${request.url}`);
              return cachedResponse;
            }
            // Si ni réseau ni cache, renvoyer une erreur JSON
            console.error(`[Service Worker] Ressource API non disponible (offline et non cachée): ${request.url}`);
            return new Response(JSON.stringify({ error: "Offline et ressource API non mise en cache." }), {
              status: 503, // Service Unavailable
              headers: { 'Content-Type': 'application/json' }
            });
          });
      })
    );
    return; // Important pour ne pas exécuter la stratégie suivante
  }

  // Stratégie pour tous les autres fichiers (HTML, CSS, JS, Images...) : Cache First, then Network
  // On vérifie si l'URL est dans la liste de pré-cache ou si c'est une ressource du même domaine
  const isPrecachedOrSameOrigin = URLS_TO_CACHE.includes(url.pathname) || url.origin === self.location.origin;

  if (isPrecachedOrSameOrigin) {
      event.respondWith(
        caches.match(request).then(cachedResponse => {
          if (cachedResponse) {
            // Servir depuis le cache statique
            return cachedResponse;
          }
          // Si non trouvé dans le cache, aller sur le réseau
          return fetch(request).then(networkResponse => {
              return networkResponse;
          }).catch(error => {
              console.error(`[Service Worker] Échec du fetch réseau pour ${request.url}:`, error);
          });
        })
      );
  } else {
      // Pour les requêtes cross-origin non API (CDN, etc.), utiliser la stratégie réseau par défaut
      return; // Laisse le navigateur gérer
  }
});


// --- Gestion de la Synchronisation en Arrière-plan ---

// 4. Sync : Se déclenche lorsque la connexion revient.
self.addEventListener('sync', event => {
  if (event.tag === 'sync-failed-requests') {
    console.log('[Service Worker] Événement Sync reçu pour sync-failed-requests.');
    event.waitUntil(replayAllFailedRequests());
  }
});

/**
 * Rejoue toutes les requêtes en attente depuis IndexedDB.
 */
async function replayAllFailedRequests() {
  try {
    const db = await idb.openDB(DB_NAME, 1); // Pas besoin d'upgrade ici, juste ouvrir
    const allRequests = await db.getAll(STORE_NAME);
    console.log(`[Service Worker] Rejeu de ${allRequests.length} requête(s) en attente.`);

    const results = await Promise.allSettled( // Utiliser allSettled pour traiter toutes les requêtes même si certaines échouent
        allRequests.map(async (request) => { // Rendre la fonction interne async
            console.log(`[Service Worker] Tentative de rejouer la requête ID ${request.id}: ${request.method} ${request.url}`);
            try {
                const response = await fetch(request.url, {
                    method: request.method,
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${request.token}` // Utilise le token sauvegardé
                    },
                    body: JSON.stringify(request.payload)
                });

                if (response.ok) {
                    console.log(`[Service Worker] Requête ID ${request.id} (${request.url}) réussie. Suppression de la file d'attente.`);
                    await db.delete(STORE_NAME, request.id);
                    return { id: request.id, status: 'fulfilled' };
                } else {
                    console.error(`[Service Worker] Échec requête ID ${request.id} (${request.url}), statut: ${response.status}`);
                    // Si erreur client (4xx), supprimer pour éviter boucle infinie
                    if (response.status >= 400 && response.status < 500) {
                        console.warn(`[Service Worker] Suppression requête ID ${request.id} car erreur client (${response.status}).`);
                        await db.delete(STORE_NAME, request.id);
                        return { id: request.id, status: 'rejected', reason: `Client error ${response.status}` };
                    }
                    // Pour les erreurs serveur (5xx) ou réseau, on laisse la requête pour une prochaine tentative
                    return { id: request.id, status: 'rejected', reason: `Server error ${response.status} or network issue` };
                }
            } catch (error) {
                 console.error(`[Service Worker] Erreur réseau lors du rejeu requête ID ${request.id} (${request.url}):`, error);
                 // Laisser la requête pour une prochaine tentative en cas d'erreur réseau
                 return { id: request.id, status: 'rejected', reason: 'Network error' };
            }
        })
    );
    console.log('[Service Worker] Traitement de la file de synchronisation terminé.');
    results.forEach(result => {
        if(result.status === 'rejected') {
            console.warn(`[Service Worker] Échec final ou temporaire pour requête ID ${result.id || 'inconnu'}: ${result.reason}`);
        }
    });

  } catch (error) {
    console.error('[Service Worker] Erreur majeure lors du rejeu des requêtes:', error);
    // L'erreur est relancée pour que le navigateur puisse retenter la synchronisation plus tard
    throw error;
  }
}