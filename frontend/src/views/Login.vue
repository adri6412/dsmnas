<template>
  <div class="login-container">
    <div class="login-card">
      <div class="login-header">
        <h2>ArmNAS</h2>
        <p>Gestione NAS per dispositivi ARM</p>
      </div>
      
      <div class="login-body">
        <form @submit.prevent="handleLogin">
          <div class="mb-3">
            <label for="username" class="form-label">{{ $t('login.username') }}</label>
            <input 
              type="text" 
              class="form-control" 
              id="username" 
              v-model="username" 
              required 
              autofocus
            >
          </div>
          
          <div class="mb-3">
            <label for="password" class="form-label">{{ $t('login.password') }}</label>
            <input 
              type="password" 
              class="form-control" 
              id="password" 
              v-model="password" 
              required
            >
          </div>
          
          <div class="mb-3 form-check">
            <input 
              type="checkbox" 
              class="form-check-input" 
              id="remember" 
              v-model="remember"
            >
            <label class="form-check-label" for="remember">
              {{ $t('login.remember') }}
            </label>
          </div>
          
          <div v-if="error" class="alert alert-danger">
            {{ error }}
          </div>
          
          <button 
            type="submit" 
            class="btn btn-primary w-100" 
            :disabled="loading"
          >
            <span v-if="loading" class="spinner-border spinner-border-sm me-2"></span>
            {{ $t('login.login') }}
          </button>
        </form>
        
        <div class="mt-3 text-center">
          <small class="text-muted">
            Accedi con le credenziali del tuo account.<br>
            L'utente predefinito è "admin" con password "admin".
          </small>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue'
import { useStore } from 'vuex'
import { useRouter } from 'vue-router'

export default {
  name: 'Login',
  setup() {
    const store = useStore()
    const router = useRouter()
    
    const username = ref('')
    const password = ref('')
    const remember = ref(false)
    const loading = ref(false)
    const error = ref('')
    
    const handleLogin = async () => {
      loading.value = true
      error.value = ''
      
      try {
        const result = await store.dispatch('auth/login', {
          username: username.value,
          password: password.value,
          remember: remember.value
        })
        
        if (result.success) {
          router.push('/')
        } else {
          error.value = result.message || 'Errore durante l\'accesso'
        }
      } catch (err) {
        error.value = err.message || 'Errore durante l\'accesso'
      } finally {
        loading.value = false
      }
    }
    
    return {
      username,
      password,
      remember,
      loading,
      error,
      handleLogin
    }
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background-color: #f8f9fa;
}

.login-card {
  width: 100%;
  max-width: 400px;
  background-color: #fff;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.login-header {
  padding: 20px;
  background-color: #343a40;
  color: #fff;
  text-align: center;
}

.login-header h2 {
  margin: 0;
  font-size: 24px;
}

.login-header p {
  margin: 5px 0 0;
  opacity: 0.8;
}

.login-body {
  padding: 20px;
}
</style>