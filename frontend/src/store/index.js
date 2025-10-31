import { createStore } from 'vuex'
import auth from './modules/auth'
import disk from './modules/disk'

export default createStore({
  modules: {
    auth,
    disk
  }
})