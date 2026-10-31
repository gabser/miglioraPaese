# Prompt da assegnare a Luna

Esegui il piano `docs/testing/piano-test-flussi-luna.md` sul working tree locale
di Migliora Paese / Fanta Comune. Il compito è il collaudo dei flussi in app:
non modificare il codice applicativo e non correggere difetti durante la prova.

Leggi le istruzioni del repository e il piano completo. Identifica il candidato
includendo le sorgenti non tracciate, verifica strumenti browser, Flutter, Node
e PostgreSQL, poi prepara i profili A/B/C/D come indicato. Conserva le modifiche
locali esistenti. Usa dati sintetici e fixture locali; non pubblicare l'app.

Esegui prima gli smoke e i percorsi P0 attraverso l'interfaccia, poi P1/P2,
prove di recupero, responsive e accessibilità. Esegui i reset alla fine. Quando
una prova richiede clock, ruoli o risposte perse, riutilizza fixture e test
esistenti, mantenendo separate le evidenze UI e automatiche. Non usare i vecchi
conteggi di test come risultati della nuova esecuzione.

Se un prerequisito manca, segna BLOCKED il caso dipendente, documenta la causa
e continua i casi indipendenti. Non dichiarare un flusso browser PASS solo
perché hai letto il codice o superato un test widget. Nessun account reale,
email reale, dato civico reale o credenziale deve finire nelle evidenze.

Crea `docs/testing/runs/<data-ora>-luna/REPORT.md` con matrice per ID/variante,
comandi ed exit code, screenshot dei percorsi, risultati automatici separati,
difetti riproducibili ordinati per gravità e casi BLOCKED/NOT RUN con prossimo
passo. Non cambiare gli esiti attesi per far passare il candidato. Se emerge una
divergenza dal piano, documentala con riferimenti al contratto/codice.

Concludi con il link al rapporto, i problemi principali e la valutazione del
collaudo locale prevista dal piano. Non creare PR, commit, issue o deploy.
