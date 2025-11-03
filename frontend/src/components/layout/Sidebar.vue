<template>
  <div class="sidebar" :class="{ 'collapsed': isCollapsed }">
    <div class="sidebar-header">
      <h3 v-if="!isCollapsed">ArmNAS</h3>
      <h3 v-else>A</h3>
      <button class="toggle-btn" @click="toggleSidebar">
        <font-awesome-icon :icon="isCollapsed ? 'angle-right' : 'angle-left'" />
      </button>
    </div>
    
    <div class="sidebar-menu">
      <router-link to="/" class="menu-item" :class="{ active: $route.path === '/' }">
        <font-awesome-icon icon="home" />
        <span v-if="!isCollapsed">{{ $t('sidebar.dashboard') }}</span>
      </router-link>
      
      <router-link v-if="isAdmin" to="/disk" class="menu-item" :class="{ active: $route.path === '/disk' }">
        <font-awesome-icon icon="server" />
        <span v-if="!isCollapsed">{{ $t('sidebar.disk') }}</span>
      </router-link>
      
      <router-link v-if="isAdmin" to="/zfs" class="menu-item" :class="{ active: $route.path === '/zfs' }">
        <font-awesome-icon icon="database" />
        <span v-if="!isCollapsed">{{ $t('sidebar.zfs') || 'ZFS' }}</span>
      </router-link>
      
      <router-link v-if="isAdmin" to="/virtual-dsm" class="menu-item" :class="{ active: $route.path === '/virtual-dsm' }">
        <font-awesome-icon icon="box" />
        <span v-if="!isCollapsed">Virtual DSM</span>
      </router-link>
      
      <router-link v-if="isAdmin" to="/auth-users" class="menu-item" :class="{ active: $route.path === '/auth-users' }">
        <font-awesome-icon icon="lock" />
        <span v-if="!isCollapsed">{{ $t('sidebar.auth_users') || 'Utenti' }}</span>
      </router-link>
      
      <router-link v-if="isAdmin" to="/updates" class="menu-item" :class="{ active: $route.path === '/updates' }">
        <font-awesome-icon icon="sync-alt" />
        <span v-if="!isCollapsed">{{ $t('sidebar.updates') || 'Aggiornamenti' }}</span>
      </router-link>
    </div>
    
    <div class="sidebar-footer">
      <div v-if="!isCollapsed" class="user-info">
        <span class="username">{{ currentUser?.username }}</span>
        <span class="role-badge" :class="{ 'admin': isAdmin }">
          {{ isAdmin ? ($t('users.admin') || 'Admin') : ($t('users.user') || 'Utente') }}
        </span>
      </div>
      <router-link to="/profile" class="menu-item" :class="{ active: $route.path === '/profile' }">
        <font-awesome-icon icon="user-cog" />
        <span v-if="!isCollapsed">{{ $t('sidebar.profile') || 'Profilo' }}</span>
      </router-link>
      <a href="#" class="menu-item" @click.prevent="logout">
        <font-awesome-icon icon="sign-out-alt" />
        <span v-if="!isCollapsed">{{ $t('sidebar.logout') }}</span>
      </a>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { useStore } from 'vuex'
import { useRouter } from 'vue-router'

export default {
  name: 'Sidebar',
  setup() {
    const store = useStore()
    const router = useRouter()
    const isCollapsed = ref(false)
    
    // Forza un refresh dell'utente corrente all'avvio
    onMounted(async () => {
      await store.dispatch('auth/checkAuth')
    })
    
    // Ottieni l'utente corrente
    const currentUser = computed(() => store.getters['auth/currentUser'])
    
    // Verifica se l'utente è admin
    const isAdmin = computed(() => currentUser.value?.is_admin)
    
    const toggleSidebar = () => {
      isCollapsed.value = !isCollapsed.value
    }
    
    const logout = async () => {
      await store.dispatch('auth/logout')
      router.push('/login')
    }
    
    return {
      isCollapsed,
      currentUser,
      isAdmin,
      toggleSidebar,
      logout
    }
  }
}
</script>

<style scoped>
.sidebar {
  width: 250px;
  height: 100vh;
  background-color: #343a40;
  color: #fff;
  display: flex;
  flex-direction: column;
  transition: width 0.3s ease;
}

.sidebar.collapsed {
  width: 60px;
}

.sidebar-header {
  padding: 15px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #495057;
}

.sidebar-header h3 {
  margin: 0;
  font-size: 1.2rem;
}

.toggle-btn {
  background: none;
  border: none;
  color: #fff;
  cursor: pointer;
}

.sidebar-menu {
  flex: 1;
  overflow-y: auto;
}

.menu-item {
  display: flex;
  align-items: center;
  padding: 15px;
  color: #fff;
  text-decoration: none;
  transition: background-color 0.3s;
}

.menu-item:hover {
  background-color: #495057;
}

.menu-item.active {
  background-color: #007bff;
}

.menu-item span {
  margin-left: 10px;
}

.sidebar-footer {
  border-top: 1px solid #495057;
}

.user-info {
  padding: 10px 15px;
  display: flex;
  flex-direction: column;
  font-size: 0.9rem;
}

.username {
  font-weight: bold;
  margin-bottom: 3px;
}

.role-badge {
  display: inline-block;
  padding: 2px 6px;
  border-radius: 10px;
  background-color: #6c757d;
  color: white;
  font-size: 0.75rem;
  text-align: center;
}

.role-badge.admin {
  background-color: #28a745;
}

/* Stili per dispositivi mobili */
@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    z-index: 1000;
    transform: translateX(-100%);
  }
  
  .sidebar.show {
    transform: translateX(0);
  }
}
</style>