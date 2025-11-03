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
                Informazioni Sistema
              </h5>
            </div>
            <div class="card-body">
              <div class="row">
                <div class="col-md-6">
                  <p><strong>Versione Corrente:</strong> <span class="badge bg-info text-dark fs-5">v{{ systemStatus.current_version }}</span></p>
                </div>
                <div class="col-md-6">
                  <p class="text-muted">
                    <font-awesome-icon icon="info-circle" class="me-2" />
                    Scarica gli aggiornamenti dalle release di GitHub o caricali manualmente
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
          <div class="card shadow-sm border-primary">
            <div class="card-header bg-gradient" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
              <h5 class="mb-0">
                <font-awesome-icon icon="upload" class="me-2" />
                Carica Pacchetto di Aggiornamento
              </h5>
            </div>
            <div class="card-body">
              <div class="alert alert-info mb-3">
                <font-awesome-icon icon="info-circle" class="me-2" />
                <strong>Scarica gli aggiornamenti da GitHub Releases:</strong>
                <a href="https://github.com/TUO-USERNAME/TUO-REPO/releases" target="_blank" class="ms-2">
                  Vai alle Release <font-awesome-icon icon="external-link-alt" class="ms-1" />
                </a>
              </div>
              
              <p class="text-muted mb-3">
                Carica il file <code>.run</code> scaricato dalle release di GitHub. Il sistema verificherà automaticamente l'integrità del pacchetto.
              </p>
              
              <div class="input-group mb-2">
                <input 
                  type="file" 
                  class="form-control" 
                  @change="handleFileSelect"
                  accept=".run"
                  ref="fileInput"
                  :disabled="uploading"
                />
                <button 
                  class="btn btn-primary btn-lg"
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
              
              <small class="text-muted">
                <font-awesome-icon icon="shield-alt" class="me-1" />
                Solo file .run con checksum valido saranno accettati
              </small>
            </div>
          </div>
        </div>
      </div>

      <!-- Card Aggiornamenti Scaricati -->
      <div class="row mb-4" v-if="downloadedUpdates.length > 0">
        <div class="col-12">
          <div class="card shadow-sm">
            <div class="card-header bg-info text-white">
              <h5 class="mb-0">
                <font-awesome-icon icon="file-archive" class="me-2" />
                Aggiornamenti Scaricati
              </h5>
            </div>
            <div class="card-body">
              <div class="table-responsive">
                <table class="table table-hover">
                  <thead>
                    <tr>
                      <th>File</th>
                      <th>Dimensione</th>
                      <th>Scaricato</th>
                      <th class="text-end">Azioni</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="update in downloadedUpdates" :key="update.filename">
                      <td>
                        <font-awesome-icon icon="file" class="me-2 text-muted" />
                        {{ update.filename }}
                      </td>
                      <td>{{ update.size_mb }} MB</td>
                      <td>{{ formatDate(update.downloaded) }}</td>
                      <td class="text-end">
                        <button 
                          class="btn btn-sm btn-success me-2"
                          @click="installDownloadedUpdate(update.filename)"
                          :disabled="installing"
                        >
                          <font-awesome-icon icon="play" class="me-1" />
                          Installa
                        </button>
                        <button 
                          class="btn btn-sm btn-danger"
                          @click="deleteDownloadedUpdate(update.filename)"
                        >
                          <font-awesome-icon icon="trash" />
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Card Backup -->
      <div class="row">
        <div class="col-12">
          <div class="card shadow-sm">
            <div class="card-header bg-dark text-white">
              <h5 class="mb-0">
                <font-awesome-icon icon="save" class="me-2" />
                Backup del Sistema
              </h5>
            </div>
            <div class="card-body">
              <p class="text-muted">
                I backup vengono creati automaticamente prima di ogni aggiornamento. 
                Puoi ripristinare una versione precedente in caso di problemi.
              </p>
              
              <div v-if="backups.length === 0" class="text-center py-3">
                <font-awesome-icon icon="folder-open" class="text-muted mb-2" size="2x" />
                <p class="text-muted">Nessun backup disponibile</p>
              </div>
              
              <div v-else class="table-responsive">
                <table class="table table-hover">
                  <thead>
                    <tr>
                      <th>File</th>
                      <th>Dimensione</th>
                      <th>Data Creazione</th>
                      <th class="text-end">Azioni</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="backup in backups" :key="backup.filename">
                      <td>
                        <font-awesome-icon icon="archive" class="me-2 text-muted" />
                        {{ backup.filename }}
                      </td>
                      <td>{{ backup.size_mb }} MB</td>
                      <td>{{ formatDate(backup.created) }}</td>
                      <td class="text-end">
                        <button 
                          class="btn btn-sm btn-warning me-2"
                          @click="restoreBackup(backup.filename)"
                          :disabled="restoring"
                        >
                          <font-awesome-icon icon="undo" class="me-1" />
                          Ripristina
                        </button>
                        <button 
                          class="btn btn-sm btn-danger"
                          @click="deleteBackup(backup.filename)"
                        >
                          <font-awesome-icon icon="trash" />
                        </button>
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

    <!-- Modal Installazione -->
    <b-modal
      v-model="showInstallModal"
      title="Conferma Installazione"
      header-bg-variant="warning"
      header-text-variant="dark"
      @ok="confirmInstall"
      ok-variant="primary"
      ok-title="Procedi"
      cancel-title="Annulla"
    >
      <p><strong>Attenzione:</strong> L'installazione dell'aggiornamento richiederà:</p>
      <ul>
        <li>Backup automatico del sistema corrente</li>
        <li>Arresto temporaneo dei servizi</li>
        <li>Riavvio del sistema al termine</li>
      </ul>
      <p>Vuoi procedere con l'installazione di <strong>{{ pendingInstallFile }}</strong>?</p>
    </b-modal>
  </div>
