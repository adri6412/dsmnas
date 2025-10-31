<template>
  <div class="user-profile">
    <h1>{{ $t('profile.title') || 'Profilo Utente' }}</h1>
    
    <div class="row">
      <div class="col-md-6 mb-4">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="user" class="me-2" />
              {{ $t('profile.info') || 'Informazioni Profilo' }}
            </h5>
          </div>
          <div class="card-body">
            <div class="mb-3">
              <strong>{{ $t('users.username') }}:</strong> {{ currentUser?.username }}
            </div>
            <div class="mb-3">
              <strong>{{ $t('users.role') }}:</strong> 
              <span class="badge" :class="currentUser?.is_admin ? 'bg-success' : 'bg-secondary'">
                {{ currentUser?.is_admin ? $t('users.admin') : $t('users.user') }}
              </span>
            </div>
          </div>
        </div>
      </div>
      
      <div class="col-md-6 mb-4">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="key" class="me-2" />
              {{ $t('profile.change_password') || 'Cambia Password' }}
            </h5>
          </div>
          <div class="card-body">
            <form @submit.prevent="changePassword">
              <div class="mb-3">
                <label for="currentPassword" class="form-label">{{ $t('profile.current_password') || 'Password Attuale' }}</label>
                <input 
                  type="password" 
                  class="form-control" 
                  id="currentPassword" 
                  v-model="passwordForm.currentPassword"
                  required
                >
              </div>
              
              <div class="mb-3">
                <label for="newPassword" class="form-label">{{ $t('profile.new_password') || 'Nuova Password' }}</label>
                <input 
                  type="password" 
                  class="form-control" 
                  id="newPassword" 
                  v-model="passwordForm.newPassword"
                  required
                  minlength="6"
                >
              </div>
              
              <div class="mb-3">
                <label for="confirmPassword" class="form-label">{{ $t('profile.confirm_password') || 'Conferma Password' }}</label>
                <input 
                  type="password" 
                  class="form-control" 
                  id="confirmPassword" 
                  v-model="passwordForm.confirmPassword"
                  required
                >
                <div class="form-text text-danger" v-if="passwordsDoNotMatch">
                  {{ $t('profile.passwords_not_match') || 'Le password non corrispondono' }}
                </div>
              </div>
              
              <button 
                type="submit" 
                class="btn btn-primary" 
                :disabled="isSubmitting || passwordsDoNotMatch"
              >
                <span v-if="isSubmitting" class="spinner-border spinner-border-sm me-2" role="status"></span>
                {{ $t('profile.update_password') || 'Aggiorna Password' }}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
    
    <div class="row">
      <div class="col-md-12 mb-4">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="shield-alt" class="me-2" />
              {{ $t('profile.security') || 'Sicurezza' }}
            </h5>
          </div>
          <div class="card-body">
            <div class="mb-3">
              <h6>{{ $t('profile.active_sessions') || 'Sessioni Attive' }}</h6>
              <p>{{ $t('profile.current_session') || 'Sessione corrente' }}</p>
              <button class="btn btn-danger" @click="logoutAllSessions">
                <font-awesome-icon icon="sign-out-alt" class="me-2" />
                {{ $t('profile.logout_all') || 'Disconnetti tutte le sessioni' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { useStore } from 'vuex'
import { useToast } from 'vue-toast-notification'
import axios from '@/plugins/axios'

export default {
  name: 'UserProfile',
  setup() {
    const store = useStore()
    const $toast = useToast()
    
    // Forza un refresh dell'utente all'avvio
    onMounted(async () => {
      await store.dispatch('auth/checkAuth')
    })
    
    // Ottieni l'utente corrente
    const currentUser = computed(() => store.getters['auth/currentUser'])
    
    // Form per il cambio password
    const passwordForm = ref({
      currentPassword: '',
      newPassword: '',
      confirmPassword: ''
    })
    
    const isSubmitting = ref(false)
    
    // Verifica se le password corrispondono
    const passwordsDoNotMatch = computed(() => {
      return passwordForm.value.newPassword !== passwordForm.value.confirmPassword &&
             passwordForm.value.confirmPassword !== ''
    })
    
    // Funzione per cambiare la password
    const changePassword = async () => {
      if (passwordsDoNotMatch.value) {
        return
      }
      
      isSubmitting.value = true
      
      try {
        const response = await axios.post('/api/auth/change-password', {
          current_password: passwordForm.value.currentPassword,
          new_password: passwordForm.value.newPassword
        })
        
        $toast.success(response.data.message || 'Password aggiornata con successo')
        // Reset del form
        passwordForm.value = {
          currentPassword: '',
          newPassword: '',
          confirmPassword: ''
        }
      } catch (error) {
        console.error('Errore durante il cambio password:', error)
        $toast.error(error.response?.data?.detail || 'Si è verificato un errore durante il cambio password')
      } finally {
        isSubmitting.value = false
      }
    }
    
    // Funzione per disconnettere tutte le sessioni
    const logoutAllSessions = async () => {
      try {
        await axios.post('/api/auth/logout-all')
        
        // Disconnetti l'utente corrente
        await store.dispatch('auth/logout')
        // Reindirizza alla pagina di login
        window.location.href = '/login'
      } catch (error) {
        console.error('Errore durante la disconnessione delle sessioni:', error)
        $toast.error(error.response?.data?.detail || 'Si è verificato un errore durante la disconnessione delle sessioni')
      }
    }
    
    return {
      currentUser,
      passwordForm,
      isSubmitting,
      passwordsDoNotMatch,
      changePassword,
      logoutAllSessions
    }
  }
}
</script>

<style scoped>
.user-profile {
  padding: 20px;
}

.card {
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  border: none;
  border-radius: 8px;
  margin-bottom: 20px;
}

.card-header {
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
  border-radius: 8px 8px 0 0;
}
</style>