<template>
  <div class="app-container">
    <Sidebar v-if="isAuthenticated" />
    <div class="main-content">
      <Navbar v-if="isAuthenticated" />
      <div class="content-area">
        <div v-if="isAuthenticated && !isAdmin" class="user-welcome-banner">
          <div class="container py-2">
            <div class="d-flex align-items-center">
              <font-awesome-icon icon="info-circle" class="me-2 text-primary" />
              <span>{{ $t('dashboard.non_admin_message') || 'Sei connesso come utente normale. Alcune funzionalità sono disponibili solo per gli amministratori.' }}</span>
            </div>
          </div>
        </div>
        <router-view />
      </div>
    </div>
  </div>
</template>

<script>
import { computed, onMounted } from 'vue'
import { useStore } from 'vuex'
import Navbar from '@/components/layout/Navbar.vue'
import Sidebar from '@/components/layout/Sidebar.vue'

export default {
  name: 'App',
  components: {
    Navbar,
    Sidebar
  },
  setup() {
    const store = useStore()
    
    // Forza un refresh dell'utente all'avvio dell'applicazione
    onMounted(async () => {
      console.log('App mounted, checking auth...')
      await store.dispatch('auth/checkAuth')
      console.log('Auth checked, current user:', store.getters['auth/currentUser'])
    })
    
    // Verifica se l'utente è autenticato
    const isAuthenticated = computed(() => store.getters['auth/isAuthenticated'])
    
    // Ottieni l'utente corrente
    const currentUser = computed(() => store.getters['auth/currentUser'])
    
    // Verifica se l'utente è admin
    const isAdmin = computed(() => {
      const isAdminValue = currentUser.value?.is_admin
      console.log('isAdmin computed:', isAdminValue, 'currentUser:', currentUser.value)
      return isAdminValue
    })
    
    return {
      isAuthenticated,
      currentUser,
      isAdmin
    }
  }
}
</script>

<style>
html, body {
  height: 100%;
  margin: 0;
  padding: 0;
}

#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-container {
  display: flex;
  height: 100vh;
  overflow: hidden;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.content-area {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
  background-color: #f8f9fa;
}

.user-welcome-banner {
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
  margin-bottom: 15px;
  font-size: 0.9rem;
}

/* Stili per dispositivi mobili */
@media (max-width: 768px) {
  .app-container {
    flex-direction: column;
  }
}
</style>