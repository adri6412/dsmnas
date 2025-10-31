import axios from '@/plugins/axios'

// Stato iniziale
const state = {
  user: JSON.parse(localStorage.getItem('user')) || null,
  isAuthenticated: localStorage.getItem('isAuthenticated') === 'true'
}

// Getters
const getters = {
  isAuthenticated: state => state.isAuthenticated,
  currentUser: state => state.user
}

// Actions
const actions = {
  async login({ commit }, credentials) {
    try {
      const response = await axios.post('/api/auth/login', {
        username: credentials.username,
        password: credentials.password,
        remember_me: credentials.remember || false
      })
      
      const user = response.data
      
      // Salva l'utente nel localStorage
      localStorage.setItem('user', JSON.stringify(user))
      localStorage.setItem('isAuthenticated', 'true')
      
      commit('SET_AUTH', { user })
      return { success: true }
    } catch (error) {
      console.error('Errore di login:', error)
      return { 
        success: false, 
        message: error.response?.data?.detail || 'Errore durante l\'accesso' 
      }
    }
  },
  
  async logout({ commit }) {
    try {
      // Chiama l'API di logout
      await axios.post('/api/auth/logout')
    } catch (error) {
      console.error('Errore durante il logout:', error)
    } finally {
      // Rimuovi i dati dal localStorage
      localStorage.removeItem('user')
      localStorage.setItem('isAuthenticated', 'false')
      
      // Resetta lo stato
      commit('RESET_AUTH')
    }
  },
  
  async checkAuth({ commit }) {
    try {
      const response = await axios.get('/api/auth/me')
      const user = response.data
      
      // Aggiorna lo stato con i dati dell'utente
      localStorage.setItem('user', JSON.stringify(user))
      localStorage.setItem('isAuthenticated', 'true')
      
      commit('SET_AUTH', { user })
      return true
    } catch (error) {
      // Se c'è un errore, l'utente non è autenticato
      localStorage.removeItem('user')
      localStorage.setItem('isAuthenticated', 'false')
      
      commit('RESET_AUTH')
      return false
    }
  }
}

// Mutations
const mutations = {
  SET_AUTH(state, { user }) {
    state.user = user
    state.isAuthenticated = true
  },
  RESET_AUTH(state) {
    state.user = null
    state.isAuthenticated = false
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}