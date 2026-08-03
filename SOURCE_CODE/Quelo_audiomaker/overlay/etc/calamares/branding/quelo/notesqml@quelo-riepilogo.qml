import QtQuick 2.7
import QtQuick.Controls 2.2
import io.calamares.ui 1.0

/* Placeholder: sovrascritto da quelo-calamares-riepilogo prima di Calamares. */
Item {
    width: 740
    height: 420
    Text {
        anchors.fill: parent
        anchors.margins: 16
        wrapMode: Text.WordWrap
        textFormat: Text.RichText
        text: "<h2>Riepilogo</h2><p>Schema partizioni non generato. "
            + "Torna indietro e riesegui il riepilogo Quelo.</p>"
    }
}
