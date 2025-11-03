<template>
  <div class="virtual-dsm-management">
    <h1>Gestione Virtual DSM</h1>
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="box" class="me-2" />
              Stato Docker
            </h5>
            <button class="btn btn-sm btn-primary" @click="refreshDockerStatus">
              <font-awesome-icon icon="sync" :class="{ 'fa-spin': loadingDockerStatus }" class="me-1" />
              Aggiorna
            </button>
          </div>
          <div class="card-body">
            <div v-if="loadingDockerStatus" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') }}</span>
              </div>
            </div>
            <div v-else-if="dockerStatus">
              <div class="row">
                <div class="col-md-4 mb-3">
                  <div class="alert" :class="getStatusClass(dockerStatus.docker_installed)">
                    <strong>Docker:</strong> {{ dockerStatus.docker_installed ? 'Installato' : 'Non installato' }}
                  </div>
                </div>
                <div class="col-md-4 mb-3">
                  <div class="alert" :class="getStatusClass(dockerStatus.compose_available)">
                    <strong>Docker Compose:</strong> {{ dockerStatus.compose_available ? 'Disponibile' : 'Non disponibile' }}
                  </div>
                </div>
                <div class="col-md-4 mb-3">
                  <div class="alert" :class="getStatusClass(dockerStatus.kvm_available)">
                    <strong>KVM:</strong> {{ dockerStatus.kvm_available ? 'Disponibile' : 'Non disponibile' }}
                  </div>
                </div>
              </div>
              <div v-if="dockerStatus.docker_version" class="mb-2">
                <strong>Versione Docker:</strong> {{ dockerStatus.docker_version }}
              </div>
              <div v-if="dockerStatus.compose_version">
                <strong>Versione Compose:</strong> {{ dockerStatus.compose_version }}
              </div>
              
              <div v-if="!dockerStatus.docker_installed" class="alert alert-warning mt-3">
                <font-awesome-icon icon="exclamation-triangle" class="me-2" />
                Docker non è installato. Esegui lo script di installazione per installare Docker.
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="layer-group" class="me-2" />
              Stato Container Virtual DSM
            </h5>
            <button class="btn btn-sm btn-primary" @click="refreshContainerStatus">
              <font-awesome-icon icon="sync" :class="{ 'fa-spin': loadingContainerStatus }" class="me-1" />
              Aggiorna
            </button>
          </div>
          <div class="card-body">
            <div v-if="loadingContainerStatus" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') }}</span>
              </div>
            </div>
            <div v-else-if="containerStatus">
              <div class="row mb-3">
                <div class="col-md-6">
                  <strong>Stato:</strong>
                  <span class="badge ms-2" :class="getContainerStatusClass(containerStatus.running)">
                    {{ containerStatus.running ? 'In esecuzione' : 'Arrestato' }}
                  </span>
                </div>
                <div v-if="containerStatus.access_url" class="col-md-6">
                  <strong>URL di accesso:</strong>
                  <a :href="containerStatus.access_url" target="_blank" class="btn btn-sm btn-link">
                    {{ containerStatus.access_url }}
                  </a>
                </div>
              </div>
              
              <div v-if="containerStatus.exists" class="mb-3">
                <strong>Stato dettagliato:</strong> {{ containerStatus.status }}
              </div>
              
              <div v-if="containerStatus.mac_address && containerStatus.running" class="alert alert-success py-2 mb-3">
                <strong>🖧 MAC Address VM QEMU:</strong> <code class="fs-6 text-dark">{{ containerStatus.mac_address }}</code>
                <button 
                  class="btn btn-sm btn-outline-success ms-2" 
                  @click="copyToClipboard(containerStatus.mac_address)"
                  title="Copia MAC address"
                >
                  <font-awesome-icon icon="copy" />
                </button>
                <br>
                <small class="text-muted">Questo è il MAC address della VM QEMU - usalo per la configurazione Serial Numbers se vuoi il login Synology</small>
              </div>
              
              <div class="btn-group">
                <button 
                  v-if="!containerStatus.running" 
                  class="btn btn-success" 
                  @click="startVirtualDSM"
                  :disabled="starting"
                >
                  <font-awesome-icon icon="play" :class="{ 'fa-spin': starting }" class="me-1" />
                  {{ starting ? 'Avvio in corso...' : 'Avvia' }}
                </button>
                <button 
                  v-if="containerStatus.running" 
                  class="btn btn-warning" 
                  @click="stopVirtualDSM"
                  :disabled="stopping"
                >
                  <font-awesome-icon icon="stop" :class="{ 'fa-spin': stopping }" class="me-1" />
                  {{ stopping ? 'Arresto in corso...' : 'Ferma' }}
                </button>
                <button 
                  v-if="containerStatus.exists" 
                  class="btn btn-info" 
                  @click="restartVirtualDSM"
                  :disabled="restarting"
                >
                  <font-awesome-icon icon="redo" :class="{ 'fa-spin': restarting }" class="me-1" />
                  {{ restarting ? 'Riavvio in corso...' : 'Riavvia' }}
                </button>
                <button class="btn btn-secondary" @click="showLogsModal">
                  <font-awesome-icon icon="file-alt" class="me-1" />
                  Visualizza Log
                </button>
              </div>
            </div>
            <div v-else class="alert alert-warning">
              Container virtual-dsm non trovato. Il container verrà creato automaticamente al primo avvio.
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="cog" class="me-2" />
              Configurazione Disco
            </h5>
          </div>
          <div class="card-body">
            <form @submit.prevent="updateDiskSize">
              <div class="row align-items-end">
                <div class="col-md-4">
                  <label for="diskSize" class="form-label">Dimensione Disco Virtual DSM</label>
                  <div class="input-group">
                    <input 
                      type="text" 
                      class="form-control" 
                      id="diskSize" 
                      v-model="diskSizeForm.size"
                      placeholder="256"
                      required
                      pattern="\d+"
                    >
                    <select class="form-select" v-model="diskSizeForm.unit" style="max-width: 80px;">
                      <option value="G">GB</option>
                      <option value="M">MB</option>
                      <option value="T">TB</option>
                    </select>
                  </div>
                  <div class="form-text">
                    Dimensione del disco virtuale per Virtual DSM (es. 256G, 512G, 1T). 
                    La modifica avrà effetto al prossimo riavvio del container.
                  </div>
                </div>
                <div class="col-md-3">
                  <button 
                    type="submit" 
                    class="btn btn-primary"
                    :disabled="updatingDiskSize || !diskSizeForm.size"
                  >
                    <font-awesome-icon 
                      icon="save" 
                      :class="{ 'fa-spin': updatingDiskSize }" 
                      class="me-1" 
                    />
                    {{ updatingDiskSize ? 'Salvataggio...' : 'Salva Configurazione' }}
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="key" class="me-2" />
              Configurazione Serial Number e MAC
            </h5>
          </div>
          <div class="card-body">
            <form @submit.prevent="updateSerialConfig">
              <div class="row mb-3">
                <div class="col-md-6">
                  <label for="hostSerial" class="form-label">HOST_SERIAL (Serial Number NAS)</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    id="hostSerial" 
                    v-model="serialConfigForm.host_serial"
                    placeholder="0000000000000"
                  >
                  <div class="form-text">
                    <strong>Opzionale:</strong> Serial Number del tuo NAS fisico Synology. Serve solo se vuoi fare login con il tuo account Synology. Lascia vuoto per uso standalone.
                  </div>
                </div>
                <div class="col-md-6">
                  <label for="guestSerial" class="form-label">GUEST_SERIAL (Serial Number Virtual DSM)</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    id="guestSerial" 
                    v-model="serialConfigForm.guest_serial"
                    placeholder="0000000000000"
                  >
                  <div class="form-text">
                    <strong>Opzionale:</strong> Serial Number univoco per questa VM. Puoi inventarne uno casuale (es: 1234ABC567890) o usare quello di una VM reale di Synology VMM. Serve per il login Synology.
                  </div>
                </div>
              </div>
              <div class="row mb-3">
                <div class="col-md-6">
                  <label for="vmNetMac" class="form-label">VM_NET_MAC (MAC Address)</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    id="vmNetMac" 
                    v-model="serialConfigForm.vm_net_mac"
                    placeholder="00:11:22:33:44:55"
                    pattern="([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})"
                  >
                  <div class="form-text">
                    <strong>Opzionale:</strong> MAC address della VM QEMU (formato: 00:11:22:33:44:55). 
                    <span class="text-success">Una volta avviata la VM, il MAC address della VM QEMU verrà recuperato automaticamente e mostrato sopra nella sezione "Stato Container".</span> 
                    Copialo da lì se necessario per il login Synology.
                  </div>
                </div>
              </div>
              <div class="alert alert-info">
                <strong>💡 Quando servono questi valori?</strong><br>
                Questi parametri sono <strong>opzionali</strong> e servono solo se vuoi:<br>
                • Fare login con il tuo account Synology (myDS, QuickConnect)<br>
                • Sincronizzare con altri dispositivi Synology<br><br>
                <strong>Per uso standalone:</strong> Lascia tutto vuoto, Virtual DSM funzionerà lo stesso con account locale.<br><br>
                <strong>Per login Synology:</strong> HOST_SERIAL è il serial del tuo NAS fisico (se lo hai). GUEST_SERIAL e VM_NET_MAC puoi inventarli o prenderli da una VM reale in Synology VMM.
              </div>
              <button 
                type="submit" 
                class="btn btn-primary"
                :disabled="updatingSerialConfig"
              >
                <font-awesome-icon 
                  icon="save" 
                  :class="{ 'fa-spin': updatingSerialConfig }" 
                  class="me-1" 
                />
                {{ updatingSerialConfig ? 'Salvataggio...' : 'Salva Configurazione' }}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="hdd" class="me-2" />
              Configurazione Docker Data Root
            </h5>
          </div>
          <div class="card-body">
            <div v-if="loadingDataRoot" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">Caricamento...</span>
              </div>
            </div>
            <div v-else>
              <div class="mb-3">
                <label class="form-label">Docker Data Root Attuale</label>
                <input 
                  type="text" 
                  class="form-control" 
                  :value="dockerDataRoot || '/var/lib/docker'"
                  readonly
                  style="background-color: #e9ecef;"
                >
                <div class="form-text">
                  Directory dove Docker salva immagini, container e volumi.
                </div>
              </div>
              
              <div class="alert alert-info">
                <strong>Configurazione consigliata:</strong> 
                Usa <code>/storage/docker</code> per salvare i dati Docker sul pool ZFS invece che sulla SD card.
                Questo protegge la SD e migliora le performance. Assicurati che il pool ZFS sia montato su /storage prima di configurare.
              </div>
              
              <button 
                class="btn btn-primary"
                @click="configureDockerDataRoot"
                :disabled="configuringDataRoot || !dockerStatus?.docker_installed"
              >
                <font-awesome-icon 
                  icon="cog" 
                  :class="{ 'fa-spin': configuringDataRoot }" 
                  class="me-1" 
                />
                {{ configuringDataRoot ? 'Configurazione...' : 'Configura Docker su /storage/docker' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">
              <font-awesome-icon icon="info-circle" class="me-2" />
              Informazioni
            </h5>
          </div>
          <div class="card-body">
            <div class="alert alert-info">
              <h6><strong>Cos'è Virtual DSM?</strong></h6>
              <p>
                Virtual DSM è un'immagine Docker che consente di eseguire Synology DSM (DiskStation Manager) su hardware non Synology. Fornisce tutte le funzionalità di un NAS Synology reale, inclusa la gestione dei volumi, condivisioni di rete, applicazioni e molto altro.
              </p>
              
              <h6 class="mt-3"><strong>Requisiti</strong></h6>
              <ul>
                <li>Docker installato e funzionante</li>
                <li>Docker Compose installato</li>
                <li>Hardware con supporto KVM (virtualizzazione)</li>
                <li>Almeno 2GB di RAM disponibili</li>
              </ul>
              
              <h6 class="mt-3"><strong>Come utilizzare</strong></h6>
              <ol>
                <li>Verifica che Docker, Docker Compose e KVM siano disponibili (controlla lo stato sopra)</li>
                <li>Clicca sul pulsante "Avvia" per creare e avviare il container virtual-dsm</li>
                <li>Attendi qualche minuto che il container si avvii completamente (il primo avvio può richiedere più tempo)</li>
                <li>Quando lo stato diventa "In esecuzione", clicca sull'URL di accesso per aprire l'interfaccia web di DSM</li>
                <li>Segui il wizard di configurazione iniziale di Synology DSM per impostare username, password e configurare il sistema</li>
              </ol>
              
              <div class="alert alert-warning mt-3">
                <font-awesome-icon icon="exclamation-triangle" class="me-2" />
                <strong>Nota importante:</strong>
                Virtual DSM è destinato all'uso su hardware Synology. Assicurati di rispettare i termini di licenza di Synology quando utilizzi questo software.
              </div>
              
              <div class="alert alert-info mt-3">
                <font-awesome-icon icon="info-circle" class="me-2" />
                <strong>Attribuzione:</strong>
                Questo progetto utilizza <a href="https://github.com/vdsm/virtual-dsm" target="_blank" rel="noopener noreferrer">Virtual DSM</a> sviluppato da <a href="https://github.com/vdsm/virtual-dsm" target="_blank" rel="noopener noreferrer">vdsm/virtual-dsm</a>. Licenza MIT.
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Modal per i log -->
    <b-modal 
      v-model="showLogs" 
      title="Log Container Virtual DSM" 
      size="lg"
      ok-only
    >
      <div v-if="loadingLogs" class="text-center py-3">
        <div class="spinner-border text-primary" role="status">
          <span class="visually-hidden">{{ $t('common.loading') }}</span>
        </div>
      </div>
      <div v-else>
        <pre class="container-logs">{{ containerLogs }}</pre>
      </div>
    </b-modal>
    
    <!-- Footer con attribuzione -->
    <div class="mt-4 text-center text-muted small">
      <p class="mb-0">
        Virtual DSM basato su <a href="https://github.com/vdsm/virtual-dsm" target="_blank" rel="noopener noreferrer">vdsm/virtual-dsm</a>
      </p>
    </div>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import { useToast } from 'vue-toast-notification'
import axios from '@/plugins/axios'

export default {
  name: 'VirtualDSM',
  setup() {
    const $toast = useToast()
    
    // Stato
    const dockerStatus = ref(null)
    const containerStatus = ref(null)
    const loadingDockerStatus = ref(false)
    const loadingContainerStatus = ref(false)
    const starting = ref(false)
    const stopping = ref(false)
    const restarting = ref(false)
    
    // Stato per i log
    const showLogs = ref(false)
    const containerLogs = ref('')
    const loadingLogs = ref(false)
    
    // Stato per la configurazione del disco
    const diskSizeForm = ref({
      size: '',
      unit: 'G'
    })
    const updatingDiskSize = ref(false)
    
    // Stato per la configurazione Serial Number e MAC
    const serialConfigForm = ref({
      host_serial: '',
      guest_serial: '',
      vm_net_mac: ''
    })
    const updatingSerialConfig = ref(false)
    
    // Stato per la configurazione Docker data-root
    const dockerDataRoot = ref('')
    const loadingDataRoot = ref(false)
    const configuringDataRoot = ref(false)
    
    // Carica i dati all'avvio
    onMounted(() => {
      refreshDockerStatus()
      refreshContainerStatus()
      loadDiskSizeConfig()
      loadSerialConfig()
      loadDockerDataRoot()
    })
    
    // Funzione per aggiornare lo stato di Docker
    const refreshDockerStatus = async () => {
      loadingDockerStatus.value = true
      try {
        const response = await axios.get('/api/docker/status')
        dockerStatus.value = response.data
      } catch (error) {
        console.error('Errore durante il recupero dello stato di Docker:', error)
        $toast.error('Errore durante il recupero dello stato di Docker')
      } finally {
        loadingDockerStatus.value = false
      }
    }
    
    // Funzione per aggiornare lo stato del container
    const refreshContainerStatus = async () => {
      loadingContainerStatus.value = true
      try {
        const response = await axios.get('/api/docker/virtual-dsm/status')
        containerStatus.value = response.data
      } catch (error) {
        console.error('Errore durante il recupero dello stato del container:', error)
        containerStatus.value = null
      } finally {
        loadingContainerStatus.value = false
      }
    }
    
    // Funzione per avviare virtual-dsm
    const startVirtualDSM = async () => {
      starting.value = true
      try {
        await axios.post('/api/docker/container/start', { container_name: 'virtual-dsm' })
        $toast.success('Container virtual-dsm avviato con successo')
        setTimeout(() => refreshContainerStatus(), 2000)
      } catch (error) {
        console.error('Errore durante l\'avvio del container:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante l\'avvio del container')
      } finally {
        starting.value = false
      }
    }
    
    // Funzione per fermare virtual-dsm
    const stopVirtualDSM = async () => {
      stopping.value = true
      try {
        await axios.post('/api/docker/container/stop', { container_name: 'virtual-dsm' })
        $toast.success('Container virtual-dsm fermato con successo')
        setTimeout(() => refreshContainerStatus(), 2000)
      } catch (error) {
        console.error('Errore durante la fermata del container:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante la fermata del container')
      } finally {
        stopping.value = false
      }
    }
    
    // Funzione per riavviare virtual-dsm
    const restartVirtualDSM = async () => {
      restarting.value = true
      try {
        await axios.post('/api/docker/container/restart', { container_name: 'virtual-dsm' })
        $toast.success('Container virtual-dsm riavviato con successo')
        setTimeout(() => refreshContainerStatus(), 2000)
      } catch (error) {
        console.error('Errore durante il riavvio del container:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante il riavvio del container')
      } finally {
        restarting.value = false
      }
    }
    
    // Funzione per mostrare i log
    const showLogsModal = () => {
      showLogs.value = true
      loadingLogs.value = true
      
      axios.post('/api/docker/container/logs', { container_name: 'virtual-dsm', tail: 100 })
        .then(response => {
          containerLogs.value = response.data.logs.join('\n')
        })
        .catch(error => {
          console.error('Errore durante il recupero dei log:', error)
          containerLogs.value = 'Errore durante il recupero dei log'
        })
        .finally(() => {
          loadingLogs.value = false
        })
    }
    
    // Funzione per caricare la configurazione del disco
    const loadDiskSizeConfig = async () => {
      try {
        const response = await axios.get('/api/docker/virtual-dsm/config')
        const diskSize = response.data.disk_size || '256G'
        
        // Estrae numero e unità
        const match = diskSize.match(/^(\d+)([GMT])?$/i)
        if (match) {
          diskSizeForm.value.size = match[1]
          diskSizeForm.value.unit = (match[2] || 'G').toUpperCase()
        } else {
          diskSizeForm.value.size = '256'
          diskSizeForm.value.unit = 'G'
        }
        
        // Carica anche Serial Number e MAC se disponibili
        if (response.data.host_serial) {
          serialConfigForm.value.host_serial = response.data.host_serial
        }
        if (response.data.guest_serial) {
          serialConfigForm.value.guest_serial = response.data.guest_serial
        }
        if (response.data.vm_net_mac) {
          serialConfigForm.value.vm_net_mac = response.data.vm_net_mac
        }
      } catch (error) {
        console.error('Errore durante il caricamento della configurazione:', error)
        // Valori di default in caso di errore
        diskSizeForm.value.size = '256'
        diskSizeForm.value.unit = 'G'
      }
    }
    
    // Funzione per aggiornare la dimensione del disco
    const updateDiskSize = async () => {
      if (!diskSizeForm.value.size) {
        $toast.error('Inserisci una dimensione valida')
        return
      }
      
      updatingDiskSize.value = true
      
      try {
        const diskSize = `${diskSizeForm.value.size}${diskSizeForm.value.unit}`
        const response = await axios.put('/api/docker/virtual-dsm/config', {
          disk_size: diskSize,
          host_serial: serialConfigForm.value.host_serial || null,
          guest_serial: serialConfigForm.value.guest_serial || null,
          vm_net_mac: serialConfigForm.value.vm_net_mac || null
        })
        
        $toast.success(response.data.message || `Dimensione disco aggiornata a ${diskSize}`)
      } catch (error) {
        console.error('Errore durante l\'aggiornamento della dimensione del disco:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante l\'aggiornamento della configurazione')
      } finally {
        updatingDiskSize.value = false
      }
    }
    
    // Funzione per caricare la configurazione Serial Number e MAC
    const loadSerialConfig = async () => {
      try {
        const response = await axios.get('/api/docker/virtual-dsm/config')
        serialConfigForm.value.host_serial = response.data.host_serial || ''
        serialConfigForm.value.guest_serial = response.data.guest_serial || ''
        serialConfigForm.value.vm_net_mac = response.data.vm_net_mac || ''
      } catch (error) {
        console.error('Errore durante il caricamento della configurazione Serial Number:', error)
      }
    }
    
    // Funzione per aggiornare la configurazione Serial Number e MAC
    const updateSerialConfig = async () => {
      updatingSerialConfig.value = true
      
      try {
        const diskSize = `${diskSizeForm.value.size}${diskSizeForm.value.unit}`
        const response = await axios.put('/api/docker/virtual-dsm/config', {
          disk_size: diskSize,
          host_serial: serialConfigForm.value.host_serial || null,
          guest_serial: serialConfigForm.value.guest_serial || null,
          vm_net_mac: serialConfigForm.value.vm_net_mac || null
        })
        
        $toast.success(response.data.message || 'Configurazione Serial Number e MAC aggiornata')
      } catch (error) {
        console.error('Errore durante l\'aggiornamento della configurazione Serial Number:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante l\'aggiornamento della configurazione')
      } finally {
        updatingSerialConfig.value = false
      }
    }
    
    // Funzione per caricare la configurazione Docker data-root
    const loadDockerDataRoot = async () => {
      loadingDataRoot.value = true
      try {
        const response = await axios.get('/api/docker/data-root')
        dockerDataRoot.value = response.data.data_root || '/var/lib/docker'
      } catch (error) {
        console.error('Errore durante il caricamento della configurazione Docker data-root:', error)
        dockerDataRoot.value = '/var/lib/docker'
      } finally {
        loadingDataRoot.value = false
      }
    }
    
    // Funzione per configurare Docker data-root su /storage/docker
    const configureDockerDataRoot = async () => {
      if (!confirm('Vuoi configurare Docker per usare /storage/docker come data-root?\n\nATTENZIONE: Questa operazione richiede il riavvio di Docker e potrebbe fermare tutti i container in esecuzione.')) {
        return
      }
      
      configuringDataRoot.value = true
      
      try {
        const response = await axios.put('/api/docker/data-root', {
          data_root: '/storage/docker',
          migrate: false
        })
        
        $toast.success(response.data.message || 'Docker data-root configurato. Riavvia Docker per applicare le modifiche.', {
          duration: 10000
        })
        
        // Ricarica la configurazione
        await loadDockerDataRoot()
      } catch (error) {
        console.error('Errore durante la configurazione Docker data-root:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante la configurazione Docker data-root')
      } finally {
        configuringDataRoot.value = false
      }
    }
    
    // Funzioni di utilità
    const getStatusClass = (status) => {
      return status ? 'alert-success' : 'alert-danger'
    }
    
    const getContainerStatusClass = (running) => {
      return running ? 'bg-success' : 'bg-secondary'
    }
    
    const copyToClipboard = async (text) => {
      try {
        await navigator.clipboard.writeText(text)
        $toast.success('MAC address copiato negli appunti!')
      } catch (error) {
        console.error('Errore nella copia:', error)
        $toast.error('Errore nella copia del MAC address')
      }
    }
    
    return {
      dockerStatus,
      containerStatus,
      loadingDockerStatus,
      loadingContainerStatus,
      starting,
      diskSizeForm,
      updatingDiskSize,
      loadDiskSizeConfig,
      updateDiskSize,
      serialConfigForm,
      updatingSerialConfig,
      loadSerialConfig,
      updateSerialConfig,
      stopping,
      restarting,
      showLogs,
      containerLogs,
      loadingLogs,
      dockerDataRoot,
      loadingDataRoot,
      configuringDataRoot,
      configureDockerDataRoot,
      refreshDockerStatus,
      refreshContainerStatus,
      startVirtualDSM,
      stopVirtualDSM,
      restartVirtualDSM,
      showLogsModal,
      getStatusClass,
      getContainerStatusClass,
      copyToClipboard
    }
  }
}
</script>

<style scoped>
.virtual-dsm-management {
  padding: 20px;
}

.card {
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  border: none;
  border-radius: 8px;
  margin-bottom: 20px;
}

.card-header {
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
  border-radius: 8px 8px 0 0;
}

.container-logs {
  background-color: #f8f9fa;
  padding: 10px;
  border-radius: 4px;
  white-space: pre-wrap;
  font-family: monospace;
  font-size: 0.9rem;
  max-height: 400px;
  overflow-y: auto;
}

.btn-group {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}
</style>

