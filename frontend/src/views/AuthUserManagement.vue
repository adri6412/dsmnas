<template>
  <div class="auth-user-management">
    <h1>{{ $t('users.auth_title') || 'Gestione Utenti Autenticazione' }}</h1>
    
    <div class="alert alert-info" v-if="!isAdmin">
      <font-awesome-icon icon="info-circle" class="me-2" />
      {{ $t('users.non_admin_message') || 'Sei connesso come utente normale. Alcune funzionalità sono disponibili solo per gli amministratori.' }}
    </div>
    
    <div class="row">
      <!-- Elenco utenti -->
      <div class="col-md-12 mb-4">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="users" class="me-2" />
              {{ $t('users.auth_list') || 'Utenti Autenticazione' }}
            </h5>
            <div>
              <button class="btn btn-sm btn-primary me-2" @click="showCreateUserModal" v-if="isAdmin">
                <font-awesome-icon icon="plus" class="me-1" />
                {{ $t('users.create') || 'Crea Utente' }}
              </button>
              <button class="btn btn-sm btn-outline-primary" @click="refreshUsers">
                <font-awesome-icon icon="sync" :class="{ 'fa-spin': loading }" />
              </button>
            </div>
          </div>
          <div class="card-body">
            <div v-if="loading" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') || 'Caricamento...' }}</span>
              </div>
            </div>
            <div v-else-if="users && users.length">
              <div class="table-responsive">
                <table class="table table-hover">
                  <thead>
                    <tr>
                      <th>{{ $t('users.username') || 'Username' }}</th>
                      <th>{{ $t('users.admin') || 'Amministratore' }}</th>
                      <th v-if="isAdmin">{{ $t('common.actions') || 'Azioni' }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="user in users" :key="user.username">
                      <td>{{ user.username }}</td>
                      <td>
                        <span v-if="user.is_admin" class="badge bg-success">
                          <font-awesome-icon icon="check" class="me-1" />
                          {{ $t('common.yes') || 'Sì' }}
                        </span>
                        <span v-else class="badge bg-secondary">
                          <font-awesome-icon icon="times" class="me-1" />
                          {{ $t('common.no') || 'No' }}
                        </span>
                      </td>
                      <td v-if="isAdmin">
                        <div class="btn-group">
                          <button 
                            class="btn btn-sm btn-danger" 
                            @click="showDeleteUserModal(user)"
                            :disabled="user.username === 'admin' || user.username === currentUser.username"
                          >
                            <font-awesome-icon icon="trash" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div v-else class="text-center py-3 text-muted">
              {{ $t('users.no_users') || 'Nessun utente trovato' }}
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Modal per la creazione di un utente -->
    <b-modal 
      v-model="showCreateModal" 
      :title="$t('users.create') || 'Crea Utente'" 
      @ok="createUser"
      ok-variant="success"
      :ok-title="$t('common.save') || 'Salva'"
      :cancel-title="$t('common.cancel') || 'Annulla'"
    >
      <div class="mb-3">
        <label for="username" class="form-label">{{ $t('users.username') || 'Username' }}</label>
        <input 
          type="text" 
          class="form-control" 
          id="username" 
          v-model="newUser.username"
          required
        >
      </div>
      <div class="mb-3">
        <label for="password" class="form-label">{{ $t('users.password') || 'Password' }}</label>
        <input 
          type="password" 
          class="form-control" 
          id="password" 
          v-model="newUser.password"
          required
        >
      </div>
      <div class="mb-3">
        <label for="confirm-password" class="form-label">{{ $t('users.confirm_password') || 'Conferma Password' }}</label>
        <input 
          type="password" 
          class="form-control" 
          id="confirm-password" 
          v-model="confirmPassword"
          required
        >
      </div>
      <div class="mb-3 form-check">
        <input 
          type="checkbox" 
          class="form-check-input" 
          id="is-admin" 
          v-model="newUser.is_admin"
        >
        <label class="form-check-label" for="is-admin">
          {{ $t('users.admin') || 'Amministratore' }}
        </label>
      </div>
    </b-modal>
    
    <!-- Modal di conferma per l'eliminazione di un utente -->
    <b-modal 
      v-model="showDeleteModal" 
      :title="$t('users.delete') || 'Elimina Utente'" 
      @ok="deleteUser"
      ok-variant="danger"
      :ok-title="$t('common.yes') || 'Sì'"
      :cancel-title="$t('common.no') || 'No'"
    >
      <p>{{ $t('users.confirm_delete') || 'Sei sicuro di voler eliminare questo utente?' }}</p>
      <p><strong>{{ selectedUser?.username }}</strong></p>
    </b-modal>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { useStore } from 'vuex'
import { useToast } from 'vue-toast-notification'
import axios from '@/plugins/axios'

export default {
  name: 'AuthUserManagement',
  setup() {
    const store = useStore()
    const $toast = useToast()
    
    // Stato
    const users = ref([])
    const loading = ref(false)
    const showCreateModal = ref(false)
    const showDeleteModal = ref(false)
    const confirmPassword = ref('')
    
    // Nuovo utente
    const newUser = ref({
      username: '',
      password: '',
      is_admin: false
    })
    
    // Utente da eliminare
    const selectedUser = ref(null)
    
    // Utente corrente
    const currentUser = computed(() => store.getters['auth/currentUser'])
    
    // Verifica se l'utente corrente è admin
    const isAdmin = computed(() => currentUser.value?.is_admin)
    
    // Carica i dati all'avvio
    onMounted(() => {
      refreshUsers()
    })
    
    // Funzioni
    const refreshUsers = async () => {
      loading.value = true
      try {
        const response = await axios.get('/api/auth/users')
        users.value = response.data
      } catch (error) {
        console.error('Errore nel caricamento degli utenti:', error)
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per visualizzare tutti gli utenti')
        } else {
          $toast.error('Errore nel caricamento degli utenti')
        }
      } finally {
        loading.value = false
      }
    }
    
    const showCreateUserModal = () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono creare nuovi utenti')
        return
      }
      
      // Reset del form
      newUser.value = {
        username: '',
        password: '',
        is_admin: false
      }
      confirmPassword.value = ''
      
      showCreateModal.value = true
    }
    
    const createUser = async () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono creare nuovi utenti')
        return
      }
      
      // Verifica che le password corrispondano
      if (newUser.value.password !== confirmPassword.value) {
        $toast.error('Le password non corrispondono')
        return
      }
      
      try {
        await axios.post('/api/auth/users', newUser.value)
        $toast.success('Utente creato con successo')
        refreshUsers()
      } catch (error) {
        console.error('Errore nella creazione dell\'utente:', error)
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per creare nuovi utenti')
        } else {
          $toast.error(error.response?.data?.detail || 'Errore nella creazione dell\'utente')
        }
      }
    }
    
    const showDeleteUserModal = (user) => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono eliminare utenti')
        return
      }
      
      selectedUser.value = user
      showDeleteModal.value = true
    }
    
    const deleteUser = async () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono eliminare utenti')
        return
      }
      
      try {
        await axios.delete(`/api/auth/users/${selectedUser.value.username}`)
        $toast.success('Utente eliminato con successo')
        refreshUsers()
      } catch (error) {
        console.error('Errore nell\'eliminazione dell\'utente:', error)
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per eliminare utenti')
        } else {
          $toast.error(error.response?.data?.detail || 'Errore nell\'eliminazione dell\'utente')
        }
      }
    }
    
    return {
      users,
      loading,
      showCreateModal,
      showDeleteModal,
      newUser,
      confirmPassword,
      selectedUser,
      currentUser,
      isAdmin,
      refreshUsers,
      showCreateUserModal,
      createUser,
      showDeleteUserModal,
      deleteUser
    }
  }
}
</script>

<style scoped>
.auth-user-management {
  padding: 20px;
}
</style>