<template>
  <div class="disk-management">
    <h1>{{ $t('disk.title') || 'Gestione Dischi' }}</h1>
    
    <div class="alert alert-info mb-4">
      <font-awesome-icon icon="info-circle" class="me-2" />
      <strong>{{ $t('disk.info_title') || 'Gestione ZFS' }}</strong>
      <p class="mb-0">{{ $t('disk.info_message') || 'Questa sezione mostra solo informazioni sui dischi. Per creare pool ZFS e gestire lo storage, utilizza la sezione' }} <router-link to="/zfs">ZFS Management</router-link>.</p>
    </div>
    
    <div class="row">
      <!-- Informazioni sui dischi -->
      <div class="col-md-12 mb-4">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="mb-0">
              <font-awesome-icon icon="hdd" class="me-2" />
              {{ $t('disk.info') }}
            </h5>
            <button class="btn btn-sm btn-outline-primary" @click="refreshDisks">
              <font-awesome-icon icon="sync" :class="{ 'fa-spin': loading }" />
            </button>
          </div>
          <div class="card-body">
            <div v-if="loading" class="text-center py-3">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">{{ $t('common.loading') }}</span>
              </div>
            </div>
            <div v-else-if="disks && disks.length">
              <div class="table-responsive">
                <table class="table table-hover">
                  <thead>
                    <tr>
                      <th>{{ $t('disk.device') }}</th>
                      <th>{{ $t('disk.mountpoint') }}</th>
                      <th>{{ $t('disk.fstype') }}</th>
                      <th>{{ $t('disk.used') }}</th>
                      <th>{{ $t('disk.free') }}</th>
                      <th>{{ $t('disk.total') }}</th>
                      <th>{{ $t('disk.percent') }}</th>
                      <th>{{ $t('disk.automount') }}</th>
                      <th>{{ $t('common.actions') }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="disk in disks" :key="disk.device">
                      <td>{{ disk.device }}</td>
                      <td>{{ disk.mountpoint || '-' }}</td>
                      <td>{{ disk.fstype || '-' }}</td>
                      <td>{{ formatBytes(disk.used) }}</td>
                      <td>{{ formatBytes(disk.free) }}</td>
                      <td>{{ formatBytes(disk.total) }}</td>
                      <td>
                        <div class="progress" style="height: 10px;">
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
                        <small>{{ disk.percent }}%</small>
                      </td>
                      <td>
                        <span
                          class="badge"
                          :class="disk.automount ? 'bg-success' : 'bg-secondary'"
                        >
                          {{ disk.automount ? $t('common.enabled') : $t('common.disabled') }}
                        </span>
                      </td>
                      <td>
                        <button
                          class="btn btn-sm btn-info"
                          @click="checkDiskHealth(disk)"
                        >
                          <font-awesome-icon icon="heartbeat" class="me-1" />
                          {{ $t('disk.check') || 'Salute' }}
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div v-else class="text-center py-3 text-muted">
              {{ $t('common.error') }}
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Modal per lo stato di salute del disco -->
    <b-modal 
      v-model="showHealthModal" 
      :title="$t('disk.health')" 
      ok-only
      ok-variant="primary"
      :ok-title="$t('common.close')"
    >
      <div v-if="diskHealth">
        <div class="mb-3">
          <strong>{{ $t('disk.device') }}:</strong> {{ diskHealth.device }}
        </div>
        <div class="mb-3">
          <strong>{{ $t('disk.health') }}:</strong>
          <span 
            class="badge" 
            :class="{
              'bg-success': diskHealth.health === 'healthy',
              'bg-danger': diskHealth.health === 'failing',
              'bg-warning': diskHealth.health === 'unknown'
            }"
          >
            {{ diskHealth.health }}
          </span>
        </div>
        <div v-if="Object.keys(diskHealth.details).length > 0">
          <h6>Dettagli SMART:</h6>
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Attributo</th>
                <th>Valore</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(value, key) in diskHealth.details" :key="key">
                <td>{{ key }}</td>
                <td>{{ value }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <div v-else class="text-center py-3 text-muted">
        {{ $t('common.loading') }}
      </div>
    </b-modal>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import { useStore } from 'vuex'
import { useToast } from 'vue-toast-notification'

export default {
  name: 'DiskManagement',
  setup() {
    const store = useStore()
    const $toast = useToast()
    
    // Stato
    const disks = ref([])
    const loading = ref(false)
    const showHealthModal = ref(false)
    const diskHealth = ref(null)
    
    // Carica i dati all'avvio
    onMounted(() => {
      refreshDisks()
    })
    
    // Funzioni
    const refreshDisks = async () => {
      loading.value = true
      try {
        await store.dispatch('disk/fetchDisks')
        disks.value = store.getters['disk/allDisks']
      } catch (error) {
        $toast.error('Errore nel caricamento delle informazioni sui dischi')
      } finally {
        loading.value = false
      }
    }
    
    const checkDiskHealth = async (disk) => {
      diskHealth.value = null
      showHealthModal.value = true
      
      try {
        const result = await store.dispatch('disk/checkDiskHealth', disk.device)
        
        if (result.success) {
          diskHealth.value = result.health
        } else {
          $toast.error(result.message || 'Errore nel controllo della salute del disco')
          showHealthModal.value = false
        }
      } catch (error) {
        $toast.error('Errore nel controllo della salute del disco')
        showHealthModal.value = false
      }
    }
    
    // Funzioni di utilità
    const formatBytes = (bytes, decimals = 2) => {
      if (bytes === 0 || !bytes) return '0 Bytes'
      
      const k = 1024
      const dm = decimals < 0 ? 0 : decimals
      const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
      
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      
      return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i]
    }
    
    const getDiskBarClass = (percent) => {
      if (percent < 75) return 'bg-success'
      if (percent < 90) return 'bg-warning'
      return 'bg-danger'
    }
    
    return {
      disks,
      loading,
      showHealthModal,
      diskHealth,
      refreshDisks,
      checkDiskHealth,
      formatBytes,
      getDiskBarClass
    }
  }
}
</script>

<style scoped>
.disk-management {
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
  border-bottom: 1px solid rgba(0, 0, 0, 0.125);
  padding: 0.75rem 1.25rem;
}

.progress {
  height: 10px;
  border-radius: 5px;
  margin-bottom: 5px;
}

.btn-group {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}

@media (max-width: 768px) {
  .btn-group {
    flex-direction: column;
  }
}
</style>