<template>
  <div class="update-management">
    <div class="container-fluid py-4">
      <h1 class="mb-4">
        <font-awesome-icon icon="sync-alt" class="me-2" />
        Gestione Aggiornamenti
      </h1>

      <!-- Card Informazioni Sistema -->
      <div class="row mb-4">
        <div class="col-12">
          <div class="card shadow-sm">
            <div class="card-header bg-primary text-white">
              <h5 class="mb-0">
                <font-awesome-icon icon="info-circle" class="me-2" />
                Versione Sistema
              </h5>
            </div>
            <div class="card-body">
              <div class="row">
                <div class="col-md-6">
                  <p><strong>Versione Corrente:</strong> <span class="badge bg-info text-dark fs-5">v{{ currentVersion }}</span></p>
                </div>
                <div class="col-md-6">
                  <p class="text-muted">
                    <font-awesome-icon icon="info-circle" class="me-2" />
                    Scarica gli aggiornamenti dalle <a href="https://github.com/adri6412/dsmnas/releases" target="_blank">release di GitHub</a>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Card Upload Aggiornamento -->
      <div class="row mb-4">
        <div class="col-12">
          <div class="card shadow-sm border-success">
            <div class="card-header bg-success text-white">
              <h5 class="mb-0">
                <font-awesome-icon icon="upload" class="me-2" />
                Carica Pacchetto di Aggiornamento
              </h5>
            </div>
            <div class="card-body">
              <div class="alert alert-info">
                <font-awesome-icon icon="info-circle" class="me-2" />
                <strong>Come aggiornare:</strong>
                <ol class="mt-2 mb-0">
                  <li>Scarica il file <code>armnas_update_v*.run</code> dalla <a href="https://github.com/adri6412/dsmnas/releases" target="_blank">pagina delle release</a></li>
                  <li>Carica il file utilizzando il form qui sotto</li>
                  <li>Riavvia il NAS per applicare l'aggiornamento</li>
                </ol>
              </div>
              
              <div class="input-group mb-3">
                <input 
                  type="file" 
                  class="form-control" 
                  @change="handleFileSelect"
                  accept=".run"
                  ref="fileInput"
                  :disabled="uploading"
                />
                <button 
                  class="btn btn-success btn-lg"
                  @click="uploadUpdate"
                  :disabled="!selectedFile || uploading"
                >
                  <font-awesome-icon 
                    :icon="uploading ? 'spinner' : 'upload'" 
                    :spin="uploading"
                    class="me-2"
                  />
                  {{ uploading ? 'Caricamento in corso...' : 'Carica Aggiornamento' }}
                </button>
              </div>

              <!-- Progress bar -->
              <div v-if="uploading" class="mb-3">
                <div class="progress" style="height: 25px;">
                  <div 
                    class="progress-bar progress-bar-striped progress-bar-animated bg-success" 
                    role="progressbar" 
                    :style="{ width: uploadProgress + '%' }"
                    :aria-valuenow="uploadProgress" 
                    aria-valuemin="0" 
                    aria-valuemax="100"
                  >
                    {{ uploadProgress }}%
                  </div>
                </div>
              </div>
              
              <small class="text-muted">
                <font-awesome-icon icon="shield-alt" class="me-1" />
                Solo file .run validi saranno accettati
              </small>
            </div>
          </div>
        </div>
      </div>

      <!-- Card Aggiornamenti Pending -->
      <div class="row mb-4">
        <div class="col-12">
          <div class="card shadow-sm">
            <div class="card-header bg-warning text-dark d-flex justify-content-between align-items-center">
              <h5 class="mb-0">
                <font-awesome-icon icon="clock" class="me-2" />
                Aggiornamenti in Attesa
              </h5>
              <button class="btn btn-sm btn-dark" @click="loadPendingUpdates" :disabled="loading">
                <font-awesome-icon icon="sync" :class="{ 'fa-spin': loading }" />
              </button>
            </div>
            <div class="card-body">
              <div v-if="loading" class="text-center py-4">
                <div class="spinner-border text-warning" role="status">
                  <span class="visually-hidden">Caricamento...</span>
                </div>
              </div>

              <div v-else-if="pendingUpdates.length === 0" class="alert alert-success">
                <font-awesome-icon icon="check-circle" class="me-2" />
                Nessun aggiornamento in attesa. Il sistema è aggiornato.
              </div>

              <div v-else>
                <div class="alert alert-warning">
                  <font-awesome-icon icon="exclamation-triangle" class="me-2" />
                  <strong>Attenzione!</strong> Ci sono {{ pendingUpdates.length }} aggiornamenti in attesa di installazione.
                  <br>
                  <strong>Riavvia il NAS</strong> per applicare gli aggiornamenti.
                </div>

                <div class="table-responsive">
                  <table class="table table-hover">
                    <thead>
                      <tr>
                        <th>File</th>
                        <th>Dimensione</th>
                        <th>Data Caricamento</th>
                        <th>Azioni</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="update in pendingUpdates" :key="update.filename">
                        <td>
                          <font-awesome-icon icon="file-archive" class="me-2 text-warning" />
                          <code>{{ update.filename }}</code>
                        </td>
                        <td>{{ formatBytes(update.size) }}</td>
                        <td>{{ formatDate(update.uploaded_at) }}</td>
                        <td>
                          <button 
                            class="btn btn-sm btn-danger"
                            @click="deletePendingUpdate(update.filename)"
                            :disabled="deleting"
                          >
                            <font-awesome-icon icon="trash" class="me-1" />
                            Elimina
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div class="d-grid gap-2 mt-3">
                  <button class="btn btn-warning btn-lg" @click="confirmReboot">
                    <font-awesome-icon icon="sync" class="me-2" />
                    Riavvia NAS per Applicare Aggiornamenti
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Card Cronologia Aggiornamenti -->
      <div class="row mb-4">
        <div class="col-12">
          <div class="card shadow-sm">
            <div class="card-header bg-secondary text-white d-flex justify-content-between align-items-center">
              <h5 class="mb-0">
                <font-awesome-icon icon="history" class="me-2" />
                Cronologia Aggiornamenti
              </h5>
              <button class="btn btn-sm btn-light" @click="loadUpdateHistory" :disabled="loading">
                <font-awesome-icon icon="sync" :class="{ 'fa-spin': loading }" />
              </button>
            </div>
            <div class="card-body">
              <div v-if="loading" class="text-center py-4">
                <div class="spinner-border text-secondary" role="status">
                  <span class="visually-hidden">Caricamento...</span>
                </div>
              </div>

              <div v-else-if="updateHistory.length === 0" class="text-muted text-center py-3">
                Nessun aggiornamento installato recentemente
              </div>

              <div v-else class="table-responsive">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Data</th>
                      <th>File</th>
                      <th>Stato</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(entry, index) in updateHistory" :key="index">
                      <td>{{ formatDate(entry.date) }}</td>
                      <td><code>{{ entry.filename }}</code></td>
                      <td>
                        <span v-if="entry.status === 'SUCCESS'" class="badge bg-success">
                          <font-awesome-icon icon="check" class="me-1" />
                          Completato
                        </span>
                        <span v-else class="badge bg-danger">
                          <font-awesome-icon icon="times" class="me-1" />
                          Fallito
                        </span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Conferma Riavvio -->
    <b-modal 
      v-model="showRebootModal" 
      title="Conferma Riavvio"
      @ok="rebootSystem"
      ok-variant="warning"
      ok-title="Riavvia Ora"
      cancel-title="Annulla"
    >
      <p class="text-warning">
        <font-awesome-icon icon="exclamation-triangle" class="me-2" />
        <strong>Attenzione!</strong>
      </p>
      <p>
        Il NAS verrà riavviato e gli aggiornamenti in attesa verranno installati automaticamente all'avvio.
      </p>
      <p>
        L'installazione potrebbe richiedere alcuni minuti. Durante questo tempo il NAS non sarà accessibile.
      </p>
      <p class="mb-0">
        Vuoi procedere con il riavvio?
      </p>
    </b-modal>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import { useToast } from 'vue-toast-notification'
