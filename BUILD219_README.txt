ATX Player 5.2 – Build 219

FIX LIVE VIDEO FREEZE
- Corretto il caso in cui il canale Live parte con audio ma immagine bloccata.
- Il Live non viene più considerato avviato soltanto perché AVPlayer sta riproducendo audio.
- Aggiunto controllo reale dei frame video decodificati.
- Se l’audio continua ma i frame video si fermano, viene tentato automaticamente l’endpoint compatibile TS/HLS una sola volta.
- Buffer Live portato a 1 secondo per maggiore stabilità del decoder senza introdurre un ritardo importante.
- Nessun secondo player sovrapposto: il vecchio item viene chiuso prima del fallback.
