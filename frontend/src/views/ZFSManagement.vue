<template>
  <div class="zfs-management">
    <h1>{{ $t('zfs.title') || 'Gestione ZFS' }}</h1>
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="database" class="me-2" />
              {{ $t('zfs.pools') || 'Pool ZFS' }}
            </h5>
            <div>
              <button class="btn btn-sm btn-primary" @click="refreshPools">
                <font-awesome-icon icon="sync" :class="{ 'fa-spin': loadingPools }" class="me-1" />
                {{ $t('common.refresh') || 'Aggiorna' }}
              </button>
              <button class="btn btn-sm btn-success ms-2" @click="showCreatePoolModal">
                <font-awesome-icon icon="plus" class="me-1" />
                {{ $t('zfs.create_pool') || 'Crea Pool' }}
              </button>
            </div>
          </div>
          <div class="card-body">
            <div v-if="loadingPools" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') }}</span>
              </div>
            </div>
            <div v-else-if="pools.length === 0" class="text-center py-3">
              <p class="text-muted">{{ $t('zfs.no_pools') || 'Nessun pool ZFS trovato' }}</p>
              <button class="btn btn-primary" @click="showCreatePoolModal">
                <font-awesome-icon icon="plus" class="me-1" />
                {{ $t('zfs.create_first_pool') || 'Crea il tuo primo pool ZFS' }}
              </button>
            </div>
            <div v-else>
              <div class="table-responsive">
                <table class="table table-hover">
                  <thead>
                    <tr>
                      <th>{{ $t('zfs.pool_name') || 'Nome Pool' }}</th>
                      <th>{{ $t('zfs.size') || 'Dimensione' }}</th>
                      <th>{{ $t('zfs.used') || 'Utilizzato' }}</th>
                      <th>{{ $t('zfs.free') || 'Libero' }}</th>
                      <th>{{ $t('zfs.capacity') || 'Capacità' }}</th>
                      <th>{{ $t('zfs.health') || 'Stato' }}</th>
                      <th>{{ $t('common.actions') || 'Azioni' }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="pool in pools" :key="pool.name">
                      <td>{{ pool.name }}</td>
                      <td>{{ formatBytes(pool.size) }}</td>
                      <td>{{ formatBytes(pool.allocated) }}</td>
                      <td>{{ formatBytes(pool.free) }}</td>
                      <td>
                        <div class="progress" style="height: 10px;">
                          <div 
                            class="progress-bar" 
                            role="progressbar" 
                            :style="{ width: pool.capacity + '%' }" 
                            :class="getCapacityClass(pool.capacity)"
                            :aria-valuenow="pool.capacity" 
                            aria-valuemin="0" 
                            aria-valuemax="100"
                          ></div>
                        </div>
                        <small>{{ pool.capacity }}%</small>
                      </td>
                      <td>
                        <span 
                          class="badge" 
                          :class="getHealthClass(pool.health)"
                        >
                          {{ pool.health }}
                        </span>
                      </td>
                      <td>
                        <div class="btn-group">
                          <button 
                            class="btn btn-sm btn-info" 
                            @click="showPoolStatus(pool.name)"
                            title="Stato"
                          >
                            <font-awesome-icon icon="info-circle" />
                          </button>
                          <button 
                            class="btn btn-sm btn-primary" 
                            @click="showCreateDatasetModal(pool.name)"
                            title="Crea Dataset"
                          >
                            <font-awesome-icon icon="folder-plus" />
                          </button>
                          <button 
                            class="btn btn-sm btn-danger" 
                            @click="openDestroyPoolModal(pool.name)"
                            title="Elimina Pool"
                          >
                            <font-awesome-icon icon="trash" />
                          </button>
                        </div>
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
    
    <div class="row mb-4">
      <div class="col-md-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="folder" class="me-2" />
              {{ $t('zfs.datasets') || 'Dataset ZFS' }}
            </h5>
            <button class="btn btn-sm btn-primary" @click="refreshDatasets">
              <font-awesome-icon icon="sync" :class="{ 'fa-spin': loadingDatasets }" class="me-1" />
              {{ $t('common.refresh') || 'Aggiorna' }}
            </button>
          </div>
          <div class="card-body">
            <div v-if="loadingDatasets" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') }}</span>
              </div>
            </div>
            <div v-else-if="datasets.length === 0" class="text-center py-3">
              <p class="text-muted">{{ $t('zfs.no_datasets') || 'Nessun dataset ZFS trovato' }}</p>
            </div>
            <div v-else>
              <div class="table-responsive">
                <table class="table table-hover">
                  <thead>
                    <tr>
                      <th>{{ $t('zfs.dataset_name') || 'Nome Dataset' }}</th>
                      <th>{{ $t('zfs.used') || 'Utilizzato' }}</th>
                      <th>{{ $t('zfs.available') || 'Disponibile' }}</th>
                      <th>{{ $t('zfs.referenced') || 'Riferito' }}</th>
                      <th>{{ $t('zfs.mountpoint') || 'Punto di montaggio' }}</th>
                      <th>{{ $t('common.actions') || 'Azioni' }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="dataset in datasets" :key="dataset.name">
                      <td>{{ dataset.name }}</td>
                      <td>{{ formatBytes(dataset.used) }}</td>
                      <td>{{ formatBytes(dataset.available) }}</td>
                      <td>{{ formatBytes(dataset.referenced) }}</td>
                      <td>{{ dataset.mountpoint }}</td>
                      <td>
                        <div class="btn-group">
                          <button 
                            class="btn btn-sm btn-info" 
                            @click="showDatasetProperties(dataset.name)"
                            title="Proprietà"
                          >
                            <font-awesome-icon icon="info-circle" />
                          </button>
                          <button 
                            class="btn btn-sm btn-danger" 
                            @click="openDestroyDatasetModal(dataset.name)"
                            title="Elimina Dataset"
                          >
                            <font-awesome-icon icon="trash" />
                          </button>
                        </div>
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
    
    <!-- Modale per la creazione di un pool ZFS -->
    <b-modal 
      v-model="showCreatePool" 
      :title="$t('zfs.create_pool') || 'Crea Pool ZFS'" 
      @ok="createPool"
      @hidden="resetCreatePoolForm"
      :ok-disabled="!isCreatePoolFormValid || isCreatingPool"
    >
      <form @submit.prevent="createPool">
        <div class="mb-3">
          <label for="poolName" class="form-label">{{ $t('zfs.pool_name') || 'Nome Pool' }}</label>
          <input 
            type="text" 
            class="form-control" 
            id="poolName" 
            v-model="createPoolForm.name"
            required
            pattern="[a-zA-Z0-9_-]+"
          >
          <div class="form-text">{{ $t('zfs.pool_name_help') || 'Il nome può contenere solo lettere, numeri, trattini e underscore' }}</div>
        </div>
        
        <div class="mb-3">
          <label for="raidType" class="form-label">{{ $t('zfs.raid_type') || 'Tipo di RAID' }}</label>
          <select class="form-select" id="raidType" v-model="createPoolForm.raidType" required>
            <option value="">{{ $t('common.select') || 'Seleziona' }}</option>
            <option value="stripe">{{ $t('zfs.raid_stripe') || 'Stripe (RAID 0)' }}</option>
            <option value="mirror">{{ $t('zfs.raid_mirror') || 'Mirror (RAID 1)' }}</option>
            <option value="raidz">{{ $t('zfs.raid_raidz') || 'RAIDZ (RAID 5)' }}</option>
            <option value="raidz2">{{ $t('zfs.raid_raidz2') || 'RAIDZ2 (RAID 6)' }}</option>
            <option value="raidz3">{{ $t('zfs.raid_raidz3') || 'RAIDZ3 (RAID 7)' }}</option>
          </select>
          <div class="form-text">{{ getRaidTypeDescription }}</div>
        </div>
        
        <div class="mb-3">
          <label class="form-label">{{ $t('zfs.select_disks') || 'Seleziona Dischi' }}</label>
          <div v-if="loadingDisks" class="text-center py-2">
            <div class="spinner-border spinner-border-sm text-primary" role="status">
              <span class="visually-hidden">{{ $t('common.loading') }}</span>
            </div>
          </div>
          <div v-else-if="availableDisks.length === 0" class="alert alert-warning">
            {{ $t('zfs.no_disks_available') || 'Nessun disco disponibile per la creazione di pool ZFS' }}
          </div>
          <div v-else>
            <div class="form-check" v-for="disk in availableDisks" :key="disk.path">
              <input 
                class="form-check-input" 
                type="checkbox" 
                :id="'disk-' + disk.name" 
                :value="disk.path" 
                v-model="createPoolForm.disks"
                :disabled="disk.in_use"
              >
              <label class="form-check-label" :for="'disk-' + disk.name">
                {{ disk.path }} ({{ disk.size }}) - {{ disk.model || $t('zfs.disk_unknown') || 'Disco sconosciuto' }}
                <span v-if="disk.in_use" class="text-danger">({{ $t('zfs.disk_in_use') || 'In uso' }})</span>
              </label>
            </div>
            <div class="form-text" v-if="diskRequirementText">
              {{ diskRequirementText }}
            </div>
          </div>
        </div>
        
        <div class="mb-3">
          <label for="mountPoint" class="form-label">{{ $t('zfs.mount_point') || 'Punto di montaggio' }}</label>
          <input 
            type="text" 
            class="form-control" 
            id="mountPoint" 
            value="/storage"
            readonly
            style="background-color: #e9ecef;"
          >
          <div class="form-text">
            {{ $t('zfs.mount_point_help') || 'Tutti i pool ZFS verranno montati in /storage. Più pool possono essere utilizzati contemporaneamente.' }}
          </div>
        </div>
      </form>
      
      <template #modal-footer="{ ok, cancel }">
        <b-button 
          variant="secondary" 
          @click="cancel()"
        >
          {{ $t('common.cancel') || 'Annulla' }}
        </b-button>
        <b-button 
          variant="primary" 
          @click="ok()" 
          :disabled="!isCreatePoolFormValid || isCreatingPool"
        >
          <span v-if="isCreatingPool" class="spinner-border spinner-border-sm me-2" role="status"></span>
          {{ $t('common.create') || 'Crea' }}
        </b-button>
      </template>
    </b-modal>
    
    <!-- Modale per la creazione di un dataset ZFS -->
    <b-modal 
      v-model="showCreateDataset" 
      :title="$t('zfs.create_dataset') || 'Crea Dataset ZFS'" 
      @ok="createDataset"
      @hidden="resetCreateDatasetForm"
      :ok-disabled="!isCreateDatasetFormValid || isCreatingDataset"
    >
      <form @submit.prevent="createDataset">
        <div class="mb-3">
          <label for="poolNameDataset" class="form-label">{{ $t('zfs.pool_name') || 'Nome Pool' }}</label>
          <input 
            type="text" 
            class="form-control" 
            id="poolNameDataset" 
            v-model="createDatasetForm.poolName"
            readonly
          >
        </div>
        
        <div class="mb-3">
          <label for="datasetName" class="form-label">{{ $t('zfs.dataset_name') || 'Nome Dataset' }}</label>
          <input 
            type="text" 
            class="form-control" 
            id="datasetName" 
            v-model="createDatasetForm.datasetName"
            required
            pattern="[a-zA-Z0-9_-]+"
          >
          <div class="form-text">{{ $t('zfs.dataset_name_help') || 'Il nome può contenere solo lettere, numeri, trattini e underscore' }}</div>
        </div>
        
        <div class="mb-3">
          <label for="datasetMountPoint" class="form-label">{{ $t('zfs.mount_point') || 'Punto di montaggio' }} ({{ $t('common.optional') || 'Opzionale' }})</label>
          <input 
            type="text" 
            class="form-control" 
            id="datasetMountPoint" 
            v-model="createDatasetForm.mountPoint"
            placeholder="/mnt/zfs/pool-name/dataset-name"
          >
        </div>
        
        <div class="mb-3">
          <label for="quota" class="form-label">{{ $t('zfs.quota') || 'Quota' }} ({{ $t('common.optional') || 'Opzionale' }})</label>
          <div class="input-group">
            <input 
              type="number" 
              class="form-control" 
              id="quota" 
              v-model="createDatasetForm.quotaValue"
              min="1"
            >
            <select class="form-select" v-model="createDatasetForm.quotaUnit">
              <option value="M">MB</option>
              <option value="G">GB</option>
              <option value="T">TB</option>
            </select>
          </div>
          <div class="form-text">{{ $t('zfs.quota_help') || 'Limite massimo di spazio per questo dataset' }}</div>
        </div>
        
        <div class="mb-3">
          <label for="compression" class="form-label">{{ $t('zfs.compression') || 'Compressione' }}</label>
          <select class="form-select" id="compression" v-model="createDatasetForm.compression">
            <option value="">{{ $t('zfs.compression_default') || 'Predefinita' }}</option>
            <option value="off">{{ $t('zfs.compression_off') || 'Disattivata' }}</option>
            <option value="lz4">LZ4 ({{ $t('zfs.compression_recommended') || 'Consigliata' }})</option>
            <option value="gzip">GZIP</option>
            <option value="gzip-9">GZIP ({{ $t('zfs.compression_max') || 'Massima' }})</option>
            <option value="zstd">ZSTD</option>
          </select>
        </div>
      </form>
      
      <template #modal-footer="{ ok, cancel }">
        <b-button 
          variant="secondary" 
          @click="cancel()"
        >
          {{ $t('common.cancel') || 'Annulla' }}
        </b-button>
        <b-button 
          variant="primary" 
          @click="ok()" 
          :disabled="!isCreateDatasetFormValid || isCreatingDataset"
        >
          <span v-if="isCreatingDataset" class="spinner-border spinner-border-sm me-2" role="status"></span>
          {{ $t('common.create') || 'Crea' }}
        </b-button>
      </template>
    </b-modal>
    
    <!-- Modale per la visualizzazione dello stato del pool -->
    <b-modal 
      v-model="showPoolStatusModal" 
      :title="$t('zfs.pool_status') || 'Stato Pool ZFS'" 
      size="lg"
      ok-only
    >
      <div v-if="loadingPoolStatus" class="text-center py-3">
        <div class="spinner-border text-primary" role="status">
          <span class="visually-hidden">{{ $t('common.loading') }}</span>
        </div>
      </div>
      <div v-else>
        <pre class="pool-status">{{ poolStatus }}</pre>
      </div>
    </b-modal>
    
    <!-- Modale per la visualizzazione delle proprietà del dataset -->
    <b-modal 
      v-model="showDatasetPropertiesModal" 
      :title="$t('zfs.dataset_properties') || 'Proprietà Dataset ZFS'" 
      size="lg"
      ok-only
    >
      <div v-if="loadingDatasetProperties" class="text-center py-3">
        <div class="spinner-border text-primary" role="status">
          <span class="visually-hidden">{{ $t('common.loading') }}</span>
        </div>
      </div>
      <div v-else-if="datasetProperties">
        <div class="table-responsive">
          <table class="table table-sm table-striped">
            <thead>
              <tr>
                <th>{{ $t('zfs.property') || 'Proprietà' }}</th>
                <th>{{ $t('zfs.value') || 'Valore' }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(value, key) in datasetProperties" :key="key">
                <td>{{ key }}</td>
                <td>{{ value }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </b-modal>
    
    <!-- Modale per la distruzione di un pool -->
    <b-modal 
      v-model="showDestroyPoolModal" 
      :title="$t('zfs.destroy_pool') || 'Elimina Pool ZFS'" 
      @ok="destroyPool"
      ok-variant="danger"
      :ok-title="$t('common.delete') || 'Elimina'"
      :cancel-title="$t('common.cancel') || 'Annulla'"
    >
      <p>{{ $t('zfs.destroy_pool_confirm') || 'Sei sicuro di voler eliminare questo pool ZFS?' }}</p>
      <p class="text-danger">{{ $t('zfs.destroy_pool_warning') || 'Questa operazione è irreversibile e tutti i dati nel pool saranno persi!' }}</p>
      <div class="form-check">
        <input class="form-check-input" type="checkbox" id="forceDestroyPool" v-model="destroyPoolForm.force">
        <label class="form-check-label" for="forceDestroyPool">
          {{ $t('zfs.force_destroy') || 'Forza eliminazione' }}
        </label>
      </div>
    </b-modal>
    
    <!-- Modale per la distruzione di un dataset -->
    <b-modal 
      v-model="showDestroyDatasetModal" 
      :title="$t('zfs.destroy_dataset') || 'Elimina Dataset ZFS'" 
      @ok="destroyDataset"
      ok-variant="danger"
      :ok-title="$t('common.delete') || 'Elimina'"
      :cancel-title="$t('common.cancel') || 'Annulla'"
    >
      <p>{{ $t('zfs.destroy_dataset_confirm') || 'Sei sicuro di voler eliminare questo dataset ZFS?' }}</p>
      <p class="text-danger">{{ $t('zfs.destroy_dataset_warning') || 'Questa operazione è irreversibile e tutti i dati nel dataset saranno persi!' }}</p>
      <div class="form-check mb-2">
        <input class="form-check-input" type="checkbox" id="recursiveDestroyDataset" v-model="destroyDatasetForm.recursive">
        <label class="form-check-label" for="recursiveDestroyDataset">
          {{ $t('zfs.recursive_destroy') || 'Elimina ricorsivamente (inclusi i dataset figli)' }}
        </label>
      </div>
      <div class="form-check">
        <input class="form-check-input" type="checkbox" id="forceDestroyDataset" v-model="destroyDatasetForm.force">
        <label class="form-check-label" for="forceDestroyDataset">
          {{ $t('zfs.force_destroy') || 'Forza eliminazione' }}
        </label>
      </div>
    </b-modal>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { useToast } from 'vue-toast-notification'
import axios from '@/plugins/axios'

export default {
  name: 'ZFSManagement',
  setup() {
    const $toast = useToast()
    
    // Stato
    const pools = ref([])
    const datasets = ref([])
    const availableDisks = ref([])
    const loadingPools = ref(false)
    const loadingDatasets = ref(false)
    const loadingDisks = ref(false)
    
    // Stato per la creazione di pool
    const showCreatePool = ref(false)
    const isCreatingPool = ref(false)
    const createPoolForm = ref({
      name: '',
      raidType: '',
      disks: [],
      mountPoint: ''
    })
    
    // Stato per la creazione di dataset
    const showCreateDataset = ref(false)
    const isCreatingDataset = ref(false)
    const createDatasetForm = ref({
      poolName: '',
      datasetName: '',
      mountPoint: '',
      quotaValue: '',
      quotaUnit: 'G',
      compression: ''
    })
    
    // Stato per la visualizzazione dello stato del pool
    const showPoolStatusModal = ref(false)
    const loadingPoolStatus = ref(false)
    const poolStatus = ref('')
    const currentPoolName = ref('')
    
    // Stato per la visualizzazione delle proprietà del dataset
    const showDatasetPropertiesModal = ref(false)
    const loadingDatasetProperties = ref(false)
    const datasetProperties = ref(null)
    const currentDatasetName = ref('')
    
    // Stato per la distruzione di pool
    const showDestroyPoolModal = ref(false)
    const destroyPoolForm = ref({
      name: '',
      force: false
    })
    
    // Stato per la distruzione di dataset
    const showDestroyDatasetModal = ref(false)
    const destroyDatasetForm = ref({
      name: '',
      recursive: false,
      force: false
    })
    
    // Carica i dati all'avvio
    onMounted(() => {
      refreshPools()
      refreshDatasets()
      refreshAvailableDisks()
    })
    
    // Funzione per aggiornare l'elenco dei pool
    const refreshPools = async () => {
      loadingPools.value = true
      try {
        const response = await axios.get('/api/zfs/pools')
        pools.value = response.data
      } catch (error) {
        console.error('Errore durante il recupero dei pool ZFS:', error)
        $toast.error('Errore durante il recupero dei pool ZFS')
      } finally {
        loadingPools.value = false
      }
    }
    
    // Funzione per aggiornare l'elenco dei dataset
    const refreshDatasets = async () => {
      loadingDatasets.value = true
      try {
        const response = await axios.get('/api/zfs/datasets')
        datasets.value = response.data
      } catch (error) {
        console.error('Errore durante il recupero dei dataset ZFS:', error)
        $toast.error('Errore durante il recupero dei dataset ZFS')
      } finally {
        loadingDatasets.value = false
      }
    }
    
    // Funzione per aggiornare l'elenco dei dischi disponibili
    const refreshAvailableDisks = async () => {
      loadingDisks.value = true
      try {
        const response = await axios.get('/api/zfs/available-disks')
        availableDisks.value = response.data
      } catch (error) {
        console.error('Errore durante il recupero dei dischi disponibili:', error)
        $toast.error('Errore durante il recupero dei dischi disponibili')
      } finally {
        loadingDisks.value = false
      }
    }
    
    // Funzione per formattare i byte in un formato leggibile
    const formatBytes = (bytes, decimals = 2) => {
      if (bytes === 0) return '0 Bytes'
      
      const k = 1024
      const dm = decimals < 0 ? 0 : decimals
      const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
      
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      
      return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i]
    }
    
    // Funzione per ottenere la classe CSS in base alla capacità
    const getCapacityClass = (capacity) => {
      const cap = parseInt(capacity)
      if (cap >= 90) return 'bg-danger'
      if (cap >= 75) return 'bg-warning'
      return 'bg-success'
    }
    
    // Funzione per ottenere la classe CSS in base allo stato di salute
    const getHealthClass = (health) => {
      if (health === 'ONLINE') return 'bg-success'
      if (health === 'DEGRADED') return 'bg-warning'
      return 'bg-danger'
    }
    
    // Descrizione del tipo di RAID selezionato
    const getRaidTypeDescription = computed(() => {
      switch (createPoolForm.value.raidType) {
        case 'stripe':
          return 'Stripe (RAID 0): Massime prestazioni e capacità, ma nessuna ridondanza. Se un disco fallisce, tutti i dati sono persi.'
        case 'mirror':
          return 'Mirror (RAID 1): Ogni dato è duplicato su tutti i dischi. Offre la massima ridondanza ma dimezza la capacità totale.'
        case 'raidz':
          return 'RAIDZ (RAID 5): Richiede almeno 3 dischi. Può sopravvivere al guasto di 1 disco.'
        case 'raidz2':
          return 'RAIDZ2 (RAID 6): Richiede almeno 4 dischi. Può sopravvivere al guasto di 2 dischi.'
        case 'raidz3':
          return 'RAIDZ3 (RAID 7): Richiede almeno 5 dischi. Può sopravvivere al guasto di 3 dischi.'
        default:
          return 'Seleziona un tipo di RAID per vedere la descrizione.'
      }
    })
    
    // Testo dei requisiti dei dischi in base al tipo di RAID
    const diskRequirementText = computed(() => {
      const numDisks = createPoolForm.value.disks.length
      
      switch (createPoolForm.value.raidType) {
        case 'stripe':
          return numDisks < 1 ? 'Seleziona almeno 1 disco.' : ''
        case 'mirror':
          return numDisks < 2 ? 'Seleziona almeno 2 dischi per il mirror.' : ''
        case 'raidz':
          return numDisks < 3 ? 'Seleziona almeno 3 dischi per RAIDZ.' : ''
        case 'raidz2':
          return numDisks < 4 ? 'Seleziona almeno 4 dischi per RAIDZ2.' : ''
        case 'raidz3':
          return numDisks < 5 ? 'Seleziona almeno 5 dischi per RAIDZ3.' : ''
        default:
          return ''
      }
    })
    
    
    // Validità del form per la creazione di pool
    const isCreatePoolFormValid = computed(() => {
      if (!createPoolForm.value.name || !createPoolForm.value.raidType) {
        return false
      }
      
      const numDisks = createPoolForm.value.disks.length
      
      switch (createPoolForm.value.raidType) {
        case 'stripe':
          return numDisks >= 1
        case 'mirror':
          return numDisks >= 2
        case 'raidz':
          return numDisks >= 3
        case 'raidz2':
          return numDisks >= 4
        case 'raidz3':
          return numDisks >= 5
        default:
          return false
      }
    })
    
    // Validità del form per la creazione di dataset
    const isCreateDatasetFormValid = computed(() => {
      return createDatasetForm.value.poolName && createDatasetForm.value.datasetName
    })
    
    // Funzione per mostrare la modale di creazione pool
    const showCreatePoolModal = () => {
      refreshAvailableDisks()
      showCreatePool.value = true
    }
    
    // Funzione per mostrare la modale di creazione dataset
    const showCreateDatasetModal = (poolName) => {
      createDatasetForm.value.poolName = poolName
      showCreateDataset.value = true
    }
    
    // Funzione per mostrare lo stato del pool
    const showPoolStatus = async (poolName) => {
      currentPoolName.value = poolName
      showPoolStatusModal.value = true
      loadingPoolStatus.value = true
      
      try {
        const response = await axios.get(`/api/zfs/pools/${poolName}/status`)
        poolStatus.value = response.data.status
      } catch (error) {
        console.error('Errore durante il recupero dello stato del pool:', error)
        $toast.error('Errore durante il recupero dello stato del pool')
        poolStatus.value = 'Errore durante il recupero dello stato del pool'
      } finally {
        loadingPoolStatus.value = false
      }
    }
    
    // Funzione per mostrare le proprietà del dataset
    const showDatasetProperties = async (datasetName) => {
      currentDatasetName.value = datasetName
      showDatasetPropertiesModal.value = true
      loadingDatasetProperties.value = true
      
      try {
        const response = await axios.get(`/api/zfs/datasets/${datasetName}/properties`)
        datasetProperties.value = response.data.properties
      } catch (error) {
        console.error('Errore durante il recupero delle proprietà del dataset:', error)
        $toast.error('Errore durante il recupero delle proprietà del dataset')
        datasetProperties.value = null
      } finally {
        loadingDatasetProperties.value = false
      }
    }
    
    // Funzione per mostrare la modale di distruzione pool
    const openDestroyPoolModal = (poolName) => {
      destroyPoolForm.value.name = poolName
      destroyPoolForm.value.force = false
      showDestroyPoolModal.value = true
    }
    
    // Funzione per mostrare la modale di distruzione dataset
    const openDestroyDatasetModal = (datasetName) => {
      destroyDatasetForm.value.name = datasetName
      destroyDatasetForm.value.recursive = false
      destroyDatasetForm.value.force = false
      showDestroyDatasetModal.value = true
    }
    
    // Funzione per creare un pool ZFS
    const createPool = async () => {
      if (!isCreatePoolFormValid.value) {
        return
      }
      
      isCreatingPool.value = true
      
      // Usa sempre /storage come mountpoint per tutti i pool
      const mountPoint = '/storage'
      
      try {
        const response = await axios.post('/api/zfs/pools', {
          name: createPoolForm.value.name,
          raid_type: createPoolForm.value.raidType,
          disks: createPoolForm.value.disks,
          mount_point: mountPoint
        })
        
        $toast.success(response.data.message || 'Pool ZFS creato con successo')
        showCreatePool.value = false
        refreshPools()
        refreshDatasets()
      } catch (error) {
        console.error('Errore durante la creazione del pool ZFS:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante la creazione del pool ZFS')
      } finally {
        isCreatingPool.value = false
      }
    }
    
    // Funzione per creare un dataset ZFS
    const createDataset = async () => {
      if (!isCreateDatasetFormValid.value) {
        return
      }
      
      isCreatingDataset.value = true
      
      // Prepara la quota se specificata
      let quota = null
      if (createDatasetForm.value.quotaValue) {
        quota = `${createDatasetForm.value.quotaValue}${createDatasetForm.value.quotaUnit}`
      }
      
      try {
        const response = await axios.post('/api/zfs/datasets', {
          pool_name: createDatasetForm.value.poolName,
          dataset_name: createDatasetForm.value.datasetName,
          mount_point: createDatasetForm.value.mountPoint || null,
          quota: quota,
          compression: createDatasetForm.value.compression || null
        })
        
        $toast.success(response.data.message || 'Dataset ZFS creato con successo')
        showCreateDataset.value = false
        refreshDatasets()
      } catch (error) {
        console.error('Errore durante la creazione del dataset ZFS:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante la creazione del dataset ZFS')
      } finally {
        isCreatingDataset.value = false
      }
    }
    
    // Funzione per distruggere un pool ZFS
    const destroyPool = async () => {
      try {
        const response = await axios.delete('/api/zfs/pools', {
          data: {
            name: destroyPoolForm.value.name,
            force: destroyPoolForm.value.force
          }
        })
        
        $toast.success(response.data.message || 'Pool ZFS eliminato con successo')
        showDestroyPoolModal.value = false
        refreshPools()
        refreshDatasets()
      } catch (error) {
        console.error('Errore durante l\'eliminazione del pool ZFS:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante l\'eliminazione del pool ZFS')
      }
    }
    
    // Funzione per distruggere un dataset ZFS
    const destroyDataset = async () => {
      try {
        const response = await axios.delete('/api/zfs/datasets', {
          data: {
            name: destroyDatasetForm.value.name,
            recursive: destroyDatasetForm.value.recursive,
            force: destroyDatasetForm.value.force
          }
        })
        
        $toast.success(response.data.message || 'Dataset ZFS eliminato con successo')
        showDestroyDatasetModal.value = false
        refreshDatasets()
      } catch (error) {
        console.error('Errore durante l\'eliminazione del dataset ZFS:', error)
        $toast.error(error.response?.data?.detail || 'Errore durante l\'eliminazione del dataset ZFS')
      }
    }
    
    // Funzione per resettare il form di creazione pool
    const resetCreatePoolForm = () => {
      createPoolForm.value = {
        name: '',
        raidType: '',
        disks: [],
        mountPoint: ''
      }
    }
    
    // Funzione per resettare il form di creazione dataset
    const resetCreateDatasetForm = () => {
      createDatasetForm.value = {
        poolName: '',
        datasetName: '',
        mountPoint: '',
        quotaValue: '',
        quotaUnit: 'G',
        compression: ''
      }
    }
    
    return {
      pools,
      datasets,
      availableDisks,
      loadingPools,
      loadingDatasets,
      loadingDisks,
      showCreatePool,
      isCreatingPool,
      createPoolForm,
      showCreateDataset,
      isCreatingDataset,
      createDatasetForm,
      showPoolStatusModal,
      loadingPoolStatus,
      poolStatus,
      currentPoolName,
      showDatasetPropertiesModal,
      loadingDatasetProperties,
      datasetProperties,
      currentDatasetName,
      showDestroyPoolModal,
      destroyPoolForm,
      showDestroyDatasetModal,
      destroyDatasetForm,
      refreshPools,
      refreshDatasets,
      refreshAvailableDisks,
      formatBytes,
      getCapacityClass,
      getHealthClass,
      getRaidTypeDescription,
      diskRequirementText,
      isCreatePoolFormValid,
      isCreateDatasetFormValid,
      showCreatePoolModal,
      showCreateDatasetModal,
      showPoolStatus,
      showDatasetProperties,
      showDestroyPoolModal,
      openDestroyPoolModal,
      showDestroyDatasetModal,
      openDestroyDatasetModal,
      createPool,
      createDataset,
      destroyPool,
      destroyDataset,
      resetCreatePoolForm,
      resetCreateDatasetForm
    }
  }
}
</script>

<style scoped>
.zfs-management {
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

.pool-status {
  background-color: #f8f9fa;
  padding: 10px;
  border-radius: 4px;
  white-space: pre-wrap;
  font-family: monospace;
  font-size: 0.9rem;
  max-height: 400px;
  overflow-y: auto;
}
</style>