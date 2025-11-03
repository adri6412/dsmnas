import axios from '@/plugins/axios'

const state = {
  systemInfo: null,
  services: [],
  loading: false,
  error: null
}

const getters = {
  systemInfo: state => state.systemInfo,
  allServices: state => state.services,
  isLoading: state => state.loading,
  hasError: state => !!state.error,
  errorMessage: state => state.error
}

const actions = {
  async fetchSystemInfo({ commit }) {
    commit('SET_LOADING', true)
    try {
      const response = await axios.get('/api/system/info')
      commit('SET_SYSTEM_INFO', response.data)
      commit('SET_ERROR', null)
    } catch (error) {
      console.error('Errore fetch system info:', error)
      commit('SET_ERROR', error.response?.data?.detail || 'Errore nel recupero delle informazioni di sistema')
    } finally {
      commit('SET_LOADING', false)
    }
  },
  
  async fetchServices({ commit }) {
    commit('SET_LOADING', true)
    try {
      const response = await axios.get('/api/system/services')
      commit('SET_SERVICES', response.data)
      commit('SET_ERROR', null)
    } catch (error) {
      console.error('Errore fetch services:', error)
      commit('SET_ERROR', error.response?.data?.detail || 'Errore nel recupero dello stato dei servizi')
    } finally {
      commit('SET_LOADING', false)
    }
  },
  
  async restartService({ commit }, serviceName) {
    commit('SET_LOADING', true)
    try {
      await axios.post('/api/system/service/restart', { service_name: serviceName })
      commit('SET_ERROR', null)
      return { success: true }
    } catch (error) {
      const errorMessage = error.response?.data?.detail || 'Errore nel riavvio del servizio'
      commit('SET_ERROR', errorMessage)
      return { success: false, message: errorMessage }
    } finally {
      commit('SET_LOADING', false)
    }
  },
  
  async stopService({ commit }, serviceName) {
    commit('SET_LOADING', true)
    try {
      await axios.post('/api/system/service/stop', { service_name: serviceName })
      commit('SET_ERROR', null)
      return { success: true }
    } catch (error) {
      const errorMessage = error.response?.data?.detail || 'Errore nell\'arresto del servizio'
      commit('SET_ERROR', errorMessage)
      return { success: false, message: errorMessage }
    } finally {
      commit('SET_LOADING', false)
    }
  },
  
  async startService({ commit }, serviceName) {
    commit('SET_LOADING', true)
    try {
      await axios.post('/api/system/service/start', { service_name: serviceName })
      commit('SET_ERROR', null)
      return { success: true }
    } catch (error) {
      const errorMessage = error.response?.data?.detail || 'Errore nell\'avvio del servizio'
      commit('SET_ERROR', errorMessage)
      return { success: false, message: errorMessage }
    } finally {
      commit('SET_LOADING', false)
    }
  }
}

const mutations = {
  SET_SYSTEM_INFO(state, info) {
    state.systemInfo = info
  },
  SET_SERVICES(state, services) {
    state.services = services
  },
  SET_LOADING(state, loading) {
    state.loading = loading
  },
  SET_ERROR(state, error) {
    state.error = error
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}

