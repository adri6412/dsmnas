import axios from 'axios'
import store from '@/store'
import router from '@/router'

// Crea un'istanza di axios
const axiosInstance = axios.create({
  baseURL: '/',
  timeout: 30000, // 30 secondi default (aumentato da 10s)
  withCredentials: true
})

// Variabile per tenere traccia dei messaggi di errore già mostrati
let errorShown = false;

// Funzione per mostrare un messaggio di errore
const showErrorToast = (message) => {
  // Non mostrare errori nella pagina di login
  if (router.currentRoute.value.name === 'Login') {
    console.log('Toast ignorato nella pagina di login:', message);
    return;
  }
  
  if (!errorShown) {
    errorShown = true;
    
    // Crea un elemento toast
    const toastEl = document.createElement('div');
    toastEl.className = 'toast-container position-fixed top-0 end-0 p-3';
    toastEl.style.zIndex = '9999';
    
    toastEl.innerHTML = `
      <div class="toast show bg-danger text-white" role="alert" aria-live="assertive" aria-atomic="true">
        <div class="toast-header bg-danger text-white">
          <strong class="me-auto">Errore</strong>
          <button type="button" class="btn-close btn-close-white" data-bs-dismiss="toast" aria-label="Close" onclick="this.parentElement.parentElement.parentElement.remove()"></button>
        </div>
        <div class="toast-body">
          ${message}
        </div>
      </div>
    `;
    
    document.body.appendChild(toastEl);
    
    // Rimuovi il toast dopo 3 secondi
    setTimeout(() => {
      if (document.body.contains(toastEl)) {
        document.body.removeChild(toastEl);
      }
      errorShown = false;
    }, 3000);
  }
};

// Interceptor per le risposte
axiosInstance.interceptors.response.use(
  response => response,
  error => {
    // Gestisci gli errori di autorizzazione
    if (error.response) {
      // Verifica se siamo nella pagina di login
      const isLoginPage = router.currentRoute.value.name === 'Login';
      
      // Non mostrare errori nella pagina di login
      if (isLoginPage) {
        console.log('Errore ignorato nella pagina di login:', error.config.url, error.response.status);
        return Promise.reject(error);
      }
      
      if (error.response.status === 401) {
        // Utente non autenticato, reindirizza al login se non è una richiesta /api/auth/me
        if (error.config.url !== '/api/auth/me') {
          store.dispatch('auth/logout')
          router.push('/login')
          showErrorToast('Sessione scaduta. Effettua nuovamente il login.');
        }
      } else if (error.response.status === 403) {
        // Utente non autorizzato - mostra il messaggio solo se l'utente sta cercando di accedere a una pagina riservata
        if (router.currentRoute.value.meta && router.currentRoute.value.meta.requiresAdmin) {
          showErrorToast('Non hai i permessi per eseguire questa operazione.');
          router.push('/');
        }
      }
    }
    
    return Promise.reject(error)
  }
)

export default axiosInstance