</template>

<script>
import { ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { useToast } from 'vue-toast-notification'

export default {
  name: 'UpdateManagement',
  setup() {
    const toast = useToast()
    
    // State
    const systemStatus = ref({
      current_version: '',
      update_server_url: '',
      temp_dir: '',
      backup_dir: '',
    })
    
    const downloadedUpdates = ref([])
    const backups = ref([])
    
    const uploading = ref(false)
    const installing = ref(false)
    const restoring = ref(false)
    
    const selectedFile = ref(null)
    const fileInput = ref(null)
    const showInstallModal = ref(false)
    const pendingInstallFile = ref(null)
    
    // Methods
    const loadSystemStatus = async () => {
      try {
        const response = await axios.get('/api/updates/status')
        systemStatus.value = response.data
      } catch (error) {
        console.error('Errore nel caricamento dello stato del sistema:', error)
        toast.error('Errore nel caricamento dello stato del sistema')
      }
    }
    
    const handleFileSelect = (event) => {
      const files = event.target.files
      if (files.length > 0) {
        selectedFile.value = files[0]
      }
    }
    
    const uploadUpdate = async () => {
      if (!selectedFile.value) {
        toast.warning('Seleziona un file da caricare')
        return
      }
      
      uploading.value = true
      try {
        const formData = new FormData()
        formData.append('file', selectedFile.value)
        
        await axios.post('/api/updates/upload', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        })
        
        toast.success('Aggiornamento caricato con successo')
        selectedFile.value = null
        fileInput.value.value = ''
        
        // Ricarica lista download
        await loadDownloadedUpdates()
        
      } catch (error) {
        console.error('Errore nell\'upload dell\'aggiornamento:', error)
        toast.error('Errore nell\'upload dell\'aggiornamento')
      } finally {
        uploading.value = false
      }
    }
    
    const installDownloadedUpdate = (filename) => {
      pendingInstallFile.value = filename
      showInstallModal.value = true
    }
    
    const confirmInstall = async () => {
      if (!pendingInstallFile.value) return
      
      installing.value = true
      showInstallModal.value = false
      
      try {
        const response = await axios.post('/api/updates/install', {
          filename: pendingInstallFile.value
        })
        
        toast.success(response.data.message || 'Installazione avviata', {
          duration: 8000
        })
        
        if (response.data.note) {
          toast.warning(response.data.note, {
            duration: 0,  // Rimane fino a chiusura manuale
            position: 'top'
          })
        }
        
        if (response.data.warning) {
          toast.warning(response.data.warning, {
            duration: 10000
          })
        }
        
        // Avvia polling per verificare quando l'installazione è completata
        let reconnectAttempts = 0
        const maxAttempts = 40  // 40 tentativi = ~2 minuti
        
        const checkConnection = setInterval(async () => {
          try {
            await axios.get('/api/updates/status', { timeout: 3000 })
            // Se arriviamo qui, il backend è tornato online
            clearInterval(checkConnection)
            
            toast.success('🎉 Aggiornamento completato! Ricarico la pagina...', {
              duration: 3000
            })
            
            // Ricarica la pagina dopo 3 secondi
            setTimeout(() => {
              window.location.reload()
            }, 3000)
            
          } catch (error) {
            reconnectAttempts++
            if (reconnectAttempts >= maxAttempts) {
              clearInterval(checkConnection)
              toast.error('Timeout: impossibile verificare lo stato. Ricarica manualmente la pagina.', {
                duration: 0
              })
            }
          }
        }, 3000)  // Controlla ogni 3 secondi
        
        // Ricarica dati
        await loadDownloadedUpdates()
        await loadBackups()
        
      } catch (error) {
        console.error('Errore nell\'installazione:', error)
        const errorMsg = error.response?.data?.detail || 'Errore nell\'avvio dell\'installazione'
        toast.error(errorMsg)
      } finally {
        installing.value = false
        pendingInstallFile.value = null
      }
    }
    
    const loadDownloadedUpdates = async () => {
      try {
        const response = await axios.get('/api/updates/downloads')
        downloadedUpdates.value = response.data.updates || []
      } catch (error) {
        console.error('Errore nel caricamento degli aggiornamenti scaricati:', error)
      }
    }
    
    const deleteDownloadedUpdate = async (filename) => {
      if (!confirm(`Vuoi eliminare ${filename}?`)) return
      
      try {
        await axios.delete(`/api/updates/downloads/${filename}`)
        toast.success('File eliminato')
        await loadDownloadedUpdates()
      } catch (error) {
        console.error('Errore nell\'eliminazione:', error)
        toast.error('Errore nell\'eliminazione del file')
      }
    }
    
    const loadBackups = async () => {
      try {
        const response = await axios.get('/api/updates/backups')
        backups.value = response.data.backups || []
      } catch (error) {
        console.error('Errore nel caricamento dei backup:', error)
      }
    }
    
    const restoreBackup = async (filename) => {
      if (!confirm(`ATTENZIONE: Ripristinare il backup ${filename}? Questa operazione sovrascriverà il sistema corrente.`)) {
        return
      }
      
      restoring.value = true
      try {
        const response = await axios.post('/api/updates/restore', { filename })
        
        toast.warning(response.data.message || 'Ripristino preparato', {
          duration: 10000
        })
        
        if (response.data.command) {
          toast.info(`Eseguire: ${response.data.command}`, {
            duration: 0
          })
        }
        
      } catch (error) {
        console.error('Errore nel ripristino:', error)
        toast.error('Errore nel ripristino del backup')
      } finally {
        restoring.value = false
      }
    }
    
    const deleteBackup = async (filename) => {
      if (!confirm(`Vuoi eliminare il backup ${filename}?`)) return
      
      try {
        await axios.delete(`/api/updates/backups/${filename}`)
        toast.success('Backup eliminato')
        await loadBackups()
      } catch (error) {
        console.error('Errore nell\'eliminazione:', error)
        toast.error('Errore nell\'eliminazione del backup')
      }
    }
    
    const formatDate = (dateString) => {
      if (!dateString) return 'N/D'
      try {
        return new Date(dateString).toLocaleString('it-IT')
      } catch {
        return dateString
      }
    }
    
    const formatSize = (bytes) => {
      if (!bytes) return 'N/D'
      const mb = bytes / (1024 * 1024)
      return `${mb.toFixed(2)} MB`
    }
    
    // Lifecycle
    onMounted(async () => {
      await loadSystemStatus()
      await loadDownloadedUpdates()
      await loadBackups()
    })
    
    return {
      systemStatus,
      downloadedUpdates,
      backups,
      uploading,
      installing,
      restoring,
      selectedFile,
      fileInput,
      showInstallModal,
      pendingInstallFile,
      handleFileSelect,
      uploadUpdate,
      installDownloadedUpdate,
      confirmInstall,
      deleteDownloadedUpdate,
      deleteBackup,
      restoreBackup,
      formatDate,
      formatSize
    }
  }
}
</script>

<style scoped>
.update-management {
  min-height: 100vh;
  background-color: #f8f9fa;
}

.card {
  border-radius: 10px;
  margin-bottom: 20px;
}

.card-header {
  border-radius: 10px 10px 0 0 !important;
}

.table {
  margin-bottom: 0;
}

.badge {
  font-size: 0.9rem;
  padding: 0.4em 0.8em;
}

.modal-content {
  border-radius: 10px;
}

.btn {
  border-radius: 5px;
}
</style>

