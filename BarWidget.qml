import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "NotificationLogic.js" as NotificationLogic

BarWidget {
  id: root
  moduleName: "omacom.notification-center"

  property bool popupOpen: false
  property var rows: []
  property int liveCount: 0

  property bool dnd: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string notificationDir: home + "/.local/state/omarchy/notifications"

  function close() {
    popupOpen = false
  }

  function sanitizeBody(s, app, appIcon) {
    return NotificationLogic.sanitizeBody(s, app, appIcon)
  }

  function notificationIconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  function refresh() {
    if (stateReader.running) return

    stateReader.command = [
      "bash", "-c",
      "dnd=$(omarchy-shell notifications dndState 2>/dev/null || printf 'off'); " +
      "printf 'D\\t%s\\n' \"$dnd\"; " +
      "for f in \"$1\"/*.json; do " +
      "  [[ -e $f ]] || continue; printf 'L\\t'; cat \"$f\"; printf '\\n'; " +
      "done; " +
      "for f in \"$1/history\"/*.json; do " +
      "  [[ -e $f ]] || continue; printf 'H\\t'; cat \"$f\"; printf '\\n'; " +
      "done",
      "--", root.notificationDir
    ]
    stateReader.running = true
  }

  function parseState(raw) {
    var nextRows = []
    var live = 0
    var lines = String(raw || "").split("\n")

    for (var i = 0; i < lines.length; ++i) {
      var line = lines[i]
      if (line.length < 2) continue

      if (line.indexOf("D\t") === 0) {
        root.dnd = line.substring(2).trim() === "on"
        continue
      }

      var isLive = line.indexOf("L\t") === 0
      var isHistory = line.indexOf("H\t") === 0
      if (!isLive && !isHistory) continue

      try {
        var value = JSON.parse(line.substring(2))
        if (!value || typeof value !== "object") continue

        if (isLive) live++

        nextRows.push({
          isLive: isLive,
          id: value.id !== undefined ? value.id : 0,
          originalId: value.originalId !== undefined ? value.originalId : value.id,
          app: String(value.app || value.appName || ""),
          appIcon: String(value.appIcon || ""),
          summary: String(value.summary || ""),
          body: String(value.body || ""),
          image: String(value.image || ""),
          urgency: Number(value.urgency === undefined ? 1 : value.urgency),
          timestamp: Number(value.timestamp || 0)
        })
      } catch (e) {
        // Ignore a file caught between write/rename and pick it up next poll.
      }
    }

    nextRows.sort(function(a, b) { return (b.timestamp || 0) - (a.timestamp || 0) })
    root.liveCount = live
    root.rows = nextRows
  }

  function toggleDnd() {
    if (dndProc.running) return
    dndProc.command = ["omarchy-shell", "notifications", "toggleDnd"]
    dndProc.running = true
  }

  function dismissAll() {
    if (actionProc.running) return
    actionProc.command = ["omarchy-shell", "notifications", "dismissAll"]
    actionProc.running = true
  }

  function clearAll() {
    if (actionProc.running) return
    actionProc.command = [
      "bash", "-c",
      "omarchy-shell notifications dismissAll >/dev/null && " +
      "omarchy-shell notifications clear >/dev/null"
    ]
    actionProc.running = true
  }

  function dismiss(row) {
    if (!row || !row.isLive || actionProc.running) return
    actionProc.command = ["omarchy-shell", "notifications", "dismiss", String(row.summary || "")]
    actionProc.running = true
  }

  onPopupOpenChanged: if (popupOpen) refresh()

  Component.onCompleted: refresh()

  Timer {
    interval: root.popupOpen ? 500 : 2000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Process {
    id: stateReader
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseState(text)
    }
  }

  Process {
    id: dndProc
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var state = String(text || "").trim()
        if (state === "on" || state === "off")
          root.dnd = state === "on"
      }
    }

    onExited: root.refresh()
  }

  Process {
    id: actionProc
    running: false
    onExited: root.refresh()
  }

  readonly property string icon: {
    if (dnd) return "󰂛"
    if (liveCount > 0) return "󱅫"
    return "󰂚"
  }

  readonly property color colForeground: Color.foreground
  readonly property color colDim: Qt.darker(Color.foreground, 1.4)
  readonly property color colBorder: Style.normalBorderFor(Color.foreground, Color.accent)
  readonly property int cardRadius: Style.cornerRadius

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    active: root.liveCount > 0 && !root.dnd
    tooltipText: root.dnd ? "Do Not Disturb"
      : (root.liveCount > 0 ? root.liveCount + " live" : "No live notifications")

    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleDnd()
      else root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.cappedContentHeight(Style.space(540))

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.space(10)

      // ----------------------------------------- header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: "Notifications"
          font.family: root.bar ? root.bar.fontFamily : ""
          color: root.colForeground
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Item { Layout.fillWidth: true }

        ToggleSwitch {
          id: dndSwitch
          checked: root.dnd
          foreground: root.colForeground
          onToggled: root.toggleDnd()

          PanelToolTip {
            visible: dndSwitch.containsMouse
            text: root.dnd ? "Turn Do Not Disturb off" : "Turn Do Not Disturb on"
            fontFamily: root.bar ? root.bar.fontFamily : ""
          }
        }
      }

      // ----------------------------------------- unified list
      ListView {
        id: listView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.space(8)
        model: root.rows
        visible: count > 0

        delegate: BorderSurface {
          id: rowCard
          required property var modelData

          readonly property string iconValue: String(modelData.image || modelData.appIcon || "")
          readonly property string smallIconSource: root.notificationIconSource(iconValue)
          readonly property bool hasIcon: smallIconSource.length > 0
          readonly property string sanitizedBody: root.sanitizeBody(
            modelData.body, modelData.app, modelData.appIcon)

          width: listView.width
          implicitHeight: rowContent.implicitHeight + Style.spacing.panelGap
          radius: root.cardRadius
          color: "transparent"
          borderSpec: Border.flat(root.colBorder, Style.normalBorderWidth)

          RowLayout {
            id: rowContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: rowCard.borderLeft + Style.space(12)
            anchors.rightMargin: rowCard.borderRight + Style.space(12)
            spacing: Style.space(10)

            Item {
              id: imageSlot
              Layout.preferredWidth: Style.space(32)
              Layout.preferredHeight: Style.space(32)
              Layout.alignment: Qt.AlignVCenter
              visible: rowCard.hasIcon && rowIconImage.status !== Image.Error

              Image {
                id: rowIconImage
                anchors.fill: parent
                source: rowCard.smallIconSource
                fillMode: Image.PreserveAspectFit
                sourceSize.width: imageSlot.width * Screen.devicePixelRatio
                sourceSize.height: imageSlot.height * Screen.devicePixelRatio
                asynchronous: true
                smooth: true
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)

                Text {
                  Layout.fillWidth: true
                  visible: String(rowCard.modelData.summary || "").length > 0
                  text: rowCard.modelData.summary
                  font.family: root.bar ? root.bar.fontFamily : ""
                  color: root.colForeground
                  font.pixelSize: Style.font.subtitle
                  font.bold: rowCard.modelData.isLive
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }

                Rectangle {
                  visible: rowCard.modelData.isLive
                  Layout.preferredWidth: Style.space(6)
                  Layout.preferredHeight: Style.space(6)
                  Layout.alignment: Qt.AlignVCenter
                  radius: width / 2
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                visible: rowCard.sanitizedBody.length > 0
                text: rowCard.sanitizedBody
                font.family: root.bar ? root.bar.fontFamily : ""
                textFormat: Text.PlainText
                color: root.colDim
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
              }
            }

            Rectangle {
              visible: rowCard.modelData.isLive
              Layout.preferredWidth: Style.space(18)
              Layout.preferredHeight: Style.space(18)
              Layout.alignment: Qt.AlignVCenter
              radius: Math.min(4, root.cardRadius)
              color: rowCloseArea.containsMouse ? root.colBorder : "transparent"

              Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: root.bar ? root.bar.fontFamily : ""
                color: root.colDim
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: rowCloseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismiss(rowCard.modelData)
              }
            }
          }
        }
      }

      // ----------------------------------------- empty state
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.rows.length === 0

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰂚"
            font.family: root.bar ? root.bar.fontFamily : ""
            color: root.colBorder
            font.pixelSize: Style.font.displayLarge
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No notifications"
            font.family: root.bar ? root.bar.fontFamily : ""
            color: root.colDim
            font.pixelSize: Style.font.body
          }
        }
      }

      // ----------------------------------------- footer actions
      RowLayout {
        Layout.fillWidth: true
        visible: root.rows.length > 0
        spacing: Style.space(8)

        FooterAction {
          Layout.fillWidth: true
          text: "Dismiss all"
          enabled: root.liveCount > 0
          onClicked: root.dismissAll()
        }

        FooterAction {
          Layout.fillWidth: true
          text: "Clear"
          onClicked: root.clearAll()
        }
      }
    }
  }

  component FooterAction: BorderSurface {
    id: action

    property string text: ""
    signal clicked()

    Layout.preferredHeight: Math.max(Style.space(28), Style.font.bodySmall + Style.spacing.controlPaddingY * 2)
    radius: Math.min(Style.space(6), root.cardRadius)
    color: actionArea.containsMouse && action.enabled ? root.colBorder : "transparent"
    borderSpec: Border.flat(root.colBorder, Style.normalBorderWidth)
    opacity: action.enabled ? 1 : 0.45

    Text {
      anchors.centerIn: parent
      text: action.text
      font.family: root.bar ? root.bar.fontFamily : ""
      color: root.colForeground
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    MouseArea {
      id: actionArea
      anchors.fill: parent
      enabled: action.enabled
      hoverEnabled: true
      cursorShape: action.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: action.clicked()
    }
  }
}
