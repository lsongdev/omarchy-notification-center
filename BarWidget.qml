import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "NotificationLogic.js" as NotificationLogic

BarWidget {
  id: root
  moduleName: "omacom.notification-center"

  property bool popupOpen: false

  function close() {
    popupOpen = false
  }

  readonly property var hostShell: bar && bar.shell ? bar.shell : null
  readonly property var notificationService: hostShell?.firstPartyServiceFor("omarchy.notifications")

  function isChromiumDerived(app, appIcon) {
    return NotificationLogic.isChromiumDerived(app, appIcon)
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

  function clearAllNotifications() {
    if (!notificationService) return

    // Dismiss pending notifications first, then clear the history they may
    // have moved into. Keep this as UI orchestration and leave storage/state
    // semantics owned by Omarchy's notification service.
    for (var i = notificationService.pendingModel.count - 1; i >= 0; --i)
      notificationService.dismissPending(i)

    notificationService.clearPast()
  }

  readonly property int pendingCount: notificationService ? notificationService.pendingModel.count : 0
  readonly property int pastCount: notificationService ? notificationService.pastModel.count : 0
  readonly property int totalCount: pendingCount + pastCount
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  readonly property string icon: {
    if (dnd) return "󰂛"
    if (pendingCount > 0) return "󱅫"
    return "󰂚"
  }

  readonly property color colForeground: Color.foreground
  readonly property color colDim: Qt.darker(Color.foreground, 1.4)
  readonly property color colBorder: Style.normalBorderFor(Color.foreground, Color.accent)
  readonly property int cardRadius: notificationService ? notificationService.cornerRadius : 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    active: root.pendingCount > 0 && !root.dnd
    tooltipText: root.dnd ? "Do Not Disturb"
      : (root.pendingCount > 0 ? root.pendingCount + " unread" : "No unread notifications")

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (root.notificationService)
          root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen

    // Match the standard Network, Bluetooth and Audio panels.
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.cappedContentHeight(Style.space(540))

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.space(10)

      // ----------------------------------------- header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)

          Text {
            text: "Notifications"
            font.family: root.bar ? root.bar.fontFamily : ""
            color: root.colForeground
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            visible: root.pendingCount > 0
            text: root.pendingCount + (root.pendingCount === 1 ? " unread notification" : " unread notifications")
            font.family: root.bar ? root.bar.fontFamily : ""
            color: root.colDim
            font.pixelSize: Style.font.caption
          }
        }

        ToggleSwitch {
          id: dndSwitch
          checked: root.dnd
          foreground: root.colForeground
          onToggled: {
            if (root.notificationService)
              root.notificationService.setDoNotDisturb(!root.dnd)
          }

          PanelToolTip {
            visible: dndSwitch.containsMouse
            text: root.dnd ? "Turn Do Not Disturb off" : "Turn Do Not Disturb on"
            fontFamily: root.bar ? root.bar.fontFamily : ""
          }
        }
      }

      // ----------------------------------------- unified list
      Flickable {
        id: scrollArea
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        visible: root.totalCount > 0

        Column {
          id: listColumn
          width: scrollArea.width
          spacing: Style.space(8)

          Repeater {
            model: root.notificationService ? root.notificationService.pendingModel : null

            delegate: NotificationRow {
              pendingRow: true
              width: listColumn.width
            }
          }

          Repeater {
            model: root.notificationService ? root.notificationService.pastModel : null

            delegate: NotificationRow {
              pendingRow: false
              width: listColumn.width
            }
          }
        }
      }

      // ----------------------------------------- empty state
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.totalCount === 0

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
        visible: root.totalCount > 0
        spacing: Style.space(8)

        FooterAction {
          Layout.fillWidth: true
          text: "Mark all as read"
          enabled: root.pendingCount > 0
          onClicked: {
            if (root.notificationService) root.notificationService.markAllSeen()
          }
        }

        FooterAction {
          Layout.fillWidth: true
          text: "Clear"
          onClicked: root.clearAllNotifications()
        }
      }
    }
  }

  component NotificationRow: BorderSurface {
    id: rowCard

    required property int index
    required property string app
    required property string appIcon
    required property string summary
    required property string body
    required property string image
    required property int urgency
    required property double timestamp
    property bool pendingRow: false

    readonly property bool hasMedia: image.length > 0 && (
      image.indexOf("image://icon//") === 0 || image.indexOf("file://") === 0)
    readonly property string smallIconSource: image.length > 0 ? image : root.notificationIconSource(appIcon)
    readonly property bool hasIcon: !hasMedia && smallIconSource.length > 0
    readonly property string sanitizedBody: root.sanitizeBody(body, app, appIcon)

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
        visible: (rowCard.hasIcon || rowCard.hasMedia) && rowIconImage.status !== Image.Error

        Image {
          id: rowIconImage
          anchors.fill: parent
          source: rowCard.hasMedia ? rowCard.image : rowCard.smallIconSource
          fillMode: rowCard.hasMedia ? Image.PreserveAspectCrop : Image.PreserveAspectFit
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
            visible: rowCard.summary.length > 0
            text: rowCard.summary
            font.family: root.bar ? root.bar.fontFamily : ""
            color: root.colForeground
            font.pixelSize: Style.font.subtitle
            font.bold: rowCard.pendingRow
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          Rectangle {
            visible: rowCard.pendingRow
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
          onClicked: {
            if (!root.notificationService) return
            if (rowCard.pendingRow) root.notificationService.dismissPending(rowCard.index)
            else root.notificationService.dismissPast(rowCard.index)
          }
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
    color: actionArea.containsMouse && enabled ? root.colBorder : "transparent"
    borderSpec: Border.flat(root.colBorder, Style.normalBorderWidth)
    opacity: enabled ? 1 : 0.45

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
