ATX Player 5.2 build 218

Mosaico: righe a tutta larghezza in verticale; griglia in orizzontale, senza quarto riquadro vuoto con tre canali. Video riempie la cella con ritaglio proporzionale. Stato connessione e errore per ciascun canale, pulsante Riprova. Audio di un solo canale alla volta.
Player: verifica errori cancellabile e legata al player e item correnti; rimosse pause forzate in avvio e cambio formato basato su probe dei fotogrammi. Fallback live solo in seguito a un errore reale.

Verifica richiesta su Mac/iPhone: apertura film/episodi/live, passaggio episodio, rotazione/fullscreen, mosaico 2/3/4 canali, chiusura e riapertura. Questo ambiente non dispone di Xcode o SDK iOS; compilazione e riproduzione reali non eseguite. AVPlayer conserva i suoi limiti di codec e contenitori. La playlist deve consentire il numero di connessioni simultanee scelto nel mosaico.
