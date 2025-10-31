<template>
  <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
    <div class="container-fluid">
      <button 
        class="navbar-toggler d-md-none" 
        type="button" 
        @click="toggleSidebar"
      >
        <span class="navbar-toggler-icon"></span>
      </button>
      
      <span class="navbar-brand d-none d-md-block">{{ currentPage }}</span>
      
      <div class="collapse navbar-collapse">
        <ul class="navbar-nav ms-auto">
          <li class="nav-item dropdown">
            <a 
              class="nav-link dropdown-toggle" 
              href="#" 
              id="navbarDropdown" 
              role="button" 
              data-bs-toggle="dropdown" 
              aria-expanded="false"
            >
              {{ username }}
            </a>
            <ul class="dropdown-menu dropdown-menu-end" aria-labelledby="navbarDropdown">
              <li>
                <a class="dropdown-item" href="#" @click.prevent="logout">
                  <font-awesome-icon icon="sign-out-alt" />
                  {{ $t('navbar.logout') }}
                </a>
              </li>
            </ul>
          </li>
        </ul>
      </div>
    </div>
  </nav>
</template>

<script>
import { computed } from 'vue'
import { useStore } from 'vuex'
import { useRouter, useRoute } from 'vue-router'

export default {
  name: 'Navbar',
  setup() {
    const store = useStore()
    const router = useRouter()
    const route = useRoute()
    
    // Ottieni il nome utente corrente
    const username = computed(() => {
      const user = store.getters['auth/currentUser']
      return user ? user.username : ''
    })
    
    // Ottieni il nome della pagina corrente
    const currentPage = computed(() => {
      switch (route.path) {
        case '/':
          return 'Dashboard'
        case '/disk':
          return 'Gestione Disco'
        case '/users':
          return 'Gestione Utenti'
        case '/shares':
          return 'Condivisioni'
        case '/network':
          return 'Impostazioni di Rete'
        case '/system':
          return 'Impostazioni di Sistema'
        case '/files':
          return 'Gestione File'
        default:
          return 'ArmNAS'
      }
    })
    
    // Funzione per il logout
    const logout = async () => {
      await store.dispatch('auth/logout')
      router.push('/login')
    }
    
    // Funzione per mostrare/nascondere la sidebar su dispositivi mobili
    const toggleSidebar = () => {
      const sidebar = document.querySelector('.sidebar')
      if (sidebar) {
        sidebar.classList.toggle('show')
      }
    }
    
    return {
      username,
      currentPage,
      logout,
      toggleSidebar
    }
  }
}
</script>

<style scoped>
.navbar {
  padding: 0.5rem 1rem;
}

.navbar-brand {
  font-weight: 500;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
</style>