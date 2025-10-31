import axios from '@/plugins/axios'

const state = {
  disks: [],
  loading: false,
  error: null
}

const getters = {
  allDisks: state => state.disks,
  isLoading: state => state.loading,
  hasError: state => !!state.error,
  errorMessage: state => state.error
}

const actions = {
  async fetchDisks({ commit }) {
    commit('SET_LOADING', true)
    try {
      const response = await axios.get('/api/disk/info')
      commit('SET_DISKS', response.data)
      commit('SET_ERROR', null)
    } catch (error) {
      commit('SET_ERROR', error.response?.data?.detail || 'Errore nel recupero delle informazioni sui dischi')
    } finally {
      commit('SET_LOADING', false)
    }
  },
  
  async performDiskOperation({ commit, dispatch }, operation) {
    commit('SET_LOADING', true)
    try {
      await axios.post('/api/disk/operation', operation)
      commit('SET_ERROR', null)
      // Aggiorna l'elenco dei dischi dopo l'operazione
      dispatch('fetchDisks')
      return { success: true }
    } catch (error) {
      const errorMessage = error.response?.data?.detail || 'Errore nell\'operazione sul disco'
      commit('SET_ERROR', errorMessage)
      return { success: false, message: errorMessage }
    } finally {
      commit('SET_LOADING', false)
    }
  },
  
  async checkDiskHealth({ commit }, device) {
    commit('SET_LOADING', true)
    try {
      const response = await axios.get(`/api/disk/health?device=${device}`)
      commit('SET_ERROR', null)
      return { success: true, health: response.data.health }
    } catch (error) {
      const errorMessage = error.response?.data?.detail || 'Errore nel controllo della salute del disco'
      commit('SET_ERROR', errorMessage)
      return { success: false, message: errorMessage }
    } finally {
      commit('SET_LOADING', false)
    }
  }
}

const mutations = {
  SET_DISKS(state, disks) {
    state.disks = disks
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