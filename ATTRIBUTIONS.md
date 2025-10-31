# Attribuzioni e Licenze

Questo documento elenca tutti i progetti open-source, librerie e dipendenze utilizzate in ArmNAS, insieme ai relativi crediti e licenze.

## Progetti Principali

### Virtual DSM

**Repository**: [vdsm/virtual-dsm](https://github.com/vdsm/virtual-dsm)  
**Licenza**: MIT  
**Descrizione**: Virtual DSM in a Docker container  
**Utilizzo**: Questo progetto utilizza Virtual DSM per eseguire Synology DSM in un container Docker.

**Disclaimer**: Solo eseguire il container Virtual DSM su hardware Synology ufficiale, qualsiasi altro uso non è consentito dalla EULA di Synology. I nomi di prodotto, loghi, marchi e altri marchi commerciali menzionati sono proprietà dei rispettivi titolari di marchio. Questo progetto non è affiliato, sponsorizzato o approvato da Synology, Inc.

## Dipendenze Backend (Python)

### FastAPI

**Repository**: [tiangolo/fastapi](https://github.com/tiangolo/fastapi)  
**Licenza**: MIT  
**Versione**: 0.95.0  
**Descrizione**: Framework web moderno e veloce per costruire API con Python

### Uvicorn

**Repository**: [encode/uvicorn](https://github.com/encode/uvicorn)  
**Licenza**: BSD  
**Versione**: 0.21.1  
**Descrizione**: Server ASGI veloce basato su uvloop e httptools

### Pydantic

**Repository**: [pydantic/pydantic](https://github.com/pydantic/pydantic)  
**Licenza**: MIT  
**Versione**: 1.10.7  
**Descrizione**: Validazione di dati usando annotazioni di tipo Python

### SQLAlchemy

**Repository**: [sqlalchemy/sqlalchemy](https://github.com/sqlalchemy/sqlalchemy)  
**Licenza**: MIT  
**Versione**: 2.0.15  
**Descrizione**: SQL toolkit e Object-Relational Mapping (ORM) per Python

### Passlib

**Repository**: [gazzar/passlib](https://bitbucket.org/ecollins/passlib)  
**Licenza**: BSD  
**Versione**: 1.7.4  
**Descrizione**: Libreria per gestione password con supporto per Argon2

### Argon2-cffi

**Repository**: [hynek/argon2-cffi](https://github.com/hynek/argon2-cffi)  
**Licenza**: MIT  
**Versione**: 23.1.0  
**Descrizione**: Binding Python per la libreria di hashing password Argon2

### Python-jose

**Repository**: [mpdavis/python-jose](https://github.com/mpdavis/python-jose)  
**Licenza**: MIT  
**Versione**: 3.3.0  
**Descrizione**: Implementazione JWT in Python

### Psutil

**Repository**: [giampaolo/psutil](https://github.com/giampaolo/psutil)  
**Licenza**: BSD  
**Versione**: 5.9.5  
**Descrizione**: Libreria cross-platform per recuperare informazioni su processi e utilizzo sistema

### Aiofiles

**Repository**: [Tinche/aiofiles](https://github.com/Tinche/aiofiles)  
**Licenza**: Apache-2.0  
**Versione**: 23.1.0  
**Descrizione**: Supporto asincrono per file in Python

### Requests

**Repository**: [psf/requests](https://github.com/psf/requests)  
**Licenza**: Apache-2.0  
**Versione**: 2.31.0  
**Descrizione**: Libreria HTTP elegante e semplice per Python

### Python-multipart

**Repository**: [andrew-d/python-multipart](https://github.com/andrew-d/python-multipart)  
**Licenza**: Apache-2.0  
**Versione**: 0.0.6  
**Descrizione**: Analizzatore di form-data multipart per Python

## Dipendenze Frontend (JavaScript/TypeScript)

### Vue.js

**Repository**: [vuejs/vue](https://github.com/vuejs/vue)  
**Licenza**: MIT  
**Versione**: ^3.2.47  
**Descrizione**: Framework JavaScript progressivo per costruire interfacce utente

### Vue Router

**Repository**: [vuejs/router](https://github.com/vuejs/router)  
**Licenza**: MIT  
**Versione**: ^4.1.6  
**Descrizione**: Router ufficiale per Vue.js

### Vuex

**Repository**: [vuejs/vuex](https://github.com/vuejs/vuex)  
**Licenza**: MIT  
**Versione**: ^4.1.0  
**Descrizione**: Libreria di gestione dello stato per applicazioni Vue.js

### Bootstrap

**Repository**: [twbs/bootstrap](https://github.com/twbs/bootstrap)  
**Licenza**: MIT  
**Versione**: ^5.2.3  
**Descrizione**: Framework CSS per sviluppare progetti responsive e mobile-first

### Bootstrap Vue 3

**Repository**: [cdmoro/bootstrap-vue-3](https://github.com/cdmoro/bootstrap-vue-3)  
**Licenza**: MIT  
**Versione**: ^0.5.1  
**Descrizione**: Implementazione Bootstrap per Vue.js 3

### Chart.js

**Repository**: [chartjs/Chart.js](https://github.com/chartjs/Chart.js)  
**Licenza**: MIT  
**Versione**: ^4.2.1  
**Descrizione**: Libreria JavaScript per creare grafici interattivi

### Vue Chart.js

**Repository**: [apertureless/vue-chartjs](https://github.com/apertureless/vue-chartjs)  
**Licenza**: MIT  
**Versione**: ^5.2.0  
**Descrizione**: Wrapper Vue.js per Chart.js

### Vue I18n

**Repository**: [kazupon/vue-i18n](https://github.com/kazupon/vue-i18n)  
**Licenza**: MIT  
**Versione**: ^9.2.2  
**Descrizione**: Plugin di internazionalizzazione per Vue.js

### Vue Toast Notification

**Repository**: [ankurk91/vue-toast-notification](https://github.com/ankurk91/vue-toast-notification)  
**Licenza**: MIT  
**Versione**: ^3.1.1  
**Descrizione**: Libreria per notifiche toast in Vue.js

### Font Awesome

**Repository**: [FortAwesome/Font-Awesome](https://github.com/FortAwesome/Font-Awesome)  
**Licenza**: Font Awesome Free License / CC BY 4.0  
**Versione**: ^6.4.0  
**Descrizione**: Icone e toolkit di font

**Pacchetti utilizzati**:
- `@fortawesome/fontawesome-svg-core`: ^6.4.0
- `@fortawesome/free-solid-svg-icons`: ^6.4.0
- `@fortawesome/vue-fontawesome`: ^3.0.3

### Axios

**Repository**: [axios/axios](https://github.com/axios/axios)  
**Licenza**: MIT  
**Versione**: ^1.3.4  
**Descrizione**: Client HTTP basato su Promise per browser e Node.js

## Strumenti di Sviluppo

### Vite

**Repository**: [vitejs/vite](https://github.com/vitejs/vite)  
**Licenza**: MIT  
**Versione**: ^4.2.1  
**Descrizione**: Build tool frontend veloce e ottimizzato

### @vitejs/plugin-vue

**Repository**: [vitejs/vite-plugin-vue](https://github.com/vitejs/vite-plugin-vue)  
**Licenza**: MIT  
**Versione**: ^4.1.0  
**Descrizione**: Plugin ufficiale Vite per Vue.js

### Sass

**Repository**: [sass/dart-sass](https://github.com/sass/dart-sass)  
**Licenza**: MIT  
**Versione**: ^1.60.0  
**Descrizione**: Estensione CSS con superpoteri

## Note Legali

Tutte le licenze menzionate in questo documento sono disponibili nei rispettivi repository dei progetti. Si prega di consultare i file LICENSE di ciascun progetto per i dettagli completi sui termini di licenza.

Questo progetto rispetta tutte le licenze open-source delle dipendenze utilizzate. Per qualsiasi domanda relativa alle licenze, si prega di consultare i repository originali dei progetti.

## Ringraziamenti

Un ringraziamento speciale a tutti i maintainer e contributori dei progetti open-source menzionati in questo documento. Senza il loro lavoro e dedizione, questo progetto non sarebbe stato possibile.

