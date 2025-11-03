import { createRouter, createWebHistory } from 'vue-router'
import store from '@/store'

// Importa le viste
import Login from '@/views/Login.vue'
import Dashboard from '@/views/Dashboard.vue'
import DiskManagement from '@/views/DiskManagement.vue'
import AuthUserManagement from '@/views/AuthUserManagement.vue'
import UserProfile from '@/views/UserProfile.vue'
import ZFSManagement from '@/views/ZFSManagement.vue'
import VirtualDSM from '@/views/VirtualDSM.vue'
import UpdateManagement from '@/views/UpdateManagement.vue'

const routes = [
  {
    path: '/',
    name: 'Dashboard',
    component: Dashboard,
    meta: { requiresAuth: true }
  },
  {
    path: '/login',
    name: 'Login',
    component: Login,
    meta: { guest: true }
  },
  {
    path: '/disk',
    name: 'DiskManagement',
    component: DiskManagement,
    meta: { requiresAuth: true, requiresAdmin: true }
  },
  {
    path: '/zfs',
    name: 'ZFSManagement',
    component: ZFSManagement,
    meta: { requiresAuth: true, requiresAdmin: true }
  },
  {
    path: '/auth-users',
    name: 'AuthUserManagement',
    component: AuthUserManagement,
    meta: { requiresAuth: true, requiresAdmin: true }
  },
  {
    path: '/virtual-dsm',
    name: 'VirtualDSM',
    component: VirtualDSM,
    meta: { requiresAuth: true, requiresAdmin: true }
  },
  {
    path: '/profile',
    name: 'UserProfile',
    component: UserProfile,
    meta: { requiresAuth: true }
  },
  {
    path: '/updates',
    name: 'UpdateManagement',
    component: UpdateManagement,
    meta: { requiresAuth: true, requiresAdmin: true }
  },
  // Reindirizza tutte le rotte non trovate alla dashboard
  {
    path: '/:pathMatch(.*)*',
    redirect: '/'
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Variabile per tenere traccia se abbiamo già verificato l'autenticazione
let authChecked = false

// Guardia di navigazione per controllare l'autenticazione e i permessi
router.beforeEach(async (to, from, next) => {
  // Verifica l'autenticazione solo una volta all'avvio dell'applicazione
  if (!authChecked) {
    await store.dispatch('auth/checkAuth')
    authChecked = true
  }
  
  const isAuthenticated = store.getters['auth/isAuthenticated']
  const currentUser = store.getters['auth/currentUser']
  const isAdmin = currentUser?.is_admin || false
  
  if (to.matched.some(record => record.meta.requiresAuth)) {
    // Questa rotta richiede l'autenticazione
    if (!isAuthenticated) {
      // L'utente non è autenticato, reindirizza alla pagina di login
      next({ name: 'Login' })
    } else if (to.matched.some(record => record.meta.requiresAdmin) && !isAdmin) {
      // Questa rotta richiede i privilegi di amministratore
      // Reindirizza alla dashboard se l'utente non è admin
      next({ name: 'Dashboard' })
      
      // Mostra un messaggio di errore
      const toastEl = document.createElement('div');
      toastEl.className = 'toast-container position-fixed top-0 end-0 p-3';
      toastEl.style.zIndex = '9999';
      
      toastEl.innerHTML = `
        <div class="toast show bg-danger text-white" role="alert" aria-live="assertive" aria-atomic="true">
          <div class="toast-header bg-danger text-white">
            <strong class="me-auto">Accesso negato</strong>
            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="toast" aria-label="Close" onclick="this.parentElement.parentElement.parentElement.remove()"></button>
          </div>
          <div class="toast-body">
            Non hai i permessi per accedere a questa pagina.
          </div>
        </div>
      `;
      
      document.body.appendChild(toastEl);
      
      // Rimuovi il toast dopo 3 secondi
      setTimeout(() => {
        if (document.body.contains(toastEl)) {
          document.body.removeChild(toastEl);
        }
      }, 3000);
    } else {
      // L'utente è autenticato e ha i permessi necessari, procedi
      next()
    }
  } else if (to.matched.some(record => record.meta.guest)) {
    // Questa rotta è solo per gli ospiti
    if (isAuthenticated) {
      // L'utente è autenticato, reindirizza alla dashboard
      next({ name: 'Dashboard' })
    } else {
      // L'utente non è autenticato, procedi
      next()
    }
  } else {
    // Procedi normalmente
    next()
  }
})

export default router