import QtQuick 2.0
import calamares.slideshow 1.0
import io.calamares.ui 1.0

Presentation {
    id: presentation

    Timer {
        interval: 20000
        repeat: true
        running: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        // Sfondo pieno: l'immagine occupa tutto lo spazio utile.
        Rectangle {
            anchors.fill: parent
            color: "#1a1510"

            Image {
                id: background1
                anchors.fill: parent
                source: "slide1.png"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // Fascia scura in basso: testo leggibile sull'immagine.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 80
                color: "#e62a2118"

                Text {
                    anchors.fill: parent
                    anchors.margins: 14
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "#f5efe6"
                    font.pixelSize: 15
                    text: qsTr("Installazione di Quelo Audiomaker in corso.\n" +
                               "Tra poco potrai usare il sistema dal disco interno.")
                }
            }
        }
    }
}
