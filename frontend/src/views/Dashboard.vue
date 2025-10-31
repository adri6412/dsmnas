<template>
  <div class="dashboard">
    <!-- Debug info -->
    <div class="debug-info mb-4" style="display: none;">
      <pre>isAdmin: {{ isAdmin }} ({{ typeof isAdmin }})</pre>
      <pre>currentUser: {{ JSON.stringify(currentUser, null, 2) }}</pre>
    </div>
    
    <!-- Dashboard per utenti normali -->
    <div v-if="!isAdmin">
      <div class="alert alert-info mb-4">
        <font-awesome-icon icon="info-circle" class="me-2" />
        {{ $t('dashboard.non_admin_message') || 'Sei connesso come utente normale. Alcune funzionalità sono disponibili solo per gli amministratori.' }}
      </div>
      
      <div class="row">
        <!-- Informazioni utente -->
        <div class="col-md-6 mb-4">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <font-awesome-icon icon="user" class="me-2" />
                {{ $t('dashboard.user_info') || 'Informazioni Utente' }}
              </h5>
            </div>
            <div class="card-body">
              <div class="mb-3">
                <strong>{{ $t('users.username') }}:</strong> {{ currentUser?.username }}
              </div>
              <div class="mb-3">
                <strong>{{ $t('users.role') || 'Ruolo' }}:</strong> 
                <span class="badge bg-secondary">{{ $t('users.user') || 'Utente' }}</span>
              </div>
              <div class="alert alert-light border">
                <p>{{ $t('dashboard.user_instructions') || 'Come utente normale, puoi:' }}</p>
                <ul>
                  <li>{{ $t('dashboard.user_browse_files') || 'Sfogliare i file' }}</li>
                  <li>{{ $t('dashboard.user_view_system') || 'Visualizzare le informazioni di sistema' }}</li>
                  <li>{{ $t('dashboard.user_manage_account') || 'Gestire il tuo account' }}</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Guida rapida -->
        <div class="col-md-6 mb-4">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <font-awesome-icon icon="info-circle" class="me-2" />
                {{ $t('dashboard.quick_guide') || 'Guida Rapida' }}
              </h5>
            </div>
            <div class="card-body">
              <div class="alert alert-info">
                <p><strong>{{ $t('dashboard.welcome') || 'Benvenuto nel tuo NAS!' }}</strong></p>
                <p>{{ $t('dashboard.user_welcome_message') || 'Questo è il pannello di controllo del tuo NAS. Da qui puoi accedere ai tuoi file e gestire il tuo account.' }}</p>
              </div>
              
              <div class="mb-3">
                <h6><font-awesome-icon icon="folder" class="me-2" />{{ $t('sidebar.files') || 'File' }}</h6>
                <p>{{ $t('dashboard.files_description') || 'Accedi ai tuoi file, carica nuovi documenti e gestisci le tue cartelle.' }}</p>
                <router-link to="/files" class="btn btn-sm btn-primary">
                  {{ $t('dashboard.go_to_files') || 'Vai ai file' }}
                </router-link>
              </div>
              
              <div class="mb-3">
                <h6><font-awesome-icon icon="user-cog" class="me-2" />{{ $t('sidebar.profile') || 'Profilo' }}</h6>
                <p>{{ $t('dashboard.profile_description') || 'Gestisci il tuo profilo e cambia la tua password.' }}</p>
                <router-link to="/profile" class="btn btn-sm btn-primary">
                  {{ $t('dashboard.go_to_profile') || 'Vai al profilo' }}
                </router-link>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Informazioni di sistema (versione limitata) -->
        <div class="col-md-12 mb-4">
          <div class="card h-100">
            <div class="card-header d-flex justify-content-between align-items-center">
              <h5 class="mb-0">
                <font-awesome-icon icon="info-circle" class="me-2" />
                {{ $t('dashboard.system_info') }}
              </h5>
              <button class="btn btn-sm btn-outline-primary" @click="refreshSystemInfo">
                <font-awesome-icon icon="sync" :class="{ 'fa-spin': loading }" />
              </button>
            </div>
            <div class="card-body">
              <div v-if="loading" class="text-center py-3">
                <div class="spinner-border text-primary" role="status">
                  <span class="visually-hidden">{{ $t('common.loading') }}</span>
                </div>
              </div>
              <div v-else-if="systemInfo">
                <div class="row">
                  <div class="col-md-6">
                    <div class="mb-3">
                      <strong>{{ $t('dashboard.hostname') }}:</strong> {{ systemInfo.hostname }}
                    </div>
                    <div class="mb-3">
                      <strong>{{ $t('dashboard.os') }}:</strong> {{ systemInfo.os }}
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="mb-3">
                      <strong>{{ $t('dashboard.uptime') }}:</strong> {{ systemInfo.uptime }}
                    </div>
                    <div class="mb-3">
                      <strong>{{ $t('dashboard.kernel') }}:</strong> {{ systemInfo.kernel }}
                    </div>
                  </div>
                </div>
              </div>
              <div v-else class="text-center py-3 text-muted">
                {{ $t('common.error') }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Dashboard per amministratori -->
    <div v-else>
      <div class="row">
        <!-- Informazioni di sistema -->
        <div class="col-md-6 mb-4">
          <div class="card h-100">
            <div class="card-header d-flex justify-content-between align-items-center">
              <h5 class="mb-0">
                <font-awesome-icon icon="info-circle" class="me-2" />
                {{ $t('dashboard.system_info') }}
              </h5>
              <button class="btn btn-sm btn-outline-primary" @click="refreshSystemInfo">
                <font-awesome-icon icon="sync" :class="{ 'fa-spin': loading }" />
              </button>
            </div>
            <div class="card-body">
              <div v-if="loading" class="text-center py-3">
                <div class="spinner-border text-primary" role="status">
                  <span class="visually-hidden">{{ $t('common.loading') }}</span>
                </div>
              </div>
              <div v-else-if="systemInfo">
                <div class="mb-3">
                  <strong>{{ $t('dashboard.hostname') }}:</strong> {{ systemInfo.hostname }}
                </div>
                <div class="mb-3">
                  <strong>{{ $t('dashboard.os') }}:</strong> {{ systemInfo.os }}
                </div>
                <div class="mb-3">
                  <strong>{{ $t('dashboard.kernel') }}:</strong> {{ systemInfo.kernel }}
                </div>
                <div class="mb-3">
                  <strong>{{ $t('dashboard.uptime') }}:</strong> {{ systemInfo.uptime }}
                </div>
                
                <!-- CPU Usage -->
                <div class="mb-3">
                  <div class="d-flex justify-content-between mb-1">
                    <strong>{{ $t('dashboard.cpu_usage') }}:</strong>
                    <span>{{ systemInfo.cpu_usage }}%</span>
                  </div>
                  <div class="progress">
                    <div 
                      class="progress-bar" 
                      role="progressbar" 
                      :style="{ width: systemInfo.cpu_usage + '%' }" 
                      :class="getCpuBarClass(systemInfo.cpu_usage)"
                      :aria-valuenow="systemInfo.cpu_usage" 
                      aria-valuemin="0" 
                      aria-valuemax="100"
                    ></div>
                  </div>
                </div>
                
                <!-- Memory Usage -->
                <div>
                  <div class="d-flex justify-content-between mb-1">
                    <strong>{{ $t('dashboard.memory_usage') }}:</strong>
                    <span>{{ formatBytes(systemInfo.memory_used) }} / {{ formatBytes(systemInfo.memory_total) }} ({{ systemInfo.memory_percent }}%)</span>
                  </div>
                  <div class="progress">
                    <div 
                      class="progress-bar" 
                      role="progressbar" 
                      :style="{ width: systemInfo.memory_percent + '%' }" 
                      :class="getMemoryBarClass(systemInfo.memory_percent)"
                      :aria-valuenow="systemInfo.memory_percent" 
                      aria-valuemin="0" 
                      aria-valuemax="100"
                    ></div>
                  </div>
                </div>
              </div>
              <div v-else class="text-center py-3 text-muted">
                {{ $t('common.error') }}
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Stato dei servizi -->
      <div class="col-md-6 mb-4">
        <div class="card h-100">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="server" class="me-2" />
              {{ $t('dashboard.services') }}
            </h5>
            <button class="btn btn-sm btn-outline-primary" @click="refreshServices">
              <font-awesome-icon icon="sync" :class="{ 'fa-spin': loadingServices }" />
            </button>
          </div>
          <div class="card-body">
            <div v-if="loadingServices" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') }}</span>
              </div>
            </div>
            <div v-else-if="services && services.length">
              <table class="table table-hover">
                <thead>
                  <tr>
                    <th>{{ $t('dashboard.service_name') }}</th>
                    <th>{{ $t('dashboard.service_status') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="service in services" :key="service.name">
                    <td>{{ getServiceDisplayName(service.name) }}</td>
                    <td>
                      <span
                        class="badge"
                        :class="service.running ? 'bg-success' : 'bg-danger'"
                      >
                        {{ service.running ? $t('common.running') : $t('common.stopped') }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-else class="text-center py-3 text-muted">
              <p>{{ $t('common.error') }}</p>
              <button class="btn btn-sm btn-primary mt-2" @click="refreshServices">
                {{ $t('common.retry') }}
              </button>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Utilizzo disco -->
      <div class="col-md-6 mb-4">
        <div class="card h-100">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="hdd" class="me-2" />
              {{ $t('dashboard.disk_usage') }}
            </h5>
            <button class="btn btn-sm btn-outline-primary" @click="refreshDisks">
              <font-awesome-icon icon="sync" :class="{ 'fa-spin': loadingDisks }" />
            </button>
          </div>
          <div class="card-body">
            <div v-if="loadingDisks" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') }}</span>
              </div>
            </div>
            <div v-else-if="disks && disks.length">
              <div v-for="disk in disks" :key="disk.device" class="mb-3">
                <div class="d-flex justify-content-between mb-1">
                  <strong>{{ disk.device }} ({{ disk.mountpoint }})</strong>
                  <span>{{ formatBytes(disk.used) }} / {{ formatBytes(disk.total) }} ({{ disk.percent }}%)</span>
                </div>
                <div class="progress">
                  <div 
                    class="progress-bar" 
                    role="progressbar" 
                    :style="{ width: disk.percent + '%' }" 
                    :class="getDiskBarClass(disk.percent)"
                    :aria-valuenow="disk.percent" 
                    aria-valuemin="0" 
                    aria-valuemax="100"
                  ></div>
                </div>
              </div>
            </div>
            <div v-else class="text-center py-3 text-muted">
              {{ $t('common.error') }}
            </div>
          </div>
        </div>
      </div>
      
      <!-- Azioni rapide (solo per admin) -->
      <div class="col-md-6 mb-4" v-if="isAdmin">
        <div class="card h-100">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="bolt" class="me-2" />
              {{ $t('dashboard.quick_actions') }}
            </h5>
          </div>
          <div class="card-body">
            <div class="d-grid gap-2">
              <button class="btn btn-primary" @click="showRebootConfirm">
                <font-awesome-icon icon="sync" class="me-2" />
                {{ $t('dashboard.reboot') }}
              </button>
              <button class="btn btn-danger" @click="showShutdownConfirm">
                <font-awesome-icon icon="power-off" class="me-2" />
                {{ $t('dashboard.shutdown') }}
              </button>
              <button class="btn btn-success" @click="updateSystem">
                <font-awesome-icon icon="download" class="me-2" />
                {{ $t('dashboard.update') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Modal di conferma per il riavvio -->
    <b-modal 
      v-model="showRebootModal" 
      :title="$t('system.confirm_reboot')" 
      @ok="rebootSystem"
      ok-variant="danger"
      :ok-title="$t('common.yes')"
      :cancel-title="$t('common.no')"
    >
      <p>{{ $t('system.confirm_reboot') }}</p>
    </b-modal>
    
    <!-- Modal di conferma per lo spegnimento -->
    <b-modal 
      v-model="showShutdownModal" 
      :title="$t('system.confirm_shutdown')" 
      @ok="shutdownSystem"
      ok-variant="danger"
      :ok-title="$t('common.yes')"
      :cancel-title="$t('common.no')"
    >
      <p>{{ $t('system.confirm_shutdown') }}</p>
    </b-modal>
  </div>
</template>

<script>
import { ref, onMounted, computed } from 'vue'
import { useStore } from 'vuex'
import { useToast } from 'vue-toast-notification'

export default {
  name: 'Dashboard',
  setup() {
    const store = useStore()
    const $toast = useToast()
    
    // Stato
    const systemInfo = ref(null)
    const services = ref([])
    const disks = ref([])
    const loading = ref(false)
    const loadingServices = ref(false)
    const loadingDisks = ref(false)
    const showRebootModal = ref(false)
    const showShutdownModal = ref(false)
    
    // Ottieni l'utente corrente
    const currentUser = computed(() => store.getters['auth/currentUser'])
    
    // Verifica se l'utente è admin
    const isAdmin = computed(() => {
      const isAdminValue = !!currentUser.value?.is_admin
      console.log('Dashboard - isAdmin computed:', isAdminValue, 'currentUser:', currentUser.value)
      return isAdminValue
    })
    
    // Carica i dati all'avvio
    onMounted(async () => {
      // Forza un refresh dell'utente corrente
      await store.dispatch('auth/checkAuth')
      
      // Carica i dati
      refreshSystemInfo()
      
      // Carica i servizi e i dischi solo se l'utente è admin
      if (isAdmin.value) {
        refreshServices()
        refreshDisks()
      }
    })
    
    // Funzioni per aggiornare i dati
    const refreshSystemInfo = async () => {
      loading.value = true
      try {
        await store.dispatch('system/fetchSystemInfo')
        systemInfo.value = store.getters['system/systemInfo']
      } catch (error) {
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per accedere a queste informazioni')
        } else {
          $toast.error('Errore nel caricamento delle informazioni di sistema')
        }
      } finally {
        loading.value = false
      }
    }
    
    const refreshServices = async () => {
      loadingServices.value = true
      try {
        // Verifica se l'utente è admin
        if (!isAdmin.value) {
          $toast.error('Solo gli amministratori possono visualizzare lo stato dei servizi')
          loadingServices.value = false
          return
        }
        
        // Chiamata tramite Vuex
        await store.dispatch('system/fetchServices')
        services.value = store.getters['system/allServices']

        // Verifica se c'è un errore nello store
        if (store.getters['system/hasError']) {
          const errorMsg = store.getters['system/errorMessage']
          $toast.error(errorMsg || 'Errore nel caricamento dello stato dei servizi')
        }

        // Verifica se i servizi sono stati caricati correttamente
        if (!services.value || services.value.length === 0) {
          console.warn('Nessun servizio caricato')
        }
      } catch (error) {
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per accedere a queste informazioni')
        } else {
          $toast.error('Errore nel caricamento dello stato dei servizi')
        }
      } finally {
        loadingServices.value = false
      }
    }
    
    const refreshDisks = async () => {
      loadingDisks.value = true
      try {
        // Verifica se l'utente è admin
        if (!isAdmin.value) {
          $toast.error('Solo gli amministratori possono visualizzare le informazioni sui dischi')
          loadingDisks.value = false
          return
        }
        
        await store.dispatch('disk/fetchDisks')
        disks.value = store.getters['disk/allDisks']
      } catch (error) {
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per accedere a queste informazioni')
        } else {
          $toast.error('Errore nel caricamento delle informazioni sui dischi')
        }
      } finally {
        loadingDisks.value = false
      }
    }
    
    // Funzioni per le azioni di sistema
    const showRebootConfirm = () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono riavviare il sistema')
        return
      }
      showRebootModal.value = true
    }
    
    const showShutdownConfirm = () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono spegnere il sistema')
        return
      }
      showShutdownModal.value = true
    }
    
    const rebootSystem = async () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono riavviare il sistema')
        return
      }
      
      try {
        const result = await store.dispatch('system/rebootSystem')
        if (result.success) {
          $toast.success('Il sistema verrà riavviato tra pochi secondi')
        } else {
          $toast.error(result.message || 'Errore nel riavvio del sistema')
        }
      } catch (error) {
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per riavviare il sistema')
        } else {
          $toast.error('Errore nel riavvio del sistema')
        }
      }
    }
    
    const shutdownSystem = async () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono spegnere il sistema')
        return
      }
      
      try {
        const result = await store.dispatch('system/shutdownSystem')
        if (result.success) {
          $toast.success('Il sistema verrà spento tra pochi secondi')
        } else {
          $toast.error(result.message || 'Errore nello spegnimento del sistema')
        }
      } catch (error) {
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per spegnere il sistema')
        } else {
          $toast.error('Errore nello spegnimento del sistema')
        }
      }
    }
    
    const updateSystem = async () => {
      // Verifica se l'utente è admin
      if (!isAdmin.value) {
        $toast.error('Solo gli amministratori possono aggiornare il sistema')
        return
      }
      
      try {
        $toast.info('Aggiornamento del sistema in corso...')
        const result = await store.dispatch('system/updateSystem')
        if (result.success) {
          $toast.success(result.message || 'Sistema aggiornato con successo')
        } else {
          $toast.error(result.message || 'Errore nell\'aggiornamento del sistema')
        }
      } catch (error) {
        if (error.response && error.response.status === 403) {
          $toast.error('Non hai i permessi per aggiornare il sistema')
        } else {
          $toast.error('Errore nell\'aggiornamento del sistema')
        }
      }
    }
    
    // Funzioni di utilità
    const formatBytes = (bytes, decimals = 2) => {
      if (bytes === 0) return '0 Bytes'
      
      const k = 1024
      const dm = decimals < 0 ? 0 : decimals
      const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
      
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      
      return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i]
    }
    
    const getCpuBarClass = (percent) => {
      if (percent < 60) return 'bg-success'
      if (percent < 85) return 'bg-warning'
      return 'bg-danger'
    }
    
    const getMemoryBarClass = (percent) => {
      if (percent < 70) return 'bg-success'
      if (percent < 90) return 'bg-warning'
      return 'bg-danger'
    }
    
    const getDiskBarClass = (percent) => {
      if (percent < 75) return 'bg-success'
      if (percent < 90) return 'bg-warning'
      return 'bg-danger'
    }
    
    const getServiceDisplayName = (serviceName) => {
      switch (serviceName) {
        case 'smbd':
          return 'Samba'
        case 'vsftpd':
          return 'FTP'
        case 'ssh':
          return 'SSH/SFTP'
        default:
          return serviceName
      }
    }
    
    return {
      systemInfo,
      services,
      disks,
      loading,
      loadingServices,
      loadingDisks,
      showRebootModal,
      showShutdownModal,
      currentUser,
      isAdmin,
      refreshSystemInfo,
      refreshServices,
      refreshDisks,
      showRebootConfirm,
      showShutdownConfirm,
      rebootSystem,
      shutdownSystem,
      updateSystem,
      formatBytes,
      getCpuBarClass,
      getMemoryBarClass,
      getDiskBarClass,
      getServiceDisplayName
    }
  }
}
</script>

<style scoped>
.dashboard {
  padding: 20px;
}

.card {
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  border: none;
  border-radius: 8px;
}

.card-header {
  background-color: #f8f9fa;
  border-bottom: 1px solid rgba(0, 0, 0, 0.125);
  padding: 0.75rem 1.25rem;
}

.progress {
  height: 10px;
  border-radius: 5px;
}
</style>