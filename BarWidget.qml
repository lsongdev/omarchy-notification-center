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
  property var historyRows: []
  property var rows: []

  function close() {
    popupOpen = false
  }

  // Omarchy currently keeps only live notifications in popupModel. Once a
  // popup leaves the screen its persisted JSON file is moved into historyDir.
  readonly property var hostShell: bar && bar.shell ? bar.shell : null
  readonly property var notificationService: hostShell && hostShell.firstPartyServiceFor
    ? hostShell.firstPartyServiceFor("omarchy.notifications") : null

  readonly property var popupModel: notificationService && notificationService.popupModel
    ? notificationService.popupModel : null
  readonly property int unreadCount: popupModel ? popupModel.count : 0
  readonly property string historyDir: notificationService && notificationService.historyDir
    ? String(notificationService.historyDir) : ""

  readonly property bool dndSupported: !!notificationService
    && typeof notificationService.doNotDisturb === "boolean"
    && typeof notificationService.setDoNotDisturb === "function"
  readonly property bool dnd: dndSupported && notificationService.doNotDisturb

  function toggleDnd() {
    if (dndSupported)
      notificationService.setDoNotDisturb(!notificationService.doNotDisturb)
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

  function rowKey(row) {
    if (!row) return ""
    var originalId = row.originalId !== undefined && row.originalId !== null
      ? row.originalId : row.id
    return String(originalId || 0) + ":" + String(row.timestamp || 0)
  }

  function rebuildRows() {
    var merged = []
    var positions = ({})

    function add(row) {
      if (!row) return
      var key = root.rowKey(row)
      if (positions[key] !== undefined) {
        // Prefer the live version during the short archive transition.
        if (row.isLive) merged[positions[key]] = row
        return
      }
      positions[key] = merged.length
      merged.push(row)
    }

    for (var h = 0; h < root.historyRows.length; ++h)
      add(root.historyRows[h])

    var model = root.popupModel
    if (model) {
      for (var i = 0; i < model.count; ++i) {
        var live = model.get(i)
        if (!live) continue
        add({
          sourceIndex: i,
          isLive: true,
          id: live.id !== undefined ? live.id : 0,
          originalId: live.originalId !== undefined ? live.originalId : live.id,
          app: String(live.appName || live.app || ""),
          appIcon: String(live.appIcon || ""),
          summary: String(live.summary || ""),
          body: String(live.body || ""),
          image: String(live.image || ""),
          urgency: Number(live.urgency === undefined ? 1 : live.urgency),
          timestamp: Number(live.timestamp || 0)
        })
      }
    }

    merged.sort(function(a, b) { return (b.timestamp || 0) - (a.timestamp || 0) })
    root.rows = merged
  }

  function parseHistory(raw) {
    var parsed = []
    var lines = String(raw || "").split("\n")

    for (var i = 0; i < lines.length; ++i) {
      var line = lines[i].trim()
      if (!line) continue

      try {
        var value = JSON.parse(line)
        if (!value || typeof value !== "object") continue

        parsed.push({
          sourceIndex: -1,
          isLive: false,
          id: value.id !== undefined ? value.id : 0,
          originalId: value.originalId !== undefined ? value.originalId : value.id,
          app: String(value.app || ""),
          appIcon: String(value.appIcon || ""),
          summary: String(value.summary || ""),
          body: String(value.body || ""),
          image: String(value.image || ""),
          urgency: Number(value.urgency === undefined ? 1 : value.urgency),
          timestamp: Number(value.timestamp || 0)
        })
      } catch (e) {
        // Ignore a partially-written history file and pick it up next refresh.
      }
    }

    parsed.sort(function(a, b) { return (b.timestamp || 0) - (a.timestamp || 0) })

    var limit = notificationService && notificationService.historyLimit
      ? Number(notificationService.historyLimit) : 10
    root.historyRows = parsed.slice(0, limit)
    rebuildRows()
  }

  function refreshHistory() {
    if (!root.historyDir || historyReader.running) return
    historyReader.command = ["bash", "-c",
      "awk 1 \"$1\"/*.json 2>/dev/null || true", "--", root.historyDir]
    historyReader.running = true
  }

  function markAllRead() {
    if (!notificationService || typeof notificationService.clearPopups !== "function") return

    // Omarchy archives dismissed popups into historyDir, so clearing the live
    // popup stack is the closest native equivalent of marking everything read.
    notificationService.clearPopups()
    rebuildRows()
  }

  function clearAll() {
    if (!notificationService) return

    if (typeof notificationService.clearPopups === "function")
      notificationService.clearPopups()
    if (typeof notificationService.clearHistory === "function")
      notificationService.clearHistory()

    root.historyRows = []
    root.rows = []
  }

  function dismiss(row) {
    if (!row || !row.isLive || !notificationService
        || typeof notificationService.dismissPopup !== "function") return

    notificationService.dismissPopup(row.sourceIndex)
  }

  onPopupOpenChanged: {
    if (popupOpen) {
      refreshHistory()
      rebuildRows()
    }
  }

  Timer {
    interval: 500
    repeat: true
    running: root.popupOpen
    onTriggered: root.refreshHistory()
  }

  Process {
    id: historyReader
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseHistory(text)
    }
  }

  Connections {
    target: root.popupModel

    function onCountChanged() { root.rebuildRows() }
    function onDataChanged() { root.rebuildRows() }
    function onRowsInserted() { root.rebuildRows() }
    function onRowsRemoved() { root.rebuildRows() }
    function onModelReset() { root.rebuildRows() }
  }

  readonly property string icon: {
    if (dnd) return "󰂛"
    if (unreadCount > 0) return "󱅫"
    return "󰂚"
  }

  readonly property color colForeground: Color.foreground
  readonly property color colDim: Qt.darker(Color.foreground, 1.4)
  readonly property color colBorder: Style.normalBorderFor(Color.foreground, Color.accent)
  readonly property int cardRadius: notificationService && notificationService.cornerRadius
    ? notificationService.cornerRadius : Style.cornerRadius

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    active: root.unreadCount > 0 && !root.dnd
    tooltipText: root.dnd ? "Do Not Disturb"
      : (root.unreadCount > 0 ? root.unreadCount + " unread" : "No unread notifications")

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
          visible: root.dndSupported
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

          readonly property string smallIconSource: root.notificationIconSource(modelData.image || modelData.appIcon)
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
          text: "Mark all as read"
          enabled: root.unreadCount > 0
          onClicked: root.markAllRead()
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
