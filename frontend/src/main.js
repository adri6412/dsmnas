import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import store from './store'
import { createI18n } from 'vue-i18n'
import BootstrapVue3 from 'bootstrap-vue-3'
import ToastPlugin from 'vue-toast-notification'
import axios from './plugins/axios'
import { library } from '@fortawesome/fontawesome-svg-core'
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'
import {
  faHome, faServer, faUsers, faShareAlt, faNetworkWired,
  faCog, faFolder, faFolderOpen, faFile, faUpload, faDownload,
  faTrash, faCopy, faPaste, faEdit, faPlus, faMinus, faSync,
  faPlay, faStop, faPowerOff, faSearch, faLock, faUnlock,
  faChartLine, faInfoCircle, faExclamationTriangle, faCheck,
  faHdd, faBolt, faHeartbeat, faPlug, faUnlink, faEraser,
  faUserPlus, faAngleLeft, faAngleRight, faSignOutAlt,
  faFileImage, faFileWord, faFileExcel, faFilePdf, faFileArchive,
  faFileAudio, faFileVideo, faFileCode, faFolderPlus, faUserCog,
  faUser, faKey, faShieldAlt, faDatabase, faSyncAlt, faBell,
  faExclamationCircle, faCheckCircle, faSave, faArchive, faUndo,
  faSpinner, faBox, faExternalLinkAlt
} from '@fortawesome/free-solid-svg-icons'

// Importa gli stili Bootstrap
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue-3/dist/bootstrap-vue-3.css'
import 'vue-toast-notification/dist/theme-bootstrap.css'

// Importa i messaggi di localizzazione
import it from './locales/it.json'

// Configura i18n
const i18n = createI18n({
  locale: 'it',
  fallbackLocale: 'it',
  messages: { it }
})

// Configura FontAwesome
library.add(
  faHome, faServer, faUsers, faShareAlt, faNetworkWired,
  faCog, faFolder, faFolderOpen, faFile, faUpload, faDownload,
  faTrash, faCopy, faPaste, faEdit, faPlus, faMinus, faSync,
  faPlay, faStop, faPowerOff, faSearch, faLock, faUnlock,
  faChartLine, faInfoCircle, faExclamationTriangle, faCheck,
  faHdd, faBolt, faHeartbeat, faPlug, faUnlink, faEraser,
  faUserPlus, faAngleLeft, faAngleRight, faSignOutAlt,
  faFileImage, faFileWord, faFileExcel, faFilePdf, faFileArchive,
  faFileAudio, faFileVideo, faFileCode, faFolderPlus, faUserCog,
  faUser, faKey, faShieldAlt, faDatabase, faSyncAlt, faBell,
  faExclamationCircle, faCheckCircle, faSave, faArchive, faUndo,
  faSpinner, faBox, faExternalLinkAlt
)

// Crea l'app Vue
const app = createApp(App)

// Registra i plugin
app.use(router)
app.use(store)
app.use(i18n)
app.use(BootstrapVue3)
app.use(ToastPlugin)

// Registra i componenti globali
app.component('font-awesome-icon', FontAwesomeIcon)

// Verifica l'autenticazione prima di montare l'app
store.dispatch('auth/checkAuth').then(() => {
  console.log('Auth checked in main.js, current user:', store.getters['auth/currentUser'])
  // Monta l'app
  app.mount('#app')
})