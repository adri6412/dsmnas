import { createStore } from 'vuex'
import auth from './modules/auth'
import disk from './modules/disk'
import system from './modules/system'

export default createStore({
  modules: {
    auth,
    disk,
    system
  }
})