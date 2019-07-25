Sub Main ()
    displayMainUI ()
End Sub

'
' UI component for the top-level menu
'
Function displayMainUI () As Void
    contentList = [
        {ShortDescriptionLine1: "Dump the whole registry"},
        {ShortDescriptionLine1: "Wipe the whole registry"},
        {ShortDescriptionLine1: "Delete an individual section"},
    ]
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roPosterScreen")
    ui.SetMessagePort (port)
    ui.SetListStyle ("flat-category")
    ui.SetContentList (contentList)
    ui.Show ()
    While True
        msg = Wait (0, port)
        If Type (msg) = "roPosterScreenEvent"
            If msg.IsScreenClosed ()
                Exit While
            Else If msg.IsListItemSelected ()
                index = msg.GetIndex ()
                If index = 0
                    dumpRegistryUI ()
                Else If index = 1
                    wipeRegistryUI ()
                Else If index = 2
                    deleteSectionUI ()
                EndIf
            EndIf
        EndIf
    End While
End Function

'
' UI component for dumping the entire registry
'
Function dumpRegistryUI () As Void
    regText = getRegText ()
    If regText = ""
        displayMessage ("Registry is empty")
    Else
        port = CreateObject ("roMessagePort")
        ui = CreateObject ("roTextScreen")
        ui.SetMessagePort (port)
        ui.SetText (fixup (regText))    ' Use fw3.1 bug workaround
        ui.AddButton (0, "Quit")
        ui.Show ()
        While True
            msg = Wait (0, port)
            If Type (msg) = "roTextScreenEvent"
                If msg.IsScreenClosed ()
                    Exit While
                Else If msg.IsButtonPressed ()
                    ui.Close ()
                EndIf
            EndIf
        End While
    EndIf
End Function

'
'  UI component for deleting the entire registry
'
Function wipeRegistryUI () As Void
    If confirmUI ("Wipe Registry", "Select 'Wipe Registry' to delete the entire registry")
        deleteReg ("")  ' Delete all sections
    EndIf
End Function

'
' UI component for deleting an individual registry section
'
Function deleteSectionUI () As Void
    regSectionList = getRegSectionList ()
    If regSectionList.Count () = 0
        displayMessage ("Registry is empty")
    Else
        contentList = []
        For Each section In regSectionList
            If section.keyCount = 0
                keyCountStr = "No keys in section"
            Else If section.keyCount = 1
                keyCountStr = "1 key in section"
            Else
                keyCountStr = section.keyCount.ToStr () + " keys in section"
            EndIf
            contentList.Push ({Title: section.name, ShortDescriptionLine1: keyCountStr})
        End For
        port = CreateObject ("roMessagePort")
        ui = CreateObject ("roListScreen")
        ui.SetMessagePort (port)
        ui.SetupBehaviorAtTopRow ("exit")   ' Give fw3.1 users a way back
        ui.SetHeader ("Press 'OK' to delete section")
        ui.SetContent (contentList)
        ui.Show ()
        While True
            msg = Wait (0, port)
            If Type (msg) = "roListScreenEvent"
                If msg.IsScreenClosed ()
                    Exit While
                Else If msg.IsListItemSelected ()
                    section = contentList [msg.GetIndex ()].Title
                    If confirmUI ("Delete Section", "Select 'Delete Section' to delete the " + section + " section")
                        deleteReg (section)
                        ui.Close ()
                    EndIf
                EndIf
            EndIf
        End While
    EndIf
End Function

'
' Return a list of all registry sections and the number of keys in each section
'
Function getRegSectionList () As Object
    regSectionList = []
    r = CreateObject ("roRegistry")
    For Each section In r.GetSectionList ()
        rs = CreateObject ("roRegistrySection", section)
        regSectionList.Push ({name: section, keyCount: rs.GetKeyList ().Count ()})
    End For
    Return regSectionList
End Function

'
' Get the contents of a registry section as a text string
'
Function getRegTextSection (sectionName = "" As String) As String
    regText = "Registry Section: " + sectionName + LF ()
    rs = CreateObject ("roRegistrySection", sectionName)
    For Each key In rs.GetKeyList ()
        regText = regText + "    " + key + ": " + rs.Read (key) + LF ()
    End For
    Return regText
End Function

'
' Get the contents of a registry or registry section as a text string
'
Function getRegText (sectionName = "" As String) As String
    regText = ""
    If sectionName = ""
        r = CreateObject ("roRegistry")
        For Each section In r.GetSectionList ()
            regText = regText + getRegTextSection (section) + LF ()
        End For
    Else
        regText = regText + getRegTextSection (sectionName)
    Endif
    Return regText
End Function

'
' Roku 3.1 firmware roTextScreen bug workaround (buttons don't work unless enough text to scroll)
'
Function fixup (regText As String) As String
    fixedText = regText
    lfCount = 0
    ' Count the number of line-ending characters
    For i = 1 To Len (regText)
        If Mid (regText, i, 1) = LF () Then lfCount = lfCount + 1
    End For
    ' Ensure there are at least 18 lines to guarantee a scroll bar appears
    If lfCount < 18 Then fixedText = fixedText + String (18 - lfCount, LF ())
    Return fixedText
End Function

'
' Delete the entire registry or an individual registry section
'
Function deleteReg (section = "" As String) As Void
    r = CreateObject ("roRegistry")
    If section = ""
        For Each regSection In r.GetSectionList ()
            r.Delete (regSection)
        End For
    Else
        r.Delete (section)
    Endif
    r.Flush ()
End Function

'
' Display a confirmation before an irreversible action
'
Function confirmUI (buttonText As String, buttonDesc As String) As Boolean
    confirm = False
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roMessageDialog")
    ui.SetMessagePort (port)
    ui.SetTitle ("DANGER -- This Action Cannot Be Undone")
    ui.SetText ("Select 'Cancel' to go back")
    ui.SetText (buttonDesc)
    ui.AddButton (0, "Cancel")
    ui.AddButton (1, buttonText)
    ui.Show ()
    While True
        msg = Wait (0, port)
        If Type (msg) = "roMessageDialogEvent"
            If msg.IsScreenClosed ()
                Exit While
            Else If msg.IsButtonPressed ()
                If msg.GetIndex () = 1
                    confirm = True
                EndIf
                ui.Close ()
            EndIf
        EndIf
    End While
    Return confirm
End Function

'
' Display an informational message
'
Function displayMessage (text As String) As Void
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roMessageDialog")
    ui.SetMessagePort (port)
    ui.SetTitle (text)
    ui.AddButton (0, "OK")
    ui.Show ()
    While True
        msg = Wait (0, port)
        If Type (msg) = "roMessageDialogEvent"
            If msg.IsScreenClosed ()
                Exit While
            Else If msg.IsButtonPressed ()
                ui.Close ()
            EndIf
        EndIf
    End While
End Function

'
' Line-ending character to use in a text string
'
Function LF () As String : Return Chr (10) : End Function