import axios from '@/plugins/axios'

export default {
  name: 'UpdateManagement',
  setup() {
    const $toast = useToast()
    
    // State
    const currentVersion = ref('0.2.1')
    const selectedFile = ref(null)
    const uploading = ref(false)
    const uploadProgress = ref(0)
    const loading = ref(false)
    const deleting = ref(false)
    const pendingUpdates = ref([])
    const updateHistory = ref([])
    const showRebootModal = ref(false)
    const fileInput = ref(null)
    
    // Load data on mount
    onMounted(() => {
      loadCurrentVersion()
      loadPendingUpdates()
      loadUpdateHistory()
    })
    
    // Load current version
    const loadCurrentVersion = async () => {
      try {
        const response = await axios.get('/api/system/version')
        currentVersion.value = response.data.version
      } catch (error) {
        console.error('Errore nel caricamento della versione:', error)
      }
    }
    
    // Load pending updates
    const loadPendingUpdates = async () => {
      loading.value = true
      try {
        const response = await axios.get('/api/updates/pending')
        pendingUpdates.value = response.data.updates || []
      } catch (error) {
        console.error('Errore nel caricamento degli aggiornamenti pending:', error)
        $toast.error('Errore nel caricamento degli aggiornamenti in attesa')
      } finally {
        loading.value = false
      }
    }
    
    // Load update history
    const loadUpdateHistory = async () => {
      loading.value = true
      try {
        const response = await axios.get('/api/updates/history')
        updateHistory.value = response.data.history || []
      } catch (error) {
        console.error('Errore nel caricamento della cronologia:', error)
      } finally {
        loading.value = false
      }
    }
    
    // Handle file selection
    const handleFileSelect = (event) => {
      const file = event.target.files[0]
      if (file) {
        if (!file.name.endsWith('.run')) {
          $toast.error('Seleziona un file .run valido')
          event.target.value = ''
          return
        }
        selectedFile.value = file
      }
    }
    
    // Upload update
    const uploadUpdate = async () => {
      if (!selectedFile.value) return
      
      uploading.value = true
      uploadProgress.value = 0
      
      const formData = new FormData()
      formData.append('file', selectedFile.value)
      
      try {
        await axios.post('/api/updates/upload', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          },
          timeout: 300000, // 5 minuti per upload file .run grandi
          onUploadProgress: (progressEvent) => {
            uploadProgress.value = Math.round((progressEvent.loaded * 100) / progressEvent.total)
          }
        })
        
        $toast.success('Aggiornamento caricato con successo! Riavvia il NAS per applicarlo.')
        selectedFile.value = null
        if (fileInput.value) {
          fileInput.value.value = ''
        }
        loadPendingUpdates()
      } catch (error) {
        console.error('Errore nel caricamento dell\'aggiornamento:', error)
        $toast.error(error.response?.data?.detail || 'Errore nel caricamento dell\'aggiornamento')
      } finally {
        uploading.value = false
        uploadProgress.value = 0
      }
    }
    
    // Delete pending update
    const deletePendingUpdate = async (filename) => {
      if (!confirm(`Vuoi eliminare l'aggiornamento ${filename}?`)) return
      
      deleting.value = true
      try {
        await axios.delete(`/api/updates/pending/${filename}`)
        $toast.success('Aggiornamento eliminato')
        loadPendingUpdates()
      } catch (error) {
        console.error('Errore nell\'eliminazione:', error)
        $toast.error('Errore nell\'eliminazione dell\'aggiornamento')
      } finally {
        deleting.value = false
      }
    }
    
    // Confirm reboot
    const confirmReboot = () => {
      showRebootModal.value = true
    }
    
    // Reboot system
    const rebootSystem = async () => {
      try {
        await axios.post('/api/system/reboot')
        $toast.success('Riavvio in corso... Il sistema si riavvierà a breve.')
      } catch (error) {
        console.error('Errore nel riavvio:', error)
        $toast.error('Errore nel riavvio del sistema')
      }
    }
    
    // Format bytes
    const formatBytes = (bytes) => {
      if (!bytes) return '0 B'
      const k = 1024
      const sizes = ['B', 'KB', 'MB', 'GB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
    }
    
    // Format date
    const formatDate = (dateString) => {
      if (!dateString) return '-'
      const date = new Date(dateString)
      return date.toLocaleString('it-IT')
    }
    
    return {
      currentVersion,
      selectedFile,
      uploading,
      uploadProgress,
      loading,
      deleting,
      pendingUpdates,
      updateHistory,
      showRebootModal,
      fileInput,
      handleFileSelect,
      uploadUpdate,
      loadPendingUpdates,
      loadUpdateHistory,
      deletePendingUpdate,
      confirmReboot,
      rebootSystem,
      formatBytes,
      formatDate
    }
  }
}
</script>

<style scoped>
.update-management {
  background-color: #f8f9fa;
  min-height: 100vh;
}

.card {
  border-radius: 10px;
  overflow: hidden;
}

.card-header {
  font-weight: 600;
}

code {
  background-color: #e9ecef;
  padding: 2px 6px;
  border-radius: 3px;
  font-size: 0.9em;
}

.progress {
  border-radius: 10px;
}

.table {
  margin-bottom: 0;
}

a {
  color: #007bff;
  text-decoration: none;
}

a:hover {
  text-decoration: underline;
}
</style>